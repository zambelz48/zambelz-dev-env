import json
import re
import tomllib
from dataclasses import dataclass
from pathlib import Path

import frontmatter

AGENTS = ("claude", "opencode", "antigravity")
EVENTS = ("tool.before", "tool.after")
NAME = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")
DESCRIPTION_LIMIT = 1024
SERVER_TYPES = ("http", "stdio")


class SourceError(Exception):
    def __init__(self, problems: list[str]):
        super().__init__("\n".join(problems))
        self.problems = problems


@dataclass(frozen=True)
class Command:
    name: str
    description: str
    argument_hint: str | None
    body: str
    path: Path


@dataclass(frozen=True)
class Skill:
    name: str
    description: str
    directory: Path
    files: tuple[Path, ...]


@dataclass(frozen=True)
class HookSpec:
    name: str
    module: str
    events: tuple[str, ...]
    summary: str


@dataclass(frozen=True)
class Source:
    ai_dir: Path
    commands: tuple[Command, ...]
    skills: tuple[Skill, ...]
    servers: dict[str, dict]
    hooks: tuple[HookSpec, ...]


def _check_name(name: str, where: str, problems: list[str]) -> None:
    if not NAME.fullmatch(name):
        problems.append(f"{where}: name '{name}' must match {NAME.pattern}")


def _check_description(description: str | None, where: str, problems: list[str]) -> None:
    if not description:
        problems.append(f"{where}: 'description' is required")
        return

    if len(description) > DESCRIPTION_LIMIT:
        problems.append(f"{where}: 'description' is longer than {DESCRIPTION_LIMIT} characters")


def _load_command(path: Path, problems: list[str]) -> Command | None:
    try:
        document = frontmatter.parse(path.read_text(), str(path))
    except frontmatter.FrontmatterError as error:
        problems.append(str(error))
        return None

    unknown = sorted(set(document.fields) - {"description", "argument-hint"})

    if unknown:
        problems.append(f"{path}: unknown frontmatter keys: {', '.join(unknown)}")

    _check_name(path.stem, str(path), problems)
    _check_description(document.fields.get("description"), str(path), problems)

    return Command(
        name=path.stem,
        description=document.fields.get("description", ""),
        argument_hint=document.fields.get("argument-hint"),
        body=document.body,
        path=path,
    )


def _skill_files(directory: Path) -> tuple[Path, ...]:
    files = [item.relative_to(directory) for item in directory.rglob("*") if item.is_file()]

    return tuple(sorted(files))


def _load_skill(directory: Path, problems: list[str]) -> Skill | None:
    manifest = directory / "SKILL.md"

    if not manifest.is_file():
        problems.append(f"{directory}: missing SKILL.md")
        return None

    try:
        document = frontmatter.parse(manifest.read_text(), str(manifest))
    except frontmatter.FrontmatterError as error:
        problems.append(str(error))
        return None

    name = document.fields.get("name", "")

    if name != directory.name:
        problems.append(f"{manifest}: 'name' must equal the folder name '{directory.name}'")

    _check_name(directory.name, str(manifest), problems)
    _check_description(document.fields.get("description"), str(manifest), problems)

    return Skill(
        name=directory.name,
        description=document.fields.get("description", ""),
        directory=directory,
        files=_skill_files(directory),
    )


def _check_server(name: str, server: object, where: str, problems: list[str]) -> None:
    if not isinstance(server, dict):
        problems.append(f"{where}: server '{name}' must be an object")
        return

    match server.get("type"):
        case "http":
            if not isinstance(server.get("url"), str):
                problems.append(f"{where}: http server '{name}' needs a 'url' string")
        case "stdio":
            if not isinstance(server.get("command"), str):
                problems.append(f"{where}: stdio server '{name}' needs a 'command' string")
        case other:
            problems.append(f"{where}: server '{name}' has type {other!r}; use one of {', '.join(SERVER_TYPES)}")

    for agent in AGENTS:
        override = server.get(agent)

        if override is not None and not isinstance(override, dict):
            problems.append(f"{where}: server '{name}' override '{agent}' must be an object")


