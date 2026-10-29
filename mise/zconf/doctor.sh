# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/mise/zconf/common.sh"

_mise_project_requests() {
  local json entries tool version path
  json="$(mise -C "$PWD" ls --missing --json 2>/dev/null)" || json=""
  if [ -z "$json" ]; then
    return 0
  fi
  entries="$(ZC_MISSING_JSON="$json" zc_python - "${ZC_HOME:?}/.config/mise" <<'EOF'
import json
import os
import sys

global_dir = sys.argv[1]
for tool, items in json.loads(os.environ["ZC_MISSING_JSON"]).items():
    for item in items:
        path = item.get("source", {}).get("path", "")
        if path and not path.startswith(global_dir + "/"):
            print(f"{tool}\t{item['version']}\t{path}")
EOF
  )" || entries=""
  while IFS=$'\t' read -r tool version path; do
    if [ -n "$tool" ]; then
      zc_warn "$tool $version requested by $path is not installed" \
        "mise -C ${path%/*} install"
    fi
  done <<<"$entries"
}

_mise_pins() {
  local report line platforms relock
  platforms="$(zc_lock_platforms)"
  relock="mise -C $ZC_ROOT/mise lock --global --platform $platforms"
  if report="$(zc_python "$ZC_ROOT/zconf/lib/check_pins.py" --mise \
    "$ZC_ROOT/mise/mise.toml" "$ZC_ROOT/mise/mise.lock")"; then
    zc_ok "${report#OK: }"
    return 0
  fi
  while IFS= read -r line; do
    case "$line" in
      *" is not in the lock" | *" is not locked for "*)
        zc_error "${line#ERROR: }" "$relock"
        ;;
      'ERROR: '*) zc_error "${line#ERROR: }" "edit $ZC_ROOT/mise/mise.toml" ;;
      *) ;;
    esac
  done <<<"$report"
  return 1
}

mod_doctor() {
  local status=0 pinned line version missing tools ruby ruby_dir
  pinned="$(zc_mise_min_version)"
  line="$(mise --version 2>/dev/null)" || line=""
  read -r version _ <<<"$line"
  if [ -n "$version" ] && zc_version_ge "$version" "$pinned"; then
    zc_ok "mise $version (>= $pinned)"
  else
    zc_error "mise ${version:-missing} is older than $pinned" \
      "$ZC_ROOT/bootstrap.sh"
    status=1
  fi
  _mise_pins || status=1
  missing="$(mise -C "$ZC_HOME" ls --missing 2>/dev/null)" || missing=""
  if [ -n "$missing" ]; then
    tools="$(_mise_tool_versions "$missing")"
    zc_error "missing tools: $tools" "zconf apply mise"
    status=1
  else
    zc_ok "all pinned tools installed"
  fi
  ruby_dir="$(mise -C "$ZC_HOME" where ruby 2>/dev/null)" || ruby_dir=""
  if [ -n "$ruby_dir" ] &&
    ruby="$("$ruby_dir/bin/ruby" --version 2>/dev/null)"; then
    zc_ok "$ruby"
  else
    zc_error "ruby does not start" "zconf apply packages && zconf apply mise"
    status=1
  fi
  if [ "$PWD" != "$ZC_HOME" ]; then
    _mise_project_requests
  fi
  return "$status"
}
