---
name: fix-cve
description: Fix a known vulnerability that zconf audit reports in the pinned tools, at the source first and with an override only when no source fix exists, then prove the tools still work. Use when zconf audit --declared fails or the cve-guard hook blocks a commit or push.
---

# Fix a CVE

Findings are never accepted: there is no ignore list and no bypass
(`README.md` "Security audit and pre-push hook"). Every finding is fixed.

## 1. Read the finding

Run `zconf/bin/zconf audit --declared`. For each row note the advisory, the
package, its version, the fixed version and the source file:

| Source | Owner |
| --- | --- |
| `mise/mise.lock` | a mise tool (crates, Go, RubyGems backends) |
| `tools/npm/pnpm-lock.yaml` | an npm language server in `tools/npm/package.json` |
| `tools/python/uv.lock` | a Python tool in `tools/python/pyproject.toml` |

## 2. Find who pulls it in

- npm: `pnpm why <package>` inside `tools/npm`, with the pinned pnpm
  (`mise -C "$HOME" which pnpm`).
- Python: `uv tree --invert --package <package>` inside `tools/python`, with
  the pinned uv.
- mise: the tool itself is the package.

Take versions from the lockfiles and the registry, never from memory.

## 3. Fix at the source first, in this order

1. An update within the declared ranges: `zconf/bin/zconf upgrade` re-resolves
   both tool locks within ranges and overrides. Re-run the audit.
2. An upgrade of the tool that pulls the package in: check the registry for a
   release whose dependency range allows the fixed version; change the exact
   version in `tools/npm/package.json` or `tools/python/pyproject.toml`, or use
   `zconf/bin/zconf upgrade <tool>` for a mise tool.
3. Only when neither works: force the fixed version. For npm, add an entry to
   `overrides` in `tools/npm/pnpm-workspace.yaml` (exact version, the lowest
   release line that fixes it); for Python, constrain it in
   `tools/python/pyproject.toml`. Name the advisory in the commit message.

Record what you checked for each step: the next reader needs to know why an
override was necessary.

## 4. Relock and install

- npm: `pnpm install --lockfile-only` in `tools/npm`.
- Python: `uv lock` in `tools/python`.
- Then `zconf/bin/zconf apply tools`.

## 5. Prove the tools still work

1. `node tools/zconf/smoke/overrides.mjs`. When you added an override, add a
   check to that file that exercises the overridden package through the tool
   that depends on it, like the existing ones.
2. `node tools/zconf/smoke/lsp-smoke.mjs`.
3. `zconf/bin/zconf audit --declared` exits 0.
4. The `run-checks` skill passes.

If the tool breaks with the fixed version, do not ship the override: upgrade
or replace the tool, or report the chain to the user with what you checked.
