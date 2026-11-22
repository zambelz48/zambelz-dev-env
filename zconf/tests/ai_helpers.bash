ai_test_setup() {
  load helpers
  zc_test_setup

  REPO="$BATS_TEST_TMPDIR/repo"
  AI="$REPO/ai"
  export REPO AI

  mkdir -p "$AI/commands" "$AI/skills" "$AI/hooks"
  cp "$ZC_ROOT/ai/sync-ai.sh" "$ZC_ROOT/ai/hook.sh" "$AI/"
  cp -R "$ZC_ROOT/ai/lib" "$AI/lib"
  find "$AI/lib" -name __pycache__ -prune -exec rm -rf {} +
}

ai_stub_agents() {
  zc_stub claude 0 "2.1.330 (Claude Code)"
  zc_stub opencode 0 "opencode v2.2.7"
  zc_stub agy 0 "1.5.14"
}

ai_command() {
  local name="$1" description="$2" body="${3:-Run it.}"

  printf -- '---\ndescription: %s\n---\n\n%s\n' "$description" "$body" >"$AI/commands/$name.md"
}

ai_skill() {
  local name="$1" description="$2"

  mkdir -p "$AI/skills/$name"
  printf -- '---\nname: %s\ndescription: %s\n---\n\nDo it.\n' "$name" "$description" >"$AI/skills/$name/SKILL.md"
}

ai_payload() {
  local fixture="$1"
  shift

  "$MISE_DATA_DIR/shims/python3" -c '
import json
import sys

text = open(sys.argv[1]).read()
values = {"REPO": sys.argv[2]}

for pair in sys.argv[3:]:
    key, _, value = pair.partition("=")
    values[key] = value

for key, value in values.items():
    text = text.replace(f"@{key}@", json.dumps(value)[1:-1])

sys.stdout.write(text)
' "$ZC_ROOT/zconf/tests/fixtures/ai/$fixture" "$REPO" "$@"
}

ai_hook_module() {
  local module="$1" body="$2"

  printf '%s\n' "$body" >"$AI/hooks/$module.py"
}
