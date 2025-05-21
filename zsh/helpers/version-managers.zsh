# Author: Nanda Julianda Akbar<nanda.julianda48@gmail.com>
# Manage version managers for zsh
# This tool will help you manage version managers for zsh without having to load them manually

# Reuseable functions
_prepend_path_if_missing() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

_gvm_go_binnary_path() {
  local gvm_go_dir="$HOME/.gvm/gos"
  local latest_version

  if [[ ! -d "$gvm_go_dir" ]]; then
    return 1
  fi

  latest_version=$(
    command ls "$gvm_go_dir" 2>/dev/null \
      | grep '^go[0-9]\+\.[0-9]\+\(\.[0-9]\+\)\?$' \
      | sort -Vr \
      | head -n 1
  )

  if [[ -n "$latest_version" && -d "$gvm_go_dir/$latest_version/bin" ]]; then
    _prepend_path_if_missing "$gvm_go_dir/$latest_version/bin"
  fi
}

_source_version_manager() {
  if [ ! -v ZAMBELZ_HELPER_PATH ]; then
    return
  fi

  source "$ZAMBELZ_HELPER_PATH/version-managers.zsh"
}

_walk_up_to_find_file() {
  local filename="$1"
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/$filename" ]]; then
      echo "$dir/$filename"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}

