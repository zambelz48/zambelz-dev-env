#!/usr/bin/env bats

setup() {
  load ai_helpers
  ai_test_setup

  cp "$ZC_ROOT/ai/hooks/cve_guard.py" "$AI/hooks/"
  cat >"$AI/hooks/hooks.toml" <<'EOF'
[[hook]]
name = "cve-guard"
module = "cve_guard"
events = ["tool.before", "tool.after"]
summary = "Blocks git commit and push while zconf audit --declared fails"
EOF

  AUDIT_CALLS="$BATS_TEST_TMPDIR/calls/zconf"
  AUDIT_CODE="$BATS_TEST_TMPDIR/audit-code"
  AUDIT_SLEEP="$BATS_TEST_TMPDIR/audit-sleep"
  export AUDIT_CALLS AUDIT_CODE AUDIT_SLEEP
  printf '0\n' >"$AUDIT_CODE"
  printf '0\n' >"$AUDIT_SLEEP"

  mkdir -p "$REPO/zconf/bin" "$REPO/tools/npm"
  cat >"$REPO/zconf/bin/zconf" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$AUDIT_CALLS"
sleep "$(cat "$AUDIT_SLEEP")"
code="$(cat "$AUDIT_CODE")"

case "$code" in
  1)
    printf 'Scanned 3 files\n'
    printf '| OSV URL | PACKAGE |\n'
    printf '| https://osv.dev/GHSA-test | effect |\n'
    printf 'ERROR: vulnerabilities found\n'
    printf '  fix: upgrade the tool\n'
    ;;
  3)
    printf 'ERROR: scan could not run (osv-scanner exit 128)\n'
    ;;
  *)
    printf 'OK: no known vulnerabilities\n'
    ;;
esac

exit "$code"
EOF
  chmod +x "$REPO/zconf/bin/zconf"
  printf 'lockfileVersion: 9\n' >"$REPO/tools/npm/pnpm-lock.yaml"
}

gated() {
  "$MISE_DATA_DIR/shims/python3" -E -s -c '
import sys
sys.path[:0] = [sys.argv[1], sys.argv[2]]
import cve_guard
print(cve_guard.is_gated(sys.argv[3]))
' "$AI/lib" "$AI/hooks" "$1"
}

bash_hook() {
  local event="$1" command="$2"

  ai_payload claude/bash.json COMMAND="$command" >"$BATS_TEST_TMPDIR/payload.json"
  run "$AI/hook.sh" claude "$event" <"$BATS_TEST_TMPDIR/payload.json"
}

audits() {
  if [ -f "$AUDIT_CALLS" ]; then
    wc -l <"$AUDIT_CALLS" | tr -d ' '
  else
    printf '0\n'
  fi
}

@test "commits and pushes are detected" {
  local command

  for command in "git commit -m x" "git -C . push" "cd a && git commit" "/usr/bin/git push origin main" \
    "GIT_DIR=x git commit" "git -c user.name=x commit" "(git push)" "echo \$(git commit -m x)" \
    "make; git push" "env FOO=1 git commit" "git --no-pager commit" "a | git push" "git commit&"; do
    if [ "$(gated "$command")" != "True" ]; then
      echo "not detected: $command"
      return 1
    fi
  done
}

@test "other commands are not detected" {
  local command

  for command in "git log" 'echo "git commit"' "git commit-tree abc" "gitk" "git status && echo commit" \
    "git -C commit status" "git help commit" "git show HEAD:push" "echo git push" "ls"; do
    if [ "$(gated "$command")" != "False" ]; then
      echo "wrongly detected: $command"
      return 1
    fi
  done
}

@test "a commit is allowed while the audit is clean" {
  bash_hook PreToolUse "git commit -m x"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(audits)" = "1" ]
}

@test "a commit is denied while the audit reports vulnerabilities" {
  printf '1\n' >"$AUDIT_CODE"

  bash_hook PreToolUse "git commit -m x"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
  [[ "$output" == *"reports known vulnerabilities"* ]]
  [[ "$output" == *"GHSA-test"* ]]
  [[ "$output" == *"no bypass"* ]]
  [[ "$output" != *"Scanned 3 files"* ]]
}

