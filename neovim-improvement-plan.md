# Neovim Configuration Improvement Plan

Scope: `neovim/` in this repository.
Baseline: Neovim 0.12.6, lazy.nvim 11.17.5, nvim-lspconfig v2.12.0, tmux 3.8,
kitty 0.49.2. Audit date: 2026-10-28.

Sources used for every item: Neovim 0.12.6 runtime docs (`:h news`,
`:h news-0.11`, `:h deprecated`, `:h lsp`, `:h options`), installed plugin
sources under `~/.local/share/nvim/lazy/`, and upstream READMEs, releases and
commit histories on GitHub.

## Baseline measurements

Re-run these after every phase and compare.

| Check | Baseline |
|---|---|
| Startup time (`nvim --headless --startuptime <log> +qa`, 3 runs) | 180-230 ms |
| Plugins loaded at startup (`require('lazy').stats()`) | 34 of 38 |
| `require('options')` cost | 19.3 ms |
| Runtime deprecation warnings (probe session, 14 files) | 2 |
| `:checkhealth vim.lsp` | crashes |
| `:checkhealth vim.provider` | ERROR (python3) |
| `:checkhealth lazy` | ERROR (luarocks) |
| lua_ls diagnostics in `neovim/` | `Undefined global vim` in 20 files |

## Verification gate

The repository has no build or test command (`AGENTS.md`). Each phase is
verified with:

1. `nvim --headless +qa` exits 0 with no output.
2. `:checkhealth vim.lsp vim.deprecated vim.provider lazy` shows no ERROR.
3. Startup time and loaded-plugin count recorded against the baseline.
4. Deprecation probe: a headless session started with
   `--cmd "luafile <probe>"` that wraps `vim.deprecate`, `vim.notify` and
   `vim.notify_once` (recording, then calling the original), opens one file
   per configured language, waits for LSP attach, and dumps the records plus
   `:messages`. Expected result: zero records.
5. Manual check of the keymaps touched in the phase.

## Dependency changes requiring approval

Removals and swaps listed here change the plugin set. Each needs an explicit
go-ahead before implementation.

| Change | Type | Reason |
|---|---|---|
| `norcalli/nvim-colorizer.lua` -> `catgoose/nvim-colorizer.lua` | swap | Live `vim.tbl_flatten` deprecation (removed in 0.13); upstream unmaintained since 2024-05-10 |
| Remove `ibhagwan/fzf-lua` | removal | Never referenced |
| Remove `nvim-neotest/neotest` | removal | No adapters, never set up |
| Remove `antoinemadec/FixCursorHold.nvim` | removal | Upstream README: not needed after neovim#20198 |
| Remove `nvim-treesitter/nvim-treesitter-textobjects` | removal | `main` branch provides nothing without user keymaps; 0.12 has built-in node selection |
| Remove `numToStr/Comment.nvim` | removal | Native `gc` since 0.10; config is all defaults; last commit 2024-06-09 |

`nvim-neotest/nvim-nio` stays: `nvim-dap-ui` depends on it.

---

## Phase 1: Eliminate live deprecation warnings

### 1.1 Rename `tsgo` to `tsc`

- File: `neovim/lua/lsp_configs/typescript_lsp_conf.lua`
- Evidence: nvim-lspconfig `lsp/tsgo.lua:8` calls
  `vim.deprecate('tsgo', 'tsc', '3.0.0', 'nvim-lspconfig')` in `on_init`;
  observed firing in the probe session.
- Action: `name = 'tsc'`; drop the `cmd` override (lspconfig's `tsc.lua`
  resolves a binary that supports `--lsp`; installed `tsc` is 7.0.2).
- Also fixes 2.3 (unkeyed settings table) in the same file.

### 1.2 Replace nvim-colorizer (approval required)

- File: `neovim/lua/plugins/nvim_colorizer.lua`
- Evidence: probe recorded `vim.tbl_flatten` deprecation from
  `colorizer/nvim.lua:96` on setup and on every highlight.
- Action: swap to `catgoose/nvim-colorizer.lua`, load on `BufReadPre`,
  `opts = {}` per its README; pin a commit or tag.

### 1.3 Pre-empt upcoming deprecations

