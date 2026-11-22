#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  # shellcheck source=../lib/log.sh
  . "$ZZD_ROOT/zzd/lib/log.sh"
  # shellcheck source=../lib/exec.sh
  . "$ZZD_ROOT/zzd/lib/exec.sh"
  zzd_stub id 0 "501"
}

@test "dry-run prints the command and does not execute it" {
  zzd_stub touchme 0
  ZZD_DRY_RUN=1 run zzd_do touchme a "b c"
  [ "$status" -eq 0 ]
  [ "$output" = "DRY-RUN: touchme a b c" ]
  [ -z "$(zzd_calls touchme)" ]
}

@test "zzd_do runs the command and returns its status" {
  zzd_stub failing 4
  run zzd_do failing x
  [ "$status" -eq 4 ]
  [ "$(zzd_calls failing)" = "x" ]
}

@test "sudo without a terminal fails fast and prints the command" {
  _zc_has_tty() { return 1; }
  zzd_stub sudo 1
  zzd_stub dnf 0
  start=$SECONDS
  run zzd_sudo dnf install x </dev/null
  [ "$status" -eq 1 ]
  [ $((SECONDS - start)) -lt 2 ]
  [[ "$output" == *"fix: sudo dnf install x"* ]] || false
  [ "$(zzd_calls sudo)" = "-n true" ]
  [ -z "$(zzd_calls dnf)" ]
}

@test "sudo without a terminal uses passwordless sudo when allowed" {
  _zc_has_tty() { return 1; }
  zzd_stub sudo 0
  run zzd_sudo dnf install x </dev/null
  [ "$status" -eq 0 ]
  [ "$(zzd_calls sudo)" = "$(printf -- '-n true\n-n dnf install x')" ]
}

in_pty() {
  [ "$(uname -s)" = "Darwin" ] || skip "uses macOS script(1) for a pty"
  run script -q /dev/null bash -c \
    ". '$ZZD_ROOT/zzd/lib/log.sh'; . '$ZZD_ROOT/zzd/lib/exec.sh'; $1" \
    </dev/null
}

@test "a controlling terminal counts when stdin is redirected" {
  in_pty '_zc_has_tty </dev/null && echo has-tty || echo no-tty'
  zzd_contains "$output" "has-tty"
}

@test "sudo inside a here-string loop asks on the terminal, not -n" {
  zzd_stub sudo 0
  zzd_stub dnf 0
  in_pty 'while read -r m; do zzd_sudo dnf install x; done <<<"dnf"'
  [ "$(zzd_calls sudo)" = "dnf install x" ]
}

@test "sudo with a terminal calls sudo directly" {
  _zc_has_tty() { return 0; }
  zzd_stub sudo 0
  run zzd_sudo apt-get install -y zsh
  [ "$status" -eq 0 ]
  [ "$(zzd_calls sudo)" = "apt-get install -y zsh" ]
}

@test "root runs the command without sudo" {
  zzd_stub id 0 "0"
  zzd_stub sudo 0
  zzd_stub dnf 0
  run zzd_sudo dnf install x
  [ "$status" -eq 0 ]
  [ "$(zzd_calls dnf)" = "install x" ]
  [ -z "$(zzd_calls sudo)" ]
}

@test "sudo in dry-run prints and does not execute" {
  zzd_stub sudo 0
  ZZD_DRY_RUN=1 run zzd_sudo dnf install x
  [ "$output" = "DRY-RUN: sudo dnf install x" ]
  [ -z "$(zzd_calls sudo)" ]
}

@test "ensure_line appends once and reports OK the second time" {
  file="$HOME/.zshenv"
  line="export PATH=\"\$HOME/.local/share/mise/shims:\$PATH\""
  run zzd_ensure_line "$file" "$line"
  [[ "$output" == "CHANGED:"* ]] || false
  run zzd_ensure_line "$file" "$line"
  [[ "$output" == "OK:"* ]] || false
  [ "$(grep -cFx -- "$line" "$file")" -eq 1 ]
}

@test "ensure_line creates a missing parent directory with a space" {
  file="$HOME/dir with space/profile.zsh"
  zzd_ensure_line "$file" "export A=1"
  [ "$(cat "$file")" = "export A=1" ]
}

@test "ensure_line does not treat a longer line as a match" {
  file="$HOME/.zshenv"
  printf 'export A=1 # note\n' >"$file"
  zzd_ensure_line "$file" "export A=1"
  [ "$(wc -l <"$file" | tr -d ' ')" -eq 2 ]
}

@test "ensure_line starts a new line when the file lacks a final newline" {
  file="$HOME/.profile.zsh"
  printf 'export B=2' >"$file"
  zzd_ensure_line "$file" "export A=1"
  [ "$(sed -n 1p "$file")" = "export B=2" ]
  [ "$(sed -n 2p "$file")" = "export A=1" ]
}

@test "ensure_line in dry-run does not create the file" {
  file="$HOME/new/.zshenv"
  ZZD_DRY_RUN=1 run zzd_ensure_line "$file" "export A=1"
  [[ "$output" == "DRY-RUN:"* ]] || false
  [ ! -e "$file" ]
}
