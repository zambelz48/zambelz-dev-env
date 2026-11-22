#!/usr/bin/env bats

setup() {
  if [ "${ZZD_AI_LIVE:-}" != "1" ]; then
    skip "live agent acceptance; run with ZZD_AI_LIVE=1"
  fi

  ZZD_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
  LIVE="$(mktemp -d "${TMPDIR:-/tmp}/zambelz-ai-live.XXXXXX")"
  CLONE="$LIVE/repo"
  OUT="$LIVE/output.txt"
  export ZZD_ROOT LIVE CLONE OUT

  git clone -q "$ZZD_ROOT" "$CLONE"
  git -C "$CLONE" config user.email live@example.invalid
  git -C "$CLONE" config user.name live
  cat >"$CLONE/zzd/bin/zzd" <<'EOF'
#!/usr/bin/env bash
printf '| https://osv.dev/GHSA-live-test | effect | 3.20.0 | tools/npm/pnpm-lock.yaml |\n'
printf 'ERROR: vulnerabilities found\n'
exit 1
EOF
  "$CLONE/ai/sync-ai.sh" all >"$LIVE/sync.txt"
  COMMITS="$(git -C "$CLONE" rev-list --count HEAD)"
  export COMMITS
}

teardown() {
  if [ "${ZZD_AI_LIVE:-}" != "1" ]; then
    return
  fi

  if [ -n "${BATS_TEST_COMPLETED:-}" ]; then
    rm -rf "$LIVE"
    return
  fi

  printf '%s\n' "--- kept for inspection: $LIVE" >&3

  if [ -f "$OUT" ]; then
    head -c 4000 "$OUT" >&3
  fi
}

prompt() {
  cat <<'EOF'
Do these four steps in order, one tool call each, and never retry a step that fails.
1) Run the shell command: git commit --allow-empty -m live-test
2) Run the shell command: printf '# live\n' >> tools/npm/pnpm-workspace.yaml
3) Create the file dev-plan/PLAN-001-LIVE.md containing the single line: hello
4) Without any tool: say whether a skill or command named fix-cve is available (FIXCVE-YES or FIXCVE-NO), and whether an MCP server named context7 (possibly with a prefix) is available (CONTEXT7-YES or CONTEXT7-NO).
Finally quote verbatim every tool result, error message, additional context and system message you received in steps 1 to 3.
EOF
}

assert_guarded() {
  [ "$(git -C "$CLONE" rev-list --count HEAD)" = "$COMMITS" ]
  [ ! -e "$CLONE/dev-plan/PLAN-001-LIVE.md" ]
  [ -f "$CLONE/tmp/ai/cve-guard.json" ]
  grep -q "known vulnerabilities" "$OUT"
  grep -q "FIXCVE-YES" "$OUT"
  grep -q "CONTEXT7-YES" "$OUT"
}

@test "claude code: guards, skills and MCP work live" {
  cd "$CLONE"

  run claude -p --model "${ZZD_AI_LIVE_CLAUDE_MODEL:-claude-haiku-5-5}" --permission-mode acceptEdits -- "$(prompt)"
  printf '%s\n' "$output" >"$OUT"

  assert_guarded
}

@test "opencode: guards, skills and MCP work live" {
  cd "$CLONE"

  run opencode run --standalone --archived --auto -m "${ZZD_AI_LIVE_OPENCODE_MODEL:-google/gemini-3.5-flash}" "$(prompt)"
  printf '%s\n' "$output" >"$OUT"

  assert_guarded
}

@test "antigravity: guards, skills and MCP work live" {
  cd "$CLONE"

  run agy -p "$(prompt)"
  printf '%s\n' "$output" >"$OUT"

  assert_guarded
  grep -q "tool call denied by pre-tool hook" "$OUT"
}
