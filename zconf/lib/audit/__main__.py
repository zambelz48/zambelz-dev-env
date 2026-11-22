import json
import os
import sys
from pathlib import Path

import catalog_check
import ghapi
import inventory
import procs
import webapi
from catalog import Catalog, CatalogError
from model import Exit, Problem

USAGE = "usage: audit inventory [--declared | --installed] [--json]\n       audit catalog [--verify]"


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


def main(argv: list[str]) -> int:
    match argv:
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


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
