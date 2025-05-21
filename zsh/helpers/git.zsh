git_clean_pull() {
  local branch=$1

  git checkout -b temp && \
    git branch -D $branch && \
    git fetch --prune --all && \
    git checkout $branch && \
    git branch -D temp && \
    git gc
}
