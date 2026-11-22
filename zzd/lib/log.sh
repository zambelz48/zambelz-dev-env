# shellcheck shell=bash

zc_log_init() {
  if [ -z "${ZC_RUN_LOG:-}" ]; then
    ZC_RUN_LOG="$(mktemp "${TMPDIR:-/tmp}/zconf-run.XXXXXX")"
    export ZC_RUN_LOG
  fi
}

_zc_record() {
  if [ -n "${ZC_RUN_LOG:-}" ]; then
    printf '%s\n' "$1" >>"$ZC_RUN_LOG"
  fi
}

_zc_fix() {
  if [ -n "${1:-}" ]; then
    printf '  fix: %s\n' "$1"
  fi
}

zc_ok() {
  printf 'OK: %s\n' "$1"
  _zc_record ok
}

zc_info() {
  printf 'INFO: %s\n' "$1"
}

_zc_dry_run() {
  [ "${ZC_DRY_RUN:-0}" = "1" ]
}

zc_changed() {
  if _zc_dry_run; then
    return 0
  fi
  printf 'CHANGED: %s\n' "$1"
  _zc_record changed
}

zc_warn() {
  printf 'WARN: %s\n' "$1"
  _zc_fix "${2:-}"
  _zc_record warn
}

zc_error() {
  printf 'ERROR: %s\n' "$1"
  _zc_fix "${2:-}"
  _zc_record error
}

_zc_count() {
  if [ -n "${ZC_RUN_LOG:-}" ] && [ -f "$ZC_RUN_LOG" ]; then
    grep -c "^$1\$" "$ZC_RUN_LOG" || true
  else
    printf '0\n'
  fi
}

zc_summary() {
  local changed ok warn error
  changed="$(_zc_count changed)"
  ok="$(_zc_count ok)"
  warn="$(_zc_count warn)"
  error="$(_zc_count error)"
  printf 'Summary: %s changed, %s ok, %s warnings, %s errors\n' \
    "$changed" "$ok" "$warn" "$error"
  [ "$error" -eq 0 ]
}
