import json
from collections.abc import Callable
from pathlib import Path

import decode
import events
import tools
from agents.common import base_dir, command_markdown, hook_script, skill_files, subscribes
from decode import DecodeError
from events import Decision, Event
from hookio import Reply, json_reply
from model import Command, Source, resolve_server
from writer import Output, Plan, json_bytes

NAME = "opencode"
TESTED_VERSION = "2.2.7"
VERSION_COMMAND = ("opencode", "--version")
PLUGIN_DIR = ".opencode/plugins/zambelz-dev-env/"
CONFIG_FILE = "opencode.json"
OWNED = (CONFIG_FILE, ".opencode/commands/", ".opencode/skills/", PLUGIN_DIR)
TEMPLATE = Path(__file__).resolve().parent.parent / "templates" / "opencode_plugin.ts"
SCHEMA = "https://opencode.ai/config.json"


def _server(server: dict) -> dict:
    resolved = resolve_server(server, NAME)

    match resolved.get("type"):
        case "http":
            translated: dict = {
                "type": "remote",
                "url": resolved["url"],
            }

            if resolved.get("headers"):
                translated["headers"] = resolved["headers"]
                translated["oauth"] = False

            return translated
        case "stdio":
            translated = {
                "type": "local",
                "command": [resolved["command"], *resolved.get("args", [])],
            }

            if resolved.get("env"):
                translated["environment"] = resolved["env"]

            return translated
        case other:
            raise ValueError(f"unsupported server type {other!r}")


def _command(command: Command) -> bytes:
    plain = Command(
        name=command.name,
        description=command.description,
        argument_hint=None,
        body=command.body,
        path=command.path,
    )

    return command_markdown(plain)


def _plugin(source: Source, repo_root: Path) -> bytes:
    replacements = {
        "@@HOOK_SCRIPT@@": json.dumps(str(hook_script(repo_root))),
        "@@TOOLS@@": json.dumps(tools.names(NAME)),
        "@@BEFORE@@": json.dumps(subscribes(source, "tool.before")),
        "@@AFTER@@": json.dumps(subscribes(source, "tool.after")),
    }
    text = TEMPLATE.read_text()

    for token, value in replacements.items():
        text = text.replace(token, value)

    return text.encode()


def render(source: Source, repo_root: Path) -> Plan:
    files: dict[str, Output] = {}

    for command in source.commands:
        files[f".opencode/commands/{command.name}.md"] = Output(_command(command))

    for skill in source.skills:
        files.update(skill_files(skill, ".opencode/skills"))

    if source.servers:
        servers = {name: _server(server) for name, server in sorted(source.servers.items())}
        config = {
            "$schema": SCHEMA,
            "mcp": {
                "servers": servers,
            },
        }
        files[CONFIG_FILE] = Output(json_bytes(config))

    if source.hooks:
        files[f"{PLUGIN_DIR}index.ts"] = Output(_plugin(source, repo_root))

    return Plan(agent=NAME, files=files, owned=OWNED)


KIND_FOR = {
    "execute.before": events.BEFORE,
    "execute.after": events.AFTER,
}


def hook(event_name: str, payload: dict, repo_root: Path, run_hooks: Callable[[list[Event]], Decision]) -> Reply:
    call = payload.get("event")

    if not isinstance(call, dict):
        raise DecodeError("the payload has no 'event' object")

    base = base_dir(payload.get("directory"), repo_root)
    event = decode.tool_event(KIND_FOR[event_name], NAME, call.get("tool"), call.get("input"), repo_root, base)
    decision = run_hooks([event])
    verdict = "none"

    if decision.deny:
        verdict = "deny"

    return json_reply(
        {
            "decision": verdict,
            "message": decision.deny,
            "warnings": list(decision.warnings),
        }
    )


def failure(event_name: str) -> Reply:
    return Reply(exit_code=2)
