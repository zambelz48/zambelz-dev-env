#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  for lib in log paths os exec links fonts modules; do
    # shellcheck source=/dev/null
    . "$ZZD_ROOT/zzd/lib/$lib.sh"
  done
  ZZD_ROOT="$BATS_TEST_TMPDIR/repo dir"
  TRACE="$BATS_TEST_TMPDIR/trace"
  export ZZD_ROOT TRACE
  mkdir -p "$ZZD_ROOT/zzd" "$ZZD_ROOT/alpha/zzd" "$ZZD_ROOT/beta/zzd"
  printf 'beta\n# comment\n\nalpha\n' >"$ZZD_ROOT/zzd/modules"
  zzd_log_init
}

@test "list follows the registry order and skips comments" {
  run zzd_modules_list
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'beta\nalpha')" ]
}

@test "list fails for a registered module without a zzd dir" {
  printf 'beta\nghost\n' >"$ZZD_ROOT/zzd/modules"
  run zzd_modules_list
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: module ghost has no ghost/zzd"* ]] || false
}

@test "apply runs pre-apply, links, then apply in that order" {
  printf 'x\n' >"$ZZD_ROOT/alpha/file"
  printf 'alpha/file\t.alpha\n' >"$ZZD_ROOT/alpha/zzd/links"
  cat >"$ZZD_ROOT/alpha/zzd/apply.sh" <<'EOF'
linked() {
  if [ -L "$ZZD_HOME/.alpha" ]; then echo linked; else echo unlinked; fi
}
mod_pre_apply() { echo "pre:$(linked)" >>"$TRACE"; }
mod_apply() { echo "apply:$(linked)" >>"$TRACE"; }
EOF
  run zzd_module_run alpha apply
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "$(printf 'pre:unlinked\napply:linked')" ]
}

@test "a failed pre-apply stops the module before links and apply" {
  printf 'x\n' >"$ZZD_ROOT/alpha/file"
  printf 'alpha/file\t.alpha\n' >"$ZZD_ROOT/alpha/zzd/links"
  cat >"$ZZD_ROOT/alpha/zzd/apply.sh" <<'EOF'
mod_pre_apply() { zzd_error "clone failed"; return 1; }
mod_apply() { echo "apply ran" >>"$TRACE"; }
EOF
  run zzd_module_run alpha apply
  [ "$status" -eq 1 ]
  [ ! -e "$ZZD_HOME/.alpha" ]
  [ ! -L "$ZZD_HOME/.alpha" ]
  [ ! -e "$TRACE" ]
}

@test "phase hooks run in a subshell" {
  cat >"$ZZD_ROOT/alpha/zzd/apply.sh" <<'EOF'
mod_apply() {
  LEAKED=yes
  echo "$ZZD_MODULE" >>"$TRACE"
}
EOF
  zzd_module_run alpha apply
  [ -z "${LEAKED:-}" ]
  [ "$(cat "$TRACE")" = "alpha" ]
}

@test "doctor fails when the module's doctor fails" {
  cat >"$ZZD_ROOT/beta/zzd/doctor.sh" <<'EOF'
mod_doctor() { zzd_error "beta broken"; return 1; }
EOF
  run zzd_module_run beta doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: beta broken"* ]] || false
}

@test "doctor checks links without creating them" {
  printf 'x\n' >"$ZZD_ROOT/alpha/file"
  printf 'alpha/file\t.alpha\n' >"$ZZD_ROOT/alpha/zzd/links"
  run zzd_module_run alpha doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"fix: zzd apply alpha"* ]] || false
  [ ! -e "$ZZD_HOME/.alpha" ]
}

module_with_font() {
  FONTSRC="$BATS_TEST_TMPDIR/font-install"
  mkdir -p "$FONTSRC"
  printf 'font\n' >"$FONTSRC/Alpha.ttf"
  printf 'github:example/fonts\n' >"$ZZD_ROOT/alpha/zzd/fonts"
  zzd_stub_script mise "echo $FONTSRC"
  zzd_stub uname 0 "Darwin"
}

@test "apply installs the fonts a module declares" {
  module_with_font
  run zzd_module_run alpha apply
  [ "$status" -eq 0 ]
  cmp "$FONTSRC/Alpha.ttf" "$ZZD_HOME/Library/Fonts/Alpha.ttf"
}

@test "doctor checks a module's fonts without installing them" {
  module_with_font
  run zzd_module_run alpha doctor
  [ "$status" -eq 1 ]
  zzd_contains "$output" "ERROR: Alpha.ttf from github:example/fonts" \
    "fix: zzd apply alpha"
  [ ! -e "$ZZD_HOME/Library/Fonts/Alpha.ttf" ]
}

@test "modules run follows the registry, or only the named modules" {
  for m in alpha beta; do
    printf "mod_update() { echo %s >>\"\$TRACE\"; }\n" "$m" \
      >"$ZZD_ROOT/$m/zzd/update.sh"
  done
  run zzd_modules_run update
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "$(printf 'beta\nalpha')" ]
  zzd_contains "$output" "INFO: beta: update" "INFO: alpha: update"
  rm "$TRACE"
  run zzd_modules_run update alpha
  [ "$(cat "$TRACE")" = "alpha" ]
}

@test "modules run reports failure and still runs the rest" {
  printf 'mod_update() { return 1; }\n' >"$ZZD_ROOT/beta/zzd/update.sh"
  printf "mod_update() { echo alpha >>\"\$TRACE\"; }\n" \
    >"$ZZD_ROOT/alpha/zzd/update.sh"
  run zzd_modules_run update
  [ "$status" -eq 1 ]
  [ "$(cat "$TRACE")" = "alpha" ]
}

@test "a module with nothing for the phase succeeds" {
  run zzd_module_run beta update
  [ "$status" -eq 0 ]
}
