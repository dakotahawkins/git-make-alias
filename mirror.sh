#!/bin/bash

main() {
    declare -a force_opts
    local non_ff_opt=
    local remote_opts=0
    local source_remote=
    local dest_remote=
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                [[ "$remote_opts" -eq 0 ]] && {
                    force_opts=(--force --prune)
                    non_ff_opt=+
                } || error_exit "Force option must be the first option"
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

    git fetch $source_remote || error_exit
    git push "${force_opts[@]}" $dest_remote \
        ${non_ff_opt}refs/remotes/$source_remote/*:refs/heads/* \
        ${non_ff_opt}refs/heads/*:refs/heads/* \
        ${non_ff_opt}refs/tags/*:refs/tags/* || error_exit
}

error_exit() {
    [[ $# -gt 0 ]] && {
        echo "Fatal: $1" >&2
        shift
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
