#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  FIX="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$FIX/.githooks" "$FIX/zconf/bin"
  cp "$ZC_ROOT/.githooks/pre-push" "$FIX/.githooks/pre-push"
  TRACE="$BATS_TEST_TMPDIR/trace"
  export TRACE
  # Fake zconf: records each step, the commit it sees, the tools it can see,
  # and fails on demand or when the checked-out marker says broken.
  cat >"$FIX/zconf/bin/zconf" <<'EOF'
#!/usr/bin/env bash
marker="$(cat "$(dirname "$0")/../../marker")"
echo "step $* on $marker" >>"$TRACE"
for tool in shellcheck osv-scanner python3; do
  if command -v "$tool" >/dev/null; then
    echo "found $tool" >>"$TRACE"
  fi
done
if [ "$marker" = "broken" ]; then
  exit 1
fi
case " ${FAIL_STEP:-} " in
  *" $1 "*) exit "${FAIL_CODE:-1}" ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$FIX/zconf/bin/zconf"
  git -C "$FIX" init -q
  HOOK="$FIX/.githooks/pre-push"
  ZERO=0000000000000000000000000000000000000000
}

commit_marker() {
  printf '%s\n' "$1" >"$FIX/marker"
  git -C "$FIX" add -A
  git -C "$FIX" -c user.name=test -c user.email=test@example.com \
    -c commit.gpgsign=false commit -q -m "$1"
  git -C "$FIX" rev-parse HEAD
}

push() {
  printf 'refs/heads/main %s refs/heads/main %s\n' "$1" "$ZERO" |
    env PATH=/usr/bin:/bin "$HOOK" origin url
}

worktrees() {
  git -C "$FIX" worktree list | wc -l | tr -d ' '
}

@test "the hook runs check-pins, lint, then the declared audit" {
  sha="$(commit_marker good)"
  run push "$sha"
  [ "$status" -eq 0 ]
  [ "$(grep '^step' "$TRACE")" = "$(printf '%s\n' 'step check-pins on good' \
    'step lint on good' 'step audit --declared on good')" ]
}

@test "the hook finds the pinned tools with a bare PATH" {
  sha="$(commit_marker good)"
  run push "$sha"
  [ "$status" -eq 0 ]
  grep -qx "found shellcheck" "$TRACE"
  grep -qx "found osv-scanner" "$TRACE"
  grep -qx "found python3" "$TRACE"
}

@test "the hook checks the pushed commit, not the working tree" {
  sha="$(commit_marker good)"
  printf 'broken\n' >"$FIX/marker"
  run push "$sha"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^step .* on good$' "$TRACE")" -eq 3 ]
}

@test "a broken commit is blocked even when the working tree is fixed" {
  sha="$(commit_marker broken)"
  printf 'good\n' >"$FIX/marker"
  run push "$sha"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: push blocked: zconf check-pins failed for"* ]] ||
    false
}

@test "the hook blocks when check-pins fails" {
  sha="$(commit_marker good)"
  FAIL_STEP=check-pins run push "$sha"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: push blocked: zconf check-pins failed"* ]] ||
    false
  [ "$(grep -c '^step' "$TRACE")" -eq 1 ]
}

@test "the hook blocks when lint fails" {
  sha="$(commit_marker good)"
  FAIL_STEP=lint run push "$sha"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: push blocked: zconf lint failed"* ]] || false
}

@test "the hook blocks when the audit cannot run" {
  sha="$(commit_marker good)"
  FAIL_STEP=audit FAIL_CODE=3 run push "$sha"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: push blocked: zconf audit --declared failed"* ]] ||
    false
}

@test "no worktree is left behind after a pass or a block" {
  sha="$(commit_marker good)"
  run push "$sha"
  [ "$status" -eq 0 ]
  [ "$(worktrees)" -eq 1 ]
  FAIL_STEP=lint run push "$sha"
  [ "$status" -eq 1 ]
  [ "$(worktrees)" -eq 1 ]
  [ -z "$(find "$TMPDIR" -mindepth 1 -maxdepth 1)" ]
}

@test "a branch deletion runs no checks" {
  commit_marker good >/dev/null
  run env PATH=/usr/bin:/bin "$HOOK" origin url <<<"(delete) $ZERO \
refs/heads/old 1111111111111111111111111111111111111111"
  [ "$status" -eq 0 ]
  [ ! -e "$TRACE" ]
}

@test "a commit pushed to several refs is checked once" {
  sha="$(commit_marker good)"
  run env PATH=/usr/bin:/bin "$HOOK" origin url <<<"refs/heads/a $sha \
refs/heads/a $ZERO
refs/heads/b $sha refs/heads/b $ZERO"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^step check-pins' "$TRACE")" -eq 1 ]
}
