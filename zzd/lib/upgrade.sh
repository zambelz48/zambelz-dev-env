# shellcheck shell=bash

_zc_versions() {
  zc_python "${ZC_ROOT:?}/zconf/lib/versions.py" "$@"
}

_zc_mise_save() {
  mkdir -p "$1"
  cp "$ZC_ROOT/mise/mise.toml" "$ZC_ROOT/mise/mise.lock" "$1/"
}

_zc_mise_snapshot() {
  local dir
  dir="$(mktemp -d)"
  _zc_mise_save "$dir"
  printf '%s' "$dir"
}

_zc_mise_interrupted() {
  _zc_mise_restore "$1"
  zc_error "interrupted; mise.toml and the lock were restored"
  exit 130
}

_zc_mise_guard() {
  # shellcheck disable=SC2064 # the snapshot path is fixed when the trap is set
  trap "_zc_mise_interrupted '$1'" INT TERM
}

_zc_mise_unguard() {
  trap - INT TERM
}

_zc_mise_restore() {
  local dir="$1"
  cp "$dir/mise.toml" "$dir/mise.lock" "$ZC_ROOT/mise/"
  rm -rf "$dir"
}

_zc_pin_tool() {
  local step="$1/step" tool="$2" version="$3" platforms
  shift 3
  platforms="$(zc_lock_platforms)"
  _zc_mise_save "$step"
  if ! _zc_versions "$@"; then
    _zc_mise_restore "$step"
    zc_error "could not set $tool $version; $tool was left as it was"
    return 1
  fi
  if ! mise -C "$ZC_ROOT/mise" lock --global --platform "$platforms" \
    "$tool" || ! _zc_versions locked "$ZC_ROOT/mise/mise.toml" \
    "$ZC_ROOT/mise/mise.lock" "$step/mise.lock" "$tool" "$version"; then
    _zc_mise_restore "$step"
    zc_error "could not lock $tool $version; $tool was left as it was" \
      "check $tool $version exists for $platforms"
    return 1
  fi
  rm -rf "$step"
}

_zc_install_locked() {
  if ! mise -C "${ZC_HOME:?}" install --locked; then
    zc_error "mise install --locked failed" "zconf apply mise"
    return 1
  fi
}

_zc_changed_files() {
  local changes line
  changes="$(git -C "$ZC_ROOT" status --short -- mise 2>/dev/null)" ||
    changes=""
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      zc_info "changed (not committed): $line"
    fi
  done <<<"$changes"
}

_zc_upgrade_select() {
  local candidates="$1" yes="$2"
  if [ -z "$candidates" ] || [ "$yes" -eq 1 ]; then
    printf '%s' "$candidates"
    return 0
  fi
  printf '%s\n' "$candidates" | fzf --multi --prompt 'upgrade> ' || true
}

_zc_upgrade_dry_run() {
  local selected="$1" named="$2" tool old new platforms
  while read -r tool old new; do
    if [ -n "$tool" ]; then
      printf 'DRY-RUN: %s %s -> %s\n' "$tool" "$old" "$new"
    fi
  done <<<"$selected"
  if [ -n "$selected" ]; then
    platforms="$(zc_lock_platforms)"
    printf 'DRY-RUN: mise -C %s lock --global --platform %s\n' \
      "$ZC_ROOT/mise" "$platforms"
    printf 'DRY-RUN: mise -C %s install --locked\n' "$ZC_HOME"
  fi
  if [ "$named" -eq 0 ]; then
    (
      ZC_DRY_RUN=1
      export ZC_DRY_RUN
      zc_modules_run upgrade
    )
  fi
}

_zc_upgrade_apply() {
  local selected="$1" snapshot tool old new status=0 changed=()
  snapshot="$(_zc_mise_snapshot)"
  _zc_mise_guard "$snapshot"
  while read -r tool old new; do
    if [ -z "$tool" ]; then
      continue
    fi
    if _zc_pin_tool "$snapshot" "$tool" "$new" \
      set "$ZC_ROOT/mise/mise.toml" "$tool" "$old" "$new"; then
      changed+=("$tool $old -> $new")
    else
      status=1
    fi
  done <<<"$selected"
  _zc_mise_unguard
  rm -rf "$snapshot"
  if [ "${#changed[@]}" -eq 0 ]; then
    return "$status"
  fi
  _zc_install_locked || return 1
  for tool in "${changed[@]}"; do
    zc_changed "$tool"
  done
  return "$status"
}

zc_upgrade() {
  local arg yes=0 dry=0 named=0 status=0 candidates selected
  local args=(outdated "${ZC_ROOT:?}/mise/mise.toml")
  for arg in "$@"; do
    case "$arg" in
      --yes) yes=1 ;;
      --dry-run) dry=1 ;;
      --major) args+=(--major) ;;
      -*)
        zc_error "unknown option: $arg" \
          "zconf upgrade [--yes] [--major] [--dry-run] [tool...]"
        return 2
        ;;
      *)
        args+=("$arg")
        named=1
        ;;
    esac
  done
  zc_github_token
  candidates="$(_zc_versions "${args[@]}")" || {
    zc_error "could not check mise versions"
    return 1
  }
  if [ -z "$candidates" ]; then
    zc_ok "mise tools are current"
  elif [ "$yes" -eq 0 ] && ! _zc_has_tty; then
    zc_error "no terminal for the selection" "zconf upgrade --yes"
    return 2
  fi
  selected="$(_zc_upgrade_select "$candidates" "$yes")"
  if [ -n "$candidates" ] && [ -z "$selected" ]; then
    zc_ok "nothing selected"
    return 0
  fi
  if [ "$dry" -eq 1 ]; then
    _zc_upgrade_dry_run "$selected" "$named"
    return
  fi
  if [ -n "$selected" ]; then
    _zc_upgrade_apply "$selected" || return 1
  fi
  if [ "$named" -eq 0 ]; then
    zc_modules_run upgrade || status=1
  fi
  zc_audit --declared || status=1
  _zc_changed_files
  return "$status"
}

zc_use() {
  local snapshot
  if [ "$#" -ne 2 ]; then
    zc_error "usage: zconf use <tool> <version>"
    return 2
  fi
  snapshot="$(_zc_mise_snapshot)"
  _zc_mise_guard "$snapshot"
  zc_github_token
  if ! _zc_pin_tool "$snapshot" "$1" "$2" \
    use "${ZC_ROOT:?}/mise/mise.toml" "$1" "$2"; then
    _zc_mise_unguard
    rm -rf "$snapshot"
    return 1
  fi
  _zc_mise_unguard
  rm -rf "$snapshot"
  _zc_install_locked || return 1
  zc_changed "$1 $2 is the global default"
  _zc_changed_files
}