@test "a push is denied when the audit cannot run" {
  printf '3\n' >"$AUDIT_CODE"

  bash_hook PreToolUse "git push"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
  [[ "$output" == *"could not run"* ]]
  [[ "$output" == *"osv-scanner exit 128"* ]]
}

@test "an audit that never finishes counts as could not run" {
  printf '3\n' >"$AUDIT_SLEEP"

  run "$MISE_DATA_DIR/shims/python3" -E -s -c '
import sys
from pathlib import Path
sys.path[:0] = [sys.argv[1], sys.argv[2]]
import cve_guard
cve_guard.AUDIT_TIMEOUT_SECONDS = 1
audit = cve_guard.run_audit(Path(sys.argv[3]))
print(audit.code, audit.detail)
' "$AI/lib" "$AI/hooks" "$REPO"

  [ "$status" -eq 0 ]
  [[ "$output" == "3 the scan did not finish within 1 seconds" ]]
}

@test "other shell commands do not run the audit" {
  bash_hook PreToolUse "git status"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(audits)" = "0" ]
}

@test "the first after-tool call records the baseline quietly" {
  bash_hook PostToolUse "ls"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -f "$REPO/tmp/ai/cve-guard.json" ]
  [ "$(audits)" = "1" ]
}

@test "unchanged lockfiles do not run the audit again" {
  bash_hook PostToolUse "ls"
  bash_hook PostToolUse "ls"

  [ -z "$output" ]
  [ "$(audits)" = "1" ]
}

@test "a lockfile change reports a clean audit" {
  bash_hook PostToolUse "ls"
  printf 'lockfileVersion: 9\npackages: {}\n' >"$REPO/tools/npm/pnpm-lock.yaml"

  bash_hook PostToolUse "pnpm install"

  [ "$status" -eq 0 ]
  [[ "$output" == *"no known vulnerabilities after changes to tools/npm/pnpm-lock.yaml"* ]]
  [ "$(audits)" = "2" ]
}

@test "a lockfile change reports findings" {
  bash_hook PostToolUse "ls"
  printf '1\n' >"$AUDIT_CODE"
  printf 'lockfileVersion: 9\npackages: {}\n' >"$REPO/tools/npm/pnpm-lock.yaml"

  bash_hook PostToolUse "pnpm install"

  [ "$status" -eq 0 ]
  [[ "$output" == *'"additionalContext"'* ]]
  [[ "$output" == *"reports known vulnerabilities after changes to tools/npm/pnpm-lock.yaml"* ]]
  [[ "$output" == *"GHSA-test"* ]]
}

@test "a new watched file counts as a change" {
  bash_hook PostToolUse "ls"
  mkdir -p "$REPO/tools/python"
  printf 'version = 1\n' >"$REPO/tools/python/uv.lock"

  bash_hook PostToolUse "uv lock"

  [[ "$output" == *"after changes to tools/python/uv.lock"* ]]
}

@test "antigravity gets lockfile findings on its next model call" {
  ai_payload antigravity/run_command.json COMMAND="ls" >"$BATS_TEST_TMPDIR/payload.json"
  "$AI/hook.sh" antigravity PostToolUse <"$BATS_TEST_TMPDIR/payload.json"
  printf '1\n' >"$AUDIT_CODE"
  printf 'lockfileVersion: 9\npackages: {}\n' >"$REPO/tools/npm/pnpm-lock.yaml"

  run "$AI/hook.sh" antigravity PostToolUse <"$BATS_TEST_TMPDIR/payload.json"

  [ "$output" = "{}" ]

  ai_payload antigravity/preinvocation.json >"$BATS_TEST_TMPDIR/invocation.json"
  run "$AI/hook.sh" antigravity PreInvocation <"$BATS_TEST_TMPDIR/invocation.json"

  [[ "$output" == *"reports known vulnerabilities"* ]]
}
