---
description: Resume work from a development plan
argument-hint: "<plan number or name>"
---

Resume work from a plan in `dev-plan/`. `$ARGUMENTS` is the plan's number or
name (`007`, `PLAN-007` or `AUTH-FLOW`).

## 1. Locate the plan

Run `ls dev-plan/PLAN-*.md`. Strip a leading `PLAN-` from `$ARGUMENTS`, then
match a number as `PLAN-<n>-*.md` and a name as `PLAN-*<name>*.md`. Read the
matching file completely. When nothing matches, list the plans, ask the user
which one to resume, and stop.

## 2. Find the current state

- Completed phases: every checkbox in the phase is `[x]`.
- Current phase: the first phase with an unticked task.
- Next action: the first unticked task in the current phase.

## 3. Load the context

Read `AGENTS.md` and the files the plan names.

## 4. Report the status

```markdown
## Plan status: {plan name}

Progress: {X}/{total} phases complete

Completed phases:
- Phase 1: {name}

Current phase: Phase {N}, {name} ({X}/{Y} tasks complete)

Next task:
- [ ] {first unticked task}

{One or two sentences on what the next task needs.}
```

Then ask whether to proceed with the next task, and wait.

## Rules

- Tick each task `[x]` the moment its result is seen.
- Run the `run-checks` skill at the end of every phase.
- Work phase by phase: finish the current phase before starting the next.
