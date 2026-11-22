# shellcheck shell=bash

_zc_os_release_value() {
  local key="$1" file="$2" line value
  while IFS= read -r line; do
    case "$line" in
      "$key="*)
        value="${line#*=}"
        value="${value#\"}"
        value="${value%\"}"
        value="${value#\'}"
        value="${value%\'}"
        printf '%s\n' "$value"
        return 0
        ;;
      *) ;;
    esac
  done <"$file"
}

zc_os() {
  local kernel release="${ZC_OS_RELEASE:-/etc/os-release}" id="" id_like=""
  kernel="$(uname -s)"
  case "$kernel" in
    Darwin)
      printf 'darwin\n'
      return 0
      ;;
    Linux) ;;
    *)
      printf 'unsupported\n'
      return 0
      ;;
  esac
  if [ -r "$release" ]; then
    id="$(_zc_os_release_value ID "$release")"
    id_like="$(_zc_os_release_value ID_LIKE "$release")"
  fi
  case " $id $id_like " in
    *" fedora "*) printf 'fedora\n' ;;
    *" ubuntu "*) printf 'ubuntu\n' ;;
    *) printf 'unsupported\n' ;;
  esac
}

zc_login_shell() {
  local user line
  user="$(id -un)"
  case "$(zc_os)" in
    darwin)
      line="$(dscl . -read "/Users/$user" UserShell 2>/dev/null)" || line=""
      printf '%s' "${line#UserShell: }"
      ;;
    *)
      line="$(getent passwd "$user" 2>/dev/null)" || line=""
      printf '%s' "${line##*:}"
      ;;
  esac
}
