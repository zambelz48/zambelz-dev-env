#!/usr/bin/env bats

setup() {
  load ai_helpers
  ai_test_setup

  ai_hook_module probe 'import json
import events


def handle(event):
    text = event.command or event.content or ""
    record = {
        "kind": event.kind,
        "agent": event.agent,
        "tool": event.tool,
        "tool_kind": event.tool_kind,
        "command": event.command,
        "path": str(event.path),
        "content": event.content,
        "edits": [[edit.old, edit.new, edit.replace_all] for edit in event.edits],
    }

    with open(event.repo_root / "events.jsonl", "a") as stream:
        stream.write(json.dumps(record) + "\n")

    if "RAISE" in text:
        raise RuntimeError("probe failure")

    if event.kind == events.BEFORE and "DENY" in text:
        return events.deny("PROBE-DENIED")

    if event.kind == events.AFTER and "WARN" in text:
        return events.warn("PROBE-WARNED")

    return None'
  cat >"$AI/hooks/hooks.toml" <<'EOF'
[[hook]]
name = "probe"
module = "probe"
events = ["tool.before", "tool.after"]
summary = "Probe"
EOF
}

hook() {
  local agent="$1" event="$2" fixture="$3"
  shift 3

  ai_payload "$fixture" "$@" >"$BATS_TEST_TMPDIR/payload.json"
  run "$AI/hook.sh" "$agent" "$event" <"$BATS_TEST_TMPDIR/payload.json"
}

recorded() {
  "$MISE_DATA_DIR/shims/python3" -c '
import json, sys
lines = open(sys.argv[1]).read().splitlines()
print(json.loads(lines[-1])[sys.argv[2]])
' "$REPO/events.jsonl" "$1"
}

@test "claude: no objection prints nothing" {
  hook claude PreToolUse claude/bash.json COMMAND="echo hello"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(recorded tool_kind)" = "shell" ]
  [ "$(recorded command)" = "echo hello" ]
}

@test "claude: a deny is a PreToolUse deny decision" {
  hook claude PreToolUse claude/bash.json COMMAND="echo DENY"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"hookEventName": "PreToolUse"'* ]]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
  [[ "$output" == *'"permissionDecisionReason": "PROBE-DENIED"'* ]]
}

@test "claude: warnings after a tool are additional context" {
  hook claude PostToolUse claude/bash.json COMMAND="echo WARN"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"hookEventName": "PostToolUse"'* ]]
  [[ "$output" == *'"additionalContext": "PROBE-WARNED"'* ]]
}

