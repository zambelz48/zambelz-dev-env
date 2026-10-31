# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/tools/zconf/common.sh"

_tools_report() {
  local kind="$1" lines="$2" name current latest
  if [ -z "$lines" ]; then
    zc_ok "$kind tools are current"
    return 0
  fi
  while IFS=$'\t' read -r name current latest; do
    zc_info "$kind $name $current -> $latest"
  done <<<"$lines"
}

_tools_outdated_npm() {
  local json lines
  json="$(_tools_npm_run outdated --format json 2>/dev/null)"
  case "$?" in
    0 | 1) ;;
    *)
      zc_warn "npm tool versions unknown (pnpm outdated failed)"
      return 0
      ;;
  esac
  if [ -z "$json" ]; then
    json='{}'
  fi
  lines="$(ZC_JSON="$json" zc_python - <<'EOF'
import json
import os

for name, info in json.loads(os.environ["ZC_JSON"]).items():
    print(f"{name}\t{info['current']}\t{info['latest']}")
EOF
  )" || {
    zc_error "cannot read pnpm outdated output"
    return 1
  }
  _tools_report npm "$lines"
}

_tools_outdated_python() {
  local dir="${ZC_ROOT:?}/tools/python" json lines
  if ! json="$(_tools_uv_run pip list --outdated --format json \
    --python "$dir/.venv/bin/python" 2>/dev/null)"; then
    zc_warn "python tool versions unknown (uv pip list failed)"
    return 0
  fi
  lines="$(ZC_JSON="$json" zc_python - "$dir/pyproject.toml" <<'EOF'
import json
import os
import sys
import tomllib

with open(sys.argv[1], "rb") as f:
    declared = tomllib.load(f)["project"]["dependencies"]
names = {d.split("==", 1)[0].strip().lower() for d in declared}
for item in json.loads(os.environ["ZC_JSON"]):
    if item["name"].lower() in names:
        print(f"{item['name']}\t{item['version']}\t{item['latest_version']}")
EOF
  )" || {
    zc_error "cannot read uv pip list output"
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
