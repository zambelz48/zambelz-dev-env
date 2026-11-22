import json
import os
import re
import sys
import textwrap
from pathlib import Path

import catalog_check
import engine
import ghapi
import inventory
import model
import procs
import webapi
from catalog import Catalog, CatalogError
from model import Exit, Finding, Problem, Result

CRITICAL_SCORE = 9.0
HIGH_SCORE = 7.0
MEDIUM_SCORE = 4.0
WRAP = 100
MAX_LINES = 6
DNF_SOURCE = "dnf security advisories"

AUDIT_OPTIONS = {"--json", "--gate"}
USAGE = (
    "usage: audit audit [--declared | --installed | --all] [--json] [--gate]\n"
    "       audit inventory [--declared | --installed] [--json]\n"
    "       audit catalog [--verify]"
)
SCOPES = {
    "--declared": ("declared",),
    "--installed": ("installed",),
    "--all": ("declared", "installed"),
}


def repo_root() -> Path:
    return Path(os.environ.get("ZC_ROOT") or Path(__file__).resolve().parents[3])


def paths() -> inventory.Paths:
    return inventory.Paths(repo=repo_root(), home=Path.home(), mise_data=procs.mise_data_dir())


def _problem_text(problem: Problem) -> str:
    subject = ""

    if problem.component is not None:
        subject = f"{problem.component.key()}: "

    return f"{subject}{problem.message}"


def _print_inventory(result: inventory.Inventory, as_json: bool) -> None:
    if as_json:
        data = {
            "components": [
                {
                    "kind": component.kind,
                    "name": component.name,
                    "version": component.version,
                    "origin": component.origin,
                    "scope": component.scope,
                    "locator": component.locator,
                }
                for component in result.components
            ],
            "leftovers": [_problem_text(problem) for problem in result.leftovers],
            "information": [_problem_text(problem) for problem in result.information],
        }
        print(json.dumps(data, indent=2))
        return

    for component in result.components:
        print(f"{component.scope}\t{component.kind}\t{component.name}\t{component.version}")

    for problem in result.leftovers:
        print(f"LEFTOVER\t{_problem_text(problem)}")

    for problem in result.information:
        print(f"INFO\t{_problem_text(problem)}")


def run_inventory(scope: str, as_json: bool) -> int:
    root = paths()

    try:
        catalog = Catalog(root.repo / "zconf/audit/catalog.toml")

        match scope:
            case "--declared":
                result = inventory.declared(root, ghapi.raw_file, catalog.repo)
            case "--installed":
                result = inventory.installed(root)
    except (CatalogError, LookupError, procs.CommandError, ghapi.GitHubError) as error:
        print(f"ERROR: the inventory could not be built: {error}", file=sys.stderr)
        return Exit.COULD_NOT_RUN

    _print_inventory(result, as_json)

    return Exit.CLEAN


def run_catalog(live: bool) -> int:
    root = paths()

    try:
        catalog = Catalog(root.repo / "zconf/audit/catalog.toml")
        declared = inventory.declared(root, ghapi.raw_file, catalog.repo)
        installed = inventory.installed(root)
        components = [*declared.components, *installed.components]
        managers = inventory.os_managers(root.repo)

        match live:
            case True:
                result = catalog_check.verify(catalog, components, managers)
            case False:
                result = catalog_check.coverage(catalog, components, managers)
    except (CatalogError, LookupError, procs.CommandError, ghapi.GitHubError, webapi.WebError) as error:
        print(f"ERROR: the catalog could not be checked: {error}", file=sys.stderr)
        return Exit.COULD_NOT_RUN

    for line in result.not_covered:
        print(f"NOT COVERED: {line}")

    for line in result.problems:
        print(f"ERROR: {line}")

    for line in result.unused:
        print(f"WARN: unused catalog entry {line}")

    print(
        f"Summary: {len(components)} components, {result.checked} sources verified, "
        f"{len(result.not_covered)} not covered, {len(result.problems)} problems, {len(result.unused)} unused"
    )

    if result.not_covered or result.problems:
        return Exit.FINDINGS

    return Exit.CLEAN


def _finding_json(finding: Finding, failing: list[Finding]) -> dict:
    return {
        "component": finding.component.key(),
        "origin": finding.component.origin,
        "scope": finding.component.scope,
        "source": finding.source,
        "id": finding.id,
        "aliases": list(finding.aliases),
        "summary": finding.summary,
        "fixed_in": list(finding.fixed_in),
        "severity": finding.severity,
        "dev_only": finding.dev_only,
        "severity_level": severity_level(finding.severity),
        "notice": finding.notice,
        "failing": finding in failing,
        "status": finding.status,
        "action": finding.action,
        "url": finding.url,
        "package": finding.package,
    }


def _problem_json(problem: Problem) -> dict:
    subject = None

    if problem.component is not None:
        subject = problem.component.key()

    return {
        "component": subject,
        "source": problem.source,
        "message": problem.message,
        "fix": problem.fix,
    }


def severity_level(raw: str) -> str:
    text = (raw or "").strip().lower()
    score = re.search(r"([0-9]+(?:\.[0-9]+)?)", text)

    match text:
        case "critical" | "high" | "low":
            return text
        case "important":
            return "high"
        case "moderate" | "medium":
            return "medium"
        case _ if score is not None:
            return _level_for_score(float(score.group(1)))
        case _:
            return "unscored"


def _level_for_score(score: float) -> str:
    if score >= CRITICAL_SCORE:
        return "critical"

    if score >= HIGH_SCORE:
        return "high"

    if score >= MEDIUM_SCORE:
        return "medium"

    return "low"


