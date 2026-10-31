# shellcheck shell=bash

_zc_mise_data() {
  printf '%s' "${MISE_DATA_DIR:-${ZC_HOME:?}/.local/share/mise}"
}

_zc_osv_run() {
  local osv rc config
  if ! osv="$(zc_tool osv-scanner)"; then
    zc_error "osv-scanner is not installed by mise" "zconf apply mise"
    return 3
  fi
  config="$(mktemp)"
  "$osv" scan --config "$config" "$@"
  rc=$?
  rm -f "$config"
  case "$rc" in
    0)
      zc_ok "no known vulnerabilities"
      return 0
      ;;
    1)
      zc_error "vulnerabilities found" \
        "upgrade the tool, or force a fixed version in ${ZC_ROOT:?}/tools"
      return 1
      ;;
    *)
      zc_error "scan could not run (osv-scanner exit $rc)" \
        "$osv scan $*"
      return 3
      ;;
  esac
}

_zc_audit_declared() {
  local tmp status
  tmp="$(mktemp -d)"
  if ! zc_python "$ZC_ROOT/zconf/lib/audit_lock_to_osv.py" \
    "$ZC_ROOT/mise/mise.lock" "$tmp/mise-lock.json"; then
    rm -rf "$tmp"
    zc_error "scan could not run (mise.lock conversion failed)"
    return 3
  fi
  _zc_osv_run -L "osv-scanner:$tmp/mise-lock.json" \
    -L "$ZC_ROOT/tools/npm/pnpm-lock.yaml" \
    -L "$ZC_ROOT/tools/python/uv.lock"
  status=$?
  rm -rf "$tmp"
  return "$status"
}

_zc_os_advisories() {
  local os output line
  os="$(zc_os)"
  case "$os" in
    fedora)
      output="$(dnf -q updateinfo list --security 2>/dev/null)" || true
      if [ -z "$output" ]; then
        zc_info "no pending OS security advisories"
      fi
      while IFS= read -r line; do
        if [ -n "$line" ]; then
          zc_info "$line"
        fi
      done <<<"$output"
      ;;
    *)
      zc_info "no native OS advisory source"
      ;;
  esac
}

_zc_audit_installed() {
  local status gradle
  local args=(-r "$(_zc_mise_data)/installs" "$ZC_ROOT/tools")
  gradle="$ZC_ROOT/neovim/.lsp_vendors/vscode-gradle/gradle-language-server"
  if [ -d "$gradle/build/install" ]; then
    args+=("$gradle/build/install")
  fi
  _zc_osv_run "${args[@]}"
  status=$?
  _zc_os_advisories
  return "$status"
}

zc_audit() {
  case "${1:---declared}" in
    --declared) _zc_audit_declared ;;
    --installed) _zc_audit_installed ;;
    *)
      zc_error "unknown audit mode: $1" "zconf audit [--declared|--installed]"
      return 2
      ;;
  esac
}
