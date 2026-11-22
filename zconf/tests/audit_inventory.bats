#!/usr/bin/env bats

setup() {
  load audit_helpers
  audit_test_setup
  audit_fixture_repo
}

@test "the declared inventory lists one of every pinned kind" {
  run audit_engine inventory --declared

  [ "$status" -eq 0 ]
  [[ "$output" == *$'declared\tmise-tool\tnode\t24.22.1'* ]]
  [[ "$output" == *$'declared\tmise-tool\tnode\t22.23.4'* ]]
  [[ "$output" == *$'declared\tmise-tool\tneovim\t0.12.6'* ]]
  [[ "$output" == *$'declared\tmise\tmise\t2026.11.4'* ]]
  [[ "$output" == *$'declared\tlockfile\ttools/npm/pnpm-lock.yaml'* ]]
  [[ "$output" == *$'declared\tlockfile\ttools/python/uv.lock'* ]]
  [[ "$output" == *$'declared\tnvim-plugin\tlazy.nvim\t1111111111111111111111111111111111111111'* ]]
  [[ "$output" == *$'declared\ttreesitter-parser\tbash\taaaa000000000000000000000000000000000000'* ]]
  [[ "$output" == *$'declared\ttmux-plugin\ttmux-plugins/tpm\t3333333333333333333333333333333333333333'* ]]
  [[ "$output" == *$'declared\toh-my-zsh\toh-my-zsh\t4444444444444444444444444444444444444444'* ]]
  [[ "$output" == *$'declared\tsubmodule\tzsh/.plugins/evalcache\t5555555555555555555555555555555555555555'* ]]
  [[ "$output" == *$'declared\tnvim-bundled\tlibuv\tv1.52.1'* ]]
  [[ "$output" == *$'declared\tnvim-bundled\tlpeg\t1.1.0'* ]]
}

@test "a version pinned for several platforms is listed once" {
  run audit_engine inventory --declared

  [ "$(grep -c $'mise-tool\tnode\t24.22.1' <<<"$output")" = "1" ]
}

@test "a query-only tree-sitter entry is information, not a component" {
  run audit_engine inventory --declared

  [[ "$output" == *"INFO"*"tree-sitter 'jsx' is query files only"* ]]
  [[ "$output" != *$'treesitter-parser\tjsx'* ]]
}

@test "a listed parser missing from nvim-treesitter stops the inventory" {
  printf "return {\n  'bash',\n  'cobol',\n}\n" >"$REPO/neovim/lua/treesitter_parsers.lua"

  run audit_engine inventory --declared

  [ "$status" -eq 3 ]
  [[ "$output" == *"parser 'cobol' is not in nvim-treesitter"* ]]
}

@test "neovim dependencies the release does not ship are information; new ones are audited" {
  run audit_engine inventory --declared

  [[ "$output" == *"lists lua in cmake.deps/deps.txt but its release build does not ship it"* ]]
  [[ "$output" == *"lists win32yank_x86_64"*"Windows-only"* ]]
  [[ "$output" != *$'nvim-bundled\tlua\t'* ]]
  [[ "$output" == *$'nvim-bundled\tnewdep\tv9.9.9'* ]]
}

@test "a catalog without the repositories the inventory needs stops it" {
  printf '' >"$REPO/zconf/audit/catalog.toml"

  run audit_engine inventory --declared

  [ "$status" -eq 3 ]
  [[ "$output" == *"has no repository in the audit catalog"* ]]
}

@test "the inventory reads parser revisions from a local nvim-treesitter clone first" {
  local clone="$HOME/.local/share/nvim/lazy/nvim-treesitter" commit

  mkdir -p "$clone/lua/nvim-treesitter"
  git -C "$clone" init -q
  sed 's/aaaa0000/bbbb0000/' "$BATS_TEST_TMPDIR/parsers.lua" >"$clone/lua/nvim-treesitter/parsers.lua"
  git -C "$clone" add -A
  git -C "$clone" -c user.email=t@example.invalid -c user.name=t commit -q -m parsers
  commit="$(git -C "$clone" rev-parse HEAD)"
  printf '{\n  "nvim-treesitter": {\n    "branch": "main",\n    "commit": "%s"\n  }\n}\n' "$commit" \
    >"$REPO/neovim/lazy-lock.json"

  run audit_engine inventory --declared

  [[ "$output" == *$'treesitter-parser\tbash\tbbbb000000000000000000000000000000000000'* ]]
}

