# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/mise/zzd/common.sh"

# The mise command lives in ~/.local/bin; its PATH line goes before the shims
# line so the shims end up first.
mod_apply() {
  local status=0 missing tools root_line
  zzd_mise_ensure || return 1
  zzd_github_token
  zzd_do mise trust -q "$ZZD_ROOT/mise/mise.toml" || status=1
  zzd_ensure_line "${ZZD_HOME:?}/.zshenv" \
    "export PATH=\"\$HOME/.local/bin:\$PATH\"" || status=1
  zzd_ensure_line "$ZZD_HOME/.zshenv" \
    "export PATH=\"\$HOME/.local/share/mise/shims:\$PATH\"" || status=1
  zzd_ensure_line "$ZZD_HOME/.zshenv" \
    "export PATH=\"$ZZD_ROOT/zzd/bin:\$PATH\"" || status=1
  root_line="$(_mise_global_root_line)"
  zzd_ensure_line "$ZZD_HOME/.zshenv" "$root_line" || status=1
  missing="$(mise -C "$ZZD_HOME" ls --missing 2>/dev/null)" || missing=""
  if zzd_do mise -C "$ZZD_HOME" install --locked; then
    if [ -n "$missing" ]; then
      tools="$(_mise_tool_versions "$missing")"
      zzd_changed "installed: $tools"
    else
      zzd_ok "mise tools installed from the lock"
    fi
  else
    zzd_error "mise install --locked failed" "zzd apply mise"
    status=1
  fi
  return "$status"
}
