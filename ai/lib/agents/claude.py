from pathlib import Path

import tools
from agents.common import HOOK_TIMEOUT_SECONDS, command_markdown, shell_hook_command, skill_files, subscribes
from model import Source, resolve_server
from writer import Output, Plan, json_bytes

NAME = "claude"
TESTED_VERSION = "2.1.330"
VERSION_COMMAND = ("claude", "--version")
OWNED = (".claude/settings.json", ".claude/commands/", ".claude/skills/", ".mcp.json")
EVENT_FOR = {
    "tool.before": "PreToolUse",
    "tool.after": "PostToolUse",
}


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

    for command in source.commands:
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
