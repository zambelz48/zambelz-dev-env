# shellcheck shell=bash

_zzd_versions() {
  zzd_python "${ZZD_ROOT:?}/zzd/lib/versions.py" "$@"
}

_zzd_mise_save() {
  mkdir -p "$1"
  cp "$ZZD_ROOT/mise/mise.toml" "$ZZD_ROOT/mise/mise.lock" "$1/"
}

_zzd_mise_snapshot() {
  local dir
  dir="$(mktemp -d)"
  _zzd_mise_save "$dir"
  printf '%s' "$dir"
}

_zzd_mise_interrupted() {
  _zzd_mise_restore "$1"
  zzd_error "interrupted; mise.toml and the lock were restored"
  exit 130
}

_zzd_mise_guard() {
  # shellcheck disable=SC2064 # the snapshot path is fixed when the trap is set
  trap "_zzd_mise_interrupted '$1'" INT TERM
}

_zzd_mise_unguard() {
  trap - INT TERM
}

_zzd_mise_restore() {
  local dir="$1"
  cp "$dir/mise.toml" "$dir/mise.lock" "$ZZD_ROOT/mise/"
  rm -rf "$dir"
}

_zzd_pin_tool() {
  local step="$1/step" tool="$2" version="$3" platforms
  shift 3
  platforms="$(zzd_lock_platforms)"
  _zzd_mise_save "$step"
  if ! _zzd_versions "$@"; then
    _zzd_mise_restore "$step"
    zzd_error "could not set $tool $version; $tool was left as it was"
    return 1
  fi
  if ! mise -C "$ZZD_ROOT/mise" lock --global --platform "$platforms" \
    "$tool" || ! _zzd_versions locked "$ZZD_ROOT/mise/mise.toml" \
    "$ZZD_ROOT/mise/mise.lock" "$step/mise.lock" "$tool" "$version"; then
    _zzd_mise_restore "$step"
    zzd_error "could not lock $tool $version; $tool was left as it was" \
      "check $tool $version exists for $platforms"
    return 1
  fi
  rm -rf "$step"
}

_zzd_install_locked() {
  if ! mise -C "${ZZD_HOME:?}" install --locked; then
    zzd_error "mise install --locked failed" "zzd apply mise"
    return 1
  fi
}

_zzd_changed_files() {
  local changes line
  changes="$(git -C "$ZZD_ROOT" status --short -- mise 2>/dev/null)" ||
    changes=""
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      zzd_info "changed (not committed): $line"
    fi
  done <<<"$changes"
}

_zzd_upgrade_select() {
  local candidates="$1" yes="$2"
  if [ -z "$candidates" ] || [ "$yes" -eq 1 ]; then
    printf '%s' "$candidates"
    return 0
  fi
  printf '%s\n' "$candidates" | fzf --multi --prompt 'upgrade> ' || true
}

_zzd_upgrade_dry_run() {
  local selected="$1" named="$2" tool old new platforms
  while read -r tool old new; do
    if [ -n "$tool" ]; then
      printf 'DRY-RUN: %s %s -> %s\n' "$tool" "$old" "$new"
    fi
  done <<<"$selected"
  if [ -n "$selected" ]; then
    platforms="$(zzd_lock_platforms)"
    printf 'DRY-RUN: mise -C %s lock --global --platform %s\n' \
      "$ZZD_ROOT/mise" "$platforms"
    printf 'DRY-RUN: mise -C %s install --locked\n' "$ZZD_HOME"
  fi
  if [ "$named" -eq 0 ]; then
    (
      ZZD_DRY_RUN=1
      export ZZD_DRY_RUN
      zzd_modules_run upgrade
    )
  fi
}

_zzd_upgrade_apply() {
  local selected="$1" snapshot tool old new status=0 changed=()
  snapshot="$(_zzd_mise_snapshot)"
  _zzd_mise_guard "$snapshot"
  while read -r tool old new; do
    if [ -z "$tool" ]; then
      continue
    fi
    if _zzd_pin_tool "$snapshot" "$tool" "$new" \
      set "$ZZD_ROOT/mise/mise.toml" "$tool" "$old" "$new"; then
      changed+=("$tool $old -> $new")
    else
      status=1
    fi
  done <<<"$selected"
  _zzd_mise_unguard
  rm -rf "$snapshot"
  if [ "${#changed[@]}" -eq 0 ]; then
    return "$status"
  fi
  _zzd_install_locked || return 1
  for tool in "${changed[@]}"; do
    zzd_changed "$tool"
  done
  return "$status"
}

zzd_upgrade() {
  local arg yes=0 dry=0 named=0 status=0 candidates selected
  local args=(outdated "${ZZD_ROOT:?}/mise/mise.toml")
  for arg in "$@"; do
    case "$arg" in
      --yes) yes=1 ;;
      --dry-run) dry=1 ;;
      --major) args+=(--major) ;;
      -*)
        zzd_error "unknown option: $arg" \
          "zzd upgrade [--yes] [--major] [--dry-run] [tool...]"
        return 2
        ;;
      *)
        args+=("$arg")
        named=1
        ;;
    esac
  done
  zzd_github_token
  candidates="$(_zzd_versions "${args[@]}")" || {
    zzd_error "could not check mise versions"
    return 1
  }
  if [ -z "$candidates" ]; then
    zzd_ok "mise tools are current"
  elif [ "$yes" -eq 0 ] && ! _zzd_has_tty; then
    zzd_error "no terminal for the selection" "zzd upgrade --yes"
    return 2
  fi
  selected="$(_zzd_upgrade_select "$candidates" "$yes")"
  if [ -n "$candidates" ] && [ -z "$selected" ]; then
    zzd_ok "nothing selected"
    return 0
  fi
  if [ "$dry" -eq 1 ]; then
    _zzd_upgrade_dry_run "$selected" "$named"
    return
  fi
  if [ -n "$selected" ]; then
    _zzd_upgrade_apply "$selected" || return 1
  fi
  if [ "$named" -eq 0 ]; then
    zzd_modules_run upgrade || status=1
  fi
  zzd_audit --declared || status=1
  _zzd_changed_files
  return "$status"
}

zzd_use() {
  local snapshot
  if [ "$#" -ne 2 ]; then
    zzd_error "usage: zzd use <tool> <version>"
    return 2
  fi
  snapshot="$(_zzd_mise_snapshot)"
  _zzd_mise_guard "$snapshot"
  zzd_github_token
  if ! _zzd_pin_tool "$snapshot" "$1" "$2" \
    use "${ZZD_ROOT:?}/mise/mise.toml" "$1" "$2"; then
    _zzd_mise_unguard
    rm -rf "$snapshot"
    return 1
  fi
  _zzd_mise_unguard
  rm -rf "$snapshot"
  _zzd_install_locked || return 1
  zzd_changed "$1 $2 is the global default"
  _zzd_changed_files
}
