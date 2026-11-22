#!/usr/bin/env bats

setup() {
  load ai_helpers
  ai_test_setup

  cp "$ZZD_ROOT/ai/hooks/dev_plan.py" "$AI/hooks/"
  cat >"$AI/hooks/hooks.toml" <<'EOF'
[[hook]]
name = "dev-plan"
module = "dev_plan"
events = ["tool.before"]
summary = "Plans in dev-plan/ that miss the required format"
EOF

  mkdir -p "$REPO/dev-plan"
  VALID="$ZZD_ROOT/zzd/tests/fixtures/ai/plan_valid.md"
  PLAN="dev-plan/PLAN-001-REPORT.md"
}

write_plan() {
  local text="$1"

  ai_payload claude/write.json FILE="$PLAN" CONTENT="$text" >"$BATS_TEST_TMPDIR/payload.json"
  run "$AI/hook.sh" claude PreToolUse <"$BATS_TEST_TMPDIR/payload.json"
}

edit_plan() {
  local fixture="$1" old="$2" new="$3"

  ai_payload "$fixture" FILE="$PLAN" OLD="$old" NEW="$new" >"$BATS_TEST_TMPDIR/payload.json"
  run "$AI/hook.sh" claude PreToolUse <"$BATS_TEST_TMPDIR/payload.json"
}

valid_without() {
  grep -vF -- "$1" "$VALID"
}

@test "a valid plan is allowed, including bad checkboxes quoted in prose" {
  write_plan "$(cat "$VALID")"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a plan without MANDATORY RULES is denied" {
  write_plan "$(valid_without '## MANDATORY RULES')"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
  [[ "$output" == *"missing the '## MANDATORY RULES' section"* ]]
  [[ "$output" == *"create-dev-plan skill"* ]]
}

@test "a plan without an Overview or any phase is denied with every problem" {
  write_plan "$(grep -vE '^## (Overview|Phase)' "$VALID")"

  [[ "$output" == *"missing the '## Overview' section"* ]]
  [[ "$output" == *"missing a '## Phase <n>' section"* ]]
}

@test "each required rule phrase is checked" {
  write_plan "$(valid_without 'Work phase by phase' | grep -vF 'Mark completed tasks')"

  [[ "$output" == *"does not say 'Work phase by phase'"* ]]
  [[ "$output" == *"does not say 'Mark completed tasks'"* ]]
  [[ "$output" != *"Adhere to AGENTS.md'"* ]]
}

@test "a phase without a checkbox task is denied" {
  write_plan "$(valid_without '- [ ] Document the flag.')"

  [[ "$output" == *"'## Phase 2: Docs' has no '- [ ]' or '- [x]' task"* ]]
}

@test "a heading inside a code fence is not a phase" {
  write_plan "$(cat "$VALID")"

  [[ "$output" != *"Phase 9"* ]]
}

@test "invalid checkbox list items are denied" {
  write_plan "$(cat "$VALID")
- [X] done
* [ ] other
- [] empty"

  [[ "$output" == *"line 37 uses an invalid checkbox"* ]]
  [[ "$output" == *"line 38 uses an invalid checkbox"* ]]
  [[ "$output" == *"line 39 uses an invalid checkbox"* ]]
}

@test "an edit is checked against the whole new file" {
  cp "$VALID" "$REPO/$PLAN"

  edit_plan claude/edit.json "Add the flag." "Add the --format flag."

  [ "$status" -eq 0 ]
  [ -z "$output" ]

  edit_plan claude/edit.json "**Work phase by phase**" "**Go**"

  [[ "$output" == *"does not say 'Work phase by phase'"* ]]
}

@test "an edit replaces the first match unless it asks for all" {
  cp "$VALID" "$REPO/$PLAN"

  edit_plan claude/edit.json "- [ ]" "-"

  [ -z "$output" ]

  edit_plan claude/multiedit.json "- [ ]" "-"

  [[ "$output" == *"'## Phase 2: Docs' has no '- [ ]' or '- [x]' task"* ]]
}

@test "an edit whose old text is missing is denied" {
  cp "$VALID" "$REPO/$PLAN"

  edit_plan claude/edit.json "no such text" "x"

  [[ "$output" == *"cannot be checked"*"Re-read the file"* ]]
}

@test "an edit of a plan that does not exist is denied" {
  edit_plan claude/edit.json "x" "y"

  [[ "$output" == *"cannot be checked"* ]]
}

@test "a patch that touches a plan is denied" {
  cat >"$BATS_TEST_TMPDIR/payload.json" <<EOF
{
  "directory": "$REPO",
  "event": {
    "tool": "apply_patch",
    "input": {
      "patchText": "*** Begin Patch\n*** Update File: $PLAN\n@@\n-a\n+b\n*** End Patch"
    }
  }
}
EOF

  run "$AI/hook.sh" opencode execute.before <"$BATS_TEST_TMPDIR/payload.json"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "deny"'* ]]
  [[ "$output" == *"use the write or edit tool"* ]]
}

@test "files outside dev-plan are not checked" {
  ai_payload claude/write.json FILE="notes/PLAN-001-X.md" CONTENT="anything" >"$BATS_TEST_TMPDIR/payload.json"

  run "$AI/hook.sh" claude PreToolUse <"$BATS_TEST_TMPDIR/payload.json"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "other files in dev-plan are not checked" {
  ai_payload claude/write.json FILE="dev-plan/notes.md" CONTENT="anything" >"$BATS_TEST_TMPDIR/payload.json"

  run "$AI/hook.sh" claude PreToolUse <"$BATS_TEST_TMPDIR/payload.json"

  [ -z "$output" ]
}

@test "antigravity edit_file replaces every occurrence before the check" {
  cp "$VALID" "$REPO/$PLAN"
  ai_payload antigravity/edit_file.json FILE="$PLAN" OLD="- [ ]" NEW="-" >"$BATS_TEST_TMPDIR/payload.json"

  run "$AI/hook.sh" antigravity PreToolUse <"$BATS_TEST_TMPDIR/payload.json"

  [[ "$output" == *'"decision": "deny"'* ]]
  [[ "$output" == *"has no '- [ ]' or '- [x]' task"* ]]
}
