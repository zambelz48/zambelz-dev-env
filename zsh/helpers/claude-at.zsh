#
# usage: claude-at <tmux-session> <window-title> <prompt> <at-time> [claude-session-id]
#
claude-at() {
  emulate -L zsh
  setopt no_unset pipe_fail

  if (( $# < 4 )); then
    print -u2 "usage: claude-at <tmux-session> <window-title> <prompt> <at-time> [claude-session-id]"
    return 64
  fi

  local session=$1 window=$2 prompt=$3 when=$4 sid=${5:-}
  local target="=${session}:=${window}"   # '=' forces exact match on both names

  tmux has-session -t "=${session}" 2>/dev/null \
    || { print -u2 "no tmux session: $session"; return 1 }
  tmux list-windows -t "=${session}" -F '#{window_name}' | grep -qxF -- "$window" \
    || { print -u2 "no window '$window' in session '$session'"; return 1 }

  local -a cmd
  if [[ -n $sid ]]; then
    cmd=(claude --resume "$sid" "$prompt")
  else
    cmd=(claude --continue "$prompt")
  fi
  local line=${(j: :)${(q)cmd[@]}}

  local job_dir=$HOME/.claude-at
  mkdir -p "$job_dir" || return 1
  local job
  job=$(mktemp "$job_dir/job.XXXXXX") || return 1
  {
    print -r -- '#!/usr/bin/env zsh'
    print -r -- "T=${(qq)target}"
    print -r -- "LINE=${(qq)line}"
    print -r -- 'tmux send-keys -t "$T" C-c'
    print -r -- 'tmux send-keys -t "$T" -l "$LINE"'
    print -r -- 'tmux send-keys -t "$T" Enter'
    print -r -- 'rm -f -- "$0"'
  } > "$job" || return 1
  chmod +x "$job"

  print -r -- "$job" | at "$when" 2>&1 | grep -v '^warning: commands will be executed'
  print -r -- "→ $target"
}
