# shellcheck shell=bash

_mise_tool_versions() {
  local tool version list=""
  while read -r tool version _; do
    if [ -n "$tool" ]; then
      list="${list:+$list, }$tool $version"
    fi
  done <<<"$1"
  printf '%s' "$list"
}
