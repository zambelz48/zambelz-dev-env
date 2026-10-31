# shellcheck shell=bash

_zc_scan_rc() {
  local name file number line trimmed
  for name in .zshrc .zprofile .zshenv .profile.zsh; do
    file="${ZC_HOME:?}/$name"
    if [ ! -f "$file" ]; then
      continue
    fi
    number=0
    while IFS= read -r line || [ -n "$line" ]; do
      number=$((number + 1))
      trimmed="${line#"${line%%[![:space:]]*}"}"
      case "$trimmed" in
        '#'*) continue ;;
        *"mise activate"*"--shims"*) ;;
        *"mise activate"*)
          zc_warn "$file:$number runs mise activate in hook mode" \
            "remove line $number from $file"
          ;;
        *"fnm env"* | *"pyenv init"* | *"rbenv init"* | *"jenv init"* | \
          *"gvm/scripts"* | *"version-managers.zsh"*)
          zc_warn "$file:$number loads a retired version manager" \
            "remove line $number from $file"
          ;;
        *) ;;
      esac
    done <"$file"
  done
}

_zc_shadowed() {
  local dir="$1" shims="$2" shim name names=""
  for shim in "$shims"/*; do
    name="${shim##*/}"
    if [ -f "$dir/$name" ] && [ -x "$dir/$name" ]; then
      names="$names $name"
    fi
  done
  printf '%s' "${names# }"
}

_zc_check_path() {
  local shims="$ZC_HOME/.local/share/mise/shims" output path_line entry
  local seen_shims=0 status=0 entries shadowed
  output="$(zsh -i -c 'print -r -- $PATH' 2>/dev/null)" || output=""
  path_line="${output##*$'\n'}"
  IFS=: read -r -a entries <<<"$path_line"
  for entry in "${entries[@]}"; do
    if [ "$entry" = "$shims" ]; then
      seen_shims=1
      break
    fi
    case "$entry" in
      "$ZC_HOME/.local/share/zconf/bin") ;;
      */.pyenv/* | */.rbenv/* | */.jenv/* | */.gvm/* | *fnm*)
        zc_error "$entry comes before the mise shims on PATH" \
          "zconf doctor (remove the retired manager lines it reports)"
        status=1
        ;;
      *)
        shadowed="$(_zc_shadowed "$entry" "$shims")"
        if [ -n "$shadowed" ]; then
          zc_error "$entry shadows mise shims: $shadowed" "zconf apply zsh"
          status=1
        fi
        ;;
    esac
  done
  if [ "$seen_shims" -eq 0 ]; then
    zc_error "mise shims are not on the interactive PATH" "zconf apply mise"
    return 1
  fi
  case ":$path_line:" in
    *":$ZC_HOME/.local/bin:"*) ;;
    *)
      zc_error "the mise command ($ZC_HOME/.local/bin) is not on PATH" \
        "zconf apply mise"
      status=1
      ;;
  esac
  if [ "$status" -eq 0 ]; then
    zc_ok "mise shims lead the tool locations on PATH"
  fi
  return "$status"
}

zc_doctor_core() {
  local status=0 os dir note
  os="$(zc_os)"
  if [ "$os" = "unsupported" ]; then
    zc_error "unsupported OS" "use macOS, Fedora or Ubuntu"
    status=1
  else
    zc_ok "os: $os"
  fi
  zc_github_token
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    zc_ok "GitHub token available"
  else
    zc_warn "no GitHub token (mise downloads may hit the API rate limit)" \
      "gh auth login"
  fi
  _zc_check_path || status=1
  _zc_scan_rc
  for dir in .pyenv .rbenv .jenv .gvm .local/share/fnm; do
    if [ -d "$ZC_HOME/$dir" ]; then
      note="(retired; remove it manually when ready)"
      zc_info "$ZC_HOME/$dir is present $note"
    fi
  done
  return "$status"
}

zc_doctor_perf() {
  local samples="" ms median="unknown" hooks sorted values
  for _ in 1 2 3 4 5; do
    ms="$(zsh -c 'zmodload zsh/datetime; s=$EPOCHREALTIME
zsh -i -c exit >/dev/null 2>&1
printf "%.0f\n" $(( (EPOCHREALTIME - s) * 1000 ))' 2>/dev/null)" || ms=""
    if [ -n "$ms" ]; then
      samples="$samples$ms"$'\n'
    fi
  done
  if [ -n "$samples" ]; then
    sorted="$(sort -n <<<"$samples")"
    values=()
    while IFS= read -r ms; do
      if [ -n "$ms" ]; then
        values+=("$ms")
      fi
    done <<<"$sorted"
    median="${values[$(((${#values[@]} - 1) / 2))]}"
  fi
  zc_info "zsh startup median $median ms (5 runs)"
  hooks="$(zsh -i -c 'print -r -- $precmd_functions $chpwd_functions' \
    2>/dev/null)" || hooks=""
  case "$hooks" in
    *_mise_hook*)
      zc_warn "mise prompt hooks are active (hook mode)" "zconf doctor"
      ;;
    *) zc_ok "no mise prompt hooks" ;;
  esac
}
