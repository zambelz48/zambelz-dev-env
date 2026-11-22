# shellcheck shell=bash
# shellcheck source=common.sh
. "${ZZD_ROOT:?}/neovim/zzd/common.sh"

_nvim_build_gradle() {
  local dir java head built
  dir="$(_nvim_gradle_dir)"
  if [ ! -x "$dir/gradlew" ]; then
    zzd_error "vscode-gradle submodule is not checked out" \
      "git -C $ZZD_ROOT submodule update --init ${dir#"$ZZD_ROOT"/}"
    return 1
  fi
  head="$(zzd_git_head "$dir")" || head=""
  built="$(_nvim_gradle_built_commit)"
  if [ -n "$head" ] && [ "$built" = "$head" ]; then
    zzd_ok "gradle-language-server built at $head"
    return 0
  fi
  java="$(mise -C "${ZZD_HOME:?}" where java@temurin-17 2>/dev/null)" ||
    java=""
  if [ -z "$java" ]; then
    zzd_error "Java 17 is not installed" "zzd apply mise"
    return 1
  fi
  if _zzd_dry_run; then
    printf 'DRY-RUN: build gradle-language-server with %s\n' "$java"
    return 0
  fi
  if (cd "$dir" && JAVA_HOME="$java" ./gradlew --no-daemon -q \
    :gradle-language-server:installDist); then
    printf '%s\n' "$head" >"$(_nvim_gradle_stamp)"
    zzd_changed "built gradle-language-server at $head"
    return 0
  fi
  zzd_error "gradle-language-server build failed" \
    "cd $dir && ./gradlew :gradle-language-server:installDist"
  return 1
}

_nvim_restore() {
  local nvim output
  if ! nvim="$(zzd_tool nvim)"; then
    zzd_error "neovim is not installed by mise" "zzd apply mise"
    return 1
  fi
  if _zzd_dry_run; then
    zzd_do "$nvim" --headless "+Lazy! restore" +qa
  elif output="$("$nvim" --headless "+Lazy! restore" +qa 2>&1)"; then
    zzd_ok "lazy.nvim plugins restored from lazy-lock.json"
  else
    printf '%s\n' "$output"
    zzd_error "lazy.nvim restore failed" \
      "\"$nvim\" --headless \"+Lazy! restore\" +qa"
    return 1
  fi
}

_nvim_parsers_sync() {
  local out err installed updated count status=0
  _nvim_parsers_prepare sync || return 1
  if _zzd_dry_run; then
    printf 'DRY-RUN: install and update treesitter parsers with %s\n' \
      "$_NVIM_BIN"
    return 0
  fi
  out="$(mktemp)"
  err="$(mktemp)"
  if ! _nvim_parsers_run sync "$out" "$err"; then
    cat "$err"
    zzd_error "treesitter parser sync failed" "zzd apply neovim"
    rm -f "$out" "$err"
    return 1
  fi
  installed="$(_nvim_parsers_names installed "$out")"
  updated="$(_nvim_parsers_names updated "$out")"
  if [ -n "$installed" ]; then
    zzd_changed "treesitter parsers installed: $installed"
  fi
  if [ -n "$updated" ]; then
    zzd_changed "treesitter parsers updated: $updated"
  fi
  if ! _nvim_parsers_problems "$out"; then
    cat "$err"
    status=1
  elif [ -z "$installed$updated" ]; then
    count="$(_nvim_parsers_count "$out")"
    zzd_ok "treesitter parsers match nvim-treesitter ($count)"
  fi
  rm -f "$out" "$err"
  return "$status"
}

mod_apply() {
  local status=0
  _nvim_restore || status=1
  if zzd_tool nvim >/dev/null; then
    _nvim_parsers_sync || status=1
  fi
  _nvim_build_gradle || status=1
  return "$status"
}
