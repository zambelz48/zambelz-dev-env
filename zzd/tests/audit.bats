#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  REAL="$ZZD_ROOT"
  ZZD_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZZD_ROOT
  mkdir -p "$ZZD_ROOT/zzd/lib/audit"
  for lib in log paths os exec audit; do
    # shellcheck source=/dev/null
    . "$REAL/zzd/lib/$lib.sh"
  done
  zzd_log_init
  zzd_stub_mise_passthrough
}

stub_engine() {
  cat >"$ZZD_ROOT/zzd/lib/audit/__main__.py" <<EOF
import sys
open("$BATS_TEST_TMPDIR/engine-args", "w").write(" ".join(sys.argv[1:]))
print("REPORT")
sys.exit($1)
EOF
}

@test "the audit runs every scope by default" {
  stub_engine 0

  run zzd_audit

  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/engine-args")" = "audit --all" ]
  [[ "$output" == *"OK: no known vulnerabilities, every component covered, no leftovers"* ]]
}

@test "the scope and json flags are passed to the engine" {
  stub_engine 0

  run zzd_audit --declared --json

  [ "$(cat "$BATS_TEST_TMPDIR/engine-args")" = "audit --declared --json" ]
}

@test "json output keeps the status line off stdout" {
  stub_engine 1

  run --separate-stderr zzd_audit --installed --json

  [ "$status" -eq 1 ]
  [ "$output" = "REPORT" ]
  [[ "$stderr" == *"ERROR: the audit found vulnerabilities"* ]]
}

@test "findings exit 1 with the fix route" {
  stub_engine 1

  run zzd_audit --declared

  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: the audit found vulnerabilities, uncovered components or leftover installs" \
    "fix: follow each finding's Action line"
}

@test "a passing gate never claims there are no vulnerabilities" {
  stub_engine 0

  run zzd_audit --declared --gate

  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: nothing blocks; open findings marked 'waiting for upstream' are listed above"* ]]
  [[ "$output" != *"no known vulnerabilities"* ]]
}

@test "an engine that could not run exits 3" {
  stub_engine 3

  run zzd_audit --declared

  [ "$status" -eq 3 ]
  [[ "$output" == *"ERROR: the audit could not run (exit 3); nothing was proven clean"* ]]
}

@test "an unexpected engine exit code is could-not-run, never findings or clean" {
  stub_engine 7

  run zzd_audit --declared

  [ "$status" -eq 3 ]
}

@test "a missing python exits 3 with the apply fix" {
  zzd_stub_script mise <<EOF
case "\$*" in
  *" which python3") exit 1 ;;
  *) exec "$ZZD_REAL_MISE" "\$@" ;;
esac
EOF

  run zzd_audit --declared

  [ "$status" -eq 3 ]
  zzd_contains "$output" "python3 is not installed by mise" "fix: zzd apply mise"
}

@test "an unknown argument exits 2" {
  stub_engine 0

  run zzd_audit --everything

  [ "$status" -eq 2 ]
  [[ "$output" == *"ERROR: unknown audit argument: --everything"* ]]
}

@test "an engine crash is reported as could not run" {
  cp -R "$REAL/zzd/lib/audit/." "$ZZD_ROOT/zzd/lib/audit/"
  printf 'raise RuntimeError("boom")\n' >"$ZZD_ROOT/zzd/lib/audit/engine.py"

  run zzd_audit --declared

  [ "$status" -eq 3 ]
}
