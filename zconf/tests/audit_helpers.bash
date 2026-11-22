audit_test_setup() {
  REAL_HOME="$HOME"
  REAL_PATH="$PATH"
  export REAL_HOME REAL_PATH

  load helpers
  zc_test_setup

  REAL_ROOT="$ZC_ROOT"
  PY="$("$MISE_DATA_DIR/shims/python3" -c 'import sys; print(sys.executable)')"
  ENGINE="$REAL_ROOT/zconf/lib/audit"
  REPO="$BATS_TEST_TMPDIR/repo"
  export REAL_ROOT PY ENGINE REPO

  mkdir -p "$REPO/zconf/lib" "$REPO/zconf/audit" "$REPO/packages/zconf" "$REPO/mise" "$REPO/neovim/lua" \
    "$REPO/tmux/zconf" "$REPO/zsh/zconf" "$REPO/tools/npm" "$REPO/tools/python"
  cp "$REAL_ROOT/zconf/lib/os.sh" "$REPO/zconf/lib/"
  cp "$REAL_ROOT/packages/zconf/managers" "$REPO/packages/zconf/"
}

audit_fixture_repo() {
  cat >"$REPO/mise/mise.toml" <<'EOF'
min_version = "2026.11.4"

[tools]
node = ["24.22.1", "22.23.4"]
neovim = "0.12.6"
EOF
  cat >"$REPO/mise/mise.lock" <<'EOF'
lockfile_version = 3

[[tools.node]]
version = "24.22.1"
backend = "core:node"

[tools.node."platforms.linux-x64"]
url = "https://example.invalid/node-24-linux"

[[tools.node]]
version = "24.22.1"
backend = "core:node"

[tools.node."platforms.macos-arm64"]
url = "https://example.invalid/node-24-macos"

[[tools.node]]
version = "22.23.4"
backend = "core:node"

[[tools.neovim]]
version = "0.12.6"
backend = "aqua:neovim/neovim"
EOF
  printf 'lockfileVersion: 9\n' >"$REPO/tools/npm/pnpm-lock.yaml"
  printf 'version = 1\n' >"$REPO/tools/python/uv.lock"
  cat >"$REPO/neovim/lazy-lock.json" <<'EOF'
{
  "lazy.nvim": {
    "branch": "main",
    "commit": "1111111111111111111111111111111111111111"
  },
  "nvim-treesitter": {
    "branch": "main",
    "commit": "2222222222222222222222222222222222222222"
  }
}
EOF
  cat >"$REPO/neovim/lua/treesitter_parsers.lua" <<'EOF'
return {
  'bash',
  'jsx',
}
EOF
  printf 'tmux-plugins/tpm\t3333333333333333333333333333333333333333\n' >"$REPO/tmux/zconf/pins"
  printf 'OHMYZSH_URL=https://github.com/ohmyzsh/ohmyzsh.git\nOHMYZSH_COMMIT=4444444444444444444444444444444444444444\n' \
    >"$REPO/zsh/zconf/pins"
  cat >"$REPO/zconf/audit/catalog.toml" <<'EOF'
[mise-tool.neovim]
repo = "neovim/neovim"

[nvim-plugin.nvim-treesitter]
repo = "nvim-treesitter/nvim-treesitter"
EOF
  cat >"$BATS_TEST_TMPDIR/parsers.lua" <<'EOF'
return {
  bash = {
    install_info = {
      revision = 'aaaa000000000000000000000000000000000000',
      url = 'https://github.com/tree-sitter/tree-sitter-bash',
    },
    tier = 2,
  },
  jsx = {
    readme_note = 'queries required by javascript, tsx',
    tier = 2,
  },
}
EOF
  cat >"$BATS_TEST_TMPDIR/deps.txt" <<'EOF'
LIBUV_URL https://github.com/libuv/libuv/archive/v1.52.1.tar.gz
LIBUV_SHA256 0000
LUAJIT_URL https://github.com/luajit/luajit/archive/fbb36bb6bfa88716a47c58bcf9ce9f2ef752abac.tar.gz
LUA_URL https://www.lua.org/ftp/lua-5.1.5.tar.gz
LPEG_URL https://github.com/neovim/deps/raw/d495ee6f79e7962a53ad79670cb92488abe0b9b4/opt/lpeg-1.1.0.tar.gz
WIN32YANK_X86_64_URL https://github.com/equalsraf/win32yank/releases/download/v0.1.1/win32yank-x64.zip
NEWDEP_URL https://github.com/example/newdep/archive/v9.9.9.tar.gz
EOF
  zc_stub_script gh <<EOF
case "\$*" in
  *parsers.lua*)
    cat "$BATS_TEST_TMPDIR/parsers.lua"
    ;;
  *deps.txt*)
    cat "$BATS_TEST_TMPDIR/deps.txt"
    ;;
  *)
    exit 1
    ;;
esac
EOF

  git -C "$REPO" init -q
  printf '[submodule "zsh/.plugins/evalcache"]\n\tpath = zsh/.plugins/evalcache\n\turl = https://github.com/mroth/evalcache\n' \
    >"$REPO/.gitmodules"
  git -C "$REPO" update-index --add --cacheinfo 160000,5555555555555555555555555555555555555555,zsh/.plugins/evalcache
  git -C "$REPO" -c user.email=t@example.invalid -c user.name=t commit -q -m fixture
}

audit_engine() {
  ZC_ROOT="$REPO" "$PY" -E -s "$ENGINE" "$@"
}
