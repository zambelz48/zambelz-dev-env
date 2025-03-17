#!/usr/bin/env bash

function tmux_nvim_process {
  local target_session="$1"
  local pane_pid=$(tmux list-panes -t "$target_session" -F "#{pane_pid}" | head -1)
  local nvim_process=$(ps -ef | grep "$pane_pid" | grep nvim)

  echo "$nvim_process"
}

function tmux_generate_sessions_file_path {
  local tmux_tmp_dir="$HOME/.tmux/.tmp"
  if [ ! -d "$tmux_tmp_dir" ]; then
    mkdir -p "$tmux_tmp_dir"
  fi

  local tmux_sessions_file_path="$tmux_tmp_dir/tmux_sessions"
  if [ -f "$tmux_sessions_file_path" ]; then
    rm -rf "$tmux_sessions_file_path"
  fi

  tmux list-sessions -F "#{session_name}" >> "$tmux_sessions_file_path"

  if [ ! -f "$tmux_sessions_file_path" ]; then
    echo "tmux sessions file not found"
    return 1
  fi

  echo "$tmux_sessions_file_path"
}

function tmux_clear_sessions {
  local tmux_sessions_file_path=$(tmux_generate_sessions_file_path)
  local sessions=()
  while IFS= read -r line; do
    sessions+=("$line")
  done < "$tmux_sessions_file_path"

  for session in "${sessions[@]}"; do
    local total_panes=$(echo "$(($(tmux list-windows -t "$session" | cut -d: -f1 | wc -l) - 1))")
    for i in $(seq 0 $total_panes); do
      local nvim_process=$(tmux_nvim_process "$session:$i")
      if [ -z "$nvim_process" ]; then
        tmux send-keys -t "$session:$i" C-c Enter C-l
      fi
    done
  done
}

function tmux_update_shell {
  local tmux_sessions_file_path=$(tmux_generate_sessions_file_path)
  local sessions=()
  while IFS= read -r line; do
    sessions+=("$line")
  done < "$tmux_sessions_file_path"

  for session in "${sessions[@]}"; do
    local total_panes=$(echo "$(($(tmux list-windows -t "$session" | cut -d: -f1 | wc -l) - 1))")
    for i in $(seq 0 $total_panes); do
      local nvim_process=$(tmux_nvim_process "$session:$i")
      if [ -z "$nvim_process" ]; then
        tmux send-keys -t "$session:$i" C-c Enter C-l "exec $SHELL" Enter C-l
      fi
    done
  done
}
