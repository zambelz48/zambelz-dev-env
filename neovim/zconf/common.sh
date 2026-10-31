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

_nvim_gradle_built_commit() {
  local out stamp
  out="$(_nvim_gradle_out)"
  stamp="$(_nvim_gradle_stamp)"
  if [ -x "$out" ] && [ -f "$stamp" ]; then
    cat "$stamp"
  fi
}
