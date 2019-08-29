#!/bin/bash

main() {
    local no_edit=
    [[ $1 = --no-edit ]] && {
        no_edit=1
        shift
    }

    local bootstrapping=
    if [[ $# -eq 0 ]]; then
        [[ "$_IN_MAKE_ALIAS" = "$make_alias" ]] && {
            error_exit "Supply the name of an alias to make"
        }
        echo "Bootstrapping..."
        echo
        config_alias --check "$make_alias"
        bootstrapping=1
    elif [[ $# -gt 1 ]]; then
        error_exit "You can only make one alias at a time"
    else
        [[ "$_IN_MAKE_ALIAS" != "$make_alias" ]] && {
            error_exit "Use the alias \"$make_alias\" to make new aliases"
        }
        [[ "$1" = "$make_alias" ]] && {
            error_exit "Don't use \"$make_alias\" alias to make itself"
        }
    fi

    [[ -d "$alias_dir" ]] || mkdir -p "$alias_dir" || {
        error_exit "Failed to create git-make-alias dir \"$alias_dir\""
    }

    [[ -f "$alias_dir/$make_alias.sh" ]] && \
    [[ -f "$alias_dir/.template" ]] && \
    [[ -f "$alias_dir/.editorconfig" ]] && \
    [[ -f "$alias_dir/.gitattributes" ]] || {
        install_files
    }

    [[ "$(readlink -f "$0")" != "$alias_dir/$make_alias.sh" ]] && {
        cp -f -T "$(readlink -f "$0")" "$alias_dir/$make_alias.sh" || error_exit
    }

    cd "$alias_dir" || error_exit
    git init -q . || error_exit
    git config core.whitespace \
        "trailing-space,cr-at-eol,tab-in-indent,tabwidth=4" > /dev/null 2>&1
    git config --get "user.name" > /dev/null 2>&1 || {
        git config user.name "Unknown User" > /dev/null 2>&1
    }
    git config --get "user.email" > /dev/null 2>&1 || {
        git config user.email "user@email.com" > /dev/null 2>&1
    }

    add_file ".template" ".editorconfig" ".gitattributes"
    add_filex "./$make_alias.sh"
    commit

    [[ -n "$bootstrapping" ]] && {
        config_alias "$make_alias"
        no_error_exit \
            "Done!" \
            "" \
            "Files for the alias \"$make_alias\" and any new aliases you "`
            `"create can be found in \"$alias_dir\"" \
            "" \
            "Create new aliases with 'git $make_alias <alias_name>'"
    }

    declare -r new_alias="$1"
    config_alias --check "$new_alias"

    declare -r new_alias_filename="$alias_dir/$new_alias.sh"
    cp --no-clobber ".template" "$new_alias.sh" > /dev/null 2>&1 || {
        error_exit "Failed to copy alias template to \"$new_alias_filename\""
    }
    add_filex "./$new_alias.sh"
    commit
    config_alias "$new_alias"

    [[ -n "$no_edit" ]] && {
        no_error_exit \
            "Configured alias \"$new_alias\" at \"$new_alias_filename\"" \
            "You will need to edit it yourself." \
            "" \
            "Done!"
    }

    echo "Configured alias \"$new_alias\" at \"$new_alias_filename\""
    echo "Opening file for editing..."
    echo
    edit_alias "$new_alias_filename" || {
        no_error_exit \
            "Failed to edit \"$new_alias_filename\"." \
            "You will need to edit it yourself." \
            "" \
            "Done!"
    }

    add_filex "./$new_alias.sh"
    commit
}

add_filex() {
    chmod +x "$@" || error_exit
    git add --chmod=+x -- "$@" || error_exit
}

add_file() {
    git add -- "$@" || error_exit
}

commit() {
    git diff --cached --quiet || \
        git commit --quiet --no-gpg-sign \
            -m "Added/updated $(git diff --cached --name-only | tr '\n' ' ')" \
            -m "$(git diff --cached --name-status)" > /dev/null || error_exit
}

config_alias() {
    declare -ar gcg=(git config --global)

    [[ $1 = --check ]] && {
        "${gcg[@]}" --includes --get "alias.$2" > /dev/null 2>&1 && {
            error_exit "Alias name \"$2\" conflicts with existing global alias."
        }
        return
    }

    declare -a alias_filename="$(printf "%q" "$alias_dir/$1.sh")"
    "${gcg[@]}" "alias.$1" "!_IN_MAKE_ALIAS=\"$1\" $alias_filename" || {
        error_exit
    }
}

edit_alias() {
    [[ -z "$GIT_EDITOR" ]] && {
        GIT_EDITOR="$(git var GIT_EDITOR)" || return $?
    }
    eval "$GIT_EDITOR" '"$@"'
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

declare -r make_alias="${GIT_MAKE_ALIAS_CMD:-make-alias}"
declare -r alias_dir="$(readlink -f ${GIT_MAKE_ALIAS_DIR:-~/.git-make-alias})"
declare -r script_dir="$(dirname "$(readlink -f "$0")")"
cd "$script_dir" || {
    error_exit "Failed to cd to running script directory"
}

install_files() {
    readarray t <<'    EOF'
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
    EOF
    printf '%s' "${t[@]#        }" > "$alias_dir/.template" || {
        error_exit "Failed to install \"$alias_dir/.template\""
    }

    readarray ec <<'    EOF'
        root = true

        [*]
        charset = utf-8
        end_of_line = lf
        insert_final_newline = true
        indent_style = space
        indent_size = 4
        trim_trailing_whitespace = true
    EOF
    printf '%s' "${ec[@]#        }" > "$alias_dir/.editorconfig" || {
        error_exit "Failed to install \"$alias_dir/.editorconfig\""
    }

    readarray ga <<'    EOF'
        * text eol=lf
    EOF
    printf '%s' "${ga[@]#        }" > "$alias_dir/.gitattributes" || {
        error_exit "Failed to install \"$alias_dir/.gitattributes\""
    }
}

main "$@" && no_error_exit "Done!" || error_exit
