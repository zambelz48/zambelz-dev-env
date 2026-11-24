import shutil
import subprocess
from collections.abc import Callable
from pathlib import Path

import decode
import events
import tools
from agents.common import HOOK_TIMEOUT_SECONDS, base_dir, command_as_skill, shell_hook_command, skill_files, subscribes
from decode import DecodeError
from events import Decision, Event
from hookio import PendingQueue, Reply, joined, json_reply
from model import Source, commands_without_skill, resolve_server
from report import Report
from writer import Output, Plan, json_bytes

NAME = "antigravity"
TESTED_VERSION = "1.5.16"
VERSION_COMMAND = ("agy", "--version")
PLUGIN = "zambelz-dev-env"
PLUGIN_DIR = f".agents/plugins/{PLUGIN}/"
OWNED = (PLUGIN_DIR,)
PLUGIN_VERSION = "1.0.0"
VALIDATE_TIMEOUT_SECONDS = 60


def _handler(repo_root: Path, event: str) -> dict:
    return {
        "type": "command",
        "command": shell_hook_command(repo_root, NAME, event),
        "timeout": HOOK_TIMEOUT_SECONDS,
    }


def _tool_group(repo_root: Path, event: str) -> list[dict]:
    return [
        {
            "matcher": f"^({tools.matcher(NAME)})$",
            "hooks": [_handler(repo_root, event)],
        },
    ]


def _hooks(source: Source, repo_root: Path) -> dict:
    events: dict = {}

    if subscribes(source, "tool.before"):
        events["PreToolUse"] = _tool_group(repo_root, "PreToolUse")

    if subscribes(source, "tool.after"):
        events["PostToolUse"] = _tool_group(repo_root, "PostToolUse")
        events["PreInvocation"] = [_handler(repo_root, "PreInvocation")]

    return {PLUGIN: events}


def _server(server: dict) -> dict:
    resolved = resolve_server(server, NAME)
    override = server.get(NAME) or {}

    match resolved.get("type"):
        case "http":
            translated: dict = {
                "url": resolved["url"],
            }

            if override.get("headers"):
                translated["headers"] = override["headers"]

            return translated
        case "stdio":
            translated = {
                "command": resolved["command"],
            }

            if resolved.get("args"):
                translated["args"] = resolved["args"]

            if resolved.get("env"):
                translated["env"] = resolved["env"]

            return translated
        case other:
            raise ValueError(f"unsupported server type {other!r}")


def render(source: Source, repo_root: Path) -> Plan:
    manifest = {
        "name": PLUGIN,
        "version": PLUGIN_VERSION,
    }
    files: dict[str, Output] = {
        f"{PLUGIN_DIR}plugin.json": Output(json_bytes(manifest)),
    }

    for skill in source.skills:
        files.update(skill_files(skill, f"{PLUGIN_DIR}skills"))

    for command in commands_without_skill(source):
        files[f"{PLUGIN_DIR}skills/{command.name}/SKILL.md"] = Output(command_as_skill(command))

    if source.servers:
        servers = {name: _server(server) for name, server in sorted(source.servers.items())}
        files[f"{PLUGIN_DIR}mcp_config.json"] = Output(json_bytes({"mcpServers": servers}))

    if source.hooks:
        files[f"{PLUGIN_DIR}hooks.json"] = Output(json_bytes(_hooks(source, repo_root)))

    return Plan(agent=NAME, files=files, owned=OWNED)


def validate(repo_root: Path, report: Report) -> None:
    plugin = repo_root / PLUGIN_DIR

    if shutil.which("agy") is None or not plugin.is_dir():
        return

    try:
        run = subprocess.run(
            ["agy", "plugin", "validate", "--strict", str(plugin)],
            capture_output=True,
            text=True,
            timeout=VALIDATE_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        report.error(f"antigravity: agy plugin validate could not run: {error}")
        return

    if run.returncode != 0:
        report.error(
            f"antigravity: agy plugin validate --strict failed:\n{run.stdout}{run.stderr}",
            f"fix the source under ai/, then run ai/sync-ai.sh {NAME}",
        )
        return

    report.ok("antigravity: agy plugin validate --strict passed")


KIND_FOR = {
    "PreToolUse": events.BEFORE,
    "PostToolUse": events.AFTER,
}


def _inject(queue: PendingQueue) -> Reply:
    warnings = queue.take()

    if not warnings:
        return json_reply({})

    return json_reply(
        {
            "injectSteps": [
                {
                    "systemMessage": {
                        "systemMessage": joined(tuple(warnings)),
                    },
                },
            ],
        }
    )


def hook(event_name: str, payload: dict, repo_root: Path, run_hooks: Callable[[list[Event]], Decision]) -> Reply:
    queue = PendingQueue(repo_root, payload.get("conversationId"))

    if event_name == "PreInvocation":
        return _inject(queue)

    call = payload.get("toolCall")

    if not isinstance(call, dict):
        raise DecodeError("the payload has no 'toolCall' object")

    base = base_dir(payload.get("cwd"), repo_root)
    event = decode.tool_event(KIND_FOR[event_name], NAME, call.get("name"), call.get("args"), repo_root, base)
    decision = run_hooks([event])

    match event_name:
        case "PreToolUse" if decision.deny:
            return json_reply(
                {
                    "decision": "deny",
                    "reason": decision.deny,
                }
            )
        case "PreToolUse":
            return Reply()
        case "PostToolUse":
            if decision.warnings:
                queue.add(decision.warnings)

            return json_reply({})


def failure(event_name: str) -> Reply:
    match event_name:
        case "PreInvocation":
            return json_reply({})
        case _:
            return Reply(exit_code=2)
