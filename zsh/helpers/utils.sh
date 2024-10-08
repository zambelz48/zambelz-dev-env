#!/usr/bin/env bash

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

function measure_zsh_time {
  for i in $(seq 1 10); do
    /usr/bin/time $SHELL -i -c exit;
  done
}
