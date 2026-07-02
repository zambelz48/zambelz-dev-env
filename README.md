# Zambelz Dev Environment

Personal macOS/Linux development environment configuration: [Kitty](https://github.com/kovidgoyal/kitty) (terminal), [Zsh](https://github.com/ohmyzsh/ohmyzsh) (shell), [Neovim](https://neovim.io/) (editor), and [tmux](https://github.com/tmux/tmux) (multiplexer), unified under a single Dracula theme.

Every tool's config lives in this repository and is **symlinked** into place by a small setup script — there's no copying, so editing a file here immediately affects your live config, and `git pull` is enough to update everything.

## Table of contents

1. [Repository structure](#repository-structure)
1. [Pre-requisites](#pre-requisites)
1. [Kitty configs](#kitty-configs)
1. [Zsh configs](#zsh-configs)
1. [Neovim configs](#neovim-configs)
1. [Tmux configs](#tmux-configs)
1. [Resetting a tool's config](#resetting-a-tools-config)

## Repository structure

```
.
├── main.sh              # entry point for `zconf <tool>`, dispatches to <tool>/setup.sh
├── AGENTS.md             # conventions for AI coding agents working in this repo
├── kitty/
│   ├── kitty.base.conf   # tracked, shared kitty settings
│   ├── kitty.conf        # git-ignored, per-machine overrides (e.g. font_size)
│   └── setup.sh
├── zsh/
│   ├── .zshrc
│   ├── helpers/          # sourced shell functions (git, tmux, postgres, version managers)
│   ├── .plugins/         # git submodules (oh-my-zsh custom plugins)
│   ├── .themes/          # git submodules (Dracula theme, syntax highlighting)
│   └── setup.sh
├── neovim/
│   ├── init.lua           # bootstraps lazy.nvim, auto-loads lua/plugins and lua/lsp_configs
│   ├── lua/
│   │   ├── options.lua     # vim.opt settings
│   │   ├── keymaps.lua     # global keymaps (quickfix, fugitive, markdown preview)
│   │   ├── utils.lua       # shared helpers, incl. LSP on_attach keymaps
│   │   ├── plugins/*.lua   # one lazy.nvim plugin spec per file — auto-discovered
│   │   └── lsp_configs/*.lua # one language server config per file — auto-discovered
│   ├── .lsp_vendors/       # manually-installed language servers (git-ignored per-server)
│   ├── .dap/               # manually-installed debug adapters (git-ignored per-adapter)
│   └── setup.sh
├── tmux/
│   ├── .tmux.conf
│   ├── tmux_dracula.theme
│   └── setup.sh
└── .editorconfig
```

Dropping a new file into `neovim/lua/plugins/` or `neovim/lua/lsp_configs/` is enough to register it — `init.lua` globs both directories automatically, no central list to edit.

## Pre-requisites

1. Make sure your shell is `zsh` — [see this guide](https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH).
1. Install required tools.
   - **Mandatory**
     - General
       - Terminal emulator: [kitty](https://github.com/kovidgoyal/kitty)
       - oh-my-zsh: [source](https://github.com/ohmyzsh/ohmyzsh)
       - tmux: [source](https://github.com/tmux/tmux/wiki)
       - fzf: [source](https://github.com/junegunn/fzf)
       - fd: [source](https://github.com/sharkdp/fd)
       - ripgrep: [source](https://github.com/BurntSushi/ripgrep)
       - marksman: [source](https://github.com/artempyanykh/marksman)
     - Mac only
       - Xcode: <https://developer.apple.com/xcode>
       - Xcode command line utilities: `xcode-select --install`
       - Rosetta (*for Apple Silicon*): `softwareupdate --install-rosetta`
       - Homebrew: <https://docs.brew.sh/Installation>
   - **Optional**
     - mcfly: [source](https://github.com/cantino/mcfly)
     - tldr: [source](https://tldr.sh)
     - gvm (*manage multiple Go versions*): [source](https://github.com/moovweb/gvm)
     - jenv (*manage multiple Java versions*): [source](https://github.com/jenv/jenv)
     - rbenv (*manage multiple Ruby versions*): [source](https://github.com/rbenv/rbenv)
     - pyenv (*manage multiple Python versions*): [source](https://github.com/pyenv/pyenv)
     - fnm (*manage multiple Node.js versions*): [source](https://github.com/Schniz/fnm)
     - glow (*render markdown in terminal*): [source](https://github.com/charmbracelet/glow)
     - chafa (*render images in terminal*): [source](https://github.com/hpjansson/chafa)
1. Clone this repository at `$HOME` (**important** — several scripts assume the repo lives directly under your home directory):
   ```sh
   git clone git@github.com:zambelz48/zambelz-dev-env.git "$HOME/zambelz-dev-env"
   ```
1. Initialize git submodules (Dracula theme, zsh-syntax-highlighting, evalcache):
   ```sh
   cd "$HOME/zambelz-dev-env" && git submodule update --init --recursive
   ```
1. Create `$HOME/.profile.zsh` and export `ZAMBELZ_DEV_ENV_PATH` — this is **required**, every tool's config (Neovim's LSP/DAP vendor paths, tmux's theme, the zsh helpers, the `zconf` alias itself) resolves paths relative to it:
   ```sh
   echo 'export ZAMBELZ_DEV_ENV_PATH="$HOME/zambelz-dev-env"' >> "$HOME/.profile.zsh"
   ```
   If this is missing, `.zshrc` will print `ZAMBELZ_DEV_ENV_PATH not found in .profile.zsh` on every new shell. Use `.profile.zsh` for any other machine-local, non-tracked environment variables too.
1. Symlink `$HOME/.zshrc` to this repo's zsh config:
   ```sh
   ln -s "$HOME/zambelz-dev-env/zsh/.zshrc" "$HOME/.zshrc"
   ```
1. Source your `.zshrc` or restart the terminal. From here on, the `zconf <tool>` alias (defined in `.zshrc`) is available to (re)install any tool's config — it's a thin wrapper around `main.sh`.

## Kitty configs

#### Installation

```sh
$ zconf kitty
```

Kitty's config is split in two:

- **`kitty/kitty.base.conf`** — tracked, shared across every machine.
- **`kitty/kitty.conf`** — git-ignored, per-machine overrides (currently just `font_size`). It `include`s `kitty.base.conf`.

`kitty/setup.sh` generates `kitty.conf` from a small template **only the first time** (if it doesn't already exist), so re-running `zconf kitty` never overwrites your local font size. To tweak anything per-machine (font size, opacity, etc.), edit `kitty/kitty.conf` directly — it's not tracked by git.

## Zsh configs

#### Installation

```sh
$ zconf zsh
```

> You can source your `.zshrc` or restart the terminal after running the above command.

#### Notes

- Custom helper functions live in `zsh/helpers/*.zsh` (git, tmux session management, PostgreSQL backup/restore, version-manager toggling via `verman`) and are sourced automatically by `.zshrc`.
- `CODING_ASSISTANT` (used by Neovim's Copilot integration) defaults to `copilot`. Switch it per-shell with the `use_copilot` / `use_windsurf` helper functions in `zsh/helpers/utils.zsh`.

## Neovim configs

#### Pre-requisites

##### Install Neovim providers

```sh
# Node.js provider
$ npm install -g neovim

# Python provider
$ pip install neovim

# Ruby provider
$ gem install neovim
```

##### Install language servers

The table below covers every language server currently wired up in `neovim/lua/lsp_configs/`. See the [full list of supported servers](https://github.com/neovim/nvim-lspconfig/blob/master/CONFIG.md) for reference on any not listed here.

| Language(s) | Server | Install |
| --- | --- | --- |
| Rust | rust-analyzer | `rustup component add rust-src rust-analyzer` (or `cargo install rust-analyzer`) — [docs](https://rust-analyzer.github.io/manual.html#installation) |
| CMake | neocmakelsp | `cargo install neocmakelsp` — [source](https://github.com/Decodetalkers/neocmakelsp) |
| Bash/Zsh, Docker, Docker Compose, Vim, HTML/CSS/JSON/ESLint, YAML, Tailwind CSS, GraphQL, Prisma, Ansible, TypeScript/JavaScript | bash-language-server, dockerfile-language-server-nodejs, `@microsoft/compose-language-service`, vim-language-server, vscode-langservers-extracted, yaml-language-server, `@tailwindcss/language-server`, graphql-language-service-cli, `@prisma/language-server`, `@ansible/ansible-language-server`, typescript-language-server | Single npm command — see [below](#install-common-npm-based-language-servers) |
| Python | pyrefly | `pip install pyrefly` — [pyrefly.org](https://pyrefly.org) |
| Go | gopls | `go install golang.org/x/tools/gopls@latest` — make sure `$GOPATH/bin` is on your `PATH` |
| Ruby | solargraph | `gem install solargraph` — requires Ruby >= 2.7.0 |
| Lua | lua-language-server | Built from source, see [Setup "lua-language-server"](#setup-lua-language-server) below |
| C# | omnisharp | Manually vendored, see [Setup "omnisharp"](#setup-omnisharp-c-language-server) below |
| Java | jdtls | Manually vendored, see [Setup "jdtls"](#setup-jdtls-java-language-server) below |
| Groovy (Gradle) | gradle-language-server | Manually vendored, see [Setup "vscode-gradle"](#setup-vscode-gradle) below |
| Kotlin | kotlin-language-server | Manually vendored, see [Setup "kotlin-language-server"](#setup-kotlin-language-server) below |
| XML | lemminx | Manually vendored, see [Setup "lemminx"](#setup-lemminx-xml-language-server) below |
| Terraform | terraform-ls | See [hashicorp/terraform-ls](https://github.com/hashicorp/terraform-ls) |
| C/C++, Objective-C | clangd | Ships with Xcode Command Line Tools on macOS, or install LLVM (`brew install llvm`) |
| Swift, Objective-C++ | sourcekit-lsp | Ships with the Swift toolchain / Xcode |
| Dart | dartls (`dart language-server`) | Ships with the [Dart SDK](https://dart.dev/get-dart) / Flutter SDK |
| CSS/JS/TS/JSON/HTML/GraphQL/Vue (formatter+linter) | biome | See [biomejs.dev](https://biomejs.dev/guides/getting-started/) — not yet fully documented here |
| Vue | vls | Not yet documented here |

###### Install common npm-based language servers

```sh
npm install -g @microsoft/compose-language-service \
  bash-language-server \
  dockerfile-language-server-nodejs \
  vim-language-server \
  vscode-langservers-extracted \
  yaml-language-server \
  @tailwindcss/language-server \
  graphql-language-service-cli \
  @prisma/language-server \
  @ansible/ansible-language-server \
  typescript-language-server
```

Also install [ansible-lint](https://ansible.readthedocs.io/projects/lint/installing/#installing-the-latest-version) for the Ansible LSP.

###### Setup "omnisharp" (C# language server)

Prerequisites: .NET SDK.

1. `mkdir neovim/.lsp_vendors/omnisharp`
1. Download `omnisharp-roslyn` from the [releases page](https://github.com/OmniSharp/omnisharp-roslyn/releases) (`omnisharp-osx-arm64-net6.0.zip` on Apple Silicon, `omnisharp-linux-<ARCH>-net6.0.zip` on Linux).
1. Extract its contents into `neovim/.lsp_vendors/omnisharp`.
1. Symlink the `OmniSharp` executable, or add `neovim/.lsp_vendors/omnisharp` to your `PATH`.
1. Make it executable: `chmod ugo+x /path/to/OmniSharp`.
1. Make sure `$DOTNET_ROOT` points at your .NET installation.
1. [Trust the ASP.NET Core HTTPS dev certificate](https://learn.microsoft.com/en-us/aspnet/core/security/enforcing-ssl?view=aspnetcore-8.0&tabs=visual-studio%2Clinux-rhel#trust-the-aspnet-core-https-development-certificate-on-windows-and-macos).

###### Setup "jdtls" (Java language server)

Prerequisites: Java 21+. Source: [mfussenegger/nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls). Check the [latest JDTLS milestone](https://download.eclipse.org/jdtls/milestones/) before running the command below.

```sh
curl -o neovim/.lsp_vendors/jdt-language-server-1.46.0-202503271314.tar.gz \
  https://download.eclipse.org/jdtls/milestones/1.46.0/jdt-language-server-1.46.0-202503271314.tar.gz
mkdir neovim/.lsp_vendors/jdtls
tar xf neovim/.lsp_vendors/jdt-language-server-1.46.0-202503271314.tar.gz \
  --directory=neovim/.lsp_vendors/jdtls
mkdir neovim/.lsp_vendors/jdtls/project_data
```

Then create `neovim/.lsp_vendors/jdtls/config/intellij-java-google-style.xml`, copying its content from [google/styleguide](https://github.com/google/styleguide/blob/gh-pages/intellij-java-google-style.xml).

###### Setup "vscode-gradle"

```sh
cd neovim/.lsp_vendors/vscode-gradle && ./gradlew installDist
```

###### Setup "kotlin-language-server"

Requires Java 11.

```sh
cd neovim/.lsp_vendors/kotlin-language-server && ./gradlew :server:installDist
```

###### Setup "lua-language-server"

Requires [ninja](https://ninja-build.org/).

```sh
cd neovim/.lsp_vendors/lua-language-server && ./make.sh
```

###### Setup "lemminx" (XML language server)

1. Download the binary from the [vscode-xml releases page](https://github.com/redhat-developer/vscode-xml/releases).
1. Save it to `neovim/.lsp_vendors/xml-lsp/lemminx`.
1. Make sure it's on your `PATH`.

##### Neovim debugger (DAP)

- **Install debug adapters**
  - C/C++/Rust — download the latest `vscode-codelldb` release (`.vsix`) from [releases](https://github.com/vadimcn/codelldb/releases) and unzip it to `neovim/.dap/vscode-codelldb`. See [nvim-dap's C/C++/Rust guide](https://github.com/mfussenegger/nvim-dap/wiki/C-C---Rust-(via--codelldb)).
  - Go — install delve: `go install github.com/go-delve/delve/cmd/dlv@latest`. See [nvim-dap's install guide](https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation#go-using-delve-directly).
  - JavaScript/TypeScript — download `js-debug-dap-${version}.tar.gz` from the [vscode-js-debug releases](https://github.com/microsoft/vscode-js-debug/releases) and extract it to `neovim/.dap/vscode-js-debug`.
  - Dart/Flutter — just install the Flutter SDK.
- **Per-project debug config** — create a `launch.json` inside `.vscode/` at your project root.

#### Installation

```sh
$ zconf neovim
```

#### Activate neovim plugins

Open Neovim — [lazy.nvim](https://github.com/folke/lazy.nvim) bootstraps and installs every plugin automatically on first launch.

#### Setup LuaRocks

Some plugins (e.g. `LuaSnip`) need LuaRocks for their build step.

1. Install [hererocks](https://github.com/mpeterv/hererocks):
   ```sh
   pip install --user hererocks
   ```
1. Manually set up Lua 5.1 + LuaRocks:
   ```sh
   cd ~/.local/share/nvim
   mkdir -p lazy-rocks
   cd lazy-rocks

   hererocks . --lua=5.1 -r latest
   source ./bin/activate
   ```

## Tmux configs

#### Installation

```sh
$ zconf tmux
```

#### Activate the tmux plugin manager

1. Open tmux.
1. Press `Ctrl+B` then `Shift+I` to install plugins via [TPM](https://github.com/tmux-plugins/tpm).

## Resetting a tool's config

Every `<tool>/setup.sh` script **removes and recreates** the tool's config directory/symlinks before installing (e.g. `rm -rf "$HOME/.config/nvim"`, `rm -rf "$HOME/.tmux"`). This is safe for anything managed by this repo, but if you've added unmanaged files directly inside a tool's live config directory (e.g. `~/.config/nvim`), running `zconf <tool>` again will delete them. Keep machine-local additions in the tool's git-ignored override file where one exists (e.g. `kitty/kitty.conf`) instead.
