# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/tools/zzd/common.sh"

_tools_report() {
  local kind="$1" lines="$2" name current latest
  if [ -z "$lines" ]; then
    zzd_ok "$kind tools are current"
    return 0
  fi
  while IFS=$'\t' read -r name current latest; do
    zzd_info "$kind $name $current -> $latest"
  done <<<"$lines"
}

_tools_outdated_npm() {
  local json lines
  json="$(_tools_npm_run outdated --format json 2>/dev/null)"
  case "$?" in
    0 | 1) ;;
    *)
      zzd_warn "npm tool versions unknown (pnpm outdated failed)"
      return 0
      ;;
  esac
  if [ -z "$json" ]; then
    json='{}'
  fi
  lines="$(ZZD_JSON="$json" zzd_python - <<'EOF'
import json
import os

for name, info in json.loads(os.environ["ZZD_JSON"]).items():
    print(f"{name}\t{info['current']}\t{info['latest']}")
EOF
  )" || {
    zzd_error "cannot read pnpm outdated output"
    return 1
  }
  _tools_report npm "$lines"
}

_tools_outdated_python() {
  local dir="${ZZD_ROOT:?}/tools/python" json lines
  if ! json="$(_tools_uv_run pip list --outdated --format json \
    --python "$dir/.venv/bin/python" 2>/dev/null)"; then
    zzd_warn "python tool versions unknown (uv pip list failed)"
    return 0
  fi
  lines="$(ZZD_JSON="$json" zzd_python - "$dir/pyproject.toml" <<'EOF'
import json
import os
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    declared = tomllib.load(f)["project"]["dependencies"]
names = {d.split("==", 1)[0].strip().lower() for d in declared}
for item in json.loads(os.environ["ZZD_JSON"]):
    if item["name"].lower() in names:
        print(f"{item['name']}\t{item['version']}\t{item['latest_version']}")
EOF
  )" || {
    zzd_error "cannot read uv pip list output"
    return 1
  }
  _tools_report python "$lines"
}

mod_update() {
  local status=0
  _tools_outdated_npm || status=1
  _tools_outdated_python || status=1
  return "$status"
}
