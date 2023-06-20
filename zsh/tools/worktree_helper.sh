#!/usr/bin/env bash

COLOR_OUTPUT='\033[0;31m'

function worktree_list {

    if [ ! -d .git ] && [ ! -f .git ]; then
		cd current
    fi

	git worktree list
}

function worktree_add {

    local new_worktree=$1

    if [ ! -d .git ] && [ ! -f .git ]; then
        echo "${COLOR_OUPUT}There is not git associated in this project"
        return
    fi

    git worktree add "../$new_worktree"

    cd ..

    if [ -d current ]; then
        rm current
    fi

    ln -s "$new_worktree" current

    cd current

    git worktree list
}

function worktree_remove {

	local current_dir_name=${PWD##*/}
	local target_worktree=$1

    if [ -d .git ] || [ -f .git ]; then
        cd ..
    fi

    if [ ! -d "$target_worktree" ]; then
        echo "${COLOR_OUPUT}Target worktree '$target_worktree' doesn't exists"
        return
    fi

    local current_link=$(ls -l | grep current | awk '{ print $11 }')
	local next_dir="$current_link"

    if [ "$target_worktree" = "$current_link" ]; then

        local next_dir=""
        local worktrees_dir=($(ls -d *))

        for worktree in "${worktrees_dir[@]}"; do
            if [ -d "$worktree" ]; then
                if [ "$worktree" = "master" ] || [ "$worktree" = "main" ]; then
                    next_dir="$worktree"
                    break
                fi
            fi
        done
	fi

    if [ "$next_dir" = "" ]; then
        echo "${COLOR_OUPUT}Failed to remove target worktree: '$target_worktree'"
        return
    fi

    rm current
    rm -rf "$target_worktree"

    ln -s "$next_dir" current
    cd current

	git worktree prune
	git worktree list
}

function worktree_switch {

    local target_worktree=$1

    if [ -d .git ] || [ -f .git ]; then
        cd ..
    fi

    if [ ! -d "$target_worktree" ]; then
        echo "${COLOR_OUPUT}Target worktree '$target_worktree' doesn't exists"
        return
    fi

    if [ -d current ]; then
        rm current
    fi

    ln -s "$target_worktree" current

    cd current
}

