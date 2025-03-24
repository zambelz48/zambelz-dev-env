#!/usr/bin/env bash

TMUX_TMP_DIR="$HOME/.tmux/.tmp"

function tmux_nvim_process {
  local target_session="$1"
  local pane_pid=$(tmux list-panes -t "$target_session" -F "#{pane_pid}" | head -1)
  local nvim_process=$(ps -ef | grep "$pane_pid" | grep nvim)

  echo "$nvim_process"
}

function tmux_generate_sessions_file_path {
  if [ ! -d "$TMUX_TMP_DIR" ]; then
    mkdir -p "$TMUX_TMP_DIR"
  fi

  local tmux_sessions_file_path="$TMUX_TMP_DIR/tmux_sessions"
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

function tmux_quit_nvim {
  local tmux_sessions_file_path=$(tmux_generate_sessions_file_path)
  local sessions=()
  while IFS= read -r line; do
    sessions+=("$line")
  done < "$tmux_sessions_file_path"

  for session in "${sessions[@]}"; do
    local total_panes=$(echo "$(($(tmux list-windows -t "$session" | cut -d: -f1 | wc -l) - 1))")
    for i in $(seq 0 $total_panes); do
      local nvim_process=$(tmux_nvim_process "$session:$i")
      if [ ! -z "$nvim_process" ]; then
        tmux send-keys -t "$session:$i" :q! Enter C-l
      fi
    done
  done
}

function tmux_backup_sessions {
  tmux_quit_nvim

  local tmux_sessions_file_path=$(tmux_generate_sessions_file_path)
  local sessions=()
  while IFS= read -r line; do
    sessions+=("$line")
  done < "$tmux_sessions_file_path"

  local tmux_backup_sessions_file_path="$TMUX_TMP_DIR/backup_tmux_sessions"
  if [ -f "$tmux_backup_sessions_file_path" ]; then
    rm -rf "$tmux_backup_sessions_file_path"
  fi

  for session in "${sessions[@]}"; do
    local total_panes=$(echo "$(($(tmux list-windows -t "$session" | cut -d: -f1 | wc -l) - 1))")
    for i in $(seq 0 $total_panes); do
      tmux send-keys -t "$session:$i" C-c Enter C-l pwd Enter
      local session_path=$(tmux capture-pane -p -t "$session:$i" | sed -n '2p')
      echo "$session:$i=$session_path" >> "$tmux_backup_sessions_file_path"
    done
  done
}

function tmux_restore_sessions {
  local tmux_backup_sessions_file_path="$TMUX_TMP_DIR/backup_tmux_sessions"
  if [ ! -f "$tmux_backup_sessions_file_path" ]; then
    echo "tmux backup sessions file not found"
    return 1
  fi

  local sessions=()
  while IFS= read -r line; do
    sessions+=($line)
  done < "$tmux_backup_sessions_file_path"

  for session in "${sessions[@]}"; do
    local session_info=$(echo "$session" | cut -f 1 -d '=')
    local session_name=$(echo "$session_info" | cut -f 1 -d ':')
    local session_pane=$(echo "$session_info" | cut -f 2 -d ':')
    local session_path=$(echo "$session" | cut -f 2 -d '=')

    local target_session="$session_name:$session_pane"

    local nvim_process=$(tmux_nvim_process "$target_session")
    if [ -z "$nvim_process" ]; then
      tmux send-keys -t "$target_session" cd Space "$session_path" Enter C-l
    fi
  done
}
