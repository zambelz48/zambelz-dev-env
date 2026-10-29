#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  # shellcheck source=../lib/log.sh
  . "$ZC_ROOT/zconf/lib/log.sh"
  # shellcheck source=../lib/exec.sh
  . "$ZC_ROOT/zconf/lib/exec.sh"
  zc_stub id 0 "501"
}

@test "dry-run prints the command and does not execute it" {
  zc_stub touchme 0
  ZC_DRY_RUN=1 run zc_do touchme a "b c"
  [ "$status" -eq 0 ]
  [ "$output" = "DRY-RUN: touchme a b c" ]
  [ -z "$(zc_calls touchme)" ]
}

@test "zc_do runs the command and returns its status" {
  zc_stub failing 4
  run zc_do failing x
  [ "$status" -eq 4 ]
  [ "$(zc_calls failing)" = "x" ]
}

@test "sudo without a terminal fails fast and prints the command" {
  _zc_has_tty() { return 1; }
  zc_stub sudo 1
  zc_stub dnf 0
  start=$SECONDS
  run zc_sudo dnf install x </dev/null
  [ "$status" -eq 1 ]
  [ $((SECONDS - start)) -lt 2 ]
  [[ "$output" == *"fix: sudo dnf install x"* ]] || false
  [ "$(zc_calls sudo)" = "-n true" ]
  [ -z "$(zc_calls dnf)" ]
}

@test "sudo without a terminal uses passwordless sudo when allowed" {
  _zc_has_tty() { return 1; }
  zc_stub sudo 0
  run zc_sudo dnf install x </dev/null
  [ "$status" -eq 0 ]
  [ "$(zc_calls sudo)" = "$(printf -- '-n true\n-n dnf install x')" ]
}

in_pty() {
  [ "$(uname -s)" = "Darwin" ] || skip "uses macOS script(1) for a pty"
  run script -q /dev/null bash -c \
    ". '$ZC_ROOT/zconf/lib/log.sh'; . '$ZC_ROOT/zconf/lib/exec.sh'; $1" \
    </dev/null
}

@test "a controlling terminal counts when stdin is redirected" {
  in_pty '_zc_has_tty </dev/null && echo has-tty || echo no-tty'
  zc_contains "$output" "has-tty"
}

@test "sudo inside a here-string loop asks on the terminal, not -n" {
  zc_stub sudo 0
  zc_stub dnf 0
  in_pty 'while read -r m; do zc_sudo dnf install x; done <<<"dnf"'
  [ "$(zc_calls sudo)" = "dnf install x" ]
}

@test "sudo with a terminal calls sudo directly" {
  _zc_has_tty() { return 0; }
  zc_stub sudo 0
  run zc_sudo apt-get install -y zsh
  [ "$status" -eq 0 ]
  [ "$(zc_calls sudo)" = "apt-get install -y zsh" ]
}

@test "root runs the command without sudo" {
  zc_stub id 0 "0"
  zc_stub sudo 0
  zc_stub dnf 0
  run zc_sudo dnf install x
  [ "$status" -eq 0 ]
  [ "$(zc_calls dnf)" = "install x" ]
  [ -z "$(zc_calls sudo)" ]
}

@test "sudo in dry-run prints and does not execute" {
  zc_stub sudo 0
  ZC_DRY_RUN=1 run zc_sudo dnf install x
  [ "$output" = "DRY-RUN: sudo dnf install x" ]
  [ -z "$(zc_calls sudo)" ]
}

@test "ensure_line appends once and reports OK the second time" {
  file="$HOME/.zshenv"
  line="export PATH=\"\$HOME/.local/share/mise/shims:\$PATH\""
  run zc_ensure_line "$file" "$line"
  [[ "$output" == "CHANGED:"* ]] || false
  run zc_ensure_line "$file" "$line"
  [[ "$output" == "OK:"* ]] || false
  [ "$(grep -cFx -- "$line" "$file")" -eq 1 ]
}

@test "ensure_line creates a missing parent directory with a space" {
  file="$HOME/dir with space/profile.zsh"
  zc_ensure_line "$file" "export A=1"
  [ "$(cat "$file")" = "export A=1" ]
}

@test "ensure_line does not treat a longer line as a match" {
  file="$HOME/.zshenv"
  printf 'export A=1 # note\n' >"$file"
  zc_ensure_line "$file" "export A=1"
  [ "$(wc -l <"$file" | tr -d ' ')" -eq 2 ]
}

@test "ensure_line starts a new line when the file lacks a final newline" {
  file="$HOME/.profile.zsh"
  printf 'export B=2' >"$file"
  zc_ensure_line "$file" "export A=1"
  [ "$(sed -n 1p "$file")" = "export B=2" ]
  [ "$(sed -n 2p "$file")" = "export A=1" ]
}

@test "ensure_line in dry-run does not create the file" {
  file="$HOME/new/.zshenv"
  ZC_DRY_RUN=1 run zc_ensure_line "$file" "export A=1"
  [[ "$output" == "DRY-RUN:"* ]] || false
  [ ! -e "$file" ]
}
