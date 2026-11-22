# shellcheck shell=bash

zzd_log_init() {
  if [ -z "${ZZD_RUN_LOG:-}" ]; then
    ZZD_RUN_LOG="$(mktemp "${TMPDIR:-/tmp}/zzd-run.XXXXXX")"
    export ZZD_RUN_LOG
  fi
}

_zzd_record() {
  if [ -n "${ZZD_RUN_LOG:-}" ]; then
    printf '%s\n' "$1" >>"$ZZD_RUN_LOG"
  fi
}

_zzd_fix() {
  if [ -n "${1:-}" ]; then
    printf '  fix: %s\n' "$1"
  fi
}

zzd_ok() {
  printf 'OK: %s\n' "$1"
  _zzd_record ok
}

zzd_info() {
  printf 'INFO: %s\n' "$1"
}

_zzd_dry_run() {
  [ "${ZZD_DRY_RUN:-0}" = "1" ]
}

zzd_changed() {
  if _zzd_dry_run; then
    return 0
  fi
  printf 'CHANGED: %s\n' "$1"
  _zzd_record changed
}

zzd_warn() {
  printf 'WARN: %s\n' "$1"
  _zzd_fix "${2:-}"
  _zzd_record warn
}

zzd_error() {
  printf 'ERROR: %s\n' "$1"
  _zzd_fix "${2:-}"
  _zzd_record error
}

_zzd_count() {
  if [ -n "${ZZD_RUN_LOG:-}" ] && [ -f "$ZZD_RUN_LOG" ]; then
    grep -c "^$1\$" "$ZZD_RUN_LOG" || true
  else
    printf '0\n'
  fi
}

zzd_summary() {
  local changed ok warn error
  changed="$(_zzd_count changed)"
  ok="$(_zzd_count ok)"
  warn="$(_zzd_count warn)"
  error="$(_zzd_count error)"
  printf 'Summary: %s changed, %s ok, %s warnings, %s errors\n' \
    "$changed" "$ok" "$warn" "$error"
  [ "$error" -eq 0 ]
}
