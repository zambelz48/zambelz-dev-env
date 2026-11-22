# Report Output Development Plan

## MANDATORY RULES

1. **Adhere to AGENTS.md**: follow its guidelines throughout.
2. **Verify before you assert**: check every external behaviour.
3. **Mark completed tasks**: tick each task the moment its result is seen.
4. **Validate work**: run the `run-checks` skill at the end of every phase.
5. **Work phase by phase**: finish one phase before the next.

## Overview

Add a JSON output. The hook rejects list items written `- [X]` or `* [ ]`, but quoting them in prose is fine.

This plan is written for AI agents executing the implementation.

## Phase 1: JSON output

### Tasks

- [ ] Write a failing test.
- [x] Add the flag.

```text
## Phase 9: not a real heading inside a fence
```

## Phase 2: Docs

### Tasks

- [ ] Document the flag.

## Success Criteria

- [ ] The output is JSON.
