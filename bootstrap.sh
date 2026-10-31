#!/usr/bin/env bash
set -u

BS_REPO_URL="https://github.com/zambelz48/zambelz-dev-env.git"
BS_DIR="$HOME/zambelz-dev-env"
BS_MODULES=()

bs_usage() {
  printf 'usage: bootstrap.sh [--dir <path>] [--repo-url <url>] [module...]\n'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dir | --repo-url)
      if [ "$#" -lt 2 ]; then
        bs_usage
        exit 2
      fi
      case "$1" in
        --dir) BS_DIR="$2" ;;
        *) BS_REPO_URL="$2" ;;
      esac
      shift 2
      ;;
    -h | --help)
      bs_usage
      exit 0
      ;;
    -*)
      bs_usage
      exit 2
      ;;
    *)
      BS_MODULES+=("$1")
      shift
      ;;
  esac
done

bs_self="${BASH_SOURCE[0]:-}"
bs_root=""
if [ -n "$bs_self" ] && [ -f "$bs_self" ]; then
  bs_root="$(cd "$(dirname "$bs_self")" && pwd -P)"
fi

# Fetched on its own: get git, clone, and hand over to the clone's copy.
bs_raw() {
  case "$(uname -s)" in
    Darwin)
      if ! xcode-select -p >/dev/null 2>&1; then
        xcode-select --install
        printf 'ERROR: Xcode Command Line Tools are not installed\n'
        printf '  fix: finish the installer that just opened, then rerun\n'
        exit 1
      fi
      ;;
    Linux)
      if ! command -v git >/dev/null 2>&1; then
        if command -v dnf >/dev/null 2>&1; then
          sudo dnf install -y git || exit 1
        elif command -v apt-get >/dev/null 2>&1; then
          sudo apt-get update && sudo apt-get install -y git || exit 1
        else
          printf 'ERROR: unsupported OS\n'
          exit 1
        fi
      fi
      ;;
    *)
      printf 'ERROR: unsupported OS\n'
      exit 1
      ;;
  esac
  if [ -d "$BS_DIR/.git" ]; then
    printf 'OK: repository at %s\n' "$BS_DIR"
  elif git clone -q "$BS_REPO_URL" "$BS_DIR"; then
    printf 'CHANGED: cloned %s into %s\n' "$BS_REPO_URL" "$BS_DIR"
  else
    printf 'ERROR: clone of %s failed\n' "$BS_REPO_URL"
    exit 1
  fi
  exec bash "$BS_DIR/bootstrap.sh" ${BS_MODULES[@]+"${BS_MODULES[@]}"}
}

if [ ! -f "$bs_root/zconf/lib/log.sh" ]; then
  bs_raw
fi

ZC_ROOT="$bs_root"
export ZC_ROOT
for lib in log paths os exec version; do
  # shellcheck source=/dev/null
  . "$ZC_ROOT/zconf/lib/$lib.sh"
done
zc_log_init

bs_os() {
  BS_OS="$(zc_os)"
  if [ "$BS_OS" = "unsupported" ]; then
    zc_error "unsupported OS" "use macOS, Fedora or Ubuntu"
    return 1
  fi
  zc_ok "os: $BS_OS"
}

bs_brew_env() {
  local brew env_lines
  for brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$brew" ]; then
      env_lines="$("$brew" shellenv)" || return 1
      eval "$env_lines"
      return 0
    fi
  done
  return 1
}

bs_homebrew() {
  local installer
  if command -v brew >/dev/null 2>&1 || bs_brew_env; then
    zc_ok "Homebrew"
    return 0
  fi
  if _zc_dry_run; then
    printf 'DRY-RUN: install Homebrew\n'
    return 0
  fi
  installer="$(curl -fsSL \
    https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    zc_error "cannot download the Homebrew installer" "https://brew.sh"
    return 1
  }
  if ! /bin/bash -c "$installer" || ! bs_brew_env; then
    zc_error "Homebrew install failed" "https://brew.sh"
    return 1
  fi
  zc_changed "installed Homebrew"
}

bs_darwin_tools() {
  if xcode-select -p >/dev/null 2>&1; then
    zc_ok "Xcode Command Line Tools"
  else
    zc_do xcode-select --install
    zc_error "Xcode Command Line Tools are not installed" \
      "finish the installer that just opened, then rerun $ZC_ROOT/bootstrap.sh"
    return 1
  fi
  bs_homebrew
}

# The packages module installs the full lists; these are needed before it
# can run. Minimal Fedora images ship without chsh.
bs_linux_tools() {
  local chsh_pkg entry tool missing=()
  case "$BS_OS" in
    fedora) chsh_pkg=util-linux ;;
    *) chsh_pkg=passwd ;;
  esac
  for entry in zsh:zsh git:git curl:curl "chsh:$chsh_pkg"; do
    tool="${entry%%:*}"
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing+=("${entry#*:}")
    fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    zc_ok "zsh, git, curl and chsh"
    return 0
  fi
  case "$BS_OS" in
    fedora) zc_sudo dnf install -y "${missing[@]}" ;;
    *) zc_sudo apt-get update && zc_sudo apt-get install -y "${missing[@]}" ;;
  esac || {
    zc_error "could not install ${missing[*]}"
    return 1
  }
  zc_changed "installed ${missing[*]}"
}

