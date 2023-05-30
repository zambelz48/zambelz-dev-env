# Zambelz Mac Dev Environment

## Pre-requisites
#### MANDATORY
1. **Terminal emulator**: [iTerm](https://iterm2.com) or [alacritty](https://github.com/alacritty/alacritty) or [kitty](https://github.com/kovidgoyal/kitty)
1. **Xcode**: https://developer.apple.com/xcode
1. **Xcode command line utilities**: `xcode-select --install`
1. **Rosetta**(*for Apple M1 Users*): `softwareupdate --install-rosetta`
1. **Homebrew**: https://docs.brew.sh/Installation
1. **zsh**: [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh)
1. **nvm**: https://github.com/nvm-sh/nvm
1. **jenv**: manage multiple java versions (install using homebrew: `brew install jenv`) [source](https://github.com/jenv/jenv)
1. **tmux**: (install using homebrew: `brew install tmux`)
1. **fzf**: (install using homebrew: `brew install fzf`) [source](https://github.com/junegunn/fzf)
1. **fd**: (install using homebrew: `brew install fd`) [source](https://github.com/sharkdp/fd)
1. **ripgrep**: (install using homebrew: `brew install ripgrep`) [source](https://github.com/BurntSushi/ripgrep)
1. **marksman**: (install using homebrew: `brew install marksman`) [source](https://github.com/artempyanykh/marksman)
#### OPTIONAL
1. mcfly: (install using homebrew: `brew instal mcfly`) [source](https://github.com/cantino/mcfly)
1. tldr: (install using homebrew: `brew install tldr`) [source](https://tldr.sh)

## Table of contents
1. [Installation Steps](#installation-steps)
1. [ZSH Configs](#zsh-configs)
1. [Neovim Configs](#neovim-configs)
1. [TMUX Configs](#tmux-configs)

## Installation steps
1. clone this repository anywhere (*recommendation is at $HOME*)  
1. set `main.sh` executable by executing this command: `chmod +x main.sh`
1. add below `envar` to your shell profile (the locations might be: `.bash_profile`, `.profile`, or `.zlogin`)  
    ```
    # zambelz mac configs
    export ZAMBELZ_MAC_CONFIGS_PATH=$HOME/zambelz-mac-configs
    alias zconf="$ZAMBELZ_MAC_CONFIGS_PATH/main.sh"
    ```  
1. source your shell's rc file or execute `exec $SHELL -l`

## zsh configs
#### Pre-requisites
```
# Dracula themes syntax highlighting
# source: https://github.com/dracula/zsh-syntax-highlighting

# zsh syntax highlighting
# source: https://github.com/zsh-users/zsh-syntax-highlighting
# install using homebrew: brew install zsh-syntax-highlighting
```
#### Installation
```sh
$  zconf zsh
```
note: *don't forget to source .zshrc*

## neovim configs

#### Pre-requisites
##### Install Neovim Module
```
# NPM Module
$ npm install -g neovim

# Python Module
$ pip install neovim

# Ruby Module
$ gem install neovim --user-install
```
##### Install LSP
###### NPM Modules
```
- DOCKERCOMPOSE => @microsoft/compose-language-service  
- BASH => bash-language-server  
- DOCKERFILE => dockerfile-language-server-nodejs  
- TYPESCRIPT => typescript-language-server  
- VIM => vim-language-server  
- HTML, CSS, etc => vscode-langservers-extracted  
- YAML => yaml-language-server  

## Command:
$ npm install -g @microsoft/compose-language-service \
    bash-language-server \
    dockerfile-language-server-nodejs \
    typescript-language-server \
    vim-language-server \
    vscode-langservers-extracted \
    yaml-language-server
```
###### Custom
```
# Setup "jdtls" (Java Language Server)
source: https://github.com/mfussenegger/nvim-jdtls
1. Download jdtls
    - cmd: curl -o neovim/.lsp_vendors/jdt-language-server-1.23.0-202304271346.tar.gz https://download.eclipse.org/jdtls/milestones/1.23.0/jdt-language-server-1.23.0-202304271346.tar.gz
2. Unzip to specified location
    - cmd: tar xf neovim/.lsp_verndors/jdt-language-server-1.23.0-202304271346.tar.gz --directory=neovim/.lsp_vendors/jdtls
3. create workspace_data dir
    - cmd: mkdir neovim/.lsp_vendors/jdtls/project_data

# Setup "vscode-gradle" & "kotlin-language-server"
    - cmd: git submodule update --init --recursive
    - change to latest tag
```
#### Installation
```sh
$  zconf neovim
```

#### Activate neovim plugins
1. open neovim (`nvim`)
1. execute this command: `:PackerInstall`

## tmux configs

#### Installation
```sh
$ zconf tmux
```

#### Activate tmux package manager
1. open tmux mode
1. press `Ctrl + B` and `shift + I` to install tmux plugins

