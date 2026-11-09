# shellcheck shell=bash
# shellcheck source=../../zconf/lib/gitpin.sh
. "${ZC_ROOT:?}/zconf/lib/gitpin.sh"

_nvim_gradle_dir() {
  printf '%s/neovim/.lsp_vendors/vscode-gradle' "${ZC_ROOT:?}"
}

_nvim_gradle_out() {
  local bin="gradle-language-server/build/install/gradle-language-server/bin"
  local dir
  dir="$(_nvim_gradle_dir)"
  printf '%s/%s/gradle-language-server' "$dir" "$bin"
}

_nvim_gradle_stamp() {
  local dir
  dir="$(_nvim_gradle_dir)"
  printf '%s/gradle-language-server/build/zconf-commit' "$dir"
}

_nvim_lazy_dir() {
  printf '%s/nvim/lazy' "${XDG_DATA_HOME:-${ZC_HOME:?}/.local/share}"
}

_nvim_parsers_prepare() {
  local ts
  if ! _NVIM_BIN="$(zc_tool nvim)"; then
    zc_error "neovim is not installed by mise" "zconf apply mise"
    return 1
  fi
  _NVIM_TS_PLUGIN="$(_nvim_lazy_dir)/nvim-treesitter"
  if [ ! -d "$_NVIM_TS_PLUGIN" ]; then
    zc_error "nvim-treesitter is not installed" "zconf apply neovim"
    return 1
  fi
  _NVIM_TS_PATH="$PATH"
  if [ "$1" = "sync" ]; then
    if ! ts="$(zc_tool tree-sitter)"; then
      zc_error "tree-sitter is not installed by mise" "zconf apply mise"
      return 1
    fi
    _NVIM_TS_PATH="${ts%/*}:$PATH"
  fi
}

_nvim_parsers_run() {
  local script="${ZC_ROOT:?}/neovim/scripts/treesitter_parsers.lua"
  PATH="$_NVIM_TS_PATH" "$_NVIM_BIN" -l "$script" "$1" "$_NVIM_TS_PLUGIN" \
    >"$2" 2>"$3" && grep -q $'^checked\t' "$2"
}

_nvim_parsers_names() {
  local kind lang list=""
  while IFS=$'\t' read -r kind lang _; do
    if [ "$kind" = "$1" ]; then
      list="${list:+$list, }$lang"
    fi
  done <"$2"
  printf '%s' "$list"
}

_nvim_parsers_count() {
  local kind count
  while IFS=$'\t' read -r kind count _; do
    if [ "$kind" = "checked" ]; then
      printf '%s' "$count"
    fi
  done <"$1"
}

_nvim_parsers_problems() {
  local kind lang have want msg status=0 fix="zconf apply neovim"
  while IFS=$'\t' read -r kind lang have want; do
    case "$kind" in
      missing)
        zc_error "treesitter parser $lang is not installed" "$fix"
        status=1
        ;;
      outdated)
        case "$have" in
          queries | stale-queries)
            zc_error "treesitter queries for $lang are out of date" "$fix"
            ;;
          *)
            msg="treesitter parser $lang at ${have:0:12}"
            zc_error "$msg, nvim-treesitter wants ${want:0:12}" "$fix"
            ;;
        esac
        status=1
        ;;
      failed)
        zc_error "treesitter $lang did not finish: $have" "$fix"
        status=1
        ;;
      *) ;;
    esac
  done <"$1"
  return "$status"
}

_nvim_gradle_built_commit() {
  local out stamp
  out="$(_nvim_gradle_out)"
  stamp="$(_nvim_gradle_stamp)"
  if [ -x "$out" ] && [ -f "$stamp" ]; then
    cat "$stamp"
  fi
}
