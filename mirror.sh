#!/bin/bash

main() {
    declare -a force_opts
    local non_ff_opt=
    local remote_opts=0
    local do_fetch=1
    local source_remote=
    local dest_remote=
    declare -a extra_git_config
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                [[ "$remote_opts" -eq 0 ]] && {
                    force_opts=(--force --prune)
                    non_ff_opt=+
                } || error_exit "Force option must be the specified before remotes"
                shift
                ;;
            -n|--no-fetch)
                [[ "$remote_opts" -eq 0 ]] || {
                    error_exit "No-fetch option must be specified before remotes"
                }
                do_fetch=0
                shift
                ;;
            [-]*)
                error_exit "Unexpected option: \"$1\""
                ;;
            *)
                if [[ "$remote_opts" -eq 0 ]]; then
                    remote_opts=1
                    source_remote="$1"
                elif [[ "$remote_opts" -eq 1 ]]; then
                    remote_opts=2
                    dest_remote="$1"
                else
                    error_exit "Unexpected option: \"$1\""
                fi
                shift
                ;;
        esac
    done

    command -v git-lfs >/dev/null 2>&1 && {
        if [[ "$do_fetch" -eq 1 ]]; then
            git "${extra_git_config[@]}" lfs fetch --all $source_remote || error_exit
        else
            extra_git_config+=(-c lfs.allowincompletepush=true)
        fi
    }

    [[ "$do_fetch" -eq 1 ]] && {
        git "${extra_git_config[@]}" fetch $source_remote || error_exit
    }

    git "${extra_git_config[@]}" push "${force_opts[@]}" $dest_remote \
        ${non_ff_opt}refs/remotes/$source_remote/*:refs/heads/* \
        ${non_ff_opt}refs/heads/*:refs/heads/* \
        ${non_ff_opt}refs/tags/*:refs/tags/* || error_exit
}

error_exit() {
    [[ $# -gt 0 ]] && {
        echo "Fatal: $1" >&2
        shift
    } || {
        echo "Unknown error."
    }
    for msg in "$@"; do
        echo "$msg" >&2
    done
    echo
    exit 1
}

no_error_exit() {
    for msg in "$@"; do
        echo "$msg"
    done
    echo
    exit 0
}

main "$@" || error_exit
exit 0
