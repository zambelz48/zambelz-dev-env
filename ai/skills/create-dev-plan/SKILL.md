---
name: create-dev-plan
description: Create or restructure a development plan in dev-plan/ with mandatory rules, phases, checkbox tasks and verification, in the format the dev-plan hook checks. Use for any multi-phase work an AI agent will execute.
---

# Create a dev plan

A plan guides AI agents through multi-phase work. It is written for agents,
verified before it is written, and checked by the `dev-plan` hook on every
write and edit.

## Before writing

- Know the goal, the plans that must finish first, and the technologies
  involved, with their versions from this repository's version files
  (`mise/mise.toml`, `mise/mise.lock`, `tools/`) and `AGENTS.md`.
- Verify every external behaviour the plan relies on against the installed
  source, current docs (`context7`, web fetch) and, for known-tricky areas, the
  issue tracker. Record each fact in the plan's verified reference.

## File name

`dev-plan/PLAN-<NNN>-<NAME>.md`: `NNN` is the next three-digit number
(`ls dev-plan/PLAN-*.md`, the highest plus one); `NAME` is uppercase and
hyphenated (`AUTH-FLOW`). `dev-plan/` is gitignored: plans are working
documents, never committed.

Change plan files with the write and edit tools. A patch tool cannot change a
plan: the hook cannot check it.

## What the hook checks

A write or edit of `dev-plan/PLAN-*.md` is denied, with the list of problems,
unless the resulting file has:

- the sections `## MANDATORY RULES`, `## Overview` and at least one
  `## Phase <n>`;
- in the rules section, the phrases "Adhere to AGENTS.md", "Mark completed
  tasks" and "Work phase by phase";
- checkbox tasks written `- [ ]` or `- [x]`, at least one in every phase;
- no list item written `- []`, `- [X]` or `* [ ]`.

Headings inside code fences do not count.

## Structure

Sections in this order:

1. `# <Feature> Development Plan`.
2. `## MANDATORY RULES`, with these five rules:

   ````markdown
   ## MANDATORY RULES

   1. **Adhere to AGENTS.md**: follow its guidelines, constraints and standards throughout.
   2. **Verify before you assert (non-negotiable)**: never write or execute a step from training-data
      assumptions about a library, framework, runtime or version. Verify each external behaviour against the
      installed source or existing working code, current docs (`context7`, web fetch) and, for known-tricky
      areas, the issue tracker, before the phase that relies on it; record it in the Verified Reference.
   3. **Mark completed tasks**: tick each task `- [x]` the moment its result is seen.
   4. **Validate work**: run the `run-checks` skill at the end of every phase; never a hand-picked subset of
      checks.
   5. **Work phase by phase**: finish one phase entirely before starting the next.
   ````

3. `## Overview`: one or two paragraphs on what the plan achieves and why,
   ending with "This plan is written for AI agents executing the
   implementation."
4. `## Prerequisites`, when there are any: plans that must be complete, other
   requirements, human-only actions.
5. `## Versions`: each technology the plan relies on and where this repository
   pins it. Never a version from memory.
6. `## Status`: one row per phase with its status.
7. `## Structure`, when the plan creates files: the tree of new and changed
   files.
8. `## Phase <n>: <name>`, once per phase: a one-sentence **Goal**, the
   **Tasks** as checkboxes, the **Watch-outs** with a pre-decided fallback for
   each, and a **Verification** list: the `run-checks` skill plus what must be
   observably true after this phase.
9. `## Success Criteria`: checkboxes per phase.
10. `## Verified Reference`: every external fact the plan relies on, with its
    source (installed file, doc page and date, issue).
11. `## Reference Commands`: the commands the phases use, taken from this
    repository's own scripts. The verification gate appears only as the
    `run-checks` skill.

A green gate is static verification only. When a phase changes runtime
behaviour or a user interface, its verification also runs it and observes
the result.

## Robustness

A mid-execution stop (the agent starts confidently, then stalls because an
assumption broke) is a symptom of premature planning. Prevent it while writing
the plan, never by hiding problems:

1. **Verify external assumptions before the phase that relies on them**,
   against the installed source or current docs, never from training data and
   never by re-reading the plan.
