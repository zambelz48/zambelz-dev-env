#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  for lib in log paths exec links modules; do
    # shellcheck source=/dev/null
    . "$ZZD_ROOT/zzd/lib/$lib.sh"
  done
  zzd_log_init
}

hooks_path() {
  zzd_stub_script git <<EOF
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
  run zzd_module_run git apply
  [ "$status" -eq 0 ]
  zzd_calls git | grep -qx -- "-C $ZZD_ROOT config core.hooksPath .githooks"
  [[ "$output" == *"CHANGED: core.hooksPath = .githooks"* ]] || false
}

@test "apply leaves a correct core.hooksPath alone" {
  hooks_path ".githooks"
  run zzd_module_run git apply
  [ "$status" -eq 0 ]
  [ "$(zzd_calls git | grep -c 'config core.hooksPath')" -eq 0 ]
  [[ "$output" == *"OK: core.hooksPath = .githooks"* ]] || false
}

@test "doctor flags a missing hooks path" {
  hooks_path ""
  run zzd_module_run git doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: core.hooksPath is not .githooks"* ]] || false
  [[ "$output" == *"fix: zzd apply git"* ]] || false
}

@test "doctor passes with the hooks path set" {
  hooks_path ".githooks"
  run zzd_module_run git doctor
  [ "$status" -eq 0 ]
}
