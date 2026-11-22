from dataclasses import dataclass, field
from enum import IntEnum, StrEnum


NOT_COMPILED_IN = "not compiled into the installed binary"
NOT_SHIPPED = "only used by crates the release does not ship"
NOT_FAILING = ("unmaintained", NOT_COMPILED_IN, NOT_SHIPPED)
FIX_AVAILABLE = "fix available"
WAITING = "waiting for upstream"


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
    BUNDLED = "bundled"
    UPSTREAM_PIN = "upstream-pin"


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
    package: str = ""
    notice: str = ""
    status: str = ""
    action: str = ""
    url: str = ""


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
        return [finding for finding in self.findings if not finding.dev_only and finding.notice not in NOT_FAILING]

    def blocking_findings(self) -> list[Finding]:
        return [finding for finding in self.failing_findings() if finding.status != WAITING]

    def exit_code(self, gate: bool = False) -> Exit:
        if self.could_not_run:
            return Exit.COULD_NOT_RUN

        findings = self.failing_findings()

        if gate:
            findings = self.blocking_findings()

        if findings or self.not_covered or self.leftovers:
            return Exit.FINDINGS

        return Exit.CLEAN
