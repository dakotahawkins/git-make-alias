#!/bin/bash

main() {
    local worktree_dir="$(git rev-parse --show-toplevel --show-cdup 2> /dev/null)"
    [[ $? -eq 0 ]] || {
        error_exit "Not in a git directory."
    }
    [[ "${worktree_dir}" == */ ]] && worktree_dir="${worktree_dir: : -1}"

    declare -a gitmodules_source_old=
    declare -a gitmodules_source_new=(--file "${worktree_dir}/.gitmodules")
    local from_hook=
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --post-checkout)
                shift
                gitmodules_source_old=(--blob "${1}:.gitmodules")
                ;;
            --post-merge)
                shift
                gitmodules_source_old=(--blob "ORIG_HEAD:.gitmodules")
                ;;
            *)
                error_exit "Unrecognized argument: $1"
                ;;
        esac
    fi

    mapfile -t NEW_SUBMODULES < \
        <( git config -z "${gitmodules_source_new[@]}" --get-regexp '\.path$' 2>/dev/null \
            | sed -nz 's/^[^\n]*\n//p' \
            | tr '\0' '\n' \
            | sort -u )

    [[ -n "${NEW_SUBMODULES[@]}" ]] && {
        echo
        echo "Updating submodules..."
        git submodule update --init --recursive || {
            error_exit "Failed to update submodules."
        }
        ## TODO: Not sure if necessary
        #git submodule --quiet foreach --recursive 'git-lfs pull' || {
        #    error_exit "Failed to pull submodule LFS files."
        #}
        echo "Done."
    }

    [[ -n "${gitmodules_source_old[@]}" ]] || no_error_exit

    mapfile -t OLD_SUBMODULES < \
        <( git config -z "${gitmodules_source_old[@]}" --get-regexp '\.path$' 2>/dev/null \
            | sed -nz 's/^[^\n]*\n//p' \
            | tr '\0' '\n' \
            | sort -u )

    mapfile -t DIRS_TO_REMOVE < \
        <( diff --unchanged-line-format='' \
                --old-line-format='%L' \
                --new-line-format='' \
                <( printf "%s\n" "${OLD_SUBMODULES[@]}" ) \
                <( printf "%s\n" "${NEW_SUBMODULES[@]}" ) )
    [[ -n "${DIRS_TO_REMOVE[@]}" ]] || no_error_exit

    declare -a dirs_with_tracked_files
    declare -a failed_to_remove_dirs
    local removed_any_dirs=
    for dir in "${DIRS_TO_REMOVE[@]}"; do
        [[ -d "${worktree_dir}/${dir}" ]] || continue

        [[ $(git ls-files "${worktree_dir}/${dir}" | wc -l) -eq 0 ]] || {
            dirs_with_tracked_files+=("  ${worktree_dir}/${dir}")
            continue
        }

        [[ -z "$removed_any_dirs" ]] && {
            echo
            echo "Removing old submodule directories:"
            removed_any_dirs=1
        }

        echo "  ${worktree_dir}/${dir}"
        rm -rf "${worktree_dir}/${dir}" > /dev/null 2>&1 || {
            failed_to_remove_dirs+=("  ${worktree_dir}/${dir}")
        }
    done

    [[ -n "${dirs_with_tracked_files[@]}" ]] && {
        echo
        echo "Directories contain tracked files and weren't removed:"
        for dir in "${dirs_with_tracked_files[@]}"; do
            echo "$dir"
        done
        echo
    }

    [[ -n "${failed_to_remove_dirs[@]}" ]] && {
        error_exit "Failed to remove directories:" "${failed_to_remove_dirs[@]}"
    }
}

error_exit() {
    [[ $# -gt 0 ]] && {
        echo
        echo "Fatal: $1" >&2
        echo
        shift
    }
    for msg in "$@"; do
        echo "$msg" >&2
    done
    [[ $# -gt 0 ]] && echo
    exit 1
}

no_error_exit() {
    [[ $# -gt 0 ]] && echo
    for msg in "$@"; do
        echo "$msg"
    done
    [[ $# -gt 0 ]] && echo
    exit 0
}

main "$@" || error_exit
exit 0
