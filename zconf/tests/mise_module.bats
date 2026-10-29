#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  for lib in log paths os exec version links modules; do
    # shellcheck source=/dev/null
    . "$ZC_ROOT/zconf/lib/$lib.sh"
  done
  zc_log_init
  PINNED="$(zc_mise_min_version)"
  export PINNED
}

fake_ruby() {
  RUBY_DIR="$BATS_TEST_TMPDIR/ruby"
  mkdir -p "$RUBY_DIR/bin"
  printf '#!/usr/bin/env bash\necho "ruby 3.4.1"\nexit %s\n' "$1" \
    >"$RUBY_DIR/bin/ruby"
  chmod +x "$RUBY_DIR/bin/ruby"
}

fake_mise() {
  local version="$1" missing="$2" install_status="$3" ruby_status="$4"
  fake_ruby "$ruby_status"
  zc_stub_script mise <<EOF
case "\$*" in
$(zc_mise_which_branch)
  --version) echo "$version macos-arm64 (2026-10-27)" ;;
  *"ls --missing"*) [ -n "$missing" ] && echo "$missing" ;;
  *"install --locked"*) exit $install_status ;;
  *"where ruby"*) echo "$RUBY_DIR" ;;
  *) exit 0 ;;
esac
EOF
}

@test "doctor never runs mise exec, which would install missing tools" {
  fake_mise "$PINNED" "" 0 0
  run zc_module_run mise doctor
  [ "$(zc_calls mise | grep -c -E '(^| )(x|exec) ')" -eq 0 ]
}

@test "apply trusts the config before installing from the lock" {
  fake_mise "$PINNED" "" 0 0
  run zc_module_run mise apply
  [ "$status" -eq 0 ]
  trust_line="$(zc_calls mise | grep -n 'trust' | cut -d: -f1)"
  install_line="$(zc_calls mise | grep -n 'install --locked' | cut -d: -f1)"
  [ "$trust_line" -lt "$install_line" ]
}

@test "apply links the global config and lock into the repo" {
  fake_mise "$PINNED" "" 0 0
  zc_module_run mise apply
  [ "$(readlink "$HOME/.config/mise/config.toml")" = "$ZC_ROOT/mise/mise.toml" ]
  [ "$(readlink "$HOME/.config/mise/mise.lock")" = "$ZC_ROOT/mise/mise.lock" ]
}

@test "apply adds the shims and zconf PATH lines to .zshenv once" {
  fake_mise "$PINNED" "" 0 0
  zc_module_run mise apply
  zc_module_run mise apply
  [ "$(grep -c '.local/share/mise/shims' "$HOME/.zshenv")" -eq 1 ]
  [ "$(grep -cF "$ZC_ROOT/zconf/bin" "$HOME/.zshenv")" -eq 1 ]
}

@test "apply never adds mise activate to shell files" {
  fake_mise "$PINNED" "" 0 0
  zc_module_run mise apply
  run grep -r "mise activate" "$HOME"
  [ "$status" -eq 1 ]
}

@test "apply names installed tools by tool and version only" {
  fake_mise "$PINNED" \
    "glow  3.0.0 (missing)  ~/.config/mise/config.toml  3.0.0" 0 0
  run zc_module_run mise apply
  grep -qx "CHANGED: installed: glow 3.0.0" <<<"$output"
}

@test "apply fails when the locked install fails" {
  fake_mise "$PINNED" "" 1 0
  run zc_module_run mise apply
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: mise install --locked failed"* ]] || false
}

@test "doctor flags a mise older than the pinned minimum" {
  fake_mise "2026.4.24" "" 0 0
  run zc_module_run mise doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: mise 2026.4.24 is older than $PINNED"* ]] || false
  [[ "$output" == *"fix: $ZC_ROOT/bootstrap.sh"* ]] || false
}

@test "doctor accepts a mise newer than the pinned minimum" {
  fake_mise "2099.1.1" "" 0 0
  zc_module_run mise apply
  run zc_module_run mise doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: mise 2099.1.1 (>= $PINNED)"* ]] || false
}

@test "doctor compares mise versions numerically, not as text" {
  fake_mise "2026.11.1" "" 0 0
  zc_module_run mise apply
  run zc_module_run mise doctor
  [ "$status" -eq 0 ]
}

@test "doctor reports missing tools with the apply fix" {
  fake_mise "$PINNED" "node 24.22.1" 0 0
  run zc_module_run mise doctor
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: missing tools: node 24.22.1" \
    "fix: zconf apply mise"
}

@test "doctor names missing tools by tool and version only" {
  row1="glow  3.0.0 (missing)  ~/.config/mise/config.toml  3.0.0"
  row2="fd    10.5.0 (missing) ~/.config/mise/config.toml  10.5.0"
  fake_mise "$PINNED" "$row1"$'\n'"$row2" 0 0
  run zc_module_run mise doctor
  grep -qx "ERROR: missing tools: glow 3.0.0, fd 10.5.0" <<<"$output"
}