bs_login_shell() {
  local shell zsh
  shell="$(zc_login_shell)"
  case "$shell" in
    */zsh)
      zc_ok "login shell is $shell"
      return 0
      ;;
    *) ;;
  esac
  zsh="$(command -v zsh)"
  if zc_do chsh -s "$zsh"; then
    zc_changed "login shell ${shell:-unknown} -> $zsh"
  else
    zc_error "could not change the login shell" "chsh -s $zsh"
    return 1
  fi
}

# Only checks out submodules that are missing; one at another commit is the
# owner's work and is left alone.
bs_submodules() {
  local lines line state path paths=() warned=0
  lines="$(git -C "$ZC_ROOT" submodule status 2>/dev/null)" || {
    zc_error "cannot read submodules" "git -C $ZC_ROOT submodule status"
    return 1
  }
  while IFS= read -r line; do
    if [ -z "$line" ]; then
      continue
    fi
    state="${line:0:1}"
    read -r _ path _ <<<"${line:1}"
    case "$state" in
      -) paths+=("$path") ;;
      +)
        zc_warn "submodule $path is not at its recorded commit; left as is" \
          "git -C $ZC_ROOT submodule update -- $path"
        warned=1
        ;;
      *) ;;
    esac
  done <<<"$lines"
  if [ "${#paths[@]}" -eq 0 ]; then
    if [ "$warned" -eq 0 ]; then
      zc_ok "submodules checked out"
    fi
    return 0
  fi
  if ! zc_do git -C "$ZC_ROOT" \
    -c "url.https://github.com/.insteadOf=git@github.com:" \
    submodule update --init --recursive -- "${paths[@]}"; then
    zc_error "submodule checkout failed" \
      "git -C $ZC_ROOT submodule update --init --recursive"
    return 1
  fi
  for path in "${paths[@]}"; do
    zc_changed "submodule $path"
  done
}

bs_token() {
  local token=""
  if [ -z "${GITHUB_TOKEN:-}" ] && command -v gh >/dev/null 2>&1; then
    token="$(gh auth token 2>/dev/null)" || token=""
    if [ -n "$token" ]; then
      GITHUB_TOKEN="$token"
      export GITHUB_TOKEN
    fi
  fi
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    zc_ok "GitHub token available"
    return 0
  fi
  zc_warn "no GitHub token (mise downloads may hit the API rate limit)" \
    "export GITHUB_TOKEN=<token>, or gh auth login after zconf apply"
}

bs_mise_version() {
  local line version=""
  if [ -x "$1" ]; then
    line="$("$1" --version 2>/dev/null)" || line=""
    read -r version _ <<<"$line"
  fi
  printf '%s' "$version"
}

bs_mise() {
  local pinned bin current installer after
  pinned="$(zc_mise_min_version)"
  bin="${ZC_HOME:?}/.local/bin/mise"
  current="$(bs_mise_version "$bin")"
  if [ -n "$current" ] && zc_version_ge "$current" "$pinned"; then
    zc_ok "mise $current (>= $pinned)"
    return 0
  fi
  if _zc_dry_run; then
    printf 'DRY-RUN: install mise %s from https://mise.run\n' "$pinned"
    return 0
  fi
  installer="$(curl -fsSL https://mise.run)" || {
    zc_error "cannot download the mise installer" "https://mise.run"
    return 1
  }
  printf '%s\n' "$installer" | MISE_VERSION="v$pinned" sh || {
    zc_error "mise installer failed" "https://mise.jdx.dev/installing-mise.html"
    return 1
  }
  after="$(bs_mise_version "$bin")"
  if [ "$after" != "$pinned" ]; then
    zc_error "mise is ${after:-missing} after the install, expected $pinned" \
      "https://mise.jdx.dev/installing-mise.html"
    return 1
  fi
  zc_changed "mise ${current:-missing} -> $pinned"
}

bs_main() {
  bs_os || return 1
  case "$BS_OS" in
    darwin) bs_darwin_tools || return 1 ;;
    *) bs_linux_tools || return 1 ;;
  esac
  bs_login_shell || return 1
  bs_submodules || return 1
  bs_token
  bs_mise || return 1
}

# shellcheck disable=SC2154 # ZC_RUN_LOG is set by zc_log_init (log.sh)
trap 'rm -f "${ZC_RUN_LOG:-}"' EXIT
if ! bs_main; then
  zc_summary
  exit 1
fi
zc_summary
rm -f "${ZC_RUN_LOG:-}"
unset ZC_RUN_LOG
exec "$ZC_ROOT/zconf/bin/zconf" apply ${BS_MODULES[@]+"${BS_MODULES[@]}"}