@test "claude: no warnings after a tool prints nothing" {
  hook claude PostToolUse claude/bash.json COMMAND="echo hello"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "claude: write, edit and multi-edit are decoded" {
  hook claude PreToolUse claude/write.json FILE="notes.md" CONTENT="hello"

  [ "$status" -eq 0 ]
  [ "$(recorded tool_kind)" = "write" ]
  [ "$(recorded path)" = "$REPO/notes.md" ]
  [ "$(recorded content)" = "hello" ]

  hook claude PreToolUse claude/edit.json FILE="notes.md" OLD="a" NEW="b"

  [ "$(recorded tool_kind)" = "edit" ]
  [ "$(recorded edits)" = "[['a', 'b', False]]" ]

  hook claude PreToolUse claude/multiedit.json FILE="notes.md" OLD="a" NEW="b"

  [ "$(recorded tool_kind)" = "multi-edit" ]
  [ "$(recorded edits)" = "[['a', 'b', True]]" ]
}

@test "claude: a hook that raises fails closed with exit 2" {
  hook claude PreToolUse claude/bash.json COMMAND="echo RAISE"

  [ "$status" -eq 2 ]
  [[ "$output" == *"zambelz-dev-env hook failed"*"probe failure"* ]]
}

@test "claude: a payload that is not JSON fails closed" {
  printf 'not json' >"$BATS_TEST_TMPDIR/payload.json"

  run "$AI/hook.sh" claude PreToolUse <"$BATS_TEST_TMPDIR/payload.json"

  [ "$status" -eq 2 ]
}

@test "claude: a payload without a tool name fails closed" {
  printf '{\n  "tool_input": {}\n}\n' >"$BATS_TEST_TMPDIR/payload.json"

  run "$AI/hook.sh" claude PreToolUse <"$BATS_TEST_TMPDIR/payload.json"

  [ "$status" -eq 2 ]
  [[ "$output" == *"no tool name"* ]]
}

@test "opencode: no objection is decision none" {
  hook opencode execute.before opencode/shell.json COMMAND="echo hello"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "none"'* ]]
  [ "$(recorded tool_kind)" = "shell" ]
}

@test "opencode: a deny carries the message" {
  hook opencode execute.before opencode/shell.json COMMAND="echo DENY"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "deny"'* ]]
  [[ "$output" == *'"message": "PROBE-DENIED"'* ]]
}

@test "opencode: warnings after a tool are returned" {
  hook opencode execute.after opencode/shell_after.json COMMAND="echo WARN"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "none"'* ]]
  [[ "$output" == *'"PROBE-WARNED"'* ]]
  [ "$(recorded kind)" = "tool.after" ]
}

@test "opencode: relative paths resolve against the session directory" {
  hook opencode execute.before opencode/write.json FILE="dev-plan/notes.md" CONTENT="x"

  [ "$status" -eq 0 ]
  [ "$(recorded path)" = "$REPO/dev-plan/notes.md" ]

  hook opencode execute.before opencode/edit.json FILE="notes.md" OLD="a" NEW="b"

  [ "$(recorded edits)" = "[['a', 'b', False]]" ]
}

@test "opencode: a hook that raises fails closed with exit 2" {
  hook opencode execute.before opencode/shell.json COMMAND="echo RAISE"

  [ "$status" -eq 2 ]
}

@test "antigravity: no objection prints nothing" {
  hook antigravity PreToolUse antigravity/run_command.json COMMAND="echo hello"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(recorded tool_kind)" = "shell" ]
}

@test "antigravity: a deny is a deny decision with a reason" {
  hook antigravity PreToolUse antigravity/run_command.json COMMAND="echo DENY"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"decision": "deny"'* ]]
  [[ "$output" == *'"reason": "PROBE-DENIED"'* ]]
}

@test "antigravity: write_file and edit_file are decoded; edit_file replaces all" {
  hook antigravity PreToolUse antigravity/write_file.json FILE="notes.md" CONTENT="hello"

  [ "$(recorded tool_kind)" = "write" ]
  [ "$(recorded path)" = "$REPO/notes.md" ]

  hook antigravity PreToolUse antigravity/edit_file.json FILE="notes.md" OLD="a" NEW="b"

  [ "$(recorded edits)" = "[['a', 'b', True]]" ]
}

@test "antigravity: warnings after a tool are injected before the next model call" {
  hook antigravity PostToolUse antigravity/run_command.json COMMAND="echo WARN"

  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]

  hook antigravity PreInvocation antigravity/preinvocation.json

  [ "$status" -eq 0 ]
  [[ "$output" == *'"injectSteps"'* ]]
  [[ "$output" == *'"systemMessage": "PROBE-WARNED"'* ]]

  hook antigravity PreInvocation antigravity/preinvocation.json

  [ "$output" = "{}" ]
}

@test "antigravity: PreInvocation without queued warnings prints an empty object" {
  hook antigravity PreInvocation antigravity/preinvocation.json

  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "antigravity: a broken queue never stops the model call" {
  mkdir -p "$REPO/tmp/ai/pending"
  printf 'not json' >"$REPO/tmp/ai/pending/conv-1.json"

  hook antigravity PreInvocation antigravity/preinvocation.json

  [ "$status" -eq 0 ]
  [[ "$output" == *"{}"* ]]
}

@test "antigravity: a hook that raises fails closed with exit 2" {
  hook antigravity PreToolUse antigravity/run_command.json COMMAND="echo RAISE"

  [ "$status" -eq 2 ]
}

@test "an unknown tool is passed under its own lowercased name" {
  printf '{\n  "tool_name": "WebFetch",\n  "tool_input": {\n    "url": "https://example.com"\n  }\n}\n' >"$BATS_TEST_TMPDIR/payload.json"

  run "$AI/hook.sh" claude PreToolUse <"$BATS_TEST_TMPDIR/payload.json"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(recorded tool)" = "webfetch" ]
  [ "$(recorded tool_kind)" = "None" ]
}

@test "no hooks.toml means no objection" {
  rm "$AI/hooks/hooks.toml"

  hook claude PreToolUse claude/bash.json COMMAND="echo DENY"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "no reply on any agent ever approves a call" {
  local fixture

  for fixture in "claude PreToolUse claude/bash.json" "claude PostToolUse claude/bash.json" \
    "opencode execute.before opencode/shell.json" "opencode execute.after opencode/shell_after.json" \
    "antigravity PreToolUse antigravity/run_command.json" "antigravity PostToolUse antigravity/run_command.json"; do
    for command in "echo hello" "echo DENY" "echo WARN"; do
      read -r agent event file <<<"$fixture"
      hook "$agent" "$event" "$file" COMMAND="$command"

      if [[ "$output" =~ \"(permissionDecision|decision)\":\ *\"(allow|ask|approve|auto_approve)\" ]]; then
        echo "approving reply from $agent $event: $output"
        return 1
      fi
    done
  done
}
