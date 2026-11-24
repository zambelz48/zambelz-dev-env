---
name: deep-research
description: Research a subject in depth against this codebase and current external sources, then write one report with a single decided recommendation to tmp/deep-research/yyyyMMdd_{subject}.md. Use when asked to deep-research, audit, compare options, or evaluate an approach, tool, or upgrade before any plan or code change. Read-only except for the report file.
---

Deep research produces **one report file** and changes nothing else. It ends
with a single decided recommendation that follows this repository's rules in
`AGENTS.md`.

## Output

- Path: `tmp/deep-research/yyyyMMdd_{subject}.md` at the repository root.
  `yyyyMMdd` is today's date; `{subject}` is a short lowercase slug of the
  subject, words joined by hyphens
  (`tmp/deep-research/20261011_tmux-plugin-manager.md`). If that file exists,
  append `-2`, `-3`, and so on.
- The report must stay untracked: check with
  `git check-ignore -q tmp/deep-research/x`.
- Never reference the report from a tracked file, and never write notes or
  scratch files anywhere else in the repository. Working notes worth keeping go
  into the report's appendix; everything else is discarded.
- Do not create, edit or delete any other file, do not install or upgrade
  anything, and do not commit.

## Step 1: Frame the question

Restate the subject as one question the report must answer, and list what a
good answer has to cover. Ask the user only if the subject is ambiguous in a
way that changes the research; otherwise proceed.

## Step 2: Gather evidence

Collect facts from both sides, and record where each one came from as you go.

**Inside the repository**

- Read the actual code and config. Follow the real mechanism end to end,
  through every layer it touches (config, plugin source, runtime, external
  tool), not a doc's description of it.
- Run things when running is the only way to know: a script against a sample
  input, a command in a scratch directory outside the repository, a test.
  Never test by changing tracked files.
- Take versions from this repository's lockfiles and version files
  (`mise/mise.lock`, `tools/npm/pnpm-lock.yaml`, `tools/python/uv.lock`,
  `neovim/lazy-lock.json`, the `zzd/pins` files), never from memory. For
  installed tools, check the installed version (`nvim --version`, `tmux -V`,
  `kitty --version`, plugin `git log`).

**Outside the repository**

- Official documentation through `context7` or web fetch, matched to the
  versions this repository pins.
- Registry facts (published versions, the dependencies of a specific version,
  release dates), source repositories, changelogs, issue trackers, advisories.
- Prefer primary sources. Date every fast-moving fact.

**Working alone**

Do every part yourself, one after another, in this session. Use subagents only
when the user asks for them in their own words.

## Step 3: Test the claims

Before anything goes into the report as a fact:

- Label it **verified** (and say how: read in code at `path:line`, executed, or
  quoted from a dated source), **inferred** (reasoned from verified facts), or
  **unverified**.
- Try to disprove the conclusions that matter most. A claim that decides the
  recommendation is verified by running or reading, not by reasoning.
- Unverified claims may be listed, but they never carry the recommendation.

## Step 4: Decide

The report gives **one** recommendation, not a menu:

1. **Fix at the source first.** For anything involving a dependency or a tool,
   check in order: an update within the declared range; an upgrade of the
   package or of whatever pulls it in, walking the whole chain and checking the
   versions an upgrade would actually install; an existing option or setting.
   Check every finding against every candidate upgrade. A workaround (patch,
   override, shim, wrapper, custom code) is recommended only when none of those
   works, and the report says what was checked.
2. **One source of truth.** Prefer changing the mechanism that already owns the
   concern (a zzd module, `mise/mise.toml`, `tools/`, `ai/`) over adding a
   file, command, check or list beside it. If the recommendation adds something
   new, say why nothing existing can carry it.
3. **No dead ends.** Walk each candidate path to its end. Drop any that leaves
   the user blocked, exposed, or with something left to rot. Do not present a
   dropped path as an option; mention it once under "Rejected" with the reason.
4. **Security.** Never recommend leaving or accepting a known vulnerability.
5. If two paths survive and differ only by preference, name the one you
   recommend and state the trade-off in one line.

## Step 5: Write the report

Lead with the answer. Plain ASCII, no emojis. Describe the end state for what
it does, not as a comparison with how things were.

```markdown
# {Subject}

Date: yyyy-MM-dd
Question: {the one question from Step 1}

## Recommendation

{The decision, in two to five sentences: what to do and why it is the right call.}

## What to do

{Ordered steps. Each step names the file or command, who does it (agent or human), and how to tell it worked.}

## Findings

| # | Finding | Evidence | Status | Recommendation |
|---|---|---|---|---|
| 1 | {what is true} | {path:line, command run, or dated source} | verified / inferred / unverified | {the action for this finding, or "none" and why} |

## Rejected

{Paths considered and dropped, one line each with the reason. Include upgrades that were checked and do not help.}

## Risks and open items

{What could still go wrong, and what the user has to verify themselves. Each item with its recommended action.}

## Sources

{External sources with URL and the date read. Repository evidence is cited inline in Findings.}

## Appendix

{Optional: raw data, command output, or notes that support a finding.}
```

Every row in Findings and every item in Risks has a recommendation. A finding
with no action says "none" and why.

## Step 6: Deliver

Reply with the report's path and a summary of three to five sentences: the
recommendation first, then what it rests on, then anything the user must
verify themselves. Do not paste the report into the reply, and do not start
implementing; a plan or a change is a separate request.
