# Zambelz Dev Environment

Personal development environment: [Kitty](https://github.com/kovidgoyal/kitty)
(terminal), [Zsh](https://github.com/ohmyzsh/ohmyzsh) (shell),
[Neovim](https://neovim.io/) (editor) and [tmux](https://github.com/tmux/tmux)
(multiplexer), unified under a single Dracula theme.

Configs live in this repository and are **symlinked** into place, so editing a
file here changes your live config. Language runtimes, language servers and
CLI tools are installed by [mise](https://mise.jdx.dev) at exact versions from
a committed, multi-platform lockfile. `zconf` installs what is missing, checks
the machine, reports and applies updates, and scans for vulnerabilities.

## Table of contents

1. [Platforms](#platforms)
1. [Install](#install)
1. [Commands](#commands)
1. [How it works](#how-it-works)
1. [Pins and updates](#pins-and-updates)
1. [Security audit and pre-push hook](#security-audit-and-pre-push-hook)
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
1. Git submodules that are not checked out yet, fetched over HTTPS. A
   submodule at a different commit than recorded is left alone with a
   warning.
1. GitHub token: `GITHUB_TOKEN` or `gh auth token`. Without one, mise
   downloads can hit GitHub's anonymous rate limit; the step warns and goes
   on.
1. mise at `min_version` from `mise/mise.toml`, through the official installer
   (`https://mise.run`), which verifies the release checksum. A newer mise is
   kept.
1. Hands over to `zconf apply` (all modules, or only the ones you name).

Run on its own (outside a clone), `bootstrap.sh` makes sure git exists,
clones into `--dir` (default `~/zambelz-dev-env`) and runs the cloned copy.

After bootstrap, open a new terminal. `zconf`, `mise` (in `~/.local/bin`)
and the mise shims are on `PATH` (from `~/.zshenv`), in every zsh,
interactive or not.

## Commands

| Command | What it does |
| --- | --- |
| `zconf apply [--dry-run] [module...]` | Install and link whatever is missing; changes nothing that is already right |
| `zconf doctor [--perf] [module...]` | Read-only health check; every problem prints a `fix:` command; exit 1 on errors |
| `zconf update [module...]` | Read-only report of newer versions (mise tools, OS packages, oh-my-zsh, tmux plugins, Neovim plugins) |
| `zconf upgrade [--yes] [--major] [--dry-run] [tool...]` | Pick newer mise versions (fzf, or all with `--yes`), re-lock, install, upgrade OS packages, run the audit |
| `zconf use <tool> <version>` | Make a version the global default (first in its list), re-lock, install |
| `zconf audit [--declared\|--installed]` | Vulnerability scan with osv-scanner |
| `zconf check-pins` | Fail on floating or unlocked pins and on global mise settings that would leak into other projects |
| `zconf lint` | ShellCheck, `zsh -n` and lua-language-server |
| `zconf <module>` | Same as `zconf apply <module>` |
| `zconf neovim check-updates` | Interactive Neovim plugin pin updates |

Modules, applied in this order: `packages`, `mise`, `zsh`, `kitty`, `tmux`,
`neovim`, `git` (listed in `zconf/modules`).

## How it works

- **Modules.** Each module is a `<tool>/zconf/` directory: a `links` file
  (`repo/path<TAB>home/path` per line) and optional `apply.sh`, `doctor.sh`,
  `update.sh` and `upgrade.sh`. Adding a module means adding that directory
  and one line in `zconf/modules`.
- **Links.** `apply` creates each symlink. A real file already at the target
  is moved to `~/.local/state/zconf/backup/<timestamp>-<pid>.<random>/` first;
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
  `tools/zconf/bins` into `~/.local/share/zconf/bin`, which `.zshenv` and
  `.zshrc` put first on `PATH`. npm commands run on the global node, so a
  project's node version cannot break them; Python commands run with their
  venv's `bin` on `PATH`. `check-pins` rejects `npm:`, `pipx:` and `pypi:`
  tools in `mise/mise.toml`.
- **Global tools are locked; projects stay independent.** The global config
  locks only its own tools with `[tool_config] locked = true`. A project with
  its own `mise.toml` (or `.nvmrc`, `.python-version`, ...) resolves and
  installs its own pins with mise's defaults; zconf never writes into it.
  `zconf doctor` run inside such a project reports its missing tools as
  warnings. The only global mise setting is reading those version files.
- **OS packages** come from `packages/<manager>.txt` (one package per line,
  optionally `<TAB>command` when an existing command already provides it),
  through adapters in `zconf/adapters/pkg/`.

## Pins and updates

| What | Pinned by | Where |
| --- | --- | --- |
| Runtimes, CLI tools, binary language servers | exact version, URLs and checksums for 4 platforms | `mise/mise.toml`, `mise/mise.lock` |
| npm language servers | exact version; full dependency graph with integrity hashes | `tools/npm/package.json`, `tools/npm/pnpm-lock.yaml` |
| Python tools | exact version; full dependency graph with hashes | `tools/python/pyproject.toml`, `tools/python/uv.lock` |
| mise itself | minimum version | `min_version` in `mise/mise.toml` |
| oh-my-zsh | commit | `zsh/zconf/pins` |
| TPM and tmux plugins | commit | `tmux/zconf/pins` |
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
them your global default, use `zconf use <tool> <version>` with the exact
version.

For `tools/`, `update` reports newer versions of the listed tools, and
`upgrade` re-resolves both locks to the newest dependency versions the
tools' ranges and the overrides allow, then installs them. A tool's own
version changes by hand: edit `package.json` and run
`pnpm install --lockfile-only` in `tools/npm`, or edit `pyproject.toml` and
run `uv lock` in `tools/python`, then `zconf apply tools`.

## Security audit and pre-push hook

- `zconf audit --declared` (default) scans the crates, Go and RubyGems
  tools in `mise/mise.lock` and the full dependency graphs in
  `tools/npm/pnpm-lock.yaml` and `tools/python/uv.lock`. Exit 0 clean,
  1 findings, 3 scan could not run.
- `zconf audit --installed` scans everything under mise's install
  directory, `tools/` and the built Gradle language server, then lists OS
  security advisories (Fedora) as information only.
- Findings are never accepted: there is no ignore list. Each scan passes an
  empty config, so an `osv-scanner.toml` next to a lock (even one shipped
  inside a dependency) cannot hide a finding. Fix a finding by upgrading the
  tool, or by forcing the fixed version in `tools/npm/pnpm-workspace.yaml`
  `overrides` (or `tools/python/pyproject.toml`), then check the tool still
  works with `node tools/zconf/smoke/overrides.mjs` and
  `node tools/zconf/smoke/lsp-smoke.mjs`.

- `zconf apply git` sets `core.hooksPath` to `.githooks`. The pre-push hook
  then runs `check-pins`, `lint` and `audit --declared` on a temporary
  checkout of each pushed commit, so uncommitted changes do not affect the
  result, and blocks the push if any fails (a scan that cannot run also
  blocks). `git push --no-verify` skips it.

## Kitty

- `kitty/kitty.base.conf`: tracked, shared settings.
- `kitty/kitty.conf`: git-ignored, per-machine overrides (`font_size`). It
  `include`s the base file and is generated once by `zconf apply kitty`;
  later runs never overwrite it.
- Hack Nerd Font comes from the mise pin `github:ryanoasis/nerd-fonts`
  (`Hack.tar.xz`), installed by `zconf apply kitty` on macOS and Linux.

## Zsh

- oh-my-zsh is cloned and kept at the commit in `zsh/zconf/pins`.
- `~/.profile.zsh` holds machine-local settings; `apply` adds
  `export ZAMBELZ_DEV_ENV_PATH="<repo>"` to it if missing.
- Helper functions live in `zsh/helpers/*.zsh` (git, tmux sessions,
  PostgreSQL backup/restore, disk cleanup) and are sourced by `.zshrc`.
- `CODING_ASSISTANT` (used by Neovim's Copilot integration) defaults to
  `copilot`; switch it with `use_copilot` / `use_windsurf` from
  `zsh/helpers/utils.zsh`.

## Neovim

- `zconf apply neovim` links `init.lua`, `lua`, `after`, `ftplugin` and
  `.luarc.json` into `~/.config/nvim`, restores plugins from
  `neovim/lazy-lock.json` (`nvim --headless "+Lazy! restore" +qa`) and builds
  the Gradle language server when its submodule commit changed.
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
- Plugin updates: `zconf neovim check-updates [filter]` compares every `tag`
  or `commit` pin with its upstream through `git ls-remote`, then offers an
  fzf multi-select that rewrites only the chosen pins.

## Tmux

- `zconf apply tmux` links `~/.tmux.conf`, keeps TPM and every plugin at the
  commit in `tmux/zconf/pins` and installs missing plugins through TPM.
- tmux itself is an OS package: the config needs tmux 3.8.
- The status bar is [dracula/tmux](https://github.com/dracula/tmux),
  configured with the `@dracula-*` options. Keep `tmux-continuum` as the last
  `@plugin`: dracula rewrites `status-right` and continuum's autosave hook
  must come after it.

## Repository structure

```
.
├── bootstrap.sh          # fresh machine or clone: prerequisites, mise, zconf apply
├── zconf/
│   ├── bin/              # zconf, lint
│   ├── lib/              # core shell library and Python helpers
│   ├── adapters/pkg/     # brew, brew-cask, dnf, apt
│   ├── modules           # module order
│   └── tests/            # bats suites; run with zconf/tests/run
├── packages/             # OS package lists per manager
├── mise/                 # mise.toml, mise.lock
├── tools/                # npm and Python tools: manifests, locks, overrides
│   └── zconf/            # module, command list, smoke tests
├── zsh/ kitty/ tmux/ neovim/ git/   # configs, each with a zconf/ module dir
├── .githooks/pre-push
└── AGENTS.md             # rules for AI coding agents
```

## Development

- Tests: `zconf/tests/run` (bats-core, pinned through mise, run under macOS's
  `/bin/bash` 3.2). Tests tagged `network` call the real osv-scanner.
- Lint: `zconf lint`.
- Health: `zconf doctor`.
- CI: `.github/workflows/ci.yml` bootstraps a fresh `fedora:44` and
  `ubuntu:26.04` container on every push to `main` and every pull request
  into it, then runs doctor, a second apply that must change nothing, the
  tests, lint, pins, audit, the override checks, a start-up check of every
  npm language server, the Neovim config, and the tmux config (skipped on
  Ubuntu, whose tmux 3.6a is older than the 3.8 the config needs), and fails
  if the clone has any change.
