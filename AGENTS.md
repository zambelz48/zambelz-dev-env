# AGENTS.md

This project contains configuration files for various development tools.

## Agent Rules

These rules are mandatory for every AI agent working in this repository. They
override any default behaviour, skill, or workflow that conflicts with them.

### No emojis

- Never add emojis anywhere: code, comments, log and echo output, error
  messages, commit messages, docs, or replies.
- When something must stand out, use plain text markers such as `ERROR:`,
  `WARN:`, `OK:`, `NOTE:`.
- Nerd Font glyphs used as functional UI icons (statusline, signs, file tree,
  completion kinds) are not emojis. Keep them as they are.
- Existing emojis may be removed only inside code you are already editing for
  the task. Do not run separate cleanup passes.

### Comments: rare and compact

- Default to no comment. Write one only when it explains why, or flags a
  non-obvious constraint that the code cannot express.
- A comment is at most one or two short lines.
- Never write comments that restate the code, file header banners, pasted
  upstream documentation, or blocks of commented-out default options.
- Never write parameter/return boilerplate (`@param`, `@return`, and the
  like) unless a linter enabled in this repository requires it.
- Remove comments that your change makes stale.

### Git: read-only unless asked

- Never run a git command that changes repository state unless the user
  explicitly asks for that operation in the current request. This includes
  `add`, `commit`, `push`, `pull`, `fetch` into branches, `merge`, `rebase`,
  `reset`, `revert`, `restore`, `checkout`, `switch`, `branch`, `tag`,
  `stash`, `cherry-pick`, `clean`, `rm`, `mv`, and `gh pr create`.
- Read-only commands (`status`, `diff`, `log`, `show`, `blame`,
  `ls-files`) are always allowed.
- When the work is done, say it is ready to commit and stop.

### Working documents go in `tmp/docs/`

- Write every working document under `tmp/docs/`: brainstorming notes,
  research reports, design documents and specs, development or
  implementation plans, review notes, and similar. `tmp/` is git-ignored.
- This overrides any skill or workflow default location, such as
  `docs/superpowers/specs/` or `docs/superpowers/plans/`. Keep the skill's
  subfolder layout under `tmp/docs/` (for example
  `tmp/docs/superpowers/plans/`).
- Paths written inside these documents must point at their `tmp/docs/`
  location.
- Only documentation that ships with the repository (`README.md`,
  `AGENTS.md`, per-tool docs) lives outside `tmp/`.

### Thoroughness and accuracy

- Be detailed and comprehensive. Finish the whole request; never stop
  halfway or quietly skip a part. If a part cannot be done, say which part
  and why.
- Trace before concluding. Follow the behaviour through every layer it
  touches (config, plugin source, runtime, external tool) on both the success
  and failure paths, and cite `file:line` for each decisive step.
- Never invent an API, option, plugin feature, version, or command. Verify
  against the installed source, the tool's built-in help (`:help`, `man`,
  `--help`), or the official upstream documentation. Research online when the
  local sources do not settle it.
- Do not trust memory for version-dependent behaviour. Check the installed
  version first (`nvim --version`, `tmux -V`, `kitty --version`, plugin
  `git log`) and read its changelog or release notes.
- Clearly separate what was verified from what was not. Never present a guess
  as a finding.
- Verify your own changes before reporting them done: run the validation
  steps for the touched tool (see below) and report the actual result,
  including failures.

## Build/Lint/Test

- There are no project-wide build, lint, or test commands.
- Configuration is managed by setup scripts in each tool's directory (e.g.,
  `zsh/setup.sh`, `neovim/setup.sh`).
- When modifying a tool's configuration, refer to its specific documentation
  and `README.md` for validation steps. At minimum:
  - Neovim: `nvim --headless +qa` exits cleanly, and the relevant
    `:checkhealth` sections report no new errors.
  - tmux: load the config on an isolated server
    (`tmux -L probe -f tmux/.tmux.conf new -d`), inspect it, then
    `tmux -L probe kill-server`.
  - Shell scripts: `bash -n` / `zsh -n` on the changed file.

## Code Style

- Adhere to the `.editorconfig` file for formatting.
- **Lua**: Use 2-space indentation for `.lua` files.
- **Shell**: Use 2-space indentation for `.sh` and `.zsh` files.
- **Naming**: Follow existing naming conventions in the respective
  configuration files.
- **Error Handling**: Ensure scripts and configurations are robust and handle
  potential errors gracefully.
- No specific import, typing, or error handling conventions are defined
  project-wide. Follow the conventions of the file you are editing.