- `vim.keymap.set` option `buffer` -> `buf` (renamed in 0.12, soft-deprecated
  in 0.13, removed in 0.15 per `runtime/lua/vim/keymap.lua:90`).
  Files: `plugins/gitsigns.lua`, `plugins/nvim_jdtls.lua`.
- gitsigns functions marked `@deprecated` in the installed source:
  `next_hunk`/`prev_hunk` -> `nav_hunk('next'|'prev')`;
  `undo_stage_hunk` -> `stage_hunk` on a staged hunk;
  `toggle_deleted` -> `preview_hunk_inline`;
  `:Gitsigns select_hunk` string mapping -> `gitsigns.select_hunk`.
- nvim-tree legacy option names (migrated silently by
  `nvim-tree/legacy.lua:55-56`): `update_focused_file.update_cwd` ->
  `update_root`; top-level `update_cwd` -> `sync_root_with_cwd`.

Acceptance: probe reports zero deprecation records.

---

## Phase 2: Fix broken behaviour

### 2.1 LSP keymaps calling removed functions

- File: `neovim/lua/utils.lua:61-70`
- Evidence: `vim.lsp.diagnostic.goto_prev`, `goto_next`, `set_loclist` and
  `vim.lsp.buf.range_code_action` are `nil` in 0.12.6.
- Action: drop mappings that duplicate built-in defaults
  (`:h lsp-defaults`, `:h news-0.11`, `:h news`): `grn`, `gra` (n+v), `grr`,
  `gri`, `grt`, `grx`, `gO`, `K`, `[d`, `]d`, `[D`, `]D`, insert `<C-s>`.
  Keep only non-default ones (`gd`, `gD`, `H`, `<leader>f`, `<leader>d`,
  workspace-folder maps) and point `<leader>q` at
  `vim.diagnostic.setloclist`. Delivered through the `LspAttach` autocmd in
  4.2.

### 2.2 Diagnostic sign icons ignored

- File: `neovim/lua/plugins/nvim_lsp.lua:36-51,59`
- Evidence: `:h news` "diagnostic-signs can no longer be configured with
  sign_define()".
- Action: move icons to
  `vim.diagnostic.config({ signs = { text = { [severity] = icon } } })`;
  `float.source = 'if_many'` (valid values: `boolean|'if_many'`).

### 2.3 `:checkhealth vim.lsp` crash and ignored TS settings

- File: `neovim/lua/lsp_configs/typescript_lsp_conf.lua:10`
- Evidence: unkeyed table inside the config; reproduced the crash
  ("attempt to compare string with number") with `--clean` and a minimal
  config containing a positional table.
- Action: put the inlay-hint table under `settings =`.

### 2.4 `vim.vn` typo

- File: `neovim/lua/plugins/nvim_cmp.lua:94`
- Action: `vim.fn.feedkeys`.

### 2.5 Telescope `opts` silently dropped

- File: `neovim/lua/plugins/telescope.lua`
- Evidence: lazy `core/loader.lua:376-381` passes `opts` to a custom
  `config`, which never calls `telescope.setup()`.
- Action: `config = function(_, opts) telescope.setup(opts) ... end`, or use
  `opts` only and move keymaps to `keys`.

### 2.6 ESLint forced to legacy config

- File: `neovim/lua/lsp_configs/eslint_lsp_conf.lua`
- Evidence: overrides `experimental.useFlatConfig = false` and
  `workingDirectory.mode = 'location'` against lspconfig defaults
  (`experimental = {}`, `mode = 'auto'`, `lsp/eslint.lua:154-186`).
- Action: delete the override file contents down to nothing that differs
  from lspconfig (or delete the file and just enable `eslint`).

### 2.7 jsonls schemas ignored

- File: `neovim/lua/lsp_configs/jsonls_lsp_conf.lua`
- Evidence: json-language-features server README: schema associations are
  defined in settings; `initializationOptions` only accepts
  `provideFormatter`, `handledSchemaProtocols`, `customCapabilities`.
- Action: move to `settings = { json = { schemas = ..., validate = { enable =
  true } } }`; drop `utils.cache` use.

### 2.8 Key typos

- `lsp_configs/graphql_lsp_conf.lua:4` `filtypes` -> `filetypes` (or delete
  the line; lspconfig default is identical).
