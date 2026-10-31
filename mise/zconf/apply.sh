# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/mise/zconf/common.sh"

# bootstrap installs the mise command in ~/.local/bin; its PATH line goes
# before the shims line so the shims end up first.
mod_apply() {
  local status=0 missing tools
  zc_github_token
  zc_do mise trust -q "$ZC_ROOT/mise/mise.toml" || status=1
  zc_ensure_line "${ZC_HOME:?}/.zshenv" \
    "export PATH=\"\$HOME/.local/bin:\$PATH\"" || status=1
  zc_ensure_line "$ZC_HOME/.zshenv" \
    "export PATH=\"\$HOME/.local/share/mise/shims:\$PATH\"" || status=1
  zc_ensure_line "$ZC_HOME/.zshenv" \
    "export PATH=\"$ZC_ROOT/zconf/bin:\$PATH\"" || status=1
  missing="$(mise -C "$ZC_HOME" ls --missing 2>/dev/null)" || missing=""
  if zc_do mise -C "$ZC_HOME" install --locked; then
    if [ -n "$missing" ]; then
      tools="$(_mise_tool_versions "$missing")"
      zc_changed "installed: $tools"
    else
      zc_ok "mise tools installed from the lock"
    fi
  else
    zc_error "mise install --locked failed" "zconf apply mise"
    status=1
  fi
  return "$status"
}
