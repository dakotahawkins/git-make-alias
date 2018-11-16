#!/bin/bash

main() {
    ################################
    # ADD ALIAS FUNCTIONALITY HERE #
    ################################
    :
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
