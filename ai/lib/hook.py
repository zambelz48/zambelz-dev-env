import sys

from report import usage_error

USAGE = (
    "usage: ai/hook.sh <agent> <event>\n"
    "  claude       PreToolUse | PostToolUse\n"
    "  opencode     execute.before | execute.after\n"
    "  antigravity  PreToolUse | PostToolUse | PreInvocation"
)
EVENTS = {
    "claude": ("PreToolUse", "PostToolUse"),
    "opencode": ("execute.before", "execute.after"),
    "antigravity": ("PreToolUse", "PostToolUse", "PreInvocation"),
}


def main(argv: list[str]) -> int:
    match argv:
        case [agent, event] if event in EVENTS.get(agent, ()):
            print(f"ERROR: zambelz-dev-env hook for {agent} {event} is not implemented", file=sys.stderr)

            return 2
        case _:
            return usage_error("expected an agent and one of its events", USAGE)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
