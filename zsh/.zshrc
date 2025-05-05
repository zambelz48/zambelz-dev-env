KERNEL_NAME=$(uname -s)
KERNEL_ARCH=$(uname -m)

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# ZSH Theme
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="dracula"

# Disable auto-update.
DISABLE_AUTO_UPDATE=true

# Disable auto-setting terminal title.
DISABLE_AUTO_TITLE=true

# https://github.com/ohmyzsh/ohmyzsh/wiki/Settings/7b490e3385a01937655d0a103322b572b4d23c3f#disable_untracked_files_dirty
DISABLE_UNTRACKED_FILES_DIRTY=true

# Terminal title
precmd () {print -Pn "\e]0;%~\a"}

# ZSH Plugins
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(evalcache git)

ZSH_DISABLE_COMPFIX=true

source $ZSH/oh-my-zsh.sh

# Language environment
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR="vim"
else
  export EDITOR="nvim"
fi

# Dracula theme for man pages using less
export MANPAGER="/usr/bin/less -s -M +Gg"
export LESS_TERMCAP_mb=$'\e[1;31m'      # begin bold
export LESS_TERMCAP_md=$'\e[1;34m'      # begin blink
export LESS_TERMCAP_so=$'\e[01;45;37m'  # begin reverse video
export LESS_TERMCAP_us=$'\e[01;36m'     # begin underline
export LESS_TERMCAP_me=$'\e[0m'         # reset bold/blink
export LESS_TERMCAP_se=$'\e[0m'         # reset reverse video
export LESS_TERMCAP_ue=$'\e[0m'         # reset underline
export GROFF_NO_SGR=1                   # for konsole

# Coding assistant options ("copilot" or "codeium")
export CODING_ASSISTANT="copilot"

case "$KERNEL_NAME" in

  Linux*)
    # Adds Linux related config here...
    ;;

  Darwin*)
    if [ -d "/opt/homebrew" ]; then
      export BREW_HOME="/opt/homebrew"
      export PATH="$BREW_HOME/bin:$PATH"

      export RUBY_HOME="$BREW_HOME/opt/ruby"
      export PATH="$RUBY_HOME/bin:$PATH"

      export HOMEBREW_NO_ANALYTICS=1
    fi
    ;;

esac

source "$HOME/.profile.zsh"

if [ "$ZAMBELZ_DEV_ENV_PATH" = "" ]; then
  echo "ZAMBELZ_DEV_ENV_PATH not found in .profile.zsh"
fi

ZAMBELZ_HELPER_PATH="$ZAMBELZ_DEV_ENV_PATH/zsh/helpers"

# Neovim LSP
export LSP_VENDOR_ROOT_PATH="$ZAMBELZ_DEV_ENV_PATH/neovim/.lsp_vendors"

export KOTLIN_LANGUAGE_SERVER_PATH="$LSP_VENDOR_ROOT_PATH/kotlin-language-server/server/build/install/server/bin"
export PATH="$KOTLIN_LANGUAGE_SERVER_PATH:$PATH"

export GRADLE_LANGUAGE_SERVER_PATH="$LSP_VENDOR_ROOT_PATH/vscode-gradle/gradle-language-server/build/install/gradle-language-server/bin"
export PATH="$GRADLE_LANGUAGE_SERVER_PATH:$PATH"

export JAVA_LANGUAGE_SERVER_PATH="$LSP_VENDOR_ROOT_PATH/jdtls/bin"
export PATH="$JAVA_LANGUAGE_SERVER_PATH:$PATH"

export LUA_LANGUAGE_SERVER_PATH="$LSP_VENDOR_ROOT_PATH/lua-language-server/bin"
export PATH="$LUA_LANGUAGE_SERVER_PATH:$PATH"

if [ "$KERNEL_NAME" = "Linux" ]; then
  export XML_LANGUAGE_SERVER_PATH="$LSP_VENDOR_ROOT_PATH/xml-lsp/linux"
  export PATH="$XML_LANGUAGE_SERVER_PATH:$PATH"
fi

if [ "$KERNEL_NAME" = "Darwin" ]; then
  if [ "$KERNEL_ARCH" = "arm64" ]; then
    export XML_LANGUAGE_SERVER_PATH="$LSP_VENDOR_ROOT_PATH/xml-lsp/darwin/arm"
  else
    export XML_LANGUAGE_SERVER_PATH="$LSP_VENDOR_ROOT_PATH/xml-lsp/darwin/x86"
  fi
  export PATH="$XML_LANGUAGE_SERVER_PATH:$PATH"
fi

# Dracula theme for fzf
export FZF_DEFAULT_OPTS="--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
--color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
--color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
--color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4"

FNM_DIR="$HOME/.local/share/fnm"
if [ -d "$FNM_DIR" ]; then
  export PATH="$FNM_DIR:$PATH"
fi

if command -v fnm &> /dev/null; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# TODO: jenv is slow, need to find alternative
JENV_HOME=$HOME/.jenv
if [ -d "$JENV_HOME" ] || command -v jenv &> /dev/null; then
  export PATH="$JENV_HOME/bin:$PATH"
  _evalcache jenv init - --no-rehash

    # perform background rehash
    (jenv rehash &) 2> /dev/null
fi

PYENV_HOME="$HOME/.pyenv"
if [ -d "$PYENV_HOME" ] || command -v pyenv &> /dev/null; then
  [[ -d $PYENV_HOME/bin ]] && export PATH="$PYENV_HOME/bin:$PATH"
  _evalcache pyenv init - zsh
fi

if command -v rbenv &> /dev/null; then
  _evalcache rbenv init --no-rehash - zsh

    # perform background rehash
    (rbenv rehash &) 2> /dev/null
fi

if command -v mcfly &> /dev/null; then
  _evalcache mcfly init zsh
fi

# Aliases
alias zconf="$ZAMBELZ_DEV_ENV_PATH/main.sh"

# Helper functions
source "$ZAMBELZ_HELPER_PATH/utils.sh"
source "$ZAMBELZ_HELPER_PATH/git.sh"
source "$ZAMBELZ_HELPER_PATH/tmux.sh"

# Dracula themes syntax highlighting
# source: https://github.com/dracula/zsh-syntax-highlighting
source "$ZAMBELZ_DEV_ENV_PATH/zsh/.themes/dracula-syntax-highlighting/zsh-syntax-highlighting.sh"

# zsh syntax highlighting
# source: https://github.com/zsh-users/zsh-syntax-highlighting
source "$ZAMBELZ_DEV_ENV_PATH/zsh/.themes/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

