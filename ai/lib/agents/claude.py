from collections.abc import Callable
from pathlib import Path

import decode
import tools
from agents.common import HOOK_TIMEOUT_SECONDS, base_dir, command_markdown, shell_hook_command, skill_files, subscribes
from events import Decision, Event
from hookio import Reply, joined, json_reply
from model import Source, commands_without_skill, resolve_server
from writer import Output, Plan, json_bytes

NAME = "claude"
TESTED_VERSION = "2.1.330"
VERSION_COMMAND = ("claude", "--version")
OWNED = (".claude/settings.json", ".claude/commands/", ".claude/skills/", ".mcp.json")
EVENT_FOR = {
    "tool.before": "PreToolUse",
    "tool.after": "PostToolUse",
}
KIND_FOR = {claude_event: kind for kind, claude_event in EVENT_FOR.items()}


def _hook_group(repo_root: Path, event: str) -> dict:
    handler = {
        "type": "command",
        "command": shell_hook_command(repo_root, NAME, event),
        "timeout": HOOK_TIMEOUT_SECONDS,
    }

    if event == "PreToolUse":
        handler["onFailure"] = "block"

    return {
        "matcher": tools.matcher(NAME),
        "hooks": [handler],
    }


def _settings(source: Source, repo_root: Path) -> dict:
    settings: dict = {}

    if source.servers:
        settings["enabledMcpjsonServers"] = sorted(source.servers)

    hooks = {
        claude_event: [_hook_group(repo_root, claude_event)]
        for event, claude_event in EVENT_FOR.items()
        if subscribes(source, event)
    }

    if hooks:
        settings["hooks"] = hooks

    return settings


def render(source: Source, repo_root: Path) -> Plan:
    files: dict[str, Output] = {}

    for command in commands_without_skill(source):
        files[f".claude/commands/{command.name}.md"] = Output(command_markdown(command))

    for skill in source.skills:
        files.update(skill_files(skill, ".claude/skills"))

    if source.servers:
        servers = {name: resolve_server(server, NAME) for name, server in sorted(source.servers.items())}
        files[".mcp.json"] = Output(json_bytes({"mcpServers": servers}))

    settings = _settings(source, repo_root)

    if settings:
        files[".claude/settings.json"] = Output(json_bytes(settings))

    return Plan(agent=NAME, files=files, owned=OWNED)


def hook(event_name: str, payload: dict, repo_root: Path, run_hooks: Callable[[list[Event]], Decision]) -> Reply:
    kind = KIND_FOR[event_name]
    base = base_dir(payload.get("cwd"), repo_root)
    event = decode.tool_event(kind, NAME, payload.get("tool_name"), payload.get("tool_input"), repo_root, base)
    decision = run_hooks([event])

    match event_name:
        case "PreToolUse" if decision.deny:
            return json_reply(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "deny",
                        "permissionDecisionReason": decision.deny,
                    },
                }
            )
        case "PostToolUse" if decision.warnings:
            return json_reply(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PostToolUse",
                        "additionalContext": joined(decision.warnings),
                    },
                }
            )
        case _:
            return Reply()


def failure(event_name: str) -> Reply:
    return Reply(exit_code=2)