- `lsp_configs/tailwind_lsp_conf.lua:15` `taildwindCSS` -> `tailwindCSS`.

### 2.9 Servers that never attach

- `ansiblels` (`yaml.ansible`) and `docker_compose_language_service`
  (`yaml.docker-compose`): Neovim detects `playbook.yml` and
  `docker-compose.yml` as `yaml` (verified with `vim.filetype.match`); the
  docker-compose server did not start in the probe session.
  Action: add `vim.filetype.add({ pattern = ... })` rules for
  `docker-compose*.y*ml` / `compose*.y*ml` and the Ansible layout in use, or
  drop both configs.
- `vls`: Vetur binary not installed; lspconfig's `vls` is now the V language
  server, so this config merges into an unrelated one. Action: delete. If Vue
  support is wanted, configure `vue_ls` (needs `vtsls`) as a separate task.
- `dartls` and `terraformls`: binaries missing (`:checkhealth vim.lsp`
  warns). Keep or drop depending on intended use; no code change needed.

### 2.10 omnisharp overrides

- File: `neovim/lua/lsp_configs/omnisharp_lsp_conf.lua`
- Evidence: `root_markers = { '.sln', '.csproj' }` are literal names, never
  match; `--hostPID 12345` is fake. lspconfig `lsp/omnisharp.lua` uses
  `vim.fn.getpid()` and a `root_dir` function.
- Action: remove `cmd` and `root_markers` overrides; keep only `settings`
  that differ from defaults.

### 2.11 jdtls only attaches once

- File: `neovim/lua/plugins/nvim_jdtls.lua`
- Evidence: `start_or_attach` runs once in lazy `config` (`:196`); nvim-jdtls
  README requires it on every `FileType java` (`ftplugin/java.lua`).
- Action: plugin spec keeps `ft = 'java'` with no `config`; move the setup to
  `neovim/ftplugin/java.lua` (symlinked by `setup.sh`). Remove
  `-Dlog.level=ALL` and `-Dlog.protocol=true`. Move `-data` workspace to
  `vim.fn.stdpath('cache') .. '/jdtls/<project>'`. Compute root with
  `vim.fs.root(0, { 'gradlew', 'mvnw', 'pom.xml', '.git' })`. Ensure
  `jdtls` is never passed to `vim.lsp.enable`.

### 2.12 clangd stale client cache

- File: `neovim/lua/lsp_configs/clangd_lsp_conf.lua:5`
- Action: drop `memoize`; call `vim.lsp.get_clients` directly; use
  `client:request(...)` method form.

### 2.13 lua_ls without Neovim runtime

- Evidence: lua_ls reports `Undefined global 'vim'` in 20 files, including
  the `local vim = vim` workaround lines themselves.
- Action: add `neovim/.luarc.json` with `runtime.version = "LuaJIT"` and
  `workspace.library = ["$VIMRUNTIME"]` (portable across editors), then
  delete all 20 `local vim = vim` lines.

### 2.14 Broken python provider and startup subprocesses

- File: `neovim/lua/options.lua:4-8`
- Evidence: `:checkhealth vim.provider` ERROR (homebrew python has no
  `neovim` module); `~/.local/share/nvim/rplugin.vim` absent (no remote
  plugins); the two `io.popen('which ...')` calls cost 19.3 ms.
- Action: `vim.g.loaded_python3_provider = 0`,
  `vim.g.loaded_ruby_provider = 0`; delete the `which` calls. Leave the node
  provider (healthy).

### 2.15 luarocks error

- File: `neovim/init.lua`
- Evidence: `:checkhealth lazy` ERROR; "no plugins require luarocks".
- Action: `rocks = { enabled = false }` in `lazy.setup`.

### 2.16 Crash when `ZAMBELZ_DEV_ENV_PATH` is unset

- Files: `plugins/nvim_dap.lua:17,32`, `plugins/nvim_jdtls.lua:32`
- Action: derive the repo path from
  `vim.fn.resolve(vim.fn.stdpath('config') .. '/init.lua')` (the symlink
  target) in one helper; no `nil ..` concatenation.

### 2.17 `setup.sh`

