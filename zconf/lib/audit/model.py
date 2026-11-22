from dataclasses import dataclass, field
from enum import IntEnum, StrEnum


class Exit(IntEnum):
    CLEAN = 0
    FINDINGS = 1
    USAGE = 2
    COULD_NOT_RUN = 3


class Kind(StrEnum):
    MISE_TOOL = "mise-tool"
    MISE = "mise"
    LOCKFILE = "lockfile"
    NVIM_PLUGIN = "nvim-plugin"
    NVIM_BUNDLED = "nvim-bundled"
    TREESITTER_PARSER = "treesitter-parser"
    TMUX_PLUGIN = "tmux-plugin"
    OHMYZSH = "oh-my-zsh"
    SUBMODULE = "submodule"
    INSTALL = "install"
    OS_PACKAGE = "os-package"


class Scope(StrEnum):
    DECLARED = "declared"
    INSTALLED = "installed"


@dataclass(frozen=True)
class Component:
    kind: Kind
    name: str
    version: str
    origin: str
    scope: Scope
    locator: dict = field(default_factory=dict, compare=False, hash=False)

    def key(self) -> str:
        return f"{self.kind}:{self.name}@{self.version}"


@dataclass(frozen=True)
class Finding:
    component: Component
    source: str
    id: str
    summary: str
    aliases: tuple[str, ...] = ()
    fixed_in: tuple[str, ...] = ()
    severity: str = "unknown"
    dev_only: bool = False


@dataclass(frozen=True)
class Problem:
    component: Component | None
    source: str
    message: str
    fix: str = ""


@dataclass
class Result:
    components: list[Component] = field(default_factory=list)
    findings: list[Finding] = field(default_factory=list)
    not_covered: list[Problem] = field(default_factory=list)
    leftovers: list[Problem] = field(default_factory=list)
    information: list[Problem] = field(default_factory=list)
    could_not_run: list[Problem] = field(default_factory=list)

    def failing_findings(self) -> list[Finding]:
        return [finding for finding in self.findings if not finding.dev_only]

    def exit_code(self) -> Exit:
        if self.could_not_run:
            return Exit.COULD_NOT_RUN

        if self.failing_findings() or self.not_covered or self.leftovers:
            return Exit.FINDINGS

        return Exit.CLEAN
