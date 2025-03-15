#!/usr/bin/env bash

# Export mermaid as png
function mermaid_export {
  if ! command -v mmdc &> /dev/null; then
    echo "Command 'mmdc' not found. please install it first: https://github.com/mermaid-js/mermaid-cli?tab=readme-ov-file#installation"
    return 1
  fi

  local file="$1"
  if [ ! -f "$file" ]; then
    echo "File $file does not exist"
    return 1
  fi

  local output="$(echo "$file" | cut -f 1 -d '.').png"

  mmdc -i "$file" -o "$output" -s 6
}

# Measure zsh startup time
function measure_zsh_time {
  for i in $(seq 1 10); do
    /usr/bin/time $SHELL -i -c exit;
  done
}

# Use copilot in neovim
function use_copilot {
    export CODING_ASSISTANT="copilot"
}

# Use codeium in neovim
function use_codeium {
    export CODING_ASSISTANT="codeium"
}

function tmux_clear_sessions {
  local tmux_tmp_dir="$ZAMBELZ_DEV_ENV_PATH/tmux/.tmp"
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

  local sessions=()
  while IFS= read -r line; do
    sessions+=("$line")
  done < "$tmux_sessions_file_path"

  for session in "${sessions[@]}"; do
    local total_panes=$(echo "$(($(tmux list-windows -t "$session" | cut -d: -f1 | wc -l) - 1))")
    for i in $(seq 0 $total_panes); do
      tmux send-keys -t "$session:$i" C-c Enter C-l
    done
  done
}
