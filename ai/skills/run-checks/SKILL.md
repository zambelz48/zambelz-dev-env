---
name: run-checks
description: Run this repository's whole verification gate (tests, lint, pins, audit, per-tool validation, agent setup check) and report every result as printed. Use after any change, at the end of every plan phase, and before saying work is done.
---

# Run the checks

Run every step below from the repository root, in this order, even when an
earlier step fails. Never run a hand-picked subset, and never skip a step
because the change looks unrelated.

## 1. The gate

1. `zconf/tests/run`
2. `zconf/bin/lint`
3. `zconf/bin/zconf check-pins`
4. `zconf/bin/zconf audit --declared`
5. `ai/sync-ai.sh --check all`, when anything under `ai/` changed; run
   `ai/sync-ai.sh all` first if the agents were never synced on this machine.

## 2. Per-tool validation

For each tool whose configuration the change touched, also run its check from
`AGENTS.md` "Build/Lint/Test":

- Neovim: `nvim --headless +qa` exits cleanly, and the relevant
  `:checkhealth` sections report no new errors.
- tmux: `tmux -L probe -f tmux/.tmux.conf new -d`, inspect, then
  `tmux -L probe kill-server`.
- Shell scripts: `bash -n` or `zsh -n` on each changed file.

## 3. Report

- Quote each command with its exit code and the lines that matter (the
  summary line, every `ERROR:` and `WARN:`).
- A failure is reported as a failure with its output. Do not retry until it
  passes, do not reword it, and do not call the work done while any step
  fails.
- Say which steps did not apply and why.
