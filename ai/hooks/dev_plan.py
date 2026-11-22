import re
from pathlib import Path

import events
from events import Decision, Event, TextEdit
from tools import ToolKind

PLAN_NAME = re.compile(r"PLAN-.+\.md")
PLAN_IN_PATCH = re.compile(r"dev-plan/PLAN-[^\s]*\.md")
RULE_PHRASES = ("Adhere to AGENTS.md", "Mark completed tasks", "Work phase by phase")
PHASE_HEADING = re.compile(r"## Phase \d+\b.*")
TASK = re.compile(r"\s*- \[( |x)\] .*")
BAD_CHECKBOX = re.compile(r"\s*(- \[\]|- \[X\]|\* \[ \]).*")
FENCE = re.compile(r"\s*(```|~~~)")
FORMAT_HINT = "Fix the listed items and write the file again (the create-dev-plan skill describes the format)."


def _is_plan(event: Event) -> bool:
    if event.path is None:
        return False

    return event.path.parent == event.repo_root / "dev-plan" and PLAN_NAME.fullmatch(event.path.name) is not None


def _sections(text: str) -> list[tuple[str, list[str]]]:
    sections: list[tuple[str, list[str]]] = [("", [])]
    fenced = False

    for line in text.splitlines():
        if FENCE.match(line):
            fenced = not fenced

        if not fenced and line.startswith("## "):
            sections.append((line, []))
            continue

        sections[-1][1].append(line)

    return sections


def _unfenced(lines: list[str]) -> list[str]:
    kept: list[str] = []
    fenced = False

    for line in lines:
        if FENCE.match(line):
            fenced = not fenced
            continue

        if not fenced:
            kept.append(line)

    return kept


def problems(text: str) -> list[str]:
    found: list[str] = []
    sections = _sections(text)
    headings = [heading for heading, _ in sections]
    rules = [body for heading, body in sections if heading.strip() == "## MANDATORY RULES"]
    phases = [(heading, body) for heading, body in sections if PHASE_HEADING.fullmatch(heading.strip())]

    if not rules:
        found.append("missing the '## MANDATORY RULES' section")

    if "## Overview" not in [heading.strip() for heading in headings]:
        found.append("missing the '## Overview' section")

    if not phases:
        found.append("missing a '## Phase <n>' section")

    rules_text = "\n".join(line for body in rules for line in body).lower()

    for phrase in RULE_PHRASES:
        if rules and phrase.lower() not in rules_text:
            found.append(f"the MANDATORY RULES section does not say '{phrase}'")

    for heading, body in phases:
        if not any(TASK.fullmatch(line) for line in _unfenced(body)):
            found.append(f"'{heading.strip()}' has no '- [ ]' or '- [x]' task")

    for number, line in enumerate(text.splitlines(), start=1):
        if BAD_CHECKBOX.fullmatch(line):
            found.append(f"line {number} uses an invalid checkbox; write '- [ ]' or '- [x]'")

    return found


def _apply(text: str, edit: TextEdit) -> str | None:
    if not edit.old or edit.old not in text:
        return None

    if edit.replace_all:
        return text.replace(edit.old, edit.new)

    return text.replace(edit.old, edit.new, 1)


def _rebuild(path: Path, edits: tuple[TextEdit, ...]) -> str | None:
    if not path.is_file():
        return None

    text: str | None = path.read_text()

    for edit in edits:
        if text is None:
            return None

        text = _apply(text, edit)

    return text


def _relative(event: Event) -> str:
    return str(event.path.relative_to(event.repo_root))


def _check(event: Event, text: str) -> Decision | None:
    found = problems(text)

    if not found:
        return None

    listing = "\n".join(f"- {problem}" for problem in found)

    return events.deny(f"Blocked: {_relative(event)} does not follow the plan format:\n{listing}\n{FORMAT_HINT}")


def _edit(event: Event) -> Decision | None:
    text = _rebuild(event.path, event.edits)

    if text is None:
        return events.deny(
            f"Blocked: this edit to {_relative(event)} cannot be checked: the text to replace was not found "
            "verbatim, or the file does not exist. Re-read the file and retry with an exact match, or write the whole file."
        )

    return _check(event, text)


def handle(event: Event) -> Decision | None:
    if event.kind != events.BEFORE:
        return None

    match event.tool_kind:
        case ToolKind.WRITE if _is_plan(event):
            return _check(event, event.content or "")
        case ToolKind.EDIT | ToolKind.MULTI_EDIT if _is_plan(event):
            return _edit(event)
        case ToolKind.PATCH if PLAN_IN_PATCH.search(event.patch):
            return events.deny("Blocked: do not change dev-plan/PLAN-*.md files with a patch tool; use the write or edit tool.")
        case ToolKind.PATH_ONLY if _is_plan(event):
            return events.deny(f"Blocked: {event.tool} cannot be checked on {_relative(event)}; use the write or edit tool.")
        case _:
            return None
