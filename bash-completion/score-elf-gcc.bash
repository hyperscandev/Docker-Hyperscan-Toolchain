# score-elf-gcc(1) completion                                        -*- shell-script -*-

_comp_cmd_gcc()
{
    local cur prev words cword comp_args
    _comp_initialize -- "$@" || return

    # Test that GCC is recent enough and if not fallback to
    # parsing of --completion option.
    if ! "$1" --completion=" " 2>/dev/null; then
        if [[ $cur == -* ]]; then
            local cc=$("$1" -print-prog-name=cc1 2>/dev/null)
            [[ $cc ]] || return
            _comp_compgen_split -- "$("$cc" --help 2>/dev/null | tr '\t' ' ' |
                command sed -n 's/^ \{1,\}\(-[^][ <>]*\).*/\1/p')"
            [[ ${COMPREPLY-} == *= ]] && compopt -o nospace
        else
            _comp_compgen_filedir
        fi
        return
    fi

    local prev2 argument="" prefix prefix_length
    # extract also for situations like: -fsanitize=add
    if ((cword > 2)); then
        prev2="${COMP_WORDS[cword - 2]}"
    fi

    # sample: -fsan
    if [[ $cur == -* ]]; then
        argument=$cur
        prefix=""
    # sample: -fsanitize=
    elif [[ $cur == "=" && $prev == -* ]]; then
        argument=$prev$cur
        prefix=$prev$cur
    # sample: -fsanitize=add
    elif [[ $prev == "=" && $prev2 == -* ]]; then
        argument=$prev2$prev$cur
        prefix=$prev2$prev
    # sample: --param lto-
    elif [[ $prev == --param ]]; then
        argument="$prev $cur"
        prefix="$prev "
    fi

    if [[ ! $argument ]]; then
        _comp_compgen_filedir
    else
        # In situation like '-fsanitize=add' $cur is equal to last token.
        # Thus we need to strip the beginning of suggested option.
        prefix_length=$((${#prefix} + 1))
        local flags=$("$1" --completion="$argument" | cut -c $prefix_length-)
        [[ ${flags} == "=*" ]] && compopt -o nospace 2>/dev/null
        _comp_compgen -R -- -W "$flags"
    fi
} &&
    complete -F _comp_cmd_gcc \
    score-elf-gcc \
    score-elf-g++ &&
    _comp_cmd_gcc__setup_cmd()
    {
        local REPLY
        _comp_realcommand "$1"
        if [[ $REPLY == *$2* ]] ||
            "$1" --version 2>/dev/null | command grep -q GCC; then
            complete -F _comp_cmd_gcc "$1"
        else
            complete -F _comp_complete_minimal "$1"
        fi
    } &&
        _comp_cmd_gcc__setup_cmd score-elf-cc score-elf-gcc &&
        _comp_cmd_gcc__setup_cmd score-elf-c++ score-elf-g++ &&
        unset -f _comp_cmd_gcc__setup_cmd

# ex: filetype=sh
