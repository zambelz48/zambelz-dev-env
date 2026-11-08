# shellcheck shell=bash

# The global config's root defaults to $HOME, so mise locks a version file
# (go.mod, .nvmrc) anywhere under $HOME into the global mise.lock.
_mise_global_root_line() {
  # shellcheck disable=SC2016 # $HOME expands in .zshenv
  printf '%s' 'export MISE_GLOBAL_CONFIG_ROOT="$HOME/.config/mise"'
}

_mise_tool_versions() {
  local tool version list=""
  while read -r tool version _; do
    if [ -n "$tool" ]; then
      list="${list:+$list, }$tool $version"
    fi
  done <<<"$1"
  printf '%s' "$list"
}
