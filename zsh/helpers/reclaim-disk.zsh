# Reclaim host disk by clearing regenerable caches.
#
# Every target below is declared in a table, not hardcoded in the logic: each
# row names a probe (a command or a directory) and the action to run when that
# probe resolves. A machine missing a tool simply skips its row, so the same
# helper works unchanged across macOS and Linux and across machines with
# different toolchains installed.
#
# Usage:
#   reclaim_disk              clear every safe target present on this machine
#   reclaim_disk --list       show what is present and its size, change nothing
#   reclaim_disk --dry-run    print the commands, change nothing
#   reclaim_disk --aggressive also clear caches that are slow to rebuild
#
# Never included: Docker volumes. With no container running, `docker volume
# prune` removes named volumes as readily as anonymous ones, and a named volume
# is usually the only copy of some local state. Do not add it to the table.

# kind|probe|label|action
#   cmd  — probe is a command name; the row runs when it is on PATH
#   path — probe is a directory; the row runs when it exists
ZAMBELZ_RECLAIM_TARGETS=(
  "cmd|npm|npm cache|npm cache clean --force"
  "cmd|pnpm|pnpm store|pnpm store prune"
  "cmd|yarn|yarn cache|yarn cache clean"
  "cmd|bun|bun cache|bun pm cache rm"
  "cmd|uv|uv cache|uv cache prune"
  "cmd|pip3|pip cache|pip3 cache purge"
  "cmd|brew|homebrew|brew cleanup -s --prune=all"
  "cmd|go|go build cache|go clean -cache -testcache"
  "path|$HOME/Library/Caches/Homebrew|homebrew downloads|rm -rf '$HOME/Library/Caches/Homebrew'"
  "path|$HOME/Library/Developer/Xcode/DerivedData|xcode deriveddata|rm -rf '$HOME/Library/Developer/Xcode/DerivedData'/*"
  "path|$HOME/.gradle/caches|gradle caches|rm -rf '$HOME/.gradle/caches'"
  "path|$HOME/.cargo/registry/cache|cargo registry cache|rm -rf '$HOME/.cargo/registry/cache'"
  "path|$HOME/.cache/pip|pip cache dir|rm -rf '$HOME/.cache/pip'"
  "path|$HOME/.cache/uv|uv cache dir|rm -rf '$HOME/.cache/uv'"
)

# Slow to rebuild, so opt-in rather than default.
ZAMBELZ_RECLAIM_AGGRESSIVE_TARGETS=(
  "cmd|go|go module cache|go clean -modcache"
  "path|$HOME/.cargo/registry/src|cargo registry sources|rm -rf '$HOME/.cargo/registry/src'"
  "path|$HOME/Library/Caches|macos user caches|rm -rf '$HOME/Library/Caches'/*"
  "path|$HOME/.cache|linux user caches|rm -rf '$HOME/.cache'/*"
)

_reclaim_data_mount() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    print -- "/System/Volumes/Data"
  else
    print -- "/"
  fi
}

_reclaim_free_bytes() {
  df -k "$(_reclaim_data_mount)" | awk 'NR==2 {print $4 * 1024}'
}

_reclaim_human() {
  awk -v b="$1" 'BEGIN {
    split("B KB MB GB TB", u, " "); i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf "%.2f %s", b, u[i]
  }'
}

_reclaim_probe_ok() {
  local kind="$1" probe="$2"
  case "$kind" in
    cmd)  command -v "$probe" &> /dev/null ;;
    path) [[ -d "$probe" ]] ;;
    *)    return 1 ;;
  esac
}

_reclaim_size_of() {
  local kind="$1" probe="$2"
  if [[ "$kind" == "path" ]]; then
    du -shx "$probe" 2> /dev/null | cut -f1
  else
    print -- "-"
  fi
}

