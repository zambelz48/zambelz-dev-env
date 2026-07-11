-- Checks every neovim/lua/plugins/*.lua spec's pinned `tag`/`commit`/`branch`
-- against its upstream repo's latest tag / latest commit, via `git ls-remote`
-- (no GitHub API, no auth, no rate limits). Can also emit a machine-parseable
-- candidates file and apply selected updates back into the plugin files.
--
-- Usage (from anywhere):
--   nvim -l neovim/scripts/check_plugin_updates.lua                   -- show table
--   nvim -l neovim/scripts/check_plugin_updates.lua telescope         -- filter by repo-slug substring
--   nvim -l neovim/scripts/check_plugin_updates.lua --candidates-file PATH [filters...]
--       also writes tab-separated actionable rows (file, slug, kind, current, latest) to PATH
--   nvim -l neovim/scripts/check_plugin_updates.lua --apply
--       reads tab-separated rows from stdin and rewrites the corresponding tag/commit in-place
--
-- neovim/scripts/apply_plugin_updates.sh ties --candidates-file and --apply
-- together into an interactive fzf multi-select flow — that's the one you
-- actually want to run day-to-day (wired up as `zconf neovim check-updates`).

local vim = vim
local script_path = debug.getinfo(1, 'S').source:sub(2) -- strip leading '@'
local script_dir = vim.fn.fnamemodify(script_path, ':p:h')
local plugins_dir = vim.fn.fnamemodify(script_dir, ':h') .. '/lua/plugins'

-- Parse CLI args --------------------------------------------------------

local mode = 'pretty'
local candidates_file = nil
local filters = {}

do
  local raw = arg or {}
  local i = 1
  while i <= #raw do
    local a = raw[i]
    if a == '--candidates-file' then
      candidates_file = raw[i + 1]
      i = i + 2
    elseif a == '--apply' then
      mode = 'apply'
      i = i + 1
    else
      filters[#filters + 1] = a
      i = i + 1
    end
  end
end

local function matches_filter(slug)
  if #filters == 0 then
    return true
  end
  for _, f in ipairs(filters) do
    if slug:find(f, 1, true) then
      return true
    end
  end
  return false
end

-- Under `nvim -l`, Lua's built-in `print()` writes to stderr (it goes
-- through Neovim's message/echo machinery), not stdout — confirmed by
-- testing in isolation. Use this for anything meant to be real, pipeable
-- output (the table, --apply confirmations), so it actually lands on
-- stdout and doesn't collide with the stderr progress indicator below.
-- (Named `println`, not `out`, since `out` is already used elsewhere in
-- this file as a local variable name for shell/file output.)
local function println(s)
  io.stdout:write(s, '\n')
end

-- Shell / git helpers -----------------------------------------------------

local function shell(cmd)
  local ok, result = pcall(vim.fn.system, cmd)
  if not ok or vim.v.shell_error ~= 0 then
    return nil
  end
  return vim.trim(result)
end

local function repo_url(slug)
  return 'https://github.com/' .. slug .. '.git'
end

-- Resolve a tag name to the commit it ultimately points at: dereferences
-- annotated tags (the `^{}` peeled entry) so two tags that alias the same
-- release (e.g. nvim-tree.lua's `v1.18.0` and `nvim-tree-v1.18.0`) compare
-- as equal, instead of looking like an update just because the name differs.
local function resolve_tag_commit(slug, tag)
  local out = shell({ 'git', 'ls-remote', '--tags', repo_url(slug), 'refs/tags/' ..
  tag, 'refs/tags/' .. tag .. '^{}' })
  if not out or out == '' then
    return nil
  end
  local peeled = out:match('(%x+)\t[^\n]-%^{}')
  if peeled then
    return peeled
  end
  return out:match('^(%x+)')
end

-- Highest semver-looking tag (by git's version-aware sort) and the commit it
-- resolves to.
local function latest_tag(slug)
  local out = shell({ 'git', 'ls-remote', '--tags', '--refs', '--sort=-v:refname',
    repo_url(slug) })
  if not out or out == '' then
    return nil, nil
  end
  local first_line = out:match('^[^\n]+')
  local tag = first_line and first_line:match('refs/tags/(.+)$')
  if not tag then
    return nil, nil
  end
  return tag, resolve_tag_commit(slug, tag)
end

-- Latest commit sha on a given ref (branch name, or HEAD for the default branch).
local function latest_commit(slug, ref)
  local out = shell({ 'git', 'ls-remote', repo_url(slug), ref or 'HEAD' })
  if not out or out == '' then
    return nil
  end
  local sha = out:match('^(%x+)')
  return sha and sha:sub(1, 7) or nil
end

local function load_specs(file)
  local ok, spec = pcall(dofile, file)
  if not ok then
    io.stderr:write('  failed to load ' .. file .. ': ' .. tostring(spec) .. '\n')
    return {}
  end
  if type(spec[1]) == 'table' then
    return spec
  end
  return { spec }
end

-- Progress indicator (stderr, so it never mixes with the pretty table or
-- the --candidates-file output on stdout). Only meaningful when attached to
-- a terminal, but harmless (just extra bytes) when redirected/piped.
local function progress(i, total, slug)
  io.stderr:write(('\27[2K\rChecking [%d/%d] %s...'):format(i, total, slug))
  io.stderr:flush()
end

local function clear_progress()
  io.stderr:write('\27[2K\r')
  io.stderr:flush()
end

-- Collect one row per plugin spec, querying git once per plugin -----------

local function collect()
  local files = vim.fn.glob(plugins_dir .. '/*.lua', true, true)
  table.sort(files)

  -- First pass: gather every spec matching the filter (cheap, local-only —
  -- just dofile()'ing each plugin file), so we know the total count up
  -- front for the "[i/N]" progress counter before any network call starts.
  local entries = {}
  for _, file in ipairs(files) do
    for _, spec in ipairs(load_specs(file)) do
      local slug = spec[1]
      if type(slug) == 'string' and slug:match('^[^/]+/[^/]+$') and matches_filter(slug) then
        entries[#entries + 1] = { file = file, spec = spec, slug = slug }
      end
    end
  end

  -- Second pass: the actual `git ls-remote` network calls, one plugin at a
  -- time, reporting progress as each one starts.
  local rows = {}
  for i, entry in ipairs(entries) do
    progress(i, #entries, entry.slug)

    local spec, slug, file = entry.spec, entry.slug, entry.file
    local kind, current, latest, changed = 'unpinned', '-', '-', false

    if spec.tag then
      kind, current = 'tag', spec.tag
      local latest_tag_name, latest_commit_sha = latest_tag(slug)
      latest = latest_tag_name or '?'
      if latest_tag_name and latest_tag_name ~= current then
        local current_commit_sha = resolve_tag_commit(slug, current)
        changed = not current_commit_sha or not latest_commit_sha or
        current_commit_sha ~= latest_commit_sha
      end
    elseif spec.commit then
      kind, current = 'commit', spec.commit
      latest = latest_commit(slug, spec.branch) or '?'
      changed = latest ~= '?' and latest:sub(1, #current) ~= current
    elseif spec.branch then
      -- Branch pins float on their own; there's nothing pinned to "bump".
      kind, current = 'branch', spec.branch
      latest = latest_commit(slug, spec.branch) or '?'
    end

    rows[#rows + 1] = {
      file = file,
      slug = slug,
      kind = kind,
      current = current,
      latest = latest,
      changed = changed,
    }
  end
  clear_progress()

  return rows
end

-- Apply mode: read tab-separated rows from stdin, rewrite the pinned value --

local function apply_update(file, kind, current, new_value)
  local f = io.open(file, 'r')
  if not f then
    io.stderr:write('cannot open ' .. file .. '\n')
    return false
  end
  local content = f:read('*a')
  f:close()

  -- Escape every punctuation char in `current` so it's matched literally,
  -- not interpreted as a Lua pattern (tags/commits routinely contain `.`).
  local escaped_current = current:gsub('%p', '%%%1')
  local pattern = kind .. "%s*=%s*'" .. escaped_current .. "'"
  local replacement = kind .. " = '" .. new_value .. "'"
  local new_content, n = content:gsub(pattern, replacement, 1)

  if n == 0 then
    io.stderr:write(("could not find `%s = '%s'` in %s\n"):format(kind, current,
      file))
    return false
  end

  local out = io.open(file, 'w')
  if not out then
    io.stderr:write('cannot write ' .. file .. '\n')
    return false
  end
  out:write(new_content)
  out:close()
  return true
end

local function run_apply()
  local applied = 0
  for line in io.lines() do
    if line ~= '' then
      local file, slug, kind, current, latest = line:match(
      '^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$')
      if file and kind and current and latest then
        if apply_update(file, kind, current, latest) then
          println(('updated %s: %s %s -> %s'):format(slug, kind, current, latest))
          applied = applied + 1
        end
      else
        io.stderr:write('skipping unparseable line: ' .. line .. '\n')
      end
    end
  end
  println(('applied %d update(s)'):format(applied))
end

-- Pretty / candidates-file output -------------------------------------------

local function run_pretty(rows)
  local fmt = '%-42s %-8s %-18s %-18s %s'
  println(string.format(fmt, 'plugin', 'pin', 'current', 'latest', ''))
  println(string.rep('-', 100))

  for _, row in ipairs(rows) do
    local note = (row.kind == 'tag' and row.changed) and '<- update available' or
    ''
    println(string.format(fmt, row.slug, row.kind, row.current, row.latest, note))
  end

  println(string.rep('-', 100))
  println(('checked %d plugin(s)'):format(#rows))
  println(
  'note: "commit"/"branch" pins are expected to sit behind their latest —')
  println(
  '      that is what pinning means. Only "tag" pins get an update marker.')
end

local function write_candidates(rows, path)
  local out = io.open(path, 'w')
  if not out then
    io.stderr:write('cannot write candidates file: ' .. path .. '\n')
    return
  end
  for _, row in ipairs(rows) do
    -- Only tag/commit pins have something concrete to rewrite; branch pins
    -- float already, and unpinned entries have nothing to apply.
    if row.changed and (row.kind == 'tag' or row.kind == 'commit') then
      out:write(table.concat(
      { row.file, row.slug, row.kind, row.current, row.latest }, '\t') .. '\n')
    end
  end
  out:close()
end

-- Main ----------------------------------------------------------------------

if mode == 'apply' then
  run_apply()
else
  local rows = collect()
  run_pretty(rows)
  if candidates_file then
    write_candidates(rows, candidates_file)
  end
end
