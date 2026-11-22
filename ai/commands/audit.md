---
description: Scan the pinned or installed tools for known vulnerabilities and explain each finding
argument-hint: "[declared|installed]"
---

Run `zconf/bin/zconf audit --declared` from the repository root. When
`$ARGUMENTS` says `installed`, run `zconf/bin/zconf audit --installed`
instead.

Then report:

1. The exit code and what it means: 0 clean, 1 findings, 3 the scan could not
   run.
2. For each finding: the advisory, the package and version, the fixed version,
   and the file it comes from (`mise/mise.lock`, `tools/npm/pnpm-lock.yaml`,
   `tools/python/uv.lock`, or an installed path).
3. For each finding, the fix route from `README.md` "Security audit and
   pre-push hook": upgrade the tool that pulls the package in, or force a
   fixed version in `tools/npm/pnpm-workspace.yaml` `overrides` or
   `tools/python/pyproject.toml`. Name which one applies and why.

Change nothing. To fix a finding, use the `fix-cve` skill.
