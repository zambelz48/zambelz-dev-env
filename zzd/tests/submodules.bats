#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  for lib in log paths exec links modules; do
    # shellcheck source=/dev/null
    . "$ZZD_ROOT/zzd/lib/$lib.sh"
  done
  zzd_log_init
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
  export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow
  export GIT_CONFIG_VALUE_0=always
  W="$BATS_TEST_TMPDIR/w"
  UP="$W/upstream"
  SUPER="$W/super"
  mkdir -p "$UP" "$SUPER/alpha/zzd"
  git -C "$UP" init -q
  commit_upstream one
  A="$(git -C "$UP" rev-parse HEAD)"
  git -C "$SUPER" init -q
  git -C "$SUPER" submodule add -q "$UP" alpha/sub
  printf 'alpha/sub/file\t.alpha-file\n' >"$SUPER/alpha/zzd/links"
  git -C "$SUPER" add -A
  git -C "$SUPER" commit -q -m "record one"
  ZZD_ROOT="$W/clone"
  export ZZD_ROOT
  git clone -q "$SUPER" "$ZZD_ROOT"
}

commit_upstream() {
  printf '%s\n' "$1" >"$UP/file"
  git -C "$UP" add file
  git -C "$UP" commit -q -m "$1"
}

sub_head() {
  git -C "$ZZD_ROOT/alpha/sub" rev-parse HEAD
}

checked_out() {
  git -C "$ZZD_ROOT" submodule update -q --init
}

record_new_commit() {
  commit_upstream two
  B="$(git -C "$UP" rev-parse HEAD)"
  git -C "$SUPER/alpha/sub" pull -q
  git -C "$SUPER" commit -q -am "record two"
  git -C "$ZZD_ROOT" pull -q
}

@test "apply checks out a submodule that is not checked out yet" {
  run zzd_submodules_apply alpha
  [ "$status" -eq 0 ]
  [ "$output" = "CHANGED: submodule alpha/sub checked out at $A" ]
  [ "$(sub_head)" = "$A" ]
}

@test "apply reports a submodule at its recorded commit" {
  checked_out
  run zzd_submodules_apply alpha
  [ "$status" -eq 0 ]
  [ "$output" = "OK: submodule alpha/sub at $A" ]
}

@test "apply moves a submodule left behind by a pull" {
  checked_out
  record_new_commit
  run zzd_submodules_apply alpha
  [ "$status" -eq 0 ]
  [ "$output" = "CHANGED: submodule alpha/sub $A -> $B" ]
  [ "$(sub_head)" = "$B" ]
}

@test "apply leaves a commit the repository never recorded alone" {
  checked_out
  commit_upstream local-work
  work="$(git -C "$UP" rev-parse HEAD)"
  git -C "$ZZD_ROOT/alpha/sub" fetch -q origin
  git -C "$ZZD_ROOT/alpha/sub" checkout -q "$work"
  run zzd_submodules_apply alpha
  [ "$status" -eq 0 ]
  zzd_contains "$output" \
    "WARN: submodule alpha/sub is at $work, not the recorded $A; left as is"
  [ "$(sub_head)" = "$work" ]
}

@test "apply refuses to move a stale submodule with local changes" {
  checked_out
  record_new_commit
  printf 'edited\n' >"$ZZD_ROOT/alpha/sub/file"
  run zzd_submodules_apply alpha
  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: $ZZD_ROOT/alpha/sub has local changes" \
    "fix: git -C $ZZD_ROOT/alpha/sub stash, then zzd apply alpha"
  [ "$(sub_head)" = "$A" ]
}

@test "apply in dry-run changes nothing" {
  checked_out
  record_new_commit
  ZZD_DRY_RUN=1 run zzd_submodules_apply alpha
  [ "$status" -eq 0 ]
  zzd_contains "$output" "DRY-RUN: git -C $ZZD_ROOT"
  [ "$(sub_head)" = "$A" ]
}

@test "doctor flags a missing and a stale submodule with the apply fix" {
  run zzd_submodules_check alpha
  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: submodule alpha/sub is not checked out" \
    "fix: zzd apply alpha"
  checked_out
  record_new_commit
  run zzd_submodules_check alpha
  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: submodule alpha/sub at $A, recorded $B" \
    "fix: zzd apply alpha"
  [ "$(sub_head)" = "$A" ]
}

@test "doctor passes a submodule at its recorded commit" {
  checked_out
  run zzd_submodules_check alpha
  [ "$status" -eq 0 ]
  [ "$output" = "OK: submodule alpha/sub at $A" ]
}

@test "a module without submodules prints nothing" {
  mkdir -p "$ZZD_ROOT/beta/zzd"
  run zzd_submodules_apply beta
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a repository without .gitmodules runs no git command" {
  rm "$ZZD_ROOT/.gitmodules"
  zzd_stub git 0
  run zzd_submodules_apply alpha
  [ "$status" -eq 0 ]
  [ -z "$(zzd_calls git)" ]
}

@test "the module runner checks out submodules before linking into them" {
  run zzd_module_run alpha apply
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.alpha-file")" = "$ZZD_ROOT/alpha/sub/file" ]
}
