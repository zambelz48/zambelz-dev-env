---
description: Audit every pinned and installed component for known vulnerabilities and explain each finding
argument-hint: "[declared|installed|all]"
---

From the repository root, run one of these:

- `zconf/bin/zconf audit --declared` when `$ARGUMENTS` says `declared`;
- `zconf/bin/zconf audit --installed` when it says `installed`;
- `zconf/bin/zconf audit --all` otherwise, including when it is empty.

Then report:

1. The exit code: 0 clean, 1 findings, uncovered components or leftover
   installs, 2 usage, 3 the audit could not run (nothing was proven clean).
   Quote the summary line.
2. Every finding, grouped by component, worst severity first: its label
   (`fix available, blocks push`, `blocks push` or `waiting for upstream`),
   the advisory and its aliases, the severity, the library and its fixed
   version, what the vulnerability is, the Action line, and the link.
3. Every `NOT COVERED`, `LEFTOVER` and `COULD NOT RUN` line, with its fix.

Findings marked `waiting for upstream` are open vulnerabilities in a tool
already at its newest release: report them as open, never as fixed or
accepted.

Change nothing. To fix a finding, use the `fix-cve` skill.
