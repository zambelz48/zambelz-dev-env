from dataclasses import dataclass
from enum import StrEnum


class ToolKind(StrEnum):
    SHELL = "shell"
    WRITE = "write"
    EDIT = "edit"
    MULTI_EDIT = "multi-edit"
    PATCH = "patch"
    PATH_ONLY = "path-only"


@dataclass(frozen=True)
class ToolSpec:
    name: str
    kind: ToolKind
    command_key: str = ""
    path_keys: tuple[str, ...] = ()
    content_key: str = ""
    old_key: str = ""
    new_key: str = ""
    replace_all_key: str = ""
    always_replace_all: bool = False
    edits_key: str = ""
    patch_key: str = ""


TABLE: dict[str, tuple[ToolSpec, ...]] = {
    "claude": (
        ToolSpec("Bash", ToolKind.SHELL, command_key="command"),
        ToolSpec("Write", ToolKind.WRITE, path_keys=("file_path",), content_key="content"),
        ToolSpec(
            "Edit",
            ToolKind.EDIT,
            path_keys=("file_path",),
            old_key="old_string",
            new_key="new_string",
            replace_all_key="replace_all",
        ),
        ToolSpec("MultiEdit", ToolKind.MULTI_EDIT, path_keys=("file_path",), edits_key="edits"),
        ToolSpec("NotebookEdit", ToolKind.PATH_ONLY, path_keys=("notebook_path",)),
    ),
    "opencode": (
        ToolSpec("shell", ToolKind.SHELL, command_key="command"),
        ToolSpec("write", ToolKind.WRITE, path_keys=("path", "filePath"), content_key="content"),
        ToolSpec(
            "edit",
            ToolKind.EDIT,
            path_keys=("path", "filePath"),
            old_key="oldString",
            new_key="newString",
            replace_all_key="replaceAll",
        ),
        ToolSpec("apply_patch", ToolKind.PATCH, patch_key="patchText"),
        ToolSpec("patch", ToolKind.PATCH, patch_key="patchText"),
    ),
    "antigravity": (
        ToolSpec("run_command", ToolKind.SHELL, command_key="CommandLine"),
        ToolSpec("write_file", ToolKind.WRITE, path_keys=("Path",), content_key="Content"),
        ToolSpec(
            "edit_file",
            ToolKind.EDIT,
            path_keys=("Path",),
            old_key="Target",
            new_key="Replacement",
            always_replace_all=True,
        ),
        ToolSpec("replace_file_content", ToolKind.PATH_ONLY, path_keys=("TargetFile", "Path")),
        ToolSpec("multi_replace_file_content", ToolKind.PATH_ONLY, path_keys=("TargetFile", "Path")),
    ),
}


def specs(agent: str) -> tuple[ToolSpec, ...]:
    return TABLE[agent]


def find(agent: str, name: str) -> ToolSpec | None:
    for spec in TABLE[agent]:
        if spec.name == name:
            return spec

    return None


def names(agent: str) -> list[str]:
    return [spec.name for spec in TABLE[agent]]


def matcher(agent: str) -> str:
    return "|".join(names(agent))
