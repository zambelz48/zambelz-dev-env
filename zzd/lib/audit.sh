# shellcheck shell=bash

_zc_audit_usage="zconf audit [--declared|--installed|--all] [--json] [--gate]"

_zc_audit_status() {
  case "$1" in
    0)
      zc_ok "no known vulnerabilities, every component covered, no leftovers"
      ;;
    1)
      zc_error "the audit found vulnerabilities, uncovered components or leftover installs" \
        "follow each finding's Action line (the fix-cve skill, README \"Security audit\")"
      ;;
    2)
      zc_error "the audit engine rejected its arguments" "$_zc_audit_usage"
      ;;
    *)
      zc_error "the audit could not run (exit $1); nothing was proven clean" \
        "fix the problem named above and run the audit again"
      ;;
  esac
}

zc_audit() {
  local mode="--all" json="" gate=""
  local arg

  for arg in "$@"; do
    case "$arg" in
      --declared | --installed | --all)
        mode="$arg"
        ;;
      --json)
        json="--json"
        ;;
      --gate)
        gate="--gate"
        ;;
      *)
        zc_error "unknown audit argument: $arg" "$_zc_audit_usage"
        return 2
        ;;
    esac
  done

  local python status=0

  if ! python="$(zc_tool python3)"; then
    zc_error "the audit could not run: python3 is not installed by mise" "zconf apply mise"
    return 3
  fi

  "$python" -E -s "${ZC_ROOT:?}/zconf/lib/audit" audit "$mode" ${json:+"$json"} ${gate:+"$gate"} || status=$?

  case "$status" in
    0 | 1 | 2 | 3) ;;
    *)
      status=3
      ;;
  esac

  if [ -n "$json" ]; then
    _zc_audit_status "$status" >&2
  else
    _zc_audit_status "$status"
  fi

  return "$status"
}
