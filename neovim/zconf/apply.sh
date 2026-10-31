# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZC_ROOT:?}/neovim/zconf/common.sh"

_nvim_build_gradle() {
  local dir java head built
  dir="$(_nvim_gradle_dir)"
  if [ ! -x "$dir/gradlew" ]; then
    zc_error "vscode-gradle submodule is not checked out" \
      "git -C $ZC_ROOT submodule update --init ${dir#"$ZC_ROOT"/}"
    return 1
  fi
  head="$(zc_git_head "$dir")" || head=""
  built="$(_nvim_gradle_built_commit)"
  if [ -n "$head" ] && [ "$built" = "$head" ]; then
    zc_ok "gradle-language-server built at $head"
    return 0
  fi
  java="$(mise -C "${ZC_HOME:?}" where java@temurin-17 2>/dev/null)" ||
    java=""
  if [ -z "$java" ]; then
    zc_error "Java 17 is not installed" "zconf apply mise"
    return 1
  fi
  if _zc_dry_run; then
    printf 'DRY-RUN: build gradle-language-server with %s\n' "$java"
    return 0
  fi
  if (cd "$dir" && JAVA_HOME="$java" ./gradlew --no-daemon -q \
    :gradle-language-server:installDist); then
    printf '%s\n' "$head" >"$(_nvim_gradle_stamp)"
    zc_changed "built gradle-language-server at $head"
    return 0
  fi
  zc_error "gradle-language-server build failed" \
    "cd $dir && ./gradlew :gradle-language-server:installDist"
  return 1
}

_nvim_restore() {
  local nvim output
  if ! nvim="$(zc_tool nvim)"; then
    zc_error "neovim is not installed by mise" "zconf apply mise"
    return 1
  fi
  if _zc_dry_run; then
    zc_do "$nvim" --headless "+Lazy! restore" +qa
  elif output="$("$nvim" --headless "+Lazy! restore" +qa 2>&1)"; then
    zc_ok "lazy.nvim plugins restored from lazy-lock.json"
  else
    printf '%s\n' "$output"
    zc_error "lazy.nvim restore failed" \
      "\"$nvim\" --headless \"+Lazy! restore\" +qa"
    return 1
  fi
}

mod_apply() {
  local status=0
  _nvim_restore || status=1
  _nvim_build_gradle || status=1
  return "$status"
}
