from pathlib import Path

import frontmatter
from model import Command, Skill, Source
from writer import Output

HOOK_TIMEOUT_SECONDS = 90


class RenderError(Exception):
    pass


def hook_script(repo_root: Path) -> Path:
    path = repo_root / "ai" / "hook.sh"

    if '"' in str(path):
        raise RenderError(f"the repository path {repo_root} contains a double quote, which cannot be quoted in a hook command")

    return path


def shell_hook_command(repo_root: Path, agent: str, event: str) -> str:
    return f'"{hook_script(repo_root)}" {agent} {event}'


def base_dir(value: object, repo_root: Path) -> Path:
    if isinstance(value, str) and value:
        return Path(value)

    return repo_root


def subscribes(source: Source, event: str) -> bool:
    return any(event in hook.events for hook in source.hooks)


def command_markdown(command: Command, extra: dict[str, str] | None = None) -> bytes:
    fields = {"description": command.description}

    if command.argument_hint:
        fields["argument-hint"] = command.argument_hint

    fields.update(extra or {})

    return frontmatter.render(fields, command.body).encode()


def command_as_skill(command: Command) -> bytes:
    fields = {"name": command.name, "description": command.description}

    return frontmatter.render(fields, command.body).encode()


def skill_files(skill: Skill, prefix: str) -> dict[str, Output]:
    files: dict[str, Output] = {}

    for relative in skill.files:
        source = skill.directory / relative
        executable = bool(source.stat().st_mode & 0o100)

        files[f"{prefix}/{skill.name}/{relative.as_posix()}"] = Output(source.read_bytes(), executable)

    return files
