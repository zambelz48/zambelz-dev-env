#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX/.githooks" "$FIX/zconf/bin"
  cp "$ZC_ROOT/.githooks/pre-push" "$FIX/.githooks/pre-push"
  TRACE="$BATS_TEST_TMPDIR/trace"
  export TRACE
  # Fake zconf: records each step, the tools it can see, and fails on demand.
  cat >"$FIX/zconf/bin/zconf" <<'EOF'
#!/usr/bin/env bash
echo "step $*" >>"$TRACE"
for tool in shellcheck osv-scanner python3; do
  if command -v "$tool" >/dev/null; then
    echo "found $tool" >>"$TRACE"
  fi
done
case " ${FAIL_STEP:-} " in
  *" $1 "*) exit "${FAIL_CODE:-1}" ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$FIX/zconf/bin/zconf"
  HOOK="$FIX/.githooks/pre-push"
}

@test "the hook runs check-pins, lint, then the declared audit" {
  run env PATH=/usr/bin:/bin "$HOOK" origin url </dev/null
  [ "$status" -eq 0 ]
  [ "$(grep '^step' "$TRACE")" = \
    "$(printf 'step check-pins\nstep lint\nstep audit --declared')" ]
}

@test "the hook finds the pinned tools with a bare PATH" {
  run env PATH=/usr/bin:/bin "$HOOK" origin url </dev/null
  [ "$status" -eq 0 ]
  grep -qx "found shellcheck" "$TRACE"
  grep -qx "found osv-scanner" "$TRACE"
  grep -qx "found python3" "$TRACE"
}

@test "the hook blocks when check-pins fails" {
  FAIL_STEP=check-pins run env PATH=/usr/bin:/bin "$HOOK" origin url \
    </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: push blocked: zconf check-pins failed"* ]] ||
    false
  [ "$(grep -c '^step' "$TRACE")" -eq 1 ]
}

@test "the hook blocks when lint fails" {
  FAIL_STEP=lint run env PATH=/usr/bin:/bin "$HOOK" origin url </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: push blocked: zconf lint failed"* ]] || false
}

@test "the hook blocks when the audit cannot run" {
  FAIL_STEP=audit FAIL_CODE=3 run env PATH=/usr/bin:/bin "$HOOK" origin url \
    </dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: push blocked: zconf audit --declared failed"* ]] ||
    false
}
