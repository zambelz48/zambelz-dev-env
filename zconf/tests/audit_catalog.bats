#!/usr/bin/env bats

setup() {
  load audit_helpers
  audit_test_setup
  audit_fixture_repo

  zc_stub_script mise <<'EOF'
printf '{}\n'
EOF
  ZC_OS_RELEASE="$BATS_TEST_TMPDIR/os-release"
  export ZC_OS_RELEASE
  printf 'ID=fedora\n' >"$ZC_OS_RELEASE"
  printf '' >"$REPO/packages/dnf.txt"
  zc_stub uname 0 "Linux"

  cat >"$REPO/zconf/audit/catalog.toml" <<'EOF'
[mise.mise]
repo = "jdx/mise"

[mise-tool.node]
repo = "nodejs/node"
cpe = ["cpe:2.3:a:nodejs:node.js"]
feeds = ["node"]

[mise-tool.neovim]
repo = "neovim/neovim"

[nvim-plugin."lazy.nvim"]
repo = "folke/lazy.nvim"

[nvim-plugin.nvim-treesitter]
repo = "nvim-treesitter/nvim-treesitter"

[oh-my-zsh.oh-my-zsh]
repo = "ohmyzsh/ohmyzsh"

[nvim-bundled.lpeg]
repo = "neovim/neovim"
shipped_by = "neovim"
EOF
}

sources() {
  ZC_ROOT="$REPO" "$PY" -E -s -c '
import json, sys
sys.path.insert(0, sys.argv[1])
from catalog import Catalog, sources_for
from model import Component, Kind, Scope
catalog = Catalog(__import__("pathlib").Path(sys.argv[2]))
component = Component(Kind(sys.argv[3]), sys.argv[4], sys.argv[5], "test", Scope.DECLARED, {})
for source in sources_for(catalog, component):
    print(source.kind, json.dumps(source.params, sort_keys=True))
' "$ENGINE" "$REPO/zconf/audit/catalog.toml" "$@"
}

@test "every component of the fixture is covered" {
  run audit_engine catalog

  [ "$status" -eq 0 ]
  [[ "$output" == *"0 not covered, 0 problems, 0 unused"* ]]
}

@test "a component without a catalog entry is not covered" {
  printf '[mise-tool.neovim]\nrepo = "neovim/neovim"\n\n[nvim-plugin.nvim-treesitter]\nrepo = "nvim-treesitter/nvim-treesitter"\n' \
    >"$REPO/zconf/audit/catalog.toml"

  run audit_engine catalog

  [ "$status" -eq 1 ]
  [[ "$output" == *"NOT COVERED: mise-tool:node@24.22.1 (mise/mise.lock): no source in catalog.toml"* ]]
  [[ "$output" == *"NOT COVERED: mise:mise@2026.11.4"* ]]
}

@test "an unknown key in the catalog is an error" {
  printf '\n[mise-tool.extra]\nrepo = "x/y"\nseverity = "high"\n' >>"$REPO/zconf/audit/catalog.toml"

  run audit_engine catalog

  [ "$status" -eq 1 ]
  [[ "$output" == *"[mise-tool.extra] has unknown keys: severity"* ]]
}

@test "an unused catalog entry is reported" {
  printf '\n[mise-tool.removed-tool]\nrepo = "x/y"\n' >>"$REPO/zconf/audit/catalog.toml"

  run audit_engine catalog

  [[ "$output" == *"WARN: unused catalog entry [mise-tool.removed-tool]"* ]]
}

@test "an entry for another platform's package manager is not reported as unused" {
  printf '\n[os-package."brew:tmux"]\nrepo = "tmux/tmux"\n' >>"$REPO/zconf/audit/catalog.toml"

  run audit_engine catalog

  [[ "$output" != *"brew:tmux"* ]]
}

@test "a mise tool's sources follow its catalog entry" {
  run sources mise-tool node 24.22.1

  [[ "$output" == *'github-advisories {"repo": "nodejs/node", "version": "24.22.1"}'* ]]
  [[ "$output" == *'nvd {"cpe": "cpe:2.3:a:nodejs:node.js", "version": "24.22.1"}'* ]]
  [[ "$output" == *'feed {"name": "node", "version": "24.22.1"}'* ]]
}

@test "the upstream tag template and version pattern are applied" {
  cat >>"$REPO/zconf/audit/catalog.toml" <<'EOF'

[mise-tool.biome]
repo = "biomejs/biome"
upstream_tag = "@biomejs/biome@{version}"
upstream_files = ["Cargo.lock"]

[mise-tool.java]
cpe = ["cpe:2.3:a:oracle:openjdk"]
version_pattern = '^temurin-([0-9]+\.[0-9]+\.[0-9]+)'
EOF

  run sources mise-tool biome 2.6.3

  [[ "$output" == *'upstream-files {"paths": ["Cargo.lock"], "repo": "biomejs/biome", "tag": "@biomejs/biome@2.6.3"}'* ]]

  run sources mise-tool java "temurin-17.0.20+8"

  [[ "$output" == *'nvd {"cpe": "cpe:2.3:a:oracle:openjdk", "version": "17.0.20"}'* ]]
}

@test "commit-pinned components are checked by repository and commit" {
  run sources nvim-plugin lazy.nvim 1111111111111111111111111111111111111111

  [[ "$output" == *'github-advisories {"commit": "1111111111111111111111111111111111111111", "repo": "folke/lazy.nvim"}'* ]]
  [[ "$output" == *'osv-commit {"commit": "1111111111111111111111111111111111111111"}'* ]]
}

@test "GitHub repositories are read from HTTPS and SSH URLs, including dotted names" {
  run "$PY" -E -s -c "
import sys
sys.path.insert(1, '$ENGINE')
from catalog import github_repo
for url in ('https://github.com/mroth/evalcache', 'git@github.com:dracula/zsh.git', 'ssh://git@github.com/a/b.git', 'https://github.com/catgoose/nvim-colorizer.lua', 'https://github.com/x/y.git/', 'https://gitlab.com/x/y'):
    print(github_repo(url))
"

  [ "$output" = $'mroth/evalcache\ndracula/zsh\na/b\ncatgoose/nvim-colorizer.lua\nx/y\nNone' ]
}

# bats test_tags=network
@test "the repository's own catalog verifies against the live services" {
  run env HOME="$REAL_HOME" PATH="$REAL_PATH" ZC_ROOT="$REAL_ROOT" "$PY" -E -s "$ENGINE" catalog --verify

  echo "$output"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 not covered, 0 problems"* ]]
}