2. **Pre-decide a fallback for every known risk** and write it into the phase,
   so meeting it means "run the fallback and note it", not "stop and ask".
3. **Put human-only actions at phase boundaries**: installs, approvals and
   commits are announced at the start of the phase that needs them, never
   sprung mid-phase. Agents commit only when the user asks (`AGENTS.md`).

Truth is non-negotiable: a genuine unforeseen problem (a broken premise, a
real regression) is always reported mid-execution with a concrete reason.
Papering over it to keep momentum is the worst outcome.

## Checklist

- [ ] Title, the five mandatory rules, an Overview with the AI agent sentence,
  a Status table.
- [ ] Every phase has a goal, specific checkbox tasks, watch-outs with
  fallbacks, and a verification that runs the `run-checks` skill (never a list
  of individual checks).
- [ ] Phases that change runtime behaviour or a user interface verify it by
  running it.
- [ ] Versions point to where this repository pins them.
- [ ] Every external assumption is in the Verified Reference with its source.
- [ ] Human-only actions sit at phase boundaries.

## Anti-patterns

| Anti-pattern | Why it fails | Instead |
| --- | --- | --- |
| Vague tasks ("Set up X") | The agent cannot tell when it is done | Name the file, command or observable result |
| No verification | Completion cannot be confirmed | The `run-checks` skill plus a phase-specific result |
| A list of individual checks | It misses checks the gate gains later | The `run-checks` skill |
| Versions written into the plan | They go stale | Point to where the repository pins them |
| Library behaviour from memory | A wrong premise breaks execution mid-phase | Verify it while planning; record it |
| A risk without a fallback | The agent stalls to ask | Pre-decide the fallback in the phase |
| Hiding a real problem to avoid stopping | Ships broken work and breaks trust | Report it with a concrete reason |

## Example plan

````markdown
# Doctor JSON Output Development Plan

## MANDATORY RULES

1. **Adhere to AGENTS.md**: follow its guidelines, constraints and standards throughout.
2. **Verify before you assert (non-negotiable)**: never write or execute a step from training-data
   assumptions about a library, framework, runtime or version. Verify each external behaviour against the
   installed source or existing working code, current docs (`context7`, web fetch) and, for known-tricky
   areas, the issue tracker, before the phase that relies on it; record it in the Verified Reference.
3. **Mark completed tasks**: tick each task `- [x]` the moment its result is seen.
4. **Validate work**: run the `run-checks` skill at the end of every phase; never a hand-picked subset of
   checks.
5. **Work phase by phase**: finish one phase entirely before starting the next.

## Overview

Add `--json` to `zconf doctor`, so scripts can read the result without parsing text. The text output stays
the default and does not change.

This plan is written for AI agents executing the implementation.

## Versions

The JSON encoder is Python's standard library; Python is the version `mise/mise.toml` pins.

## Status

| Phase | Status | Description |
| --- | --- | --- |
| Phase 1: JSON output | [ ] Not Started | The flag and the encoder |
| Phase 2: Docs | [ ] Not Started | The README command table |

## Phase 1: JSON output

**Goal**: `zconf doctor --json` prints the result as one JSON object.

### Tasks

- [ ] Write a failing bats test: `zconf doctor --json` prints an object with the fields of the text output.
- [ ] Add the `--json` flag; any other unknown flag stays a usage error.
- [ ] Encode the result with the standard library encoder.

### Watch-outs

- Field order: if the test compares bytes, emit keys in a fixed order, so the output is stable.

### Verification

- [ ] `run-checks` skill passes.
- [ ] `zconf doctor --json` output parses as JSON; `zconf doctor` output is unchanged.

## Phase 2: Docs

**Goal**: the README documents the flag.

### Tasks

- [ ] Add `--json` to the README command table, with one example.

### Verification

- [ ] `run-checks` skill passes.
- [ ] The README and `zconf help` name the same flag.

## Success Criteria

- [ ] `zconf doctor --json` prints the result as JSON.
- [ ] The text output and its tests are unchanged.
- [ ] The docs and the help agree.

## Verified Reference

- Python's `json.dumps` keeps dict insertion order (checked in the installed standard library docs).
````
