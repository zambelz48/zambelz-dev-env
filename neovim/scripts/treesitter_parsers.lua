local mode, plugin_dir = arg[1], arg[2]
local TIMEOUT = 1800000

if (mode ~= 'check' and mode ~= 'sync') or not plugin_dir then
  error('usage: nvim -l treesitter_parsers.lua check|sync <nvim-treesitter>')
end

local script = debug.getinfo(1, 'S').source:sub(2)
local neovim_dir = vim.fn.fnamemodify(script, ':p:h:h')
vim.opt.rtp:prepend(plugin_dir)

local ts = require('nvim-treesitter')
local config = require('nvim-treesitter.config')
local install = require('nvim-treesitter.install')
local declared = dofile(neovim_dir .. '/lua/treesitter_parsers.lua')

local function emit(...)
  io.stdout:write(table.concat({ ... }, '\t'), '\n')
end

local function read(path)
  local file = io.open(path, 'r')
  if not file then
    return nil
  end
  local content = file:read('*a')
  file:close()
  return content
end

local function state(lang)
  local parsers = require('nvim-treesitter.parsers')
  local info = parsers[lang] and parsers[lang].install_info
  if info and info.revision then
    local dir = config.get_install_dir('parser-info')
    local have = read(vim.fs.joinpath(dir, lang .. '.revision'))
    if have == nil or have == '' then
      have = 'none'
    end
    return have, info.revision
  end
  local queries = vim.fs.joinpath(config.get_install_dir('queries'), lang)
  local source = install.get_package_path('runtime', 'queries', lang)
  if vim.uv.fs_realpath(queries) == vim.uv.fs_realpath(source) then
    return 'queries', 'queries'
  end
  return 'stale-queries', 'queries'
end

local function installed()
  return config.norm_languages('all', { missing = true, unsupported = true })
end

local function check()
  local present = {}
  local count = 0
  local langs = installed()
  table.sort(langs)
  for _, lang in ipairs(langs) do
    present[lang] = true
    count = count + 1
    local have, want = state(lang)
    if have ~= want then
      emit('outdated', lang, have, want)
    end
  end
  local wanted = config.norm_languages(declared, { unsupported = true })
  table.sort(wanted)
  for _, lang in ipairs(wanted) do
    if not present[lang] then
      emit('missing', lang)
    end
  end
  emit('checked', tostring(count))
end

local function snapshot()
  local revisions = {}
  for _, lang in ipairs(installed()) do
    revisions[lang] = (state(lang))
  end
  return revisions
end

local function wait(name, task)
  local ok, err = task:pwait(TIMEOUT)
  if not ok then
    emit('failed', name, (tostring(err):gsub('\n.*', '')))
  end
end

local function sync()
  local before = snapshot()
  wait('install', ts.install(declared))
  wait('update', ts.update())
  local after = snapshot()
  local langs = vim.tbl_keys(after)
  table.sort(langs)
  for _, lang in ipairs(langs) do
    if before[lang] == nil then
      emit('installed', lang)
    elseif before[lang] ~= after[lang] then
      emit('updated', lang)
    end
  end
  check()
end

if mode == 'check' then
  check()
else
  sync()
end
