#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  REAL="$ZC_ROOT"
  ZC_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZC_ROOT
  mkdir -p "$ZC_ROOT/zconf/lib/audit"
  for lib in log paths os exec audit; do
    # shellcheck source=/dev/null
    . "$REAL/zconf/lib/$lib.sh"
  done
  zc_log_init
  zc_stub_mise_passthrough
}

stub_engine() {
  cat >"$ZC_ROOT/zconf/lib/audit/__main__.py" <<EOF
import sys
open("$BATS_TEST_TMPDIR/engine-args", "w").write(" ".join(sys.argv[1:]))
print("REPORT")
sys.exit($1)
EOF
}

@test "the audit runs every scope by default" {
  stub_engine 0

  run zc_audit

  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/engine-args")" = "audit --all" ]
  [[ "$output" == *"OK: no known vulnerabilities, every component covered, no leftovers"* ]]
}

@test "the scope and json flags are passed to the engine" {
  stub_engine 0

  run zc_audit --declared --json

  [ "$(cat "$BATS_TEST_TMPDIR/engine-args")" = "audit --declared --json" ]
}

@test "json output keeps the status line off stdout" {
  stub_engine 1

  run --separate-stderr zc_audit --installed --json

  [ "$status" -eq 1 ]
  [ "$output" = "REPORT" ]
  [[ "$stderr" == *"ERROR: the audit found vulnerabilities"* ]]
}

@test "findings exit 1 with the fix route" {
  stub_engine 1

  run zc_audit --declared

  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: the audit found vulnerabilities, uncovered components or leftover installs" \
    "fix: follow each finding's Action line"
}

@test "an engine that could not run exits 3" {
  stub_engine 3

  run zc_audit --declared

  [ "$status" -eq 3 ]
  [[ "$output" == *"ERROR: the audit could not run (exit 3); nothing was proven clean"* ]]
}

@test "an unexpected engine exit code is could-not-run, never findings or clean" {
  stub_engine 7

  run zc_audit --declared

  [ "$status" -eq 3 ]
}

@test "a missing python exits 3 with the apply fix" {
  zc_stub_script mise <<EOF
case "\$*" in
  *" which python3") exit 1 ;;
  *) exec "$ZC_REAL_MISE" "\$@" ;;
esac
EOF

  run zc_audit --declared

  [ "$status" -eq 3 ]
  zc_contains "$output" "python3 is not installed by mise" "fix: zconf apply mise"
}

@test "an unknown argument exits 2" {
  stub_engine 0

  run zc_audit --everything

  [ "$status" -eq 2 ]
  [[ "$output" == *"ERROR: unknown audit argument: --everything"* ]]
}

@test "an engine crash is reported as could not run" {
  cp -R "$REAL/zconf/lib/audit/." "$ZC_ROOT/zconf/lib/audit/"
  printf 'raise RuntimeError("boom")\n' >"$ZC_ROOT/zconf/lib/audit/engine.py"

  run zc_audit --declared

  [ "$status" -eq 3 ]
}
