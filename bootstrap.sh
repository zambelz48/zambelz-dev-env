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

if [ ! -f "$bs_root/zzd/lib/log.sh" ]; then
  bs_raw
fi

ZZD_ROOT="$bs_root"
export ZZD_ROOT
for lib in log paths os exec version misebin; do
  # shellcheck source=/dev/null
  . "$ZZD_ROOT/zzd/lib/$lib.sh"
done
zzd_log_init

bs_os() {
  BS_OS="$(zzd_os)"
  if [ "$BS_OS" = "unsupported" ]; then
    zzd_error "unsupported OS" "use macOS, Fedora or Ubuntu"
    return 1
  fi
  zzd_ok "os: $BS_OS"
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
    zzd_ok "Homebrew"
    return 0
  fi
  if _zzd_dry_run; then
    printf 'DRY-RUN: install Homebrew\n'
    return 0
  fi
  installer="$(curl -fsSL \
    https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    zzd_error "cannot download the Homebrew installer" "https://brew.sh"
    return 1
  }
  if ! /bin/bash -c "$installer" || ! bs_brew_env; then
    zzd_error "Homebrew install failed" "https://brew.sh"
    return 1
  fi
  zzd_changed "installed Homebrew"
}

bs_darwin_tools() {
  if xcode-select -p >/dev/null 2>&1; then
    zzd_ok "Xcode Command Line Tools"
  else
    zzd_do xcode-select --install
    zzd_error "Xcode Command Line Tools are not installed" \
      "finish the installer that just opened, then rerun $ZZD_ROOT/bootstrap.sh"
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
    zzd_ok "zsh, git, curl and chsh"
    return 0
  fi
  case "$BS_OS" in
    fedora) zzd_sudo dnf install -y "${missing[@]}" ;;
    *) zzd_sudo apt-get update && zzd_sudo apt-get install -y "${missing[@]}" ;;
  esac || {
    zzd_error "could not install ${missing[*]}"
    return 1
  }
  zzd_changed "installed ${missing[*]}"
}

bs_login_shell() {
  local shell zsh
  shell="$(zzd_login_shell)"
  case "$shell" in
    */zsh)
      zzd_ok "login shell is $shell"
      return 0
      ;;
    *) ;;
  esac
  zsh="$(command -v zsh)"
  if zzd_do chsh -s "$zsh"; then
    zzd_changed "login shell ${shell:-unknown} -> $zsh"
  else
    zzd_error "could not change the login shell" "chsh -s $zsh"
    return 1
  fi
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
    zzd_ok "GitHub token available"
    return 0
  fi
  zzd_warn "no GitHub token (mise downloads may hit the API rate limit)" \
    "export GITHUB_TOKEN=<token>, or gh auth login after zzd apply"
}

bs_main() {
  bs_os || return 1
  case "$BS_OS" in
    darwin) bs_darwin_tools || return 1 ;;
    *) bs_linux_tools || return 1 ;;
  esac
  bs_login_shell || return 1
  bs_token
  zzd_mise_ensure || return 1
}

# shellcheck disable=SC2154 # ZZD_RUN_LOG is set by zzd_log_init (log.sh)
trap 'rm -f "${ZZD_RUN_LOG:-}"' EXIT
if ! bs_main; then
  zzd_summary
  exit 1
fi
zzd_summary
rm -f "${ZZD_RUN_LOG:-}"
unset ZZD_RUN_LOG
exec "$ZZD_ROOT/zzd/bin/zzd" apply ${BS_MODULES[@]+"${BS_MODULES[@]}"}
