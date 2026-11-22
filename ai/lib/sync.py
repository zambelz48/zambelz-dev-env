import sys
from dataclasses import dataclass
from pathlib import Path

import model
from report import Report, usage_error

USAGE = "usage: ai/sync-ai.sh [--check | --clean] <claude|opencode|antigravity|all>..."
AI_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = AI_DIR.parent


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
    report.summary()

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
