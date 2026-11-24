#!/usr/bin/env bats

SSH_COMMAND="ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=6"

setup() {
  load helpers
  zzd_test_setup
  for lib in log paths exec links modules; do
    # shellcheck source=/dev/null
    . "$ZZD_ROOT/zzd/lib/$lib.sh"
  done
  zzd_log_init
}

git_config() {
  zzd_stub_script git <<EOF
case "\$*" in
  *"config --get core.hooksPath"*)
    [ -n "$1" ] || exit 1
    echo "$1"
    ;;
  *"config --get core.sshCommand"*)
    [ -n "$2" ] || exit 1
    echo "$2"
    ;;
  *) exit 0 ;;
esac
EOF
}

@test "apply sets core.hooksPath and core.sshCommand for this repository" {
  git_config "" ""
  run zzd_module_run git apply
  [ "$status" -eq 0 ]
  zzd_calls git | grep -qx -- "-C $ZZD_ROOT config core.hooksPath .githooks"
  zzd_calls git | grep -qx -- "-C $ZZD_ROOT config core.sshCommand $SSH_COMMAND"
  [[ "$output" == *"CHANGED: core.hooksPath = .githooks"* ]] || false
  [[ "$output" == *"CHANGED: core.sshCommand = $SSH_COMMAND"* ]] || false
}

@test "apply leaves correct settings alone" {
  git_config ".githooks" "$SSH_COMMAND"
  run zzd_module_run git apply
  [ "$status" -eq 0 ]
  [ "$(zzd_calls git | grep -c -E 'config core\.(hooksPath|sshCommand) ')" -eq 0 ]
  [[ "$output" == *"OK: core.hooksPath = .githooks"* ]] || false
  [[ "$output" == *"OK: core.sshCommand = $SSH_COMMAND"* ]] || false
}

@test "apply replaces an ssh command without keepalives" {
  git_config ".githooks" "ssh"
  run zzd_module_run git apply
  [ "$status" -eq 0 ]
  zzd_calls git | grep -qx -- "-C $ZZD_ROOT config core.sshCommand $SSH_COMMAND"
}

@test "doctor flags a missing hooks path" {
  git_config "" "$SSH_COMMAND"
  run zzd_module_run git doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: core.hooksPath is not .githooks (unset)"* ]] || false
  [[ "$output" == *"fix: zzd apply git"* ]] || false
}

@test "doctor flags a missing ssh keepalive" {
  git_config ".githooks" ""
  run zzd_module_run git doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: core.sshCommand is not $SSH_COMMAND (unset)"* ]] || false
}

@test "doctor passes with both settings in place" {
  git_config ".githooks" "$SSH_COMMAND"
  run zzd_module_run git doctor
  [ "$status" -eq 0 ]
}
