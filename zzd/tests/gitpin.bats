#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  for lib in log exec gitpin; do
    # shellcheck source=/dev/null
    . "$ZZD_ROOT/zzd/lib/$lib.sh"
  done
  zzd_log_init
  ZZD_MODULE="demo"
  export ZZD_MODULE
  DIR="$HOME/work tree"
  URL="https://example.invalid/demo.git"
  PIN="abc123"
}

fake_git() {
  local head="$1" dirty="$2" fail="${3:-}"
  zzd_stub_script git <<EOF
case "\$*" in
  *"clone"*) mkdir -p "\${@: -1}/.git" ;;
  *"rev-parse HEAD"*) echo "$head" ;;
  *"status --porcelain"*) [ -n "$dirty" ] && echo "$dirty" ;;
  *)
    if [ -n "$fail" ] && [[ "\$*" == *"$fail"* ]]; then
      exit 1
    fi
    ;;
esac
EOF
}

@test "head prints the checkout's commit" {
  mkdir -p "$DIR/.git"
  fake_git "$PIN" ""
  run zzd_git_head "$DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "$PIN" ]
}

@test "remote head prints the commit of the remote's HEAD" {
  zzd_stub git 0 "$(printf '%s\tHEAD' "$PIN")"
  run zzd_git_remote_head "$URL"
  [ "$status" -eq 0 ]
  [ "$output" = "$PIN" ]
  [ "$(zzd_calls git)" = "ls-remote $URL HEAD" ]
}

@test "remote head fails when ls-remote fails or prints nothing" {
  zzd_stub git 128
  run zzd_git_remote_head "$URL"
  [ "$status" -eq 1 ]
  zzd_stub git 0
  run zzd_git_remote_head "$URL"
  [ "$status" -eq 1 ]
}

@test "pin clones an absent checkout and checks out the commit" {
  fake_git "$PIN" ""
  run zzd_git_pin "$DIR" "$URL" "$PIN" "demo"
  [ "$status" -eq 0 ]
  [ "$(zzd_calls git | sed -n 1p)" = "clone -q $URL $DIR" ]
  [ "$(zzd_calls git | sed -n 2p)" = "-C $DIR checkout -q $PIN" ]
  [ "$output" = "CHANGED: demo cloned at $PIN" ]
}

@test "pin reports OK without fetching when already at the commit" {
  mkdir -p "$DIR/.git"
  fake_git "$PIN" ""
  run zzd_git_pin "$DIR" "$URL" "$PIN" "demo"
  [ "$status" -eq 0 ]
  [ "$output" = "OK: demo at $PIN" ]
  run zzd_calls git
  [[ "$output" != *"fetch"* ]] || false
}

@test "pin fetches and checks out a clean checkout at another commit" {
  mkdir -p "$DIR/.git"
  fake_git "old999" ""
  run zzd_git_pin "$DIR" "$URL" "$PIN" "demo"
  [ "$status" -eq 0 ]
  [ "$output" = "CHANGED: demo old999 -> $PIN" ]
  zzd_calls git | grep -qx -- "-C $DIR fetch -q origin"
  zzd_calls git | grep -qx -- "-C $DIR checkout -q $PIN"
}

@test "pin refuses a dirty checkout" {
  mkdir -p "$DIR/.git"
  fake_git "old999" " M file"
  run zzd_git_pin "$DIR" "$URL" "$PIN" "demo"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "ERROR: $DIR has local changes" ]
  [ "${lines[1]}" = "  fix: git -C $DIR stash, then zzd apply demo" ]
  run zzd_calls git
  [[ "$output" != *"checkout"* ]] || false
}

@test "pin refuses a directory that is not a git checkout" {
  mkdir -p "$DIR"
  fake_git "" ""
  run zzd_git_pin "$DIR" "$URL" "$PIN" "demo"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "ERROR: $DIR exists but is not a git checkout" ]
  [ -z "$(zzd_calls git)" ]
}

@test "pin reports a failed fetch" {
  mkdir -p "$DIR/.git"
  fake_git "old999" "" "fetch"
  run zzd_git_pin "$DIR" "$URL" "$PIN" "demo"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "ERROR: demo checkout of $PIN failed" ]
}

@test "pin in dry-run prints the commands and reports no change" {
  mkdir -p "$DIR/.git"
  fake_git "old999" ""
  ZZD_DRY_RUN=1 run zzd_git_pin "$DIR" "$URL" "$PIN" "demo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY-RUN: git -C $DIR checkout -q $PIN"* ]] || false
  [[ "$output" != *"CHANGED:"* ]] || false
}
