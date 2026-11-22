from pathlib import Path

import tools
from events import Event, TextEdit
from tools import ToolKind, ToolSpec


class DecodeError(Exception):
    pass


def _string(args: dict, key: str) -> str | None:
    value = args.get(key)

    if isinstance(value, str):
        return value

    return None


def _path(args: dict, spec: ToolSpec, base_dir: Path) -> Path | None:
    for key in spec.path_keys:
        value = _string(args, key)

        if value:
            return (base_dir / value).resolve()

    return None


def _edit(args: dict, spec: ToolSpec) -> TextEdit:
    old = _string(args, spec.old_key)
    new = _string(args, spec.new_key)

    if old is None or new is None:
        raise DecodeError(f"{spec.name} call has no {spec.old_key}/{spec.new_key} text")

    replace_all = spec.always_replace_all or args.get(spec.replace_all_key) is True

    return TextEdit(old=old, new=new, replace_all=replace_all)


def _multi_edit(args: dict, spec: ToolSpec) -> tuple[TextEdit, ...]:
    entries = args.get(spec.edits_key)

    if not isinstance(entries, list):
        raise DecodeError(f"{spec.name} call has no '{spec.edits_key}' list")

    edits: list[TextEdit] = []

    for entry in entries:
        if not isinstance(entry, dict):
            raise DecodeError(f"{spec.name} call has an edit that is not an object")

        old = _string(entry, "old_string")
        new = _string(entry, "new_string")

        if old is None or new is None:
            raise DecodeError(f"{spec.name} call has an edit without old_string/new_string")

        edits.append(TextEdit(old=old, new=new, replace_all=entry.get("replace_all") is True))

    return tuple(edits)


def _known(kind: str, agent: str, spec: ToolSpec, args: dict, repo_root: Path, base_dir: Path) -> Event:
    common = {
        "kind": kind,
        "agent": agent,
        "tool": spec.name,
        "tool_kind": spec.kind,
        "repo_root": repo_root,
        "args": args,
    }

    match spec.kind:
        case ToolKind.SHELL:
            command = _string(args, spec.command_key)

            if command is None:
                raise DecodeError(f"{spec.name} call has no '{spec.command_key}' string")

            return Event(**common, command=command)
        case ToolKind.WRITE:
            path = _path(args, spec, base_dir)
            content = _string(args, spec.content_key)

            if path is None or content is None:
                raise DecodeError(f"{spec.name} call has no path or no content")

            return Event(**common, path=path, content=content)
        case ToolKind.EDIT:
            path = _path(args, spec, base_dir)

            if path is None:
                raise DecodeError(f"{spec.name} call has no path")

            return Event(**common, path=path, edits=(_edit(args, spec),))
        case ToolKind.MULTI_EDIT:
            path = _path(args, spec, base_dir)

            if path is None:
                raise DecodeError(f"{spec.name} call has no path")

            return Event(**common, path=path, edits=_multi_edit(args, spec))
        case ToolKind.PATCH:
            patch = _string(args, spec.patch_key) or ""

            return Event(**common, patch=patch)
        case ToolKind.PATH_ONLY:
            return Event(**common, path=_path(args, spec, base_dir))


def tool_event(kind: str, agent: str, name: object, args: object, repo_root: Path, base_dir: Path) -> Event:
    if not isinstance(name, str) or not name:
        raise DecodeError("the payload has no tool name")

    if not isinstance(args, dict):
        raise DecodeError(f"the {name} call has no argument object")

    spec = tools.find(agent, name)

    if spec is None:
        return Event(kind=kind, agent=agent, tool=name.lower(), tool_kind=None, repo_root=repo_root, args=args)

    return _known(kind, agent, spec, args, repo_root, base_dir)
