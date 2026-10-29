# shellcheck shell=bash

# True when version $1 >= $2, comparing up to three numeric components.
zc_version_ge() {
  local IFS=.
  local -a have want
  local i a b
  read -r -a have <<<"$1"
  read -r -a want <<<"$2"
  for i in 0 1 2; do
    a="${have[i]:-0}"
    b="${want[i]:-0}"
    if [ "$((10#$a))" -gt "$((10#$b))" ]; then
      return 0
    fi
    if [ "$((10#$a))" -lt "$((10#$b))" ]; then
      return 1
    fi
  done
  return 0
}

# bootstrap reads it before mise or Python exist, so no TOML parser.
zc_mise_min_version() {
  local key value
  while read -r key _ value || [ -n "$key" ]; do
    case "$key" in
      '['*) return 1 ;;
      min_version)
        value="${value#\"}"
        printf '%s\n' "${value%\"}"
        return 0
        ;;
      *) ;;
    esac
  done <"${ZC_ROOT:?}/mise/mise.toml"
  return 1
}
