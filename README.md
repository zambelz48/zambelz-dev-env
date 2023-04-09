# Macbook tools and configurations

## Pre-requisites (MANDATORY)
1. Terminal emulator: [iTerm](https://iterm2.com) or [alacritty](https://github.com/alacritty/alacritty) or [kitty](https://github.com/kovidgoyal/kitty)
1. Homebrew: https://docs.brew.sh/Installation
1. zsh: [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh)
1. jenv: manage multiple java versions (install using homebrew: `brew install jenv`) [source](https://github.com/jenv/jenv)
1. tmux (install using homebrew: `brew install tmux`)
1. fzf: (install using homebrew: `brew install fzf`) [source](https://github.com/junegunn/fzf)
1. ripgrep: (install using homebrew: `brew install ripgrep`) [source](https://github.com/BurntSushi/ripgrep)
1. mcfly: [source](https://github.com/cantino/mcfly)

## zsh configs

#### Installation
```sh
$ bash /path/to/script/main.sh zsh
```
note: *don't forget to source .zshrc*

## neovim configs

#### Installation
```sh
$ bash /path/to/script/main.sh neovim
```

#### Activate vim plugins
1. open neovim (`nvim`)
1. execute this command: `:PackerInstall`

## tmux configs

#### Installation
```sh
$bash /path/to/script/main.sh tmux
```

#### Activate tmux package manager
1. open tmux mode
1. press `Ctrl + B` and `shift + I`

