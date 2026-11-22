# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/mise/zzd/common.sh"

_mise_project_requests() {
  local json entries tool version path
  json="$(mise -C "$PWD" ls --missing --json 2>/dev/null)" || json=""
  if [ -z "$json" ]; then
    return 0
  fi
  entries="$(ZZD_MISSING_JSON="$json" zzd_python - "${ZZD_HOME:?}/.config/mise" <<'EOF'
import json
import os
import sys

global_dir = sys.argv[1]
for tool, items in json.loads(os.environ["ZZD_MISSING_JSON"]).items():
    for item in items:
        path = item.get("source", {}).get("path", "")
        if path and not path.startswith(global_dir + "/"):
            print(f"{tool}\t{item['version']}\t{path}")
EOF
  )" || entries=""
  while IFS=$'\t' read -r tool version path; do
    if [ -n "$tool" ]; then
      zzd_warn "$tool $version requested by $path is not installed" \
        "mise -C ${path%/*} install"
    fi
  done <<<"$entries"
}

_mise_pins() {
  local report line platforms relock
  platforms="$(zzd_lock_platforms)"
  relock="mise -C $ZZD_ROOT/mise lock --global --platform $platforms"
  if report="$(zzd_python "$ZZD_ROOT/zzd/lib/check_pins.py" --mise \
    "$ZZD_ROOT/mise/mise.toml" "$ZZD_ROOT/mise/mise.lock")"; then
    zzd_ok "${report#OK: }"
    return 0
  fi
  while IFS= read -r line; do
    case "$line" in
      *" is not in the lock" | *" is not locked for "*)
        zzd_error "${line#ERROR: }" "$relock"
        ;;
      'ERROR: '*) zzd_error "${line#ERROR: }" "edit $ZZD_ROOT/mise/mise.toml" ;;
      *) ;;
    esac
  done <<<"$report"
  return 1
}

_mise_global_root() {
  local want="${ZZD_HOME:?}/.config/mise" line
  line="$(_mise_global_root_line)"
  if ! grep -Fxq -- "$line" "$ZZD_HOME/.zshenv" 2>/dev/null; then
    zzd_error "$ZZD_HOME/.zshenv does not set MISE_GLOBAL_CONFIG_ROOT" \
      "zzd apply mise"
    return 1
  fi
  if [ "${MISE_GLOBAL_CONFIG_ROOT:-}" = "$want" ]; then
    zzd_ok "MISE_GLOBAL_CONFIG_ROOT=$want"
  else
    zzd_warn "MISE_GLOBAL_CONFIG_ROOT is not $want in this shell" \
      "open a new shell"
  fi
}

mod_doctor() {
  local status=0 missing tools ruby ruby_dir
  zzd_mise_check || status=1
  _mise_pins || status=1
  _mise_global_root || status=1
  missing="$(mise -C "$ZZD_HOME" ls --missing 2>/dev/null)" || missing=""
  if [ -n "$missing" ]; then
    tools="$(_mise_tool_versions "$missing")"
    zzd_error "missing tools: $tools" "zzd apply mise"
    status=1
  else
    zzd_ok "all pinned tools installed"
  fi
  ruby_dir="$(mise -C "$ZZD_HOME" where ruby 2>/dev/null)" || ruby_dir=""
  if [ -n "$ruby_dir" ] &&
    ruby="$("$ruby_dir/bin/ruby" --version 2>/dev/null)"; then
    zzd_ok "$ruby"
  else
    zzd_error "ruby does not start" "zzd apply packages && zzd apply mise"
    status=1
  fi
  if [ "$PWD" != "$ZZD_HOME" ]; then
    _mise_project_requests
  fi
  return "$status"
}
