#!/bin/bash

main() {
    local force_opt=
    local remote_opts=0
    local source_remote=
    local dest_remote=
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                [[ "$remote_opts" -eq 0 ]] && force_opt="--force --prune" || error_exit "Force option must be the first option"
                shift
                ;;
            -*)
                error_exit "Unexpected option: \"$1\""
            *)
                [[ "$remote_opts" -eq 0 ]] && {
                    remote_opts=1
                    source_remote="$1"
                } || [[ "$remote_opts" -eq 1 ]] && {
                    remote_opts=2
                    dest_remote="$1"
                } || error_exit "Unexpected option: \"$1\""
                shift
                ;;
        esac
    done

    git fetch "$source_remote" || error_exit
    git push "$force_opt" refs/remotes/origin/*:refs/heads/* refs/heads/*:refs/heads/* refs/tags/*:refs/tags/* || error_exit
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
