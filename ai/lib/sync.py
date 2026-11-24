import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

import agents
import model
import rules
import writer
from agents.common import RenderError
from report import Report, usage_error

USAGE = "usage: ai/sync-ai.sh [--check | --clean] <claude|opencode|antigravity|all>..."
AI_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = AI_DIR.parent
VERSION = re.compile(r"\d+\.\d+\.\d+")
VERSION_TIMEOUT_SECONDS = 15


class UsageError(Exception):
    pass


@dataclass(frozen=True)
class Request:
    mode: str
    agents: tuple[str, ...]


def _agents(names: list[str]) -> tuple[str, ...]:
    if not names:
        raise UsageError("name at least one agent")

    chosen: list[str] = []

    for name in names:
        match name:
            case "all":
                candidates = list(model.AGENTS)
            case agent if agent in model.AGENTS:
                candidates = [agent]
            case _:
                raise UsageError(f"unknown agent or option: {name}")

        for candidate in candidates:
            if candidate not in chosen:
                chosen.append(candidate)

    return tuple(chosen)


def parse(argv: list[str]) -> Request:
    match argv:
        case ["--check", *names]:
            return Request("check", _agents(names))
        case ["--clean", *names]:
            return Request("clean", _agents(names))
        case [*names]:
            return Request("sync", _agents(names))


def _installed_version(command: tuple[str, ...]) -> str | None:
    try:
        run = subprocess.run(command, capture_output=True, text=True, timeout=VERSION_TIMEOUT_SECONDS)
    except (OSError, subprocess.TimeoutExpired):
        return None

    found = VERSION.search(run.stdout + run.stderr)

    if found is None:
        return None

    return found.group(0)


def check_version(agent: str, report: Report) -> None:
    agent_module = agents.module(agent)
    program = agent_module.VERSION_COMMAND[0]

    if shutil.which(program) is None:
        report.warn(f"{agent} is not installed ({program} is not on PATH); its files are generated anyway")
        return

    version = _installed_version(agent_module.VERSION_COMMAND)

    if version is None:
        report.warn(f"could not read the {agent} version from: {' '.join(agent_module.VERSION_COMMAND)}")
        return

    if version != agent_module.TESTED_VERSION:
        report.warn(
            f"{agent} {version} is installed; this setup was tested with {agent_module.TESTED_VERSION}",
            "run the live acceptance (README: AI agents) and update TESTED_VERSION in ai/lib/agents/",
        )


def validate(agent: str, report: Report) -> None:
    validator = getattr(agents.module(agent), "validate", None)

    if validator is not None:
        validator(REPO_ROOT, report)


def _render(source: model.Source, request: Request, report: Report) -> dict[str, writer.Plan] | None:
    plans: dict[str, writer.Plan] = {}

    for agent in request.agents:
        try:
            plans[agent] = agents.module(agent).render(source, REPO_ROOT)
        except RenderError as error:
            report.error(str(error))

    if report.has_errors():
        return None

    return plans


def _shared_rules(mode: str, plan: writer.Plan, workspace: writer.Workspace, state: writer.State) -> None:
    agent_synced = any(state.is_synced(agent) for agent in model.AGENTS)

    match mode:
        case "sync":
            writer.sync(workspace, plan, state)
        case "check":
            writer.check(workspace, plan, state)
        case "clean" if not agent_synced:
            writer.clean(workspace, plan.agent, plan.owned, state)
        case "clean":
            workspace.report.ok(f"{plan.agent}: kept; other agents are still synced")


def run(request: Request, source: model.Source, report: Report) -> None:
    plans = _render(source, request, report)

    if plans is None:
        return

    state = writer.State(REPO_ROOT)
    workspace = writer.Workspace(REPO_ROOT, report)

    for agent, plan in plans.items():
        match request.mode:
            case "sync":
                check_version(agent, report)
                writer.sync(workspace, plan, state)
                validate(agent, report)
            case "check":
                writer.check(workspace, plan, state)
            case "clean":
                writer.clean(workspace, agent, plan.owned, state)

    _shared_rules(request.mode, rules.render(source), workspace, state)

    if request.mode != "check":
        state.save()


def main(argv: list[str]) -> int:
    try:
        request = parse(argv)
    except UsageError as error:
        return usage_error(str(error), USAGE)

    report = Report()

    try:
        source = model.load(AI_DIR)
    except model.SourceError as error:
        for problem in error.problems:
            report.error(problem)

        report.summary()

        return 1

    report.ok(
        f"source: {len(source.commands)} commands, {len(source.skills)} skills, "
        f"{len(source.servers)} MCP servers, {len(source.hooks)} hooks"
    )
    run(request, source, report)
    report.summary()

    if report.has_errors():
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