def _label(finding: Finding, failing: bool) -> str:
    if not failing:
        reason = finding.notice or "dev-only"
        return f"INFO ({reason})"

    match finding.status:
        case model.FIX_AVAILABLE:
            return "FINDING (fix available, blocks push)"
        case model.WAITING:
            return "FINDING (waiting for upstream)"
        case _:
            return "FINDING (blocks push)"


def _action(finding: Finding) -> str:
    if finding.action:
        return finding.action

    if finding.source == DNF_SOURCE:
        return f"sudo dnf upgrade --advisory={finding.id}"

    return "fix it at the source (the fix-cve skill), then run the audit again"


def _print_finding(finding: Finding, failing: bool) -> None:
    aliases = ""
    severity = severity_level(finding.severity)
    fixed = "no fixed version published yet"

    if finding.aliases:
        aliases = f" / {' / '.join(finding.aliases)}"

    if severity != finding.severity.lower():
        severity = f"{severity} ({finding.severity})"

    if finding.fixed_in:
        fixed = f"fixed in {', '.join(finding.fixed_in)}"

    print(f"{_label(finding, failing)}: {finding.component.key()} [{finding.component.origin}]")
    print(f"  {finding.id}{aliases}, {severity}")

    if finding.package:
        print(f"  Library: {finding.package}, {fixed}")

    if finding.summary:
        text = " ".join(finding.summary.split())
        print(textwrap.fill(f"What: {text}", width=WRAP, initial_indent="  ", subsequent_indent="        ", max_lines=MAX_LINES))

    if finding.notice and failing:
        print(f"  Notice: {finding.notice}")

    if failing:
        print(f"  Action: {_action(finding)}")

    if finding.url:
        print(f"  More: {finding.url}")

    print(f"  Source: {finding.source}")


def print_report(result: Result) -> None:
    failing = result.failing_findings()
    blocking = result.blocking_findings()

    def order(item: Finding) -> tuple:
        return (item not in failing, item not in blocking, item.component.key(), item.id)

    for finding in sorted(result.findings, key=order):
        _print_finding(finding, finding in failing)

    for problem in result.not_covered:
        print(f"NOT COVERED: {_problem_text(problem)}")

    for problem in result.leftovers:
        fix = ""

        if problem.fix:
            fix = f" (fix: {problem.fix})"

        print(f"LEFTOVER: {_problem_text(problem)}{fix}")

    for problem in result.could_not_run:
        print(f"COULD NOT RUN: {_problem_text(problem)} [{problem.source}]")

    for problem in result.information:
        print(f"INFO: {_problem_text(problem)}")

    affected = {finding.component.key() for finding in failing}
    waiting = len(failing) - len(blocking)
    print(
        f"Summary: {len(result.components)} components, {len(failing)} findings in {len(affected)} components "
        f"({len(blocking)} block pushes, {waiting} waiting for upstream), "
        f"{len(result.findings) - len(failing)} not failing (dev-only, unmaintained, or not in what ships), "
        f"{len(result.not_covered)} not covered, {len(result.leftovers)} leftovers, "
        f"{len(result.could_not_run)} could not run"
    )


def report_json(result: Result) -> str:
    return json.dumps(
        {
            "exit": int(result.exit_code()),
            "gate_exit": int(result.exit_code(gate=True)),
            "components": len(result.components),
            "findings": [_finding_json(finding, result.failing_findings()) for finding in result.findings],
            "not_covered": [_problem_json(problem) for problem in result.not_covered],
            "leftovers": [_problem_json(problem) for problem in result.leftovers],
            "could_not_run": [_problem_json(problem) for problem in result.could_not_run],
            "information": [_problem_json(problem) for problem in result.information],
        },
        indent=2,
    )


def run_audit(flag: str, options: set[str]) -> int:
    as_json = "--json" in options
    gate = "--gate" in options
    root = paths()
    collected = inventory.Inventory()

    try:
        catalog = Catalog(root.repo / "zconf/audit/catalog.toml")
        problems = catalog.problems()

        for scope in SCOPES[flag]:
            match scope:
                case "declared":
                    part = inventory.declared(root, ghapi.raw_file, catalog.repo)
                case "installed":
                    part = inventory.installed(root)

            collected.components.extend(part.components)
            collected.leftovers.extend(part.leftovers)
            collected.information.extend(part.information)
    except (CatalogError, LookupError, OSError, procs.CommandError, ghapi.GitHubError) as error:
        print(f"ERROR: the inventory could not be built: {error}", file=sys.stderr)
        return Exit.COULD_NOT_RUN

    result = engine.Engine(catalog, root.repo).run(collected.components)
    result.leftovers.extend(collected.leftovers)
    result.information.extend(collected.information)
    result.could_not_run.extend(Problem(None, "catalog", problem) for problem in problems)

    if as_json:
        print(report_json(result))
    else:
        print_report(result)

    return result.exit_code(gate=gate)


def main(argv: list[str]) -> int:
    match argv:
        case ["audit", "--declared" | "--installed" | "--all" as flag, *options] if set(options) <= AUDIT_OPTIONS:
            return run_audit(flag, set(options))
        case ["inventory", "--declared" | "--installed" as scope]:
            return run_inventory(scope, False)
        case ["inventory", "--declared" | "--installed" as scope, "--json"]:
            return run_inventory(scope, True)
        case ["catalog"]:
            return run_catalog(False)
        case ["catalog", "--verify"]:
            return run_catalog(True)
        case _:
            print(USAGE, file=sys.stderr)
            return Exit.USAGE