project_missing() {
  fake_ruby 0
  zc_stub_script mise <<EOF
case "\$*" in
$(zc_mise_which_branch)
  --version) echo "$PINNED macos-arm64 (2026-10-27)" ;;
  *"where ruby"*) echo "$RUBY_DIR" ;;
  *"ls --missing --json"*)
    cat <<'JSON'
{
  "node": [
    {
      "version": "20.11.0",
      "source": { "type": "idiomatic-version-file", "path": "/p/.nvmrc" }
    }
  ],
  "fd": [
    {
      "version": "10.5.0",
      "source": {
        "type": "mise.toml",
        "path": "$HOME/.config/mise/config.toml"
      }
    }
  ]
}
JSON
    ;;
  *) exit 0 ;;
esac
EOF
}

@test "doctor in a project reports its own missing requests as warnings" {
  project_missing
  zc_module_run mise apply
  mkdir -p "$BATS_TEST_TMPDIR/project"
  cd "$BATS_TEST_TMPDIR/project"
  run zc_module_run mise doctor
  [ "$status" -eq 0 ]
  zc_contains "$output" \
    "WARN: node 20.11.0 requested by /p/.nvmrc is not installed" \
    "fix: mise -C /p install"
}

@test "doctor in a project leaves global tools to the global check" {
  project_missing
  mkdir -p "$BATS_TEST_TMPDIR/project"
  cd "$BATS_TEST_TMPDIR/project"
  run zc_module_run mise doctor
  [[ "$output" != *"fd 10.5.0 requested by"* ]] || false
}

@test "doctor in the home directory skips the project check" {
  fake_mise "$PINNED" "" 0 0
  zc_module_run mise apply
  cd "$HOME"
  run zc_module_run mise doctor
  [ "$status" -eq 0 ]
  run zc_calls mise
  [[ "$output" != *"--json"* ]] || false
}

@test "update reports pins with a newer version in their line" {
  zc_stub_script mise <<EOF
case "\$*" in
$(zc_mise_which_branch)
  "latest node@24") echo 24.23.0 ;;
  latest*) exit 1 ;;
  *) exit 0 ;;
esac
EOF
  run zc_module_run mise update
  [ "$status" -eq 0 ]
  [[ "$output" == *"INFO: node 24.22.1 -> 24.23.0 (mise)"* ]] || false
}

@test "update reports unchecked http tools as counted warnings with a fix" {
  zc_stub_script mise <<EOF
case "\$*" in
$(zc_mise_which_branch)
  latest*) exit 1 ;;
  *) exit 0 ;;
esac
EOF
  ZC_RUN_LOG="$BATS_TEST_TMPDIR/run.log"
  export ZC_RUN_LOG
  run zc_module_run mise update
  zc_contains "$output" "WARN: http:jdtls is not checked" \
    "fix: update its url and checksum in $ZC_ROOT/mise/mise.toml"
  grep -qx "warn" "$ZC_RUN_LOG"
}

@test "update fails loudly when the version check cannot run" {
  zc_stub_script mise <<EOF
case "\$*" in
  *" which python3") exit 1 ;;
  *) exit 0 ;;
esac
EOF
  run zc_module_run mise update
  [ "$status" -eq 1 ]
  zc_contains "$output" "ERROR: cannot check mise versions"
  [[ "$output" != *"mise tools are current"* ]] || false
}

@test "doctor confirms the pins agree with the lock" {
  fake_mise "$PINNED" "" 0 0
  run zc_module_run mise doctor
  zc_contains "$output" "OK: pins exact and locked"
}

@test "doctor reports a pin missing from the lock with the re-lock fix" {
  fake_mise "$PINNED" "" 0 0
  real="$ZC_ROOT"
  ZC_ROOT="$BATS_TEST_TMPDIR/repo"
  export ZC_ROOT
  mkdir -p "$ZC_ROOT"
  cp -R "$real/mise" "$real/zconf" "$ZC_ROOT/"
  zc_python - "$ZC_ROOT/mise/mise.toml" <<'EOF'
import sys
path = sys.argv[1]
text = open(path).read()
pin = '[tools]\nhadolint = "2.15.1"\n'
open(path, "w").write(text.replace("[tools]\n", pin, 1))
EOF
  run zc_module_run mise doctor
  [ "$status" -eq 1 ]
  platforms="macos-arm64,macos-x64,linux-x64,linux-arm64"
  zc_contains "$output" "ERROR: hadolint 2.15.1 is not in the lock" \
    "fix: mise -C $ZC_ROOT/mise lock --global --platform $platforms"
}

@test "doctor fails when ruby cannot start" {
  fake_mise "$PINNED" "" 0 1
  run zc_module_run mise doctor
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: ruby does not start"* ]] || false
}
