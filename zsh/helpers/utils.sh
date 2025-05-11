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

# Use windsurf in neovim
function use_windsurf {
    export CODING_ASSISTANT="windsurf"
}
