#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  NVIM_BIN="$("$ZC_REAL_MISE" which nvim)"
  R="$BATS_TEST_TMPDIR/repo/neovim"
  mkdir -p "$R/scripts" "$R/lua"
  cp "$ZC_ROOT/neovim/scripts/treesitter_parsers.lua" "$R/scripts/"
  printf "return { 'lua', 'tsx' }\n" >"$R/lua/treesitter_parsers.lua"
  PLUGIN="$BATS_TEST_TMPDIR/nvim-treesitter"
  SITE="$BATS_TEST_TMPDIR/site"
  export FAKE_TS_SITE="$SITE"
  fake_plugin
}

fake_plugin() {
  local dir="$PLUGIN/lua/nvim-treesitter"
  mkdir -p "$dir" "$PLUGIN/runtime/queries/jsx"
  cat >"$dir/parsers.lua" <<'EOF'
return {
  lua = { install_info = { revision = 'lua-2' } },
  tsx = { install_info = { revision = 'tsx-1' }, requires = { 'jsx' } },
  jsx = {},
}
EOF
  cat >"$dir/install.lua" <<'EOF'
local M = {}
function M.get_package_path(...)
  local plugin = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2),
    ':p:h:h:h')
  return vim.fs.joinpath(plugin, ...)
end
return M
EOF
  cat >"$dir/config.lua" <<'EOF'
local M = {}
function M.get_install_dir(name)
  local dir = vim.fs.joinpath(vim.env.FAKE_TS_SITE, name)
  vim.fn.mkdir(dir, 'p')
  return dir
end
function M.get_installed()
  local seen = {}
  for name in vim.fs.dir(M.get_install_dir('parser')) do
    seen[(name:gsub('%.so$', ''))] = true
  end
  for name in vim.fs.dir(M.get_install_dir('queries')) do
    seen[name] = true
  end
  return vim.tbl_keys(seen)
end
function M.norm_languages(languages, skip)
  if languages == 'all' and skip and skip.missing then
    return M.get_installed()
  end
  local parsers = require('nvim-treesitter.parsers')
  local out = {}
  for _, lang in ipairs(languages) do
    table.insert(out, lang)
    vim.list_extend(out, parsers[lang].requires or {})
  end
  return out
end
return M
EOF
  cat >"$dir/init.lua" <<'EOF'
local config = require('nvim-treesitter.config')
local install = require('nvim-treesitter.install')
local M = {}
local function task(name, fn)
  return {
    pwait = function()
      if vim.env.FAKE_TS_FAIL == name then
        return false, 'boom\nstack traceback'
      end
      fn()
      return true, true
    end,
  }
end
local function put(lang)
  local info = require('nvim-treesitter.parsers')[lang].install_info
  if info then
    vim.fn.writefile({}, config.get_install_dir('parser') .. '/' .. lang ..
      '.so')
    local rev = config.get_install_dir('parser-info') .. '/' .. lang ..
      '.revision'
    local file = assert(io.open(rev, 'w'))
    file:write(info.revision)
    file:close()
  else
    vim.uv.fs_symlink(install.get_package_path('runtime', 'queries', lang),
      config.get_install_dir('queries') .. '/' .. lang)
  end
end
function M.install(languages)
  return task('install', function()
    local have = config.get_installed()
    for _, lang in ipairs(config.norm_languages(languages, {})) do
      if not vim.list_contains(have, lang) then
        put(lang)
      end
    end
  end)
end
function M.update()
  return task('update', function()
    for _, lang in ipairs(config.get_installed()) do
      local info = require('nvim-treesitter.parsers')[lang].install_info
      local rev = config.get_install_dir('parser-info') .. '/' .. lang ..
        '.revision'
      if info and vim.fn.readfile(rev)[1] ~= info.revision then
        put(lang)
      end
    end
  end)
end
return M
EOF
}

parsers() {
  run "$NVIM_BIN" -l "$R/scripts/treesitter_parsers.lua" "$1" "$PLUGIN"
}

@test "check lists declared parsers and their requirements as missing" {
  parsers check
  [ "$status" -eq 0 ]
  expected="$(printf 'missing\tjsx\nmissing\tlua\nmissing\ttsx\nchecked\t0')"
  [ "$output" = "$expected" ]
}

@test "sync installs what is missing and then checks clean" {
  parsers sync
  [ "$status" -eq 0 ]
  expected="$(printf 'installed\tjsx\ninstalled\tlua\ninstalled\ttsx')"
  [ "$output" = "$expected"$'\n'"$(printf 'checked\t3')" ]
  parsers check
  [ "$output" = "$(printf 'checked\t3')" ]
}

@test "check reports a parser older than nvim-treesitter's revision" {
  parsers sync
  printf 'lua-1' >"$SITE/parser-info/lua.revision"
  parsers check
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'outdated\tlua\tlua-1\tlua-2\nchecked\t3')" ]
}

@test "sync updates only the outdated parser" {
  parsers sync
  printf 'lua-1' >"$SITE/parser-info/lua.revision"
  parsers sync
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'updated\tlua\nchecked\t3')" ]
}

@test "a parser without a recorded revision is outdated" {
  parsers sync
  rm "$SITE/parser-info/tsx.revision"
  parsers check
  [ "${lines[0]}" = "$(printf 'outdated\ttsx\tnone\ttsx-1')" ]
}

@test "queries linked somewhere else are out of date" {
  parsers sync
  rm "$SITE/queries/jsx"
  mkdir -p "$BATS_TEST_TMPDIR/old-queries"
  ln -s "$BATS_TEST_TMPDIR/old-queries" "$SITE/queries/jsx"
  parsers check
  [ "${lines[0]}" = "$(printf 'outdated\tjsx\tstale-queries\tqueries')" ]
}

@test "a task that does not finish is reported by its first line" {
  FAKE_TS_FAIL=install parsers sync
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$(printf 'failed\tinstall\tboom')" ]
  zc_contains "$output" "$(printf 'missing\tlua')"
}

@test "the parser list comes from the repository, not the runtimepath" {
  mkdir -p "$HOME/.config/nvim/lua"
  printf "return { 'decoy' }\n" >"$HOME/.config/nvim/lua/treesitter_parsers.lua"
  parsers check
  [ "$status" -eq 0 ]
  [[ "$output" != *"decoy"* ]] || false
  zc_contains "$output" "$(printf 'missing\tlua')"
}

@test "an unknown mode is an error" {
  parsers frobnicate
  [ "$status" -ne 0 ]
  zc_contains "$output" "usage: nvim -l treesitter_parsers.lua check|sync"
}
