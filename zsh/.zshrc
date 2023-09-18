KERNEL_NAME=$(uname -s)

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

# ZSH Theme
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="dracula"

# Disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Terminal title
precmd () {print -Pn "\e]0;%~\a"}

# ZSH Plugins
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

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
        fi
        ;;

esac

export ZAMBELZ_MAC_CONFIGS_PATH="$HOME/zambelz-mac-configs"

source "$HOME/.profile.zsh"

export GEM_HOME="$HOME/.gem"
export PATH="$GEM_HOME/bin:$PATH"

export RUBY_USER_HOME="$GEM_HOME/ruby/3.2.0"
export PATH="$RUBY_USER_HOME/bin:$PATH"

export LSP_VENDOR_ROOT_PATH="$ZAMBELZ_MAC_CONFIGS_PATH/neovim/.lsp_vendors"

export KOTLIN_LANGUAGE_SERVER_PATH="$LSP_VENDOR_ROOT_PATH/kotlin-language-server/server/build/install/server/bin"
export PATH="$KOTLIN_LANGUAGE_SERVER_PATH:$PATH"

export GRADLE_LANGUAGE_SERVER_PATH="$LSP_VENDOR_ROOT_PATH/vscode-gradle/gradle-language-server/build/install/gradle-language-server/bin"
export PATH="$GRADLE_LANGUAGE_SERVER_PATH:$PATH"

export JAVA_LANGUAGE_SERVER_PATH="$LSP_VENDOR_ROOT_PATH/jdtls/bin"
export PATH="$JAVA_LANGUAGE_SERVER_PATH:$PATH"

export LUA_LANGUAGE_SERVER_PATH="$LSP_VENDOR_ROOT_PATH/lua-language-server/bin"
export PATH="$LUA_LANGUAGE_SERVER_PATH:$PATH"

# Dracula theme for fzf
export FZF_DEFAULT_OPTS="--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
    --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9
    --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6
    --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4"

if [ -d "$HOME/.jenv" ]; then
	export JENV_HOME=$HOME/.jenv
	export PATH="$JENV_HOME/bin:$PATH"
	eval "$(jenv init -)"
fi

eval "$(mcfly init zsh)"

# Aliases
alias zconf="$ZAMBELZ_MAC_CONFIGS_PATH/main.sh"
alias nx="npx nx"
alias python="python3"

# Shell tools
source "$ZAMBELZ_MAC_CONFIGS_PATH/zsh/tools/worktree_helper.sh"

# Dracula themes syntax highlighting
# source: https://github.com/dracula/zsh-syntax-highlighting
source "$ZAMBELZ_MAC_CONFIGS_PATH/zsh/.themes/dracula-syntax-highlighting/zsh-syntax-highlighting.sh"

# zsh syntax highlighting
# source: https://github.com/zsh-users/zsh-syntax-highlighting
source "$ZAMBELZ_MAC_CONFIGS_PATH/zsh/.themes/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

