import json
import os
import sys
from pathlib import Path

import ghapi
import inventory
import procs
from catalog import Catalog, CatalogError
from model import Exit, Problem

USAGE = "usage: audit inventory [--declared | --installed] [--json]"


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


def main(argv: list[str]) -> int:
    match argv:
        case ["inventory", "--declared" | "--installed" as scope]:
            return run_inventory(scope, False)
        case ["inventory", "--declared" | "--installed" as scope, "--json"]:
            return run_inventory(scope, True)
        case _:
            print(USAGE, file=sys.stderr)
            return Exit.USAGE


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