# Clears the temp trees a reboot would clear. Kept out of the table because the
# paths are resolved per-platform rather than declared.
_reclaim_temp() {
  local mode="$1"
  local -a temps
  if [[ "$(uname -s)" == "Darwin" ]]; then
    temps=(
      "$(getconf DARWIN_USER_TEMP_DIR 2> /dev/null)|1"
      "$(getconf DARWIN_USER_CACHE_DIR 2> /dev/null)|7"
    )
  fi
  temps+=("/tmp|7")

  local entry dir age
  for entry in "${temps[@]}"; do
    dir="${entry%%|*}"
    age="${entry##*|}"
    [[ -z "$dir" || ! -d "$dir" ]] && continue
    if [[ "$mode" == "run" ]]; then
      find "$dir" -mindepth 1 -maxdepth 1 -mtime "+$age" -user "$(id -un)" \
        -exec rm -rf {} + 2> /dev/null
      print -- "  cleared   ${dir} (older than ${age}d)"
    else
      print -- "  would clear ${dir} (older than ${age}d)"
    fi
  done
}

# Space a process has freed but still holds open is only released when that
# process exits. This is most of what a reboot reclaims, and the reason the
# helper reports it rather than pretending to clean it.
_reclaim_report_held() {
  command -v lsof &> /dev/null || return 0
  local held
  held=$(lsof -nP +L1 2> /dev/null \
    | awk 'NR>1 && $7 ~ /^[0-9]+$/ && $7 > 104857600 {
        printf "  %-20s pid %-8s %8.1f MB  %s\n", $1, $2, $7/1048576, $NF
      }' | sort -k5 -rn | head -10)
  print -- "\nHeld open by a running process (needs a restart or a kill):"
  if [[ -n "$held" ]]; then
    print -- "$held"
  else
    print -- "  none over 100 MB"
  fi
}

reclaim_disk() {
  local mode="run"
  local aggressive=0

  while (( $# )); do
    case "$1" in
      -l|--list)       mode="list" ;;
      -n|--dry-run)    mode="dry" ;;
      -a|--aggressive) aggressive=1 ;;
      -h|--help)
        print -- "Usage: reclaim_disk [--list] [--dry-run] [--aggressive]"
        print -- "  --list        show present targets and sizes, change nothing"
        print -- "  --dry-run     print commands, change nothing"
        print -- "  --aggressive  also clear slow-to-rebuild caches"
        return 0 ;;
      *)
        print -u2 "reclaim_disk: unknown option '$1' (try --help)"
        return 2 ;;
    esac
    shift
  done

  local -a targets
  targets=("${ZAMBELZ_RECLAIM_TARGETS[@]}")
  (( aggressive )) && targets+=("${ZAMBELZ_RECLAIM_AGGRESSIVE_TARGETS[@]}")

  local start
  start=$(_reclaim_free_bytes)
  print -- "reclaim_disk on $(uname -s) — free: $(_reclaim_human "$start")"
  [[ "$mode" != "run" ]] && print -- "(no changes will be made)"

  local -a present absent
  local row kind probe label action size

  print -- "\nTargets:"
  for row in "${targets[@]}"; do
    kind="${row%%|*}"; row="${row#*|}"
    probe="${row%%|*}"; row="${row#*|}"
    label="${row%%|*}"
    action="${row#*|}"

    if _reclaim_probe_ok "$kind" "$probe"; then
      size=$(_reclaim_size_of "$kind" "$probe")
      present+=("$label")
      case "$mode" in
        list) print -- "  present   ${label}  (${size})" ;;
        dry)  print -- "  would run ${label}: ${action}" ;;
        run)
          eval "$action" &> /dev/null
          print -- "  cleaned   ${label}  (was ${size})" ;;
      esac
    else
      absent+=("$label")
    fi
  done

  (( ${#absent} )) && print -- "  skipped   ${#absent} not installed: ${(j:, :)absent}"

  print -- "\nTemporary trees:"
  if [[ "$mode" == "run" ]]; then
    _reclaim_temp run
  else
    _reclaim_temp dry
  fi

  if [[ "$mode" == "run" ]]; then
    local end delta
    end=$(_reclaim_free_bytes)
    delta=$(( end - start ))
    print -- "\nfree after: $(_reclaim_human "$end")"
    if (( delta >= 0 )); then
      print -- "reclaimed:  $(_reclaim_human "$delta")"
    else
      print -- "reclaimed:  0 B (other writes occurred during the run)"
    fi
  fi

  _reclaim_report_held
}

alias reclaim-disk="reclaim_disk"
