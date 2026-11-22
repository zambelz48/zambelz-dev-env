import json
from pathlib import Path

import tools
from agents.common import command_markdown, hook_script, skill_files, subscribes
from model import Command, Source, resolve_server
from writer import Output, Plan, json_bytes

NAME = "opencode"
TESTED_VERSION = "2.2.7"
VERSION_COMMAND = ("opencode", "--version")
PLUGIN_DIR = ".opencode/plugins/zambelz-dev-env/"
OWNED = (".opencode/opencode.json", ".opencode/commands/", ".opencode/skills/", PLUGIN_DIR)
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
        files[".opencode/opencode.json"] = Output(json_bytes(config))

    if source.hooks:
        files[f"{PLUGIN_DIR}index.ts"] = Output(_plugin(source, repo_root))

    return Plan(agent=NAME, files=files, owned=OWNED)