def _load_servers(path: Path, problems: list[str]) -> dict[str, dict]:
    if not path.is_file():
        return {}

    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as error:
        problems.append(f"{path}: invalid JSON: {error}")
        return {}

    servers = data.get("mcpServers") if isinstance(data, dict) else None

    if not isinstance(servers, dict):
        problems.append(f"{path}: expected an object with 'mcpServers'")
        return {}

    for name, server in servers.items():
        _check_name(name, str(path), problems)
        _check_server(name, server, str(path), problems)

    return servers


def _load_hook(entry: object, hooks_dir: Path, where: str, problems: list[str]) -> HookSpec | None:
    if not isinstance(entry, dict):
        problems.append(f"{where}: every [[hook]] must be a table")
        return None

    name = entry.get("name", "")
    module = entry.get("module", "")
    events = entry.get("events", [])
    summary = entry.get("summary", "")

    _check_name(str(name), where, problems)

    if not (hooks_dir / f"{module}.py").is_file():
        problems.append(f"{where}: hook '{name}' module '{module}' has no file {hooks_dir / f'{module}.py'}")

    if not isinstance(events, list) or not events:
        problems.append(f"{where}: hook '{name}' needs a non-empty 'events' list")
        events = []

    for event in events:
        if event not in EVENTS:
            problems.append(f"{where}: hook '{name}' has unknown event {event!r}; use {', '.join(EVENTS)}")

    if not summary:
        problems.append(f"{where}: hook '{name}' needs a 'summary'")

    return HookSpec(name=str(name), module=str(module), events=tuple(events), summary=str(summary))


def _load_hooks(hooks_dir: Path, problems: list[str]) -> tuple[HookSpec, ...]:
    path = hooks_dir / "hooks.toml"

    if not path.is_file():
        return ()

    try:
        data = tomllib.loads(path.read_text())
    except tomllib.TOMLDecodeError as error:
        problems.append(f"{path}: invalid TOML: {error}")
        return ()

    entries = data.get("hook", [])
    specs = [_load_hook(entry, hooks_dir, str(path), problems) for entry in entries]
    hooks = tuple(spec for spec in specs if spec is not None)
    names = [hook.name for hook in hooks]

    for name in sorted({name for name in names if names.count(name) > 1}):
        problems.append(f"{path}: hook name '{name}' is used more than once")

    return hooks


def load_hooks(hooks_dir: Path) -> tuple[HookSpec, ...]:
    problems: list[str] = []
    hooks = _load_hooks(hooks_dir, problems)

    if problems:
        raise SourceError(problems)

    return hooks


def _check_unique(commands: list[Command], skills: list[Skill], problems: list[str]) -> None:
    command_names = {command.name for command in commands}

    for skill in skills:
        if skill.name in command_names:
            problems.append(
                f"{skill.directory}: skill '{skill.name}' has the same name as a command; "
                "commands become skills on Antigravity"
            )


def load(ai_dir: Path) -> Source:
    problems: list[str] = []
    command_paths = sorted((ai_dir / "commands").glob("*.md"))
    commands = [_load_command(path, problems) for path in command_paths]
    skill_dirs = sorted(item for item in (ai_dir / "skills").glob("*") if item.is_dir())
    skills = [_load_skill(directory, problems) for directory in skill_dirs]
    servers = _load_servers(ai_dir / "mcp.json", problems)
    hooks = _load_hooks(ai_dir / "hooks", problems)
    loaded_commands = [command for command in commands if command is not None]
    loaded_skills = [skill for skill in skills if skill is not None]

    _check_unique(loaded_commands, loaded_skills, problems)

    if problems:
        raise SourceError(problems)

    return Source(
        ai_dir=ai_dir,
        commands=tuple(loaded_commands),
        skills=tuple(loaded_skills),
        servers=servers,
        hooks=hooks,
    )


def resolve_server(server: dict, agent: str) -> dict:
    resolved = {key: value for key, value in server.items() if key not in AGENTS}
    override = server.get(agent) or {}

    resolved.update(override)

    return resolved
