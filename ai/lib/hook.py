import json
import sys
from pathlib import Path

import agents
import runner
from decode import DecodeError
from events import Decision, Event
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
AI_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = AI_DIR.parent


def run_hooks(events: list[Event]) -> Decision:
    return runner.run(AI_DIR, events)


def _payload(raw: str) -> dict:
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as error:
        raise DecodeError(f"the payload is not JSON: {error}") from error

    if not isinstance(payload, dict):
        raise DecodeError("the payload is not a JSON object")

    return payload


def handle(agent: str, event: str, raw: str) -> int:
    agent_module = agents.module(agent)

    try:
        reply = agent_module.hook(event, _payload(raw), REPO_ROOT, run_hooks)
    except Exception as error:
        message = f"ERROR: zambelz-dev-env hook failed on {agent} {event} ({type(error).__name__}): {error}"
        reply = agent_module.failure(event)

        print(message, file=sys.stderr)

    sys.stdout.write(reply.stdout)

    return reply.exit_code


def main(argv: list[str]) -> int:
    match argv:
        case [agent, event] if event in EVENTS.get(agent, ()):
            return handle(agent, event, sys.stdin.read())
        case _:
            return usage_error("expected an agent and one of its events", USAGE)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
