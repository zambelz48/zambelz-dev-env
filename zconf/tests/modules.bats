#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  for lib in log paths os exec links fonts modules; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  ZC_ROOT="$BATS_TEST_TMPDIR/repo dir"
  TRACE="$BATS_TEST_TMPDIR/trace"
  export ZC_ROOT TRACE
  mkdir -p "$ZC_ROOT/zconf" "$ZC_ROOT/alpha/zconf" "$ZC_ROOT/beta/zconf"
  printf 'beta\n# comment\n\nalpha\n' >"$ZC_ROOT/zconf/modules"
  zc_log_init
}

@test "list follows the registry order and skips comments" {
  run zc_modules_list
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'beta\nalpha')" ]
}

@test "list fails for a registered module without a zconf dir" {
  printf 'beta\nghost\n' >"$ZC_ROOT/zconf/modules"
  run zc_modules_list
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: module ghost has no ghost/zconf"* ]] || false
}

@test "apply runs pre-apply, links, then apply in that order" {
  printf 'x\n' >"$ZC_ROOT/alpha/file"
  printf 'alpha/file\t.alpha\n' >"$ZC_ROOT/alpha/zconf/links"
  cat >"$ZC_ROOT/alpha/zconf/apply.sh" <<'EOF'
linked() {
  if [ -L "$ZC_HOME/.alpha" ]; then echo linked; else echo unlinked; fi
}
mod_pre_apply() { echo "pre:$(linked)" >>"$TRACE"; }
mod_apply() { echo "apply:$(linked)" >>"$TRACE"; }
EOF
  run zc_module_run alpha apply
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "$(printf 'pre:unlinked\napply:linked')" ]
}

@test "a failed pre-apply stops the module before links and apply" {
  printf 'x\n' >"$ZC_ROOT/alpha/file"
  printf 'alpha/file\t.alpha\n' >"$ZC_ROOT/alpha/zconf/links"
  cat >"$ZC_ROOT/alpha/zconf/apply.sh" <<'EOF'
mod_pre_apply() { zc_error "clone failed"; return 1; }
mod_apply() { echo "apply ran" >>"$TRACE"; }
EOF
  run zc_module_run alpha apply
  [ "$status" -eq 1 ]
  [ ! -e "$ZC_HOME/.alpha" ]
  [ ! -L "$ZC_HOME/.alpha" ]
  [ ! -e "$TRACE" ]
}

@test "phase hooks run in a subshell" {
  cat >"$ZC_ROOT/alpha/zconf/apply.sh" <<'EOF'
mod_apply() {
  LEAKED=yes
  echo "$ZC_MODULE" >>"$TRACE"
}
EOF
  zc_module_run alpha apply
  [ -z "${LEAKED:-}" ]
  [ "$(cat "$TRACE")" = "alpha" ]
}

@test "doctor fails when the module's doctor fails" {
  cat >"$ZC_ROOT/beta/zconf/doctor.sh" <<'EOF'
mod_doctor() { zc_error "beta broken"; return 1; }
EOF
  run zc_module_run beta doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: beta broken"* ]] || false
}

@test "doctor checks links without creating them" {
  printf 'x\n' >"$ZC_ROOT/alpha/file"
  printf 'alpha/file\t.alpha\n' >"$ZC_ROOT/alpha/zconf/links"
  run zc_module_run alpha doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"fix: zconf apply alpha"* ]] || false
  [ ! -e "$ZC_HOME/.alpha" ]
}

module_with_font() {
  FONTSRC="$BATS_TEST_TMPDIR/font-install"
  mkdir -p "$FONTSRC"
  printf 'font\n' >"$FONTSRC/Alpha.ttf"
  printf 'github:example/fonts\n' >"$ZC_ROOT/alpha/zconf/fonts"
  zc_stub_script mise "echo $FONTSRC"
  zc_stub uname 0 "Darwin"
}

@test "apply installs the fonts a module declares" {
  module_with_font
  run zc_module_run alpha apply
  [ "$status" -eq 0 ]
  cmp "$FONTSRC/Alpha.ttf" "$ZC_HOME/Library/Fonts/Alpha.ttf"
}

@test "doctor checks a module's fonts without installing them" {
  module_with_font
  run zc_module_run alpha doctor
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: Alpha.ttf from github:example/fonts" \
    "fix: zconf apply alpha"
  [ ! -e "$ZC_HOME/Library/Fonts/Alpha.ttf" ]
}

@test "modules run follows the registry, or only the named modules" {
  for m in alpha beta; do
    printf "mod_update() { echo %s >>\"\$TRACE\"; }\n" "$m" \
      >"$ZC_ROOT/$m/zconf/update.sh"
  done
  run zc_modules_run update
  [ "$status" -eq 0 ]
  [ "$(cat "$TRACE")" = "$(printf 'beta\nalpha')" ]
  zc_contains "$output" "INFO: beta: update" "INFO: alpha: update"
  rm "$TRACE"
  run zc_modules_run update alpha
  [ "$(cat "$TRACE")" = "alpha" ]
}

@test "modules run reports failure and still runs the rest" {
  printf 'mod_update() { return 1; }\n' >"$ZC_ROOT/beta/zconf/update.sh"
  printf "mod_update() { echo alpha >>\"\$TRACE\"; }\n" \
    >"$ZC_ROOT/alpha/zconf/update.sh"
  run zc_modules_run update
  [ "$status" -eq 1 ]
  [ "$(cat "$TRACE")" = "alpha" ]
}

@test "a module with nothing for the phase succeeds" {
  run zc_module_run beta update
  [ "$status" -eq 0 ]
}
