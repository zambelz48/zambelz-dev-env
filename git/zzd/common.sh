# shellcheck shell=bash

GIT_MODULE_SSH_COMMAND="ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=6"

_git_module_settings() {
  printf '%s\t%s\n' core.hooksPath .githooks
  printf '%s\t%s\n' core.sshCommand "$GIT_MODULE_SSH_COMMAND"
}

_git_module_current() {
  git -C "${ZZD_ROOT:?}" config --get "$1" || true
}
