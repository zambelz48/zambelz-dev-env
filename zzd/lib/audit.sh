# shellcheck shell=bash

_zzd_audit_usage="zzd audit [--declared|--installed|--all] [--json] [--gate]"

_zzd_audit_status() {
  case "$1:$2" in
    0:--gate)
      zzd_ok "nothing blocks; open findings marked 'waiting for upstream' are listed above"
      ;;
    0:*)
      zzd_ok "no known vulnerabilities, every component covered, no leftovers"
      ;;
    1:--gate)
      zzd_error "the audit found findings that block (fix available or unchecked), uncovered components or leftover installs" \
        "follow each blocking finding's Action line (the fix-cve skill, README \"Security audit\")"
      ;;
    1:*)
      zzd_error "the audit found vulnerabilities, uncovered components or leftover installs" \
        "follow each finding's Action line (the fix-cve skill, README \"Security audit\")"
      ;;
    2:*)
      zzd_error "the audit engine rejected its arguments" "$_zzd_audit_usage"
      ;;
    *)
      zzd_error "the audit could not run (exit $1); nothing was proven clean" \
        "fix the problem named above and run the audit again"
      ;;
  esac
}

zzd_audit() {
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
        zzd_error "unknown audit argument: $arg" "$_zzd_audit_usage"
        return 2
        ;;
    esac
  done

  local python status=0

  if ! python="$(zzd_tool python3)"; then
    zzd_error "the audit could not run: python3 is not installed by mise" "zzd apply mise"
    return 3
  fi

  "$python" -E -s "${ZZD_ROOT:?}/zzd/lib/audit" audit "$mode" ${json:+"$json"} ${gate:+"$gate"} || status=$?

  case "$status" in
    0 | 1 | 2 | 3) ;;
    *)
      status=3
      ;;
  esac

  if [ -n "$json" ]; then
    _zzd_audit_status "$status" "$gate" >&2
  else
    _zzd_audit_status "$status" "$gate"
  fi

  return "$status"
}
