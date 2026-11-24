# Zambelz Dev Environment

Personal development environment: [Kitty](https://github.com/kovidgoyal/kitty)
(terminal), [Zsh](https://github.com/ohmyzsh/ohmyzsh) (shell),
[Neovim](https://neovim.io/) (editor) and [tmux](https://github.com/tmux/tmux)
(multiplexer), unified under a single Dracula theme.

Configs live in this repository and are **symlinked** into place, so editing a
file here changes your live config. Language runtimes, language servers and
CLI tools are installed by [mise](https://mise.jdx.dev) at exact versions from
a committed, multi-platform lockfile. `zzd` installs what is missing, checks
the machine, reports and applies updates, and scans for vulnerabilities.

## Table of contents

1. [Platforms](#platforms)
1. [Install](#install)
   1. [Keeping machines in sync](#keeping-machines-in-sync)
1. [Commands](#commands)
1. [How it works](#how-it-works)
1. [Pins and updates](#pins-and-updates)
1. [Security audit and pre-push hook](#security-audit-and-pre-push-hook)
1. [AI agents](#ai-agents)
1. [Kitty](#kitty)
1. [Zsh](#zsh)
1. [Neovim](#neovim)
1. [Tmux](#tmux)
1. [Repository structure](#repository-structure)
1. [Development](#development)

## Platforms

| Platform | Status |
| --- | --- |
| macOS arm64 | Supported and validated (the owner's machine) |
| macOS x64, Fedora, Ubuntu | Supported, not validated: the lock covers these platforms and the package-manager code is unit-tested with stubs, but no real run has been done |

## Install

Clone the repository and run the bootstrap from the clone (the validated
path):

```sh
git clone https://github.com/zambelz48/zambelz-dev-env.git ~/zambelz-dev-env
~/zambelz-dev-env/bootstrap.sh
```

`bootstrap.sh [--dir <path>] [--repo-url <url>] [module...]` runs each step
only when it is not already satisfied and prints `OK:`, `CHANGED:`, `WARN:` or
`ERROR:` with a `fix:` line:

1. Checks the OS (macOS, Fedora or Ubuntu).
1. macOS: Xcode Command Line Tools (starts the installer and stops if they are
   missing; rerun when it finishes), then Homebrew. Linux: `zsh`, `git` and
   `curl` through `sudo dnf` or `sudo apt-get`.
1. Login shell: `chsh` to zsh (may ask for your password).
1. GitHub token: `GITHUB_TOKEN` or `gh auth token`. Without one, mise
   downloads can hit GitHub's anonymous rate limit; the step warns and goes
   on.
1. mise at `min_version` from `mise/mise.toml`, the same step `zzd apply
   mise` runs (see [Keeping machines in sync](#keeping-machines-in-sync)).
1. Hands over to `zzd apply` (all modules, or only the ones you name),
   which also checks out the git submodules.

Run on its own (outside a clone), `bootstrap.sh` makes sure git exists,
clones into `--dir` (default `~/zambelz-dev-env`) and runs the cloned copy.

After bootstrap, open a new terminal. `zzd`, `mise` (in `~/.local/bin`)
and the mise shims are on `PATH` (from `~/.zshenv`), in every zsh,
interactive or not.

### Keeping machines in sync

On every machine, `git pull` then `zzd apply` brings the machine to what
the repository records, whichever machine made the change:

- **mise itself.** `~/.config/mise/config.toml` is a symlink into the clone,
  so a pull that raises `min_version` takes effect at once: mise then
  refuses every command, the shims and `mise self-update` included.
  `zzd apply mise` (part of a full `zzd apply`) runs first in the mise
  module and installs exactly `min_version` into `~/.local/bin` through the
  official installer (`https://mise.run`), which verifies the release
  checksum, without calling mise. A newer mise is kept. An older mise that
  comes before `~/.local/bin` on `PATH` is reported, not replaced. Every
  other `zzd` command stops with `fix: zzd apply mise` while mise is too
  old.
- **Git submodules** under a module's directory (`zsh/`, `neovim/`) are
  checked out at the recorded commit by that module's apply; `git pull`
  alone does not move them. A submodule at a commit the repository recorded
  before is moved; one with local changes is an error; one at a commit the
  repository never recorded is your work in progress and is left alone with
  a warning. `zzd doctor` reports each of these.

## Commands

| Command | What it does |
| --- | --- |
| `zzd apply [--dry-run] [module...]` | Install and link whatever is missing; changes nothing that is already right |
| `zzd doctor [--perf] [module...]` | Read-only health check; every problem prints a `fix:` command; exit 1 on errors |
| `zzd update [module...]` | Read-only report of newer versions (mise tools, OS packages, oh-my-zsh, tmux plugins, Neovim plugins) |
| `zzd upgrade [--yes] [--major] [--dry-run] [tool...]` | Pick newer mise versions (fzf, or all with `--yes`), re-lock, install, upgrade OS packages, run the audit |
| `zzd use <tool> <version>` | Make a version the global default (first in its list), re-lock, install |
| `zzd audit [--declared\|--installed\|--all] [--json]` | Audit every pinned and installed component for known vulnerabilities; fails closed (default `--all`) |
| `zzd check-pins` | Fail on floating or unlocked pins and on global mise settings that would leak into other projects |
| `zzd lint` | ShellCheck, `zsh -n` and lua-language-server |
| `zzd <module>` | Same as `zzd apply <module>` |
| `zzd neovim check-updates` | Interactive Neovim plugin pin updates |

Modules, applied in this order: `packages`, `mise`, `zsh`, `kitty`, `tmux`,
`neovim`, `git` (listed in `zzd/modules`).

## How it works

- **Modules.** Each module is a `<tool>/zzd/` directory: a `links` file
  (`repo/path<TAB>home/path` per line) and optional `apply.sh`, `doctor.sh`,
  `update.sh` and `upgrade.sh`. Adding a module means adding that directory
  and one line in `zzd/modules`. Submodules in `.gitmodules` whose path is
  under `<tool>/` belong to that module; its apply checks them out before
  the links.
- **Links.** `apply` creates each symlink. A real file already at the target
  is moved to `~/.local/state/zzd/backup/<timestamp>-<pid>.<random>/` first;
  nothing is deleted.
- **Fonts.** An optional `fonts` file lists mise tools (one per line) whose
  `.ttf`/`.otf`/`.ttc` files `apply` copies into `~/Library/Fonts` (macOS)
  or `${XDG_DATA_HOME:-~/.local/share}/fonts` plus `fc-cache` (Linux). Files
  a previous version installed are removed; other fonts are never touched.
- **mise.** `~/.config/mise/config.toml` and `~/.config/mise/mise.lock` are
  symlinks to `mise/mise.toml` and `mise/mise.lock`. Tools are reached
  through mise's shims, put first on `PATH` by `~/.zshenv`; there is no
  `mise activate`, so no prompt or `cd` hooks. `.zshrc` puts the shims ahead
  of Homebrew again, because `path_helper` and Homebrew's `PATH` line reorder
  it.
- **npm and Python tools** (the language servers, `ansible-lint`, `pyrefly`)
  are not mise tools: mise cannot override their dependencies, so a
  vulnerable dependency inside a tool could not be fixed. They live in
  `tools/npm` (`package.json`, `pnpm-workspace.yaml`, `pnpm-lock.yaml`,
  installed with the pinned pnpm) and `tools/python` (`pyproject.toml`,
  `uv.lock`, installed with the pinned uv into `tools/python/.venv`).
  `overrides` in `pnpm-workspace.yaml` force fixed versions of dependencies
  past the tools' own ranges; each entry names the advisory it fixes.
  `apply tools` writes a small launcher per command listed in
  `tools/zzd/bins` into `~/.local/share/zzd/bin`, which `.zshenv` and
  `.zshrc` put first on `PATH`. npm commands run on the global node, so a
  project's node version cannot break them; Python commands run with their
  venv's `bin` on `PATH`. `check-pins` rejects `npm:`, `pipx:` and `pypi:`
  tools in `mise/mise.toml`.
- **Global tools are locked; projects stay independent.** The global config
  locks only its own tools with `[tool_config] locked = true`. A project with
  its own `mise.toml` (or `.nvmrc`, `.python-version`, ...) resolves and
  installs its own pins with mise's defaults; zzd never writes into it.
  mise locks a version file into the nearest config whose root contains it,
  and the global config's root defaults to `$HOME`, so a `go.mod` anywhere
  under `$HOME` would land in `mise/mise.lock`. `.zshenv` sets
  `MISE_GLOBAL_CONFIG_ROOT="$HOME/.config/mise"` to keep it out.
  `zzd doctor` run inside such a project reports its missing tools as
  warnings. The only global mise setting is reading those version files.
- **OS packages** come from `packages/<manager>.txt` (one package per line,
  optionally `<TAB>command` when an existing command already provides it),
  through adapters in `zzd/adapters/pkg/`.

## Pins and updates

| What | Pinned by | Where |
| --- | --- | --- |
| Runtimes, CLI tools, binary language servers | exact version, URLs and checksums for 4 platforms | `mise/mise.toml`, `mise/mise.lock` |
| npm language servers | exact version; full dependency graph with integrity hashes | `tools/npm/package.json`, `tools/npm/pnpm-lock.yaml` |
| Python tools | exact version; full dependency graph with hashes | `tools/python/pyproject.toml`, `tools/python/uv.lock` |
| mise itself | minimum version | `min_version` in `mise/mise.toml` |
| oh-my-zsh | commit | `zsh/zzd/pins` |
| TPM and tmux plugins | commit | `tmux/zzd/pins` |
| Neovim plugins | commit | `neovim/lazy-lock.json` |
| Zsh themes and plugins, Gradle language server | git submodule | `.gitmodules` |
| OS packages | not pinnable | `packages/*.txt` |

`update` and `upgrade` keep each pin on its line: node 24 stays 24, Temurin 17
stays Temurin 17. Two pins of one tool with the same major (python 3.14 and
3.10) keep their own minor, and `0.x` versions keep their minor.
`upgrade --major` crosses majors. Tools from the `http` backend (jdtls,
kotlin-lsp) are reported, not checked: update their URL and checksum by hand.
Each tool is set and locked on its own. If a new version cannot be locked for
all four platforms, `upgrade` and `use` put that tool back in `mise.toml` and
the lock, report an error, and keep the other upgrades.

Version files in other projects use any version they like. To make one of
them your global default, use `zzd use <tool> <version>` with the exact
version.

For `tools/`, `update` reports newer versions of the listed tools, and
`upgrade` re-resolves both locks to the newest dependency versions the
tools' ranges and the overrides allow, then installs them. A tool's own
version changes by hand: edit `package.json` and run
`pnpm install --lockfile-only` in `tools/npm`, or edit `pyproject.toml` and
run `uv lock` in `tools/python`, then `zzd apply tools`.

## Security audit and pre-push hook

- `zzd audit --declared` audits everything the repository pins: every
  mise tool and mise itself, the npm and Python tool trees, Neovim plugins,
  Tree-sitter parsers, the libraries Neovim's release bundles, tmux plugins,
  oh-my-zsh and the git submodules. For each tool it follows what the release
  ships: the upstream lockfiles at the pinned tag (`Cargo.lock`, `go.mod`,
  `package-lock.json`, `pom.xml`, central NuGet versions), vendored and
  bundled libraries (CMake's `Utilities/`, python-build-standalone's
  libraries), submodules and `DEPS` pins.
- `zzd audit --installed` audits what is on this machine: every mise
  install (binaries, jars, embedded `deps.json`, Haskell packages, the
  libraries the Python interpreter loads), the cloned plugins, and the OS
  packages (`dnf advisory list --security` on Fedora, OSV by source package
  on Ubuntu, catalog sources for Homebrew). Installs nothing selects and
  mise configs tracked inside tool installs are reported as leftovers.
- `zzd audit` (or `--all`) runs both. `--json` prints the report as JSON.
- Sources: OSV (osv-scanner and the API), GitHub repository advisories, NVD
  by exact CPE plus CVE.org records for CVEs NVD has not analysed yet, the
  Node.js, rubysec and .NET security feeds, endoflife.date, and dnf. Which
  sources apply to which component is declared in `zzd/audit/catalog.toml`;
  `python3 -E -s zzd/lib/audit catalog --verify` checks every catalog
  entry against the live services.
- It fails closed. A component with no source is `NOT COVERED`, a source
  that cannot answer is `COULD NOT RUN`, and nothing is skipped silently.
  Exit 0 clean, 1 findings, uncovered components or leftovers, 2 usage,
  3 could not run. On this machine (2026-11-23) `--declared` takes about
  170 s with an `NVD_API_KEY` in the environment and about 380 s without
  one (NVD allows 50 requests per 30 s with a key, 5 without); `--installed`
  takes about 45 s. The agent hook allows the audit 600 s.
- Each finding prints the affected component, the advisory and its aliases,
  the severity, the vulnerable library with its fixed version, what the
  vulnerability is, an `Action:` line and a link to the advisory. Its label
  says what can be done: `fix available, blocks push` (a newer release of
  the tool exists in its pinned line; the action names the upgrade),
  `blocks push` (the fix route depends on the component; see the `fix-cve`
  skill), or `waiting for upstream` (the tool is at its newest release and
  still ships the vulnerable library, or the newer release also has the
  advisory). For a version another project selects (its `go.mod`,
  `.tool-versions`, its own mise config), the action is to raise the
  version in that project and uninstall the old one.
- Some findings are reported as information, not failures: dev-only
  dependencies, RustSec "unmaintained" notices (no known flaw), libraries an
  installed binary's own dependency list shows it does not contain, and
  crates a release's `Cargo.lock` reaches only from crates it does not ship
  (`shipped_crates` in the catalog). Without that evidence, as in CI before
  anything is installed, they fail.
- Findings are never accepted: there is no ignore list and no severity
  threshold. Each scan passes an empty config, so an `osv-scanner.toml`
  next to a lock (even one shipped inside a dependency) cannot hide a
  finding. Fix a finding by upgrading the
  tool, or by forcing the fixed version in `tools/npm/pnpm-workspace.yaml`
  `overrides` (or `tools/python/pyproject.toml`), then check the tool still
  works with `node tools/zzd/smoke/overrides.mjs` and
  `node tools/zzd/smoke/lsp-smoke.mjs`.
- `--gate` is the mode the gates use: it prints the same report but exits 1
  only for findings that block (not for `waiting for upstream` ones),
  uncovered components and leftovers. Every run checks for new releases
  again, so a waiting finding blocks as soon as its tool ships a release.

- `zzd apply git` sets `core.hooksPath` to `.githooks`. The pre-push hook
  then runs `check-pins`, `lint` and `audit --declared --gate` on a temporary
  checkout of the commit each pushed branch or tag points to, so uncommitted
  changes do not affect the result, and blocks the push if any fails (an
  audit that cannot run also blocks). `git push --no-verify` skips it. CI
  runs `zzd audit --all --gate` in each container, with `NVD_API_KEY` from
  the repository secret.
- Git connects to GitHub before the pre-push hook runs and sends the commits
  after it, so the connection stays idle while the checks run (several
  minutes for the audit). Without keepalives the connection is dropped and
  the push fails with exit 141 after the checks pass. `zzd apply git`
  therefore also sets this repository's `core.sshCommand` to
  `ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=6`; `~/.ssh/config`
  still applies. `zzd doctor git` checks both settings.

## AI agents

Claude Code, OpenCode and Antigravity get the same project setup when they
work on this repository: rules, guard hooks, slash commands, skills and MCP
servers. Everything an agent reads is generated from the source under `ai/`
and gitignored; the rules source is `ai/rules.md`, written out as
`AGENTS.md`, which all three read on their own.

### Use

```sh
ai/sync-ai.sh claude                 # or opencode, antigravity, all; several at once
ai/sync-ai.sh --check all            # exit 1 when a synced agent's files are out of date
ai/sync-ai.sh --clean antigravity    # remove what the sync wrote for that agent
```

Run `ai/sync-ai.sh <agent>` once per machine, and again after a pull that
changes `ai/`. After syncing OpenCode, run `opencode service restart`: the
background service caches plugins. The generated files are gitignored and
belong to the script; edit the source under `ai/` instead.

| Agent | Generated files |
| --- | --- |
| Every agent | `AGENTS.md` (from `ai/rules.md`; removed by `--clean` only when no agent stays synced) |
| Claude Code | `.claude/settings.json` (hooks, MCP servers to enable), `.claude/commands/`, `.claude/skills/`, `.mcp.json` |
| OpenCode | `opencode.json` (MCP), `.opencode/plugins/zambelz-dev-env/`, `.opencode/commands/`, `.opencode/skills/` |
| Antigravity | `.agents/plugins/zambelz-dev-env/` (`hooks.json`, `mcp_config.json`, `skills/`; commands become skills) |

- `.gitignore` covers `AGENTS.md`, `opencode.json`, `.mcp.json` and the
  whole `.claude/`, `.opencode/` and `.agents/` folders. A fresh clone has no
  `AGENTS.md` until `ai/sync-ai.sh` runs.
- `.claude/settings.local.json` and any other file in those folders are
  never touched. A file the sync did not write is reported with `WARN:` and
  left alone; a generated file edited by hand is moved to
  `tmp/ai/backup/<timestamp>/` before it is rewritten.
- The sync warns when an installed agent's version differs from the one this
  setup was tested with (`TESTED_VERSION` in `ai/lib/agents/<agent>.py`:
  Claude Code 2.1.330, OpenCode 2.2.7, Antigravity CLI 1.5.15), and runs
  `agy plugin validate --strict` on the Antigravity plugin.
- Antigravity prefixes the plugin's MCP servers with its name
  (`zambelz-dev-env_context7`).
- OpenCode also loads `.opencode/plugins/` from every parent directory, so do
  not sync a clone that sits inside another synced checkout: both plugins
  share the id `zambelz-dev-env`, and the outer one can win.

### Hooks

Every agent calls one entry point, `ai/hook.sh <agent> <event>`. It turns the
agent's payload into one normalized event, runs the hooks listed in
`ai/hooks/hooks.toml` in order (the first deny wins), and replies in that
agent's own format. A hook never approves a call; with no objection, the
agent's own permission rules decide. Every failure (a crash, a payload it
cannot read, a missing `python3`) blocks the call.

| Hook | When | What it does |
| --- | --- | --- |
| `cve-guard` | before a shell command; after any file-changing tool | Blocks `git commit` and `git push` while `zzd audit --declared --gate` reports blocking findings or cannot run. After a change to any pin file the audit reads (`mise/mise.{toml,lock}`, `tools/npm/{package.json,pnpm-lock.yaml,pnpm-workspace.yaml}`, `tools/python/{pyproject.toml,uv.lock}`, `neovim/lazy-lock.json`, `neovim/lua/treesitter_parsers.lua`, `tmux/zzd/pins`, `zsh/zzd/pins`, `.gitmodules`, `zzd/audit/catalog.toml`), runs the full audit and shows the agent the result |
| `dev-plan` | before a write or edit | Blocks a `dev-plan/PLAN-*.md` that misses `## MANDATORY RULES`, `## Overview`, a `## Phase <n>` with checkbox tasks, the rule phrases "Adhere to AGENTS.md", "Mark completed tasks" and "Work phase by phase", or that has an invalid checkbox list item. Edits are checked on the whole new file |

- The CVE guard reads the command text: a commit hidden behind `bash -c`,
  `eval`, a variable or an alias is not detected, and the audit reads the
  working tree, not the staged files. The pre-push hook still audits the
  exact pushed commit. There is no ignore list and no bypass.
- On Antigravity, findings after a tool reach the agent at its next model
  call (its `PostToolUse` hook has no reply channel), through `PreInvocation`.

### Content

| Kind | Source | Items |
| --- | --- | --- |
| Commands | `ai/commands/<name>.md` (`description`, optional `argument-hint`) | `check`, `audit`, `make-plan`, `resume-plan`, `deep-research` |
| Skills | `ai/skills/<name>/SKILL.md` (`name` equal to the folder, `description`) | `run-checks`, `fix-cve`, `create-dev-plan`, `deep-research` |
| MCP servers | `ai/mcp.json` (Claude Code's `mcpServers` shape; a block named after an agent overrides keys for that agent) | `context7` |
| Hooks | `ai/hooks/hooks.toml` plus `ai/hooks/<module>.py` with `handle(event)` | `cve-guard`, `dev-plan` |

Antigravity has no commands, so each command becomes a skill there; both run
as `/<name>`. A command named like a skill (`deep-research`) is that skill's
entry point: OpenCode gets both, Claude Code and Antigravity get only the
skill, which their `/` menu already runs.

Development plans live in `dev-plan/PLAN-<NNN>-<NAME>.md` (gitignored),
written through the `create-dev-plan` skill; research reports go to
`tmp/deep-research/`. To add a hook, write `ai/hooks/<module>.py` with a
`handle(event)` that returns `events.deny(...)`, `events.warn(...)` or `None`,
list it in `hooks.toml` with its events (`tool.before`, `tool.after`), add a
test in `zzd/tests/`, and run `ai/sync-ai.sh all`. The tool names each
agent uses are in `ai/lib/tools.py`, the one table both the wiring and the
decoding read.

## Kitty

- `kitty/kitty.base.conf`: tracked, shared settings.
- `kitty/kitty.conf`: git-ignored, per-machine overrides (`font_size`). It
  `include`s the base file and is generated once by `zzd apply kitty`;
  later runs never overwrite it.
- Hack Nerd Font comes from the mise pin `github:ryanoasis/nerd-fonts`
  (`Hack.tar.xz`), installed by `zzd apply kitty` on macOS and Linux.

## Zsh

- oh-my-zsh is cloned and kept at the commit in `zsh/zzd/pins`.
- `~/.profile.zsh` holds machine-local settings; `apply` adds
  `export ZAMBELZ_DEV_ENV_PATH="<repo>"` to it if missing.
- Helper functions live in `zsh/helpers/*.zsh` (git, tmux sessions,
  PostgreSQL backup/restore, disk cleanup) and are sourced by `.zshrc`.
- `CODING_ASSISTANT` (used by Neovim's Copilot integration) defaults to
  `copilot`; switch it with `use_copilot` / `use_windsurf` from
  `zsh/helpers/utils.zsh`.

## Neovim

- `zzd apply neovim` links `init.lua`, `lua`, `after`, `ftplugin` and
  `.luarc.json` into `~/.config/nvim`, restores plugins from
  `neovim/lazy-lock.json` (`nvim --headless "+Lazy! restore" +qa`), brings
  the treesitter parsers to the pinned nvim-treesitter and builds the Gradle
  language server when its submodule commit changed.
- Treesitter parsers: `neovim/lua/treesitter_parsers.lua` lists them. Neovim
  installs missing ones in the background at start-up, and lazy.nvim runs
  `:TSUpdate` after an interactive plugin update. Neither finishes in a
  headless restore, which exits first, so `zzd apply neovim` runs
  `neovim/scripts/treesitter_parsers.lua sync` under `nvim -l`: it installs
  the listed parsers and updates every installed one, waiting for both
  (nvim-treesitter's documented `install():wait()` and `update():wait()`),
  with the pinned `tree-sitter` CLI on `PATH`. `zzd doctor` runs the same
  script with `check`, which loads no config and installs nothing, and
  reports parsers that are missing or older than the revision the pinned
  nvim-treesitter expects (the comparison its `:TSUpdate` uses).
- Every file in `neovim/after/lsp/` enables that language server; its content
  only overrides [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)'s
  defaults. Every file in `neovim/lua/plugins/` is a lazy.nvim spec.
- Language servers and debug adapters come from mise. The exceptions are
  clangd (Xcode Command Line Tools on macOS, an OS package on Linux),
  sourcekit-lsp (Xcode) and the Gradle language server (the
  `neovim/.lsp_vendors/vscode-gradle` submodule, built with Java 17 from
  mise).
- jdtls is started from `neovim/ftplugin/java.lua` with the formatter profile
  in `neovim/jdtls/eclipse-java-google-style.xml` (from google/styleguide
  `eaa0a05`, the last revision before upstream removed it).
- Kotlin uses JetBrains' Kotlin LSP (`intellij-server`). Its launcher accepts
  the bundled EULA on first start; read it with `intellij-server --show-eula`
  and withdraw with `intellij-server --reset-eula`.
- The vscode-gradle submodule stays at `3.15.0`: 3.16 and later only accept a
  named pipe, not stdio.
- Plugin updates: `zzd neovim check-updates [filter]` compares every `tag`
  or `commit` pin with its upstream through `git ls-remote`, then offers an
  fzf multi-select that rewrites only the chosen pins.

## Tmux

- `zzd apply tmux` links `~/.tmux.conf`, keeps TPM and every plugin at the
  commit in `tmux/zzd/pins` and installs missing plugins through TPM.
- tmux itself is an OS package. The config sets tmux 3.8's theme colours
  for menus and trees; older tmux, such as Ubuntu 26.04's 3.6a, loads the
  config without them.
- The status bar is [dracula/tmux](https://github.com/dracula/tmux),
  configured with the `@dracula-*` options. Keep `tmux-continuum` as the last
  `@plugin`: dracula rewrites `status-right` and continuum's autosave hook
  must come after it.

## Repository structure

```
.
├── bootstrap.sh          # fresh machine or clone: prerequisites, mise, zzd apply
├── zzd/
│   ├── bin/              # zzd, lint
│   ├── lib/              # core shell library and Python helpers
│   ├── adapters/pkg/     # brew, brew-cask, dnf, apt
│   ├── modules           # module order
│   └── tests/            # bats suites; run with zzd/tests/run
├── packages/             # OS package lists per manager
├── mise/                 # mise.toml, mise.lock
├── tools/                # npm and Python tools: manifests, locks, overrides
│   └── zzd/            # module, command list, smoke tests
├── zsh/ kitty/ tmux/ neovim/ git/   # configs, each with a zzd/ module dir
├── ai/                   # agent setup: sync-ai.sh, hook.sh, rules.md, commands, skills, hooks, MCP
└── .githooks/pre-push
```

## Development

- Tests: `zzd/tests/run` (bats-core, pinned through mise, run under macOS's
  `/bin/bash` 3.2). Tests tagged `network` call the real osv-scanner.
- AI agents, live: `ZZD_AI_LIVE=1 zzd/tests/run zzd/tests/ai_live.bats`
  clones the committed repository into a fresh temporary directory (kept for
  inspection only when a test fails), syncs every agent and drives
  Claude Code, OpenCode and Antigravity headless against the hooks, skills and
  MCP server. It needs the agents installed and signed in, and spends model
  usage; `ZZD_AI_LIVE_CLAUDE_MODEL` and `ZZD_AI_LIVE_OPENCODE_MODEL` pick the
  models. Run it after an agent upgrade, then update `TESTED_VERSION`.
- Lint: `zzd lint`.
- Health: `zzd doctor`.
- CI: `.github/workflows/ci.yml` bootstraps a fresh `fedora:44` and
  `ubuntu:26.04` container on every push to `main` and every pull request
  into it, then runs doctor, a second apply that must change nothing, the
  tests, lint, pins, audit, the override checks, a start-up check of every
  npm language server, the Neovim and tmux configs, and fails if the clone
  has any change.