# dispatcher
verman() {
  local name="$1"
  local action="$2"

  if [[ -z "$name" || -z "$action" ]]; then
    echo "Usage: version-manager <pyenv|rbenv|jenv|gvm> <enable|disable|status>"
    return 1
  fi

  # pyenv
  _pyenv_status() {
    echo "pyenv status: ${Z_VERMAN_PYENV_STATUS:-disabled}"
  }
  _pyenv_enable() {
    if [[ ! -v Z_VERMAN_PYENV_STATUS || "$Z_VERMAN_PYENV_STATUS" == "disabled" ]]; then
      export Z_VERMAN_PYENV_STATUS="enabled"
      _source_version_manager
      echo "pyenv enabled"
    else
      echo "pyenv is already enabled"
    fi
  }
  _pyenv_disable() {
    if [[ -v Z_VERMAN_PYENV_STATUS && "$Z_VERMAN_PYENV_STATUS" == "enabled" ]]; then
      chpwd_functions=(${chpwd_functions:#*pyenv*})
      unset -f prompt_pyenv 2>/dev/null
      export Z_VERMAN_PYENV_STATUS="disabled"
      _source_version_manager
      echo "pyenv disabled"
    else
      echo "pyenv is already disabled"
    fi
  }

  # rbenv
  _rbenv_status() {
    echo "rbenv status: ${Z_VERMAN_RBENV_STATUS:-disabled}"
  }
  _rbenv_enable() {
    if [[ ! -v Z_VERMAN_RBENV_STATUS || "$Z_VERMAN_RBENV_STATUS" == "disabled" ]]; then
      export Z_VERMAN_RBENV_STATUS="enabled"
      _source_version_manager
      echo "rbenv enabled"
    else
      echo "rbenv is already enabled"
    fi
  }
  _rbenv_disable() {
    if [[ -v Z_VERMAN_RBENV_STATUS && "$Z_VERMAN_RBENV_STATUS" == "enabled" ]]; then
      precmd_functions=(${precmd_functions:#*rbenv*})
      unset -f prompt_rbenv 2>/dev/null
      export Z_VERMAN_RBENV_STATUS="disabled"
      _source_version_manager
      echo "rbenv disabled"
    else
      echo "rbenv is already disabled"
    fi
  }

  # jenv
  _jenv_status() {
    echo "jenv status: ${Z_VERMAN_JENV_STATUS:-disabled}"
  }
  _jenv_enable() {
    if [[ ! -v Z_VERMAN_JENV_STATUS || "$Z_VERMAN_JENV_STATUS" == "disabled" ]]; then
      export Z_VERMAN_JENV_STATUS="enabled"
      _source_version_manager
      echo "jenv enabled"
    else
      echo "jenv is already enabled"
    fi
  }
  _jenv_disable() {
    if [[ -v Z_VERMAN_JENV_STATUS && "$Z_VERMAN_JENV_STATUS" == "enabled" ]]; then
      preexec_functions=(${preexec_functions:#*jenv*})
      unset -f prompt_jenv 2>/dev/null
      export Z_VERMAN_JENV_STATUS="disabled"
      _source_version_manager
      echo "jenv disabled"
    else
      echo "jenv is already disabled"
    fi
  }

  # gvm
  _gvm_status() {
    echo "gvm status: ${Z_VERMAN_GVM_STATUS:-disabled}"
  }
  _gvm_enable() {
    if [[ ! -v Z_VERMAN_GVM_STATUS || "$Z_VERMAN_GVM_STATUS" == "disabled" ]]; then
      export Z_VERMAN_GVM_STATUS="enabled"
      _source_version_manager
      echo "gvm enabled"
    else
      echo "gvm is already enabled"
    fi
  }
  _gvm_disable() {
    if [[ -v Z_VERMAN_GVM_STATUS && "$Z_VERMAN_GVM_STATUS" == "enabled" ]]; then
      unset -f cd 2>/dev/null
      export Z_VERMAN_GVM_STATUS="disabled"
      _source_version_manager
      echo "gvm disabled"
    else
      echo "gvm is already disabled"
    fi
  }

  local fn_name="_${name}_${action}"

  if typeset -f "$fn_name" >/dev/null; then
    "$fn_name"
  else
    echo "Unknown version manager or action: $name $action"
    echo "Available: pyenv, rbenv, jenv, gvm"

    return 2
  fi
}

# pyenv
_lazy_load_pyenv() {
  PYENV_HOME="$HOME/.pyenv"
  if [ -d "$PYENV_HOME" ]; then
    unset -f pyenv
    [[ -d $PYENV_HOME/bin ]] && export PATH="$PYENV_HOME/bin:$PATH"
    eval "$(pyenv init - zsh)"
    pyenv "$@"
  fi
}
pyenv() {
  if [[ -v Z_VERMAN_PYENV_STATUS && "$Z_VERMAN_PYENV_STATUS" == "enabled" ]]; then
    _lazy_load_pyenv "$@"
  else
    echo "pyenv is disabled"
  fi
}

# rbenv
_lazy_load_rbenv() {
  unset -f rbenv
  eval "$(rbenv init --no-rehash - zsh)"

  # perform background rehash
  (rbenv rehash &) 2> /dev/null

  rbenv "$@"
}
rbenv() {
  if [[ -v Z_VERMAN_RBENV_STATUS && "$Z_VERMAN_RBENV_STATUS" == "enabled" ]]; then
    _lazy_load_rbenv "$@"
  else
    echo "rbenv is disabled"
  fi
}

# jenv
_lazy_load_jenv() {
  unset -f jenv
  eval "$(jenv init - --no-rehash)"

  # perform background rehash
  (jenv rehash &) 2> /dev/null

  jenv "$@"
}
jenv() {
  if [[ -v Z_VERMAN_JENV_STATUS && "$Z_VERMAN_JENV_STATUS" == "enabled" ]]; then
    _lazy_load_jenv "$@"
  else
    echo "jenv is disabled"
  fi
}

# gvm
_lazy_load_gvm() {
  if [[ -s "$HOME/.gvm/scripts/gvm" ]]; then
    unset -f gvm
    source "$HOME/.gvm/scripts/gvm"

    gvm "$@"
  fi
}
gvm() {
  if [[ -v Z_VERMAN_GVM_STATUS && "$Z_VERMAN_GVM_STATUS" == "enabled" ]]; then
    _lazy_load_gvm "$@"
  else
    echo "gvm is disabled"
  fi
}

# Fallback for disabled version managers
# pyenv
if [[ ! -v Z_VERMAN_PYENV_STATUS || "$Z_VERMAN_PYENV_STATUS" == "disabled" ]]; then
  export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
  _prepend_path_if_missing "$PYENV_ROOT/shims"

  if [[ -z "$PYENV_VERSION" && -f "$PYENV_ROOT/version" ]]; then
    export PYENV_VERSION="$(cat "$PYENV_ROOT/version")"
  fi
fi

# rbenv
if [[ ! -v Z_VERMAN_RBENV_STATUS || "$Z_VERMAN_RBENV_STATUS" == "disabled" ]]; then
  export RBENV_ROOT="${RBENV_ROOT:-$HOME/.rbenv}"
  _prepend_path_if_missing "$RBENV_ROOT/shims"

  if [[ -z "$RBENV_VERSION" && -f "$RBENV_ROOT/version" ]]; then
    export RBENV_VERSION="$(cat "$RBENV_ROOT/version")"
  fi
fi

# jenv
if [[ ! -v Z_VERMAN_JENV_STATUS || "$Z_VERMAN_JENV_STATUS" == "disabled" ]]; then
  _prepend_path_if_missing "$HOME/.jenv/shims"

  if [[ -z "$JAVA_HOME" ]]; then
    local JENV_VERSION_FILE="$HOME/.jenv/version"
    if [[ -f "$JENV_VERSION_FILE" ]]; then
      local JENV_VERSION="$(cat "$JENV_VERSION_FILE")"
      local JAVA_CANDIDATE="$HOME/.jenv/versions/$JENV_VERSION"
      if [[ -d "$JAVA_CANDIDATE" ]]; then
        export JAVA_HOME="$JAVA_CANDIDATE"
      fi
    else
      local JAVA_CANDIDATE=$(ls -d "$HOME/.jenv/versions/"* 2>/dev/null | sort -Vr | head -n 1)
      [[ -d "$JAVA_CANDIDATE" ]] && export JAVA_HOME="$JAVA_CANDIDATE"
    fi
  fi
fi

# gvm
if [[ ! -v Z_VERMAN_GVM_STATUS || "$Z_VERMAN_GVM_STATUS" == "disabled" ]]; then
  local GVM_HOME="$HOME/.gvm"
  local GVM_CURRENT_SYMLINK="$GVM_HOME/environments/current"

  local GVM_GOROOT GVM_PKGSET

  if [[ -L "$GVM_CURRENT_SYMLINK" ]]; then
    GVM_GOROOT=$(grep '^export GOROOT=' "$GVM_CURRENT_SYMLINK" | cut -d'=' -f2- | tr -d '"')
    GOPATH_LINE=$(grep '^export GOPATH=' "$GVM_CURRENT_SYMLINK" | cut -d'=' -f2- | tr -d '"')
  else
    GVM_GOROOT=$(ls -d "$GVM_HOME/gos/go"* 2>/dev/null | sort -Vr | head -n 1)
    GOPATH_LINE="$GVM_HOME/pkgsets/$(basename "$GVM_GOROOT")/global"
  fi

  if [[ -n "$GVM_GOROOT" && -d "$GVM_GOROOT" ]]; then
    export GOROOT="$GVM_GOROOT"
    export GOPATH="$GOPATH_LINE"
    mkdir -p "$GOPATH"
    _prepend_path_if_missing "$GOROOT/bin"
    _prepend_path_if_missing "$GOPATH/bin"
  fi
fi

# Auto-detect intended version per project
# pyenv
if [[ ! -v Z_VERMAN_PYENV_STATUS || "$Z_VERMAN_PYENV_STATUS" == "disabled" ]]; then
  local pyenv_ver_file
  pyenv_ver_file=$(_walk_up_to_find_file ".python-version")
  if [[ -n "$pyenv_ver_file" ]]; then
    local version
    version=$(<"$pyenv_ver_file")
    _prepend_path_if_missing "$HOME/.pyenv/versions/$version/bin"
  fi
fi

# rbenv
if [[ ! -v Z_VERMAN_RBENV_STATUS || "$Z_VERMAN_RBENV_STATUS" == "disabled" ]]; then
  local rbenv_ver_file
  rbenv_ver_file=$(_walk_up_to_find_file ".ruby-version")
  if [[ -n "$rbenv_ver_file" ]]; then
    local version
    version=$(<"$rbenv_ver_file")
    _prepend_path_if_missing "$HOME/.rbenv/versions/$version/bin"
  fi
fi

# jenv
if [[ ! -v Z_VERMAN_JENV_STATUS || "$Z_VERMAN_JENV_STATUS" == "disabled" ]]; then
  local jenv_ver_file
  jenv_ver_file=$(_walk_up_to_find_file ".java-version")
  if [[ -n "$jenv_ver_file" ]]; then
    local version
    version=$(<"$jenv_ver_file")
    export JAVA_HOME="$HOME/.jenv/versions/$version"
    _prepend_path_if_missing "$JAVA_HOME/bin"
  fi
fi

# gvm
if [[ ! -v Z_VERMAN_GVM_STATUS || "$Z_VERMAN_GVM_STATUS" == "disabled" ]]; then
  local go_ver_file
  go_ver_file=$(_walk_up_to_find_file ".go-version")
  if [[ -n "$go_ver_file" ]]; then
    local version
    version=$(<"$go_ver_file")
    export GOROOT="$HOME/.gvm/gos/go$version"
    export GOPATH="$HOME/.gvm/pkgsets/go$version/global"
    _prepend_path_if_missing "$GOROOT/bin"
    _prepend_path_if_missing "$GOPATH/bin"
  fi
fi
