# Zambelz Dev Environment

## Table of contents
1. [Pre-requisites](#pre-requisites)
1. [ZSH Configs](#zsh-configs)
1. [Neovim Configs](#neovim-configs)
1. [TMUX Configs](#tmux-configs)

## Pre-requisites
1. Make sure your shell is `zsh` [see this guide](https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH)
1. install required tools
   - **MANDATORY**
        - General
            - Terminal emulator: [kitty](https://github.com/kovidgoyal/kitty)
            - oh-my-zsh: [source](https://github.com/ohmyzsh/ohmyzsh)
            - tmux: [source](https://github.com/tmux/tmux/wiki)
            - fzf: [source](https://github.com/junegunn/fzf)
            - fd: [source](https://github.com/sharkdp/fd)
            - ripgrep: [source](https://github.com/BurntSushi/ripgrep)
            - marksman: [source](https://github.com/artempyanykh/marksman)
        - Mac only
            - Xcode: https://developer.apple.com/xcode
            - Xcode command line utilities: `xcode-select --install`
            - Rosetta(*for Apple M chip users*): `softwareupdate --install-rosetta`
            - Homebrew: https://docs.brew.sh/Installation
    - **OPTIONAL**
        - mcfly: [source](https://github.com/cantino/mcfly)
        - tldr: [source](https://tldr.sh)
        - jenv (*manage multiple java versions*): [source](https://github.com/jenv/jenv)
        - rbenv (*manage multiple ruby versions*): [source](https://github.com/rbenv/rbenv)
        - pyenv (*manage multiple python versions*): [source](https://github.com/pyenv/pyenv)
        - fnm (*manage multiple nodejs versions*): [source](https://github.com/Schniz/fnm)
        - glow (*render markdown in terminal*): [source](https://github.com/charmbracelet/glow)
        - chafa (*render images in terminal*): [source](https://github.com/hpjansson/chafa)
1. clone this repository at $HOME path (IMPORTANT)
1. init git submodule: `git submodule update --init --recursive`
1. create symlink at `$HOME/.zshrc` pointing to `$HOME/zambelz-mac-configs/zsh/.zshrc`
1. source your `.zshrc` or restart the terminal

## zsh configs
#### Installation
```sh
$ zconf zsh
```
note: *you can source your .zshrc or restart the terminal after executin above command*

## neovim configs

#### Pre-requisites
##### Install Neovim Module
```sh
# NPM Module
$ npm install -g neovim

# Python Module
$ pip install neovim

# Ruby Module
$ gem install neovim
```
##### Install LSP

###### Using rustup
```sh
Prerequisites:  
You have to install rust first (https://www.rust-lang.org/tools/install)  

- Rust Language Server => rust-analyzer (https://rust-analyzer.github.io/manual.html#installation)
## Command:
$ rustup component add rust-src  
$ rustup component add rust-analyzer
```

###### Cargo Crates
```sh
Prerequisites:  
You have to install rust first (https://www.rust-lang.org/tools/install)  

- Rust Language Server => rust-analyzer  
## Command:  
$ cargo install rust-analyzer  

- CMake => neocmakelsp (https://github.com/Decodetalkers/neocmakelsp)  
## Command:  
$ cargo install neocmakelsp  
```

###### NPM Modules
```sh
- DOCKERCOMPOSE => @microsoft/compose-language-service  
- BASH => bash-language-server  
- DOCKERFILE => dockerfile-language-server-nodejs  
- VIM => vim-language-server  
- HTML, CSS, etc => vscode-langservers-extracted  
- YAML => yaml-language-server  
- TAILWINDCSS => @tailwindcss/language-server

## Command:
$ npm install -g @microsoft/compose-language-service \
    bash-language-server \
    dockerfile-language-server-nodejs \
    vim-language-server \
    vscode-langservers-extracted \
    yaml-language-server \
    @tailwindcss/language-server \
    graphql-language-service-cli \
    @prisma/language-server \
    @ansible/ansible-language-server

### Notes:
- install ansible-lint for ansible lsp: https://ansible.readthedocs.io/projects/lint/installing/#installing-the-latest-version
```

###### Python Packages
```sh
- PYTHON Language Server => pyright (https://microsoft.github.io/pyright)
## Command:
$ pip install pyright
```

###### GO Packages
```sh
- gopls => go language server (https://github.com/golang/tools/tree/master/gopls#gopls-the-go-language-server)
## Command:
$ go install golang.org/x/tools/gopls@latest
## Notes:
- Make sure GOPATH already registered on your shell
```

###### Ruby GEM Packages
```sh
- solargraph => solargraph (https://solargraph.org)

## Command:
$ gem install solargraph

## Notes:
$ Make sure ruby version is >= 2.7.0
```

###### Custom
```sh
# Setup "omnisharp" (C# Language Server)
prerequisites: .NET SDK
1. create 'omnisharp' dir
    - cmd: mkdir neovim/.lsp_vendors/omnisharp
2. download omnisharp-roslyn here: https://github.com/OmniSharp/omnisharp-roslyn/releases
    - mac: `omnisharp-osx-arm64-net6.0.zip`
    - linux: `omnisharp-linux-<ARCH>-net6.0.zip`
3. extract content of omnisharp-roslyn in neovim/.lsp_vendors/omnisharp
4. create symlink to the 'OmniSharp' executable or add 'neovim/.lsp_vendors/omnisharp' to the PATH.
5. ensure 'OmniSharp' is executable
    - cmd: chmod ugo+x /path/to/OmniSharp
6. ensure "$DOTNET_ROOT" is set in the PATH. if not, the root should be set to the .NET (dotnet) binary located.
7. enforce https: https://learn.microsoft.com/en-us/aspnet/core/security/enforcing-ssl?view=aspnetcore-8.0&tabs=visual-studio%2Clinux-rhel#trust-the-aspnet-core-https-development-certificate-on-windows-and-macos

# Setup "jdtls" (Java Language Server)
prerequisites: java 21+ (MANDATORY)
see here for updated JDTLS version: https://download.eclipse.org/jdtls/milestones/?d
source: https://github.com/mfussenegger/nvim-jdtls
1. Download jdtls 
    - cmd: curl -o neovim/.lsp_vendors/jdt-language-server-1.46.0-202503271314.tar.gz https://download.eclipse.org/jdtls/milestones/1.46.0/jdt-language-server-1.46.0-202503271314.tar.gz
2. Create "jdtls" dir
    - cmd: mkdir neovim/.lsp_vendors/jdtls
3. Unzip to specified location
    - cmd: tar xf neovim/.lsp_vendors/jdt-language-server-1.46.0-202503271314.tar.gz --directory=neovim/.lsp_vendors/jdtls
4. create workspace_data dir
    - cmd: mkdir neovim/.lsp_vendors/jdtls/project_data
5. create new file `neovim/.lsp_vendors/jdtls/config/intellij-java-google-style.xml` and copy the content from: https://github.com/google/styleguide/blob/gh-pages/intellij-java-google-style.xml

# Setup "vscode-gradle"
1. go to neovim/.lsp_vendors/vscode-gradle
2. execute: ./gradlew installDist

# Setup "kotlin-language-server"
1. Make sure your java version is Java 11
2. go to neovim/.lsp_vendors/kotlin-language-server
3. execute: ./gradlew :server:installDist

# Setup "lua-language-server"
1. make sure [ninja](https://ninja-build.org/) is installed
2. go to neovim/.lsp_vendors/lua-language-server
3. execute: ./make.sh

# Setup "lemminx" (xml language server)
1. download the binary here: https://github.com/redhat-developer/vscode-xml/releases
2. save the binary to the path: `neovim/.lsp_vendors/xml-lsp/lemminx`
3. register the binary in PATH

# Setup "terraform-ls" (terraform language server)
1. go to: https://github.com/hashicorp/terraform-ls
```
##### Neovim Debugger
- **Install Debug Adapter Protocol**
    - C/C++/Rust (https://github.com/mfussenegger/nvim-dap/wiki/C-C---Rust-(via--codelldb))
        - download latest release of vscode-codelldb (.vsix) here: https://github.com/vadimcn/codelldb/releases
        - unzip to: `neovim/.dap/vscode-codelldb`
    - Go (https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation#go-using-delve-directly)
        - Install delve: `go install github.com/go-delve/delve/cmd/dlv@latest`
    - Javascript/Typescript
        - Download `js-debug-dap-${version}.tar.gz` from their [releases](https://github.com/microsoft/vscode-js-debug/releases) page.
        - Extract to: `neovim/.dap/vscode-js-debug`
    - dart/flutter
        - just install flutter sdk
- **Add debug config**
    - Create `launch.json` file inside `.vscode` in your root project

#### Installation
```sh
$  zconf neovim
```

#### Activate neovim plugins
1. open neovim
1. execute this command: `:PackerInstall`

## tmux configs

#### Installation
```sh
$ zconf tmux
```

#### Activate tmux package manager
1. open tmux mode
1. press `Ctrl + B` and `shift + I` to install tmux plugins