- File: `neovim/setup.sh`
- Problems: `rm -rf ~/.config/nvim` deletes `lazy-lock.json`; per-file
  symlinks require re-running for every new file; `dirname "$0"` yields
  relative symlinks when run with a relative path.
- Action: resolve the script directory to an absolute path; symlink
  `init.lua`, `lua/`, `ftplugin/`, `after/` and `.luarc.json` as whole
  entries; never delete `lazy-lock.json`; set `lockfile` in `lazy.setup` to
  a path inside the repo and commit it (pins `cmp-nvim-lsp`, `cmp-buffer`,
  which have no spec pin).

Acceptance: verification gate passes; every keymap in 2.1 works in a TS, Lua,
Go and C buffer.

---

## Phase 3: Remove unused and redundant code

### 3.1 Plugin removals (approval required, see table above)

`fzf.lua`, `neotest.lua` (+ `FixCursorHold`),
`treesitter_textobjects.lua`, `comment.lua`.

For `Comment.nvim`: keep `nvim-ts-context-commentstring` with
`enable_autocmd = false` and add the `vim.filetype.get_option` override from
its wiki "Native commenting in Neovim 0.10" section. Remove
`vim.g.skip_ts_context_commentstring_module` from `options.lua` if no longer
needed.

### 3.2 Configs that restate defaults

Reduce to non-default values only:

- `plugins/fidget.lua` (also remove the `nvim-notify` redirect and
  `xcodebuild-nvim` integration; neither plugin is installed)
- `plugins/markdown_preview.lua` (only `mkdp_theme = 'light'`; set in
  `init`, not `config`)
- `plugins/nvim_dap_virtual_text.lua`
- `plugins/todo_comments.lua`
- `plugins/gitsigns.lua`, `plugins/nvim_tree.lua` (setup tables)
- `plugins/indent_blankline.lua` (excludes for absent plugins: `dashboard`,
  `Trouble`, `mason`, `notify`)

### 3.3 `utils.lua` dead code

Delete `shell_cmd_with_timeout`, `cache`, `memoize`, `trim`, `shell_cmd`
(after 2.14), `create_keymap` and `lsp_shared_keymaps` (after 4.2). Sweep for
references before each deletion; expect zero.

### 3.4 Redundant options and keymaps

- `options.lua`: duplicate `signcolumn`; `hidden` and `inccommand` equal
  defaults; `guifont` has no effect in the TUI; `smartindent` overridden by
  treesitter `indentexpr`; stale "Enable mouse mode" comment above
  `mouse = ''`.
- `keymaps.lua`: `[q` / `]q` are built-in defaults since 0.11.
- `plugins/nvim_tree.lua`: `<leader>e` defined twice (`keys` and manual
  `nvim_set_keymap`).

### 3.5 lazy update checker

- `init.lua`: `checker = { enabled = false }`; updates go through
  `neovim/scripts/apply_plugin_updates.sh`.

Acceptance: verification gate passes; reference sweep for every removed
module, file and symbol returns zero hits.

---

## Phase 4: Modernise to 0.11 / 0.12 idioms

### 4.1 Discovery instead of hand-rolled loaders

- `init.lua`: replace the `dofile` glob loop with
  `spec = { { import = 'plugins' } }`.