installed_fixture() {
  FAKE_MISE="$BATS_TEST_TMPDIR/mise-data"
  mkdir -p "$FAKE_MISE/installs/node/24.22.1" "$FAKE_MISE/installs/node/20.0.0" "$FAKE_MISE/installs/go/1.26.4/src" \
    "$FAKE_MISE/installs/go/1.25.0" "$FAKE_MISE/installs/npm-old/1.0.0"
  printf 'go 1.25\n' >"$FAKE_MISE/installs/go/1.26.4/src/go.mod"
  mkdir -p "$HOME/.local/state/mise/tracked-configs"
  ln -s "$FAKE_MISE/installs/go/1.26.4/src/go.mod" "$HOME/.local/state/mise/tracked-configs/abc"
  ln -s "$REPO/mise/mise.toml" "$HOME/.local/state/mise/tracked-configs/def"
  cat >"$BATS_TEST_TMPDIR/installed.json" <<EOF
{
  "node": [
    {
      "version": "24.22.1",
      "install_path": "$FAKE_MISE/installs/node/24.22.1"
    },
    {
      "version": "20.0.0",
      "install_path": "$FAKE_MISE/installs/node/20.0.0"
    }
  ],
  "go": [
    {
      "version": "1.25.0",
      "install_path": "$FAKE_MISE/installs/go/1.25.0"
    }
  ],
  "npm:old": [
    {
      "version": "1.0.0",
      "install_path": "$FAKE_MISE/installs/npm-old/1.0.0"
    }
  ]
}
EOF
  cat >"$BATS_TEST_TMPDIR/prunable.json" <<EOF
{
  "npm:old": [
    {
      "version": "1.0.0",
      "install_path": "$FAKE_MISE/installs/npm-old/1.0.0"
    }
  ]
}
EOF
  zc_stub_script mise <<EOF
case "\$*" in
  *--prunable*)
    cat "$BATS_TEST_TMPDIR/prunable.json"
    ;;
  *--installed*)
    cat "$BATS_TEST_TMPDIR/installed.json"
    ;;
  *)
    exit 1
    ;;
esac
EOF
  ZC_OS_RELEASE="$BATS_TEST_TMPDIR/os-release"
  printf 'ID=fedora\n' >"$ZC_OS_RELEASE"
  printf 'git\nmissing-pkg\n# comment\n\n' >"$REPO/packages/dnf.txt"
  zc_stub uname 0 "Linux"
  zc_stub_script rpm <<'EOF'
case "$*" in
  *git)
    printf '(none):2.56.1-1.fc45'
    ;;
  *)
    printf 'package %s is not installed\n' "${*: -1}"
    exit 1
    ;;
esac
EOF
  export FAKE_MISE ZC_OS_RELEASE
}

@test "the installed inventory classifies unpinned installs" {
  installed_fixture

  MISE_DATA_DIR="$FAKE_MISE" run audit_engine inventory --installed

  [ "$status" -eq 0 ]
  [[ "$output" == *$'installed\tinstall\tnode\t24.22.1'* ]]
  [[ "$output" == *"LEFTOVER"*"install:npm:old@1.0.0: installed but nothing selects it"* ]]
  [[ "$output" == *"INFO"*"install:node@20.0.0: not pinned by this repository; kept by another tracked mise config"* ]]
  [[ "$output" != *"install:node@24.22.1: not pinned"* ]]
}

@test "tracked configs inside tool installs are leftovers, grouped per install" {
  installed_fixture

  MISE_DATA_DIR="$FAKE_MISE" run audit_engine inventory --installed

  [[ "$output" == *"LEFTOVER"*"mise tracks 1 files inside the go/1.26.4 install as configs"* ]]
  [ "$(grep -c "mise tracks" <<<"$output")" = "1" ]
}

@test "the installed inventory lists OS packages through zconf's own OS detection" {
  installed_fixture

  MISE_DATA_DIR="$FAKE_MISE" run audit_engine inventory --installed

  [[ "$output" == *$'installed\tos-package\tgit\t2.56.1-1.fc45'* ]]
  [[ "$output" == *"INFO"*"dnf package missing-pkg is listed but not installed on this machine"* ]]
}

@test "an unsupported OS stops the installed inventory" {
  installed_fixture
  printf 'ID=arch\n' >"$ZC_OS_RELEASE"

  MISE_DATA_DIR="$FAKE_MISE" run audit_engine inventory --installed

  [ "$status" -eq 3 ]
  [[ "$output" == *"not supported by zconf"* ]]
}

@test "the inventory command rejects unknown arguments" {
  run audit_engine inventory --everything

  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: audit inventory"* ]]
}
