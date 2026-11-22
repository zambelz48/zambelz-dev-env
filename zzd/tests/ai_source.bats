#!/usr/bin/env bats

setup() {
  load ai_helpers
  ai_test_setup
}

@test "sync-ai loads a valid source" {
  ai_command check "Run the checks"
  ai_skill run-checks "Run every check"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: source: 1 commands, 1 skills, 0 MCP servers, 0 hooks"* ]]
}

@test "the repository's own source loads and renders for every agent" {
  ai_stub_agents
  rm -rf "$AI/commands" "$AI/skills" "$AI/hooks"
  cp -R "$ZC_ROOT/ai/commands" "$ZC_ROOT/ai/skills" "$ZC_ROOT/ai/hooks" "$ZC_ROOT/ai/mcp.json" "$AI/"

  run "$AI/sync-ai.sh" all

  [ "$status" -eq 0 ]
  [[ "$output" == *"OK: source: 5 commands, 4 skills, 1 MCP servers, 2 hooks"* ]]
  [[ "$output" != *"ERROR"* ]]
}

@test "sync-ai needs an agent" {
  run "$AI/sync-ai.sh"

  [ "$status" -eq 2 ]
  [[ "$output" == *"ERROR: name at least one agent"* ]]
  [[ "$output" == *"usage: ai/sync-ai.sh"* ]]
}

@test "sync-ai rejects an unknown agent" {
  run "$AI/sync-ai.sh" claude cursor

  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown agent or option: cursor"* ]]
}

@test "sync-ai rejects an option after an agent" {
  run "$AI/sync-ai.sh" claude --check

  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown agent or option: --check"* ]]
}

@test "sync-ai --check needs an agent" {
  run "$AI/sync-ai.sh" --check

  [ "$status" -eq 2 ]
}

@test "a command needs a description" {
  printf -- '---\nargument-hint: x\n---\n\nRun it.\n' >"$AI/commands/check.md"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"check.md: 'description' is required"* ]]
}

@test "a command rejects unknown frontmatter keys" {
  printf -- '---\ndescription: x\nagent: plan\n---\n\nRun it.\n' >"$AI/commands/check.md"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown frontmatter keys: agent"* ]]
}

@test "unclosed frontmatter names the file" {
  printf -- '---\ndescription: x\n\nRun it.\n' >"$AI/commands/check.md"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"check.md:3: expected 'key: value'"* ]]
}

@test "frontmatter must open on the first line" {
  printf -- 'Run it.\n' >"$AI/commands/check.md"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"check.md:1: expected '---'"* ]]
}

@test "frontmatter accepts quoted values and CRLF line endings" {
  printf -- '---\r\ndescription: "Runs checks: all of them"\r\n---\r\n\r\nRun it.\r\n' >"$AI/commands/check.md"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 0 ]
}

@test "frontmatter rejects a duplicate key" {
  printf -- '---\ndescription: a\ndescription: b\n---\n' >"$AI/commands/check.md"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"duplicate key 'description'"* ]]
}

@test "a skill name must equal its folder" {
  ai_skill fix-cve "Fix a CVE"
  printf -- '---\nname: other\ndescription: x\n---\n' >"$AI/skills/fix-cve/SKILL.md"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"'name' must equal the folder name 'fix-cve'"* ]]
}

@test "a skill name must be lowercase kebab case" {
  ai_skill Fix_Cve "Fix a CVE"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"name 'Fix_Cve' must match"* ]]
}

@test "a skill folder needs SKILL.md" {
  mkdir -p "$AI/skills/empty"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"empty: missing SKILL.md"* ]]
}

@test "a skill description has a length limit" {
  long="$(printf 'x%.0s' $(seq 1 1025))"
  ai_skill big "$long"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"longer than 1024 characters"* ]]
}

@test "a command may share its name with a skill" {
  ai_command audit "Audit"
  ai_skill audit "Audit"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 0 ]
}

@test "mcp.json must be valid JSON" {
  printf '{\n' >"$AI/mcp.json"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"mcp.json: invalid JSON"* ]]
}

@test "an http server needs a url and a known type" {
  cat >"$AI/mcp.json" <<'EOF'
{
  "mcpServers": {
    "docs": {
      "type": "http"
    },
    "other": {
      "type": "sse",
      "url": "https://example.com"
    }
  }
}
EOF

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"http server 'docs' needs a 'url' string"* ]]
  [[ "$output" == *"server 'other' has type 'sse'"* ]]
}

@test "hooks.toml checks events, modules and names" {
  ai_hook_module guard 'def handle(event):
    return None'
  cat >"$AI/hooks/hooks.toml" <<'EOF'
[[hook]]
name = "guard"
module = "guard"
events = ["tool.during"]
summary = "Guards"

[[hook]]
name = "guard"
module = "missing"
events = ["tool.before"]
summary = "Guards"
EOF

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown event 'tool.during'"* ]]
  [[ "$output" == *"module 'missing' has no file"* ]]
  [[ "$output" == *"hook name 'guard' is used more than once"* ]]
}

@test "every source problem is reported at once" {
  printf -- '---\nargument-hint: x\n---\n' >"$AI/commands/a.md"
  printf -- '---\nargument-hint: x\n---\n' >"$AI/commands/b.md"

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"a.md: 'description' is required"* ]]
  [[ "$output" == *"b.md: 'description' is required"* ]]
  [[ "$output" == *"2 errors"* ]]
}

@test "hook.sh rejects an unknown agent or event" {
  run "$AI/hook.sh" claude execute.before

  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: ai/hook.sh <agent> <event>"* ]]
}

@test "sync-ai fails without python3" {
  MISE_DATA_DIR="$BATS_TEST_TMPDIR/no-mise"
  export MISE_DATA_DIR
  zc_hide_command python3

  run "$AI/sync-ai.sh" claude

  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: python3 is not installed by mise"* ]]
}

@test "hook.sh fails closed without python3" {
  MISE_DATA_DIR="$BATS_TEST_TMPDIR/no-mise"
  export MISE_DATA_DIR
  zc_hide_command python3

  run "$AI/hook.sh" claude PreToolUse

  [ "$status" -eq 2 ]
  [[ "$output" == *"no python 3.11 or newer is installed by mise"* ]]
}

@test "hook.sh runs from a python install when mise itself refuses to run" {
  MISE_DATA_DIR="$BATS_TEST_TMPDIR/mise-data"
  export MISE_DATA_DIR
  mkdir -p "$MISE_DATA_DIR/installs/python/3.99.0/bin" "$MISE_DATA_DIR/shims"
  ln -s "$(command -v python3)" "$MISE_DATA_DIR/installs/python/3.99.0/bin/python3"
  printf '#!/bin/sh\necho "mise ERROR mise version 2099.1.1 is required" >&2\nexit 1\n' >"$MISE_DATA_DIR/shims/python3"
  chmod +x "$MISE_DATA_DIR/shims/python3"

  run "$AI/hook.sh" claude PreToolUse <<<'{}'

  [[ "$output" != *"mise version 2099.1.1 is required"* ]]
  [[ "$output" != *"no python 3.11 or newer"* ]]
}
