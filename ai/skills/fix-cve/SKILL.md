---
name: fix-cve
description: Fix a known vulnerability that zzd audit reports, at the source first and with an override only when no source fix exists, then prove the tools still work. Use when zzd audit fails or the cve-guard hook blocks a commit or push.
---

# Fix a CVE

Findings are never accepted: there is no ignore list and no bypass
(`README.md` "Security audit and pre-push hook"). Every finding is fixed.

## 1. Read the finding

Run `zzd/bin/zzd audit --all`. Each finding names the component, the
advisory, the library and its fixed version, an Action line and a link. Its
label says what can be done:

- `fix available, blocks push`: a newer release of the tool exists in its
  pinned line. Follow the Action line, then audit again.
- `blocks push`: the fix route is yours to find (the table below).
- `waiting for upstream`: the tool is at its newest release and still ships
  the vulnerable library. Report it to the user as open; there is nothing to
  install yet.

| Component | Fix route |
| --- | --- |
| `mise-tool:*`, `mise:mise` | `zzd/bin/zzd upgrade <tool>`; for mise itself raise `min_version` and run `zzd apply mise` |
| `bundled:<tool>/<library>`, `upstream-pin:<tool>/<path>` | upgrade the tool that ships it |
| `lockfile:tools/npm/pnpm-lock.yaml` | an npm language server in `tools/npm/package.json` (steps 2-4) |
| `lockfile:tools/python/uv.lock` | a Python tool in `tools/python/pyproject.toml` (steps 2-4) |
| `nvim-plugin:*`, `treesitter-parser:*` | move the pin to a commit that contains the fix (`zzd neovim check-updates`) |
| `tmux-plugin:*`, `oh-my-zsh:*` | move the commit in `tmux/zzd/pins` or `zsh/zzd/pins` |
| `submodule:*` | move the submodule to a commit that contains the fix |
| `os-package:*` | `sudo dnf upgrade --advisory=<id>` (Fedora) or the distribution's update; the owner runs it |
| `install:*` | an install nothing pins: remove it (`mise prune`) or pin a fixed version |

## 2. Find who pulls it in

- npm: `pnpm why <package>` inside `tools/npm`, with the pinned pnpm
  (`mise -C "$HOME" which pnpm`).
- Python: `uv tree --invert --package <package>` inside `tools/python`, with
  the pinned uv.
- mise: the tool itself is the package.

Take versions from the lockfiles and the registry, never from memory.

## 3. Fix at the source first, in this order

1. An update within the declared ranges: `zzd/bin/zzd upgrade` re-resolves
   both tool locks within ranges and overrides. Re-run the audit.
2. An upgrade of the tool that pulls the package in: check the registry for a
   release whose dependency range allows the fixed version; change the exact
   version in `tools/npm/package.json` or `tools/python/pyproject.toml`, or use
   `zzd/bin/zzd upgrade <tool>` for a mise tool.
3. Only when neither works: force the fixed version. For npm, add an entry to
   `overrides` in `tools/npm/pnpm-workspace.yaml` (exact version, the lowest
   release line that fixes it); for Python, constrain it in
   `tools/python/pyproject.toml`. Name the advisory in the commit message.

Record what you checked for each step: the next reader needs to know why an
override was necessary.

## 4. Relock and install

- npm: `pnpm install --lockfile-only` in `tools/npm`.
- Python: `uv lock` in `tools/python`.
- Then `zzd/bin/zzd apply tools`.

## 5. Prove the tools still work

1. `node tools/zzd/smoke/overrides.mjs`. When you added an override, add a
   check to that file that exercises the overridden package through the tool
   that depends on it, like the existing ones.
2. `node tools/zzd/smoke/lsp-smoke.mjs`.
3. `zzd/bin/zzd audit --declared --gate` exits 0, and the finding is gone
   from `zzd/bin/zzd audit --all`.
4. The `run-checks` skill passes.

If the tool breaks with the fixed version, do not ship the override: upgrade
or replace the tool, or report the chain to the user with what you checked.
