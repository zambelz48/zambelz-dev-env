#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  for lib in log paths exec links modules; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  zc_log_init
}

hooks_path() {
  zc_stub_script git <<EOF
case "\$*" in
  *"config --get core.hooksPath"*)
    [ -n "$1" ] || exit 1
    echo "$1"
    ;;
  *) exit 0 ;;
esac
EOF
}

@test "apply sets core.hooksPath for this repository" {
  hooks_path ""
  run zc_module_run git apply
  [ "$status" -eq 0 ]
  zc_calls git | grep -qx -- "-C $ZC_ROOT config core.hooksPath .githooks"
  [[ "$output" == *"CHANGED: core.hooksPath = .githooks"* ]] || false
}

@test "apply leaves a correct core.hooksPath alone" {
  hooks_path ".githooks"
  run zc_module_run git apply
  [ "$status" -eq 0 ]
  [ "$(zc_calls git | grep -c 'config core.hooksPath')" -eq 0 ]
  [[ "$output" == *"OK: core.hooksPath = .githooks"* ]] || false
}

@test "doctor flags a missing hooks path" {
  hooks_path ""
  run zc_module_run git doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: core.hooksPath is not .githooks"* ]] || false
  [[ "$output" == *"fix: zconf apply git"* ]] || false
}

@test "doctor passes with the hooks path set" {
  hooks_path ".githooks"
  run zc_module_run git doctor
  [ "$status" -eq 0 ]
}