- LSP: move per-server overrides from `lua/lsp_configs/*.lua` to
  `after/lsp/<name>.lua` (`:h lsp-config-merge`, priority 3, overrides
  lspconfig's `lsp/*.lua`). Enable servers from a discovered list of those
  files rather than the hardcoded `~/.config/nvim/lua/lsp_configs` path.

### 4.2 Shared LSP wiring

- `vim.lsp.config('*', { capabilities = cmp_nvim_lsp.default_capabilities() })`.
- One `LspAttach` autocmd for keymaps; remove per-server `on_attach` that
  re-calls `lsp_shared_keymaps` (clangd, rust). Server-specific user
  commands stay in their `after/lsp` file via `on_attach`.

### 4.3 Floating window styling

- Replace the `vim.lsp.buf.hover` / `signature_help` monkey-patch with
  `vim.o.winborder = 'rounded'` (0.11). Pass `max_width` / `max_height` in
  the hover keymap call if still wanted.

### 4.4 API updates

- `options.lua:84`: `nvim_exec` augroup -> `nvim_create_autocmd` with
  `vim.hl.on_yank()` (`vim.highlight` renamed to `vim.hl`).
- `clangd`, `rust`: `client.request(...)` -> `client:request(...)`;
  `client.supports_method` -> `client:supports_method`.
- `options.lua:78-81` `nvim_set_keymap` expr maps -> `vim.keymap.set`.

### 4.5 DAP signs TODO

- `plugins/nvim_dap.lua:10`: the 0.12 sign change applies to diagnostic signs
  only; nvim-dap defines its signs only when undefined
  (`lua/dap.lua:418-428`). Verify visually; if the custom icons show, delete
  the TODO.

Acceptance: verification gate passes; `lua_ls` reports no diagnostics in
`neovim/`.

---

## Phase 5: Performance

### 5.1 Lazy-load triggers

| Plugin | Trigger |
|---|---|
| nvim-dap, nvim-dap-ui, nvim-dap-virtual-text | `keys` (`<F5>`, `<leader>b`, `<leader>dt`, ...) |
| telescope (+ fzf-native, ui-select) | `keys`, `cmd = 'Telescope'` |
| toggleterm | `keys = '<C-\\>'` |
| vim-fugitive | `cmd = { 'G', 'Git', 'Gwrite', 'Gdiffsplit' }` |
| nvim-cmp, LuaSnip, cmp sources | `event = 'InsertEnter'` |
| copilot.lua | `event = 'InsertEnter'`, `cmd = 'Copilot'` (copilot.lua README) |
| gitsigns, todo-comments, colorizer | `event = { 'BufReadPre', 'BufNewFile' }` |
| tmuxline.vim | `cmd = { 'Tmuxline', 'TmuxlineSnapshot' }` |
| copilot-lualine | load only when `CODING_ASSISTANT` is copilot |

Measured startup module costs that move out of startup: cmp 8.5 ms,
telescope pickers 6.9 ms, dap-ui 6.0 ms, luasnip 5.0 ms, nvim-tree.api
5.0 ms, nio 4.4 ms, fidget 4.0 ms, copilot 3.9 ms.

Decouple `plugins/nvim_dap_ui.lua:103`: the `nvim-tree.api` subscription
moves into nvim-tree's config and checks `package.loaded['dap']`.

### 5.2 Treesitter double highlighting

- File: `plugins/treesitter.lua:87`
- Action: remove `vim.bo[bufnr].syntax = "on"` (nvim-treesitter README
  enables highlighting with `vim.treesitter.start()` only); use
  `vim.wo[0][0]` for `foldexpr` / `foldmethod` / `foldlevel`.

### 5.3 Disable replaced runtime plugins

- `lazy.setup({ performance = { rtp = { disabled_plugins = { 'netrwPlugin',
  'gzip', 'tarPlugin', 'zipPlugin', 'tutor' } } } })`; then delete the
  `loaded_netrw*` globals from `options.lua`.

### 5.4 Keymap prefix collisions (300 ms `timeoutlen` waits)

Rename so no mapping is a prefix of another:
`<leader>sf`/`sfc`, `<leader>sd`/`sdi`, `<leader>gl`/`glo`,
`<leader>gp`/`gpo`, `<leader>mp`/`mps`, `<leader>d` vs
`<leader>dt|dr|dl|df|dn`.

Acceptance: startup time and loaded-plugin count recorded; expected loaded
count at startup is limited to theme, lualine, nvim-tree, treesitter,
lspconfig and their dependencies.

---

## Not adopted (evaluated)

| Option | Reason |
|---|---|
| `vim.pack` (0.12) | Docs: "still considered experimental"; no lazy-loading |
| blink.cmp | README: "V2 is under active development with many breaking changes"; nvim-cmp still maintained (commit 2026-07-09) |
| `ui2`, `'autocomplete'`, native LSP inline completion for Copilot | Experimental or lacking parity (snippets, buffer source, copilot panel) |
| Replacing markdown-preview.nvim | Unmaintained (last commit 2023-10-17) but functional; no equivalent |

## Execution order

Phase 1 -> 2 -> 3 -> 4 -> 5. Each phase is a separate change set and passes
the verification gate before the next starts. Dependency removals and swaps
wait for approval.
