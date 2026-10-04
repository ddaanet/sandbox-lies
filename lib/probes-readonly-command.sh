#!/usr/bin/env bash
# lib/probes-readonly-command.sh — the shell-command scan behind
# _readonly_print_facts' readfile= and merge=1/target= facts (readonly-path.md's
# readonly-path Probe facts table): _readonly_tokenize splits
# tool_input.command into words and segments, _readonly_readfile_arg and
# _readonly_merge_segment read them. Split out of
# lib/probes-readonly-facts.sh to keep that file under the line cap;
# lib/probes-readonly.sh sources both, so no other caller needs a source
# line of its own for it.
#
# set -u as in lib/probes-readonly.sh; bats does not set it, so setting it
# here keeps an unset variable an error when a caller sources this file
# directly. Under set -u, bash before 4.4 (macOS's 3.2, NFR-2) calls an empty
# array unbound, so every array that can be empty expands as
# ${a[@]+"${a[@]}"} or behind a count check.
set -u

# _readonly_tokenize <command> — sets _readonly_tokens to <command>'s words,
# each prefixed `w`, with a lone `|` between pipeline or list segments (an
# unquoted |, ;, & or newline, except an & right after > or < in the same
# word, which keeps 2>&1 or >&2 one word). Quotes and backslashes are
# removed as the shell removes them; a # opening a word runs to the line's
# end. Sets _readonly_tokens_cut=1 when the scan stops early: at the end of
# a line holding an unquoted << (a heredoc's body is not commands), or at
# 16384 characters, dropping the word cut there. That bound is NFR-3's: the
# loop costs tens of microseconds a character, and characters are read one
# at a time from a pipe because ${cmd:i:1} rescans the string on every call
# (a 40 KB command took 20 s that way). Residuals: $'...', $( ), backticks,
# subshells and braces are not parsed, so their contents read as words of
# the enclosing command; any << ends the scan at its line, arithmetic's
# included; a reader behind a cd, or a reader or git behind a variable
# assignment or another prefix word, is not recognised (readonly-path.md).
_readonly_tokenize() {
    local ch word='' invalue=0 quote='' esc=0 lts=0 heredoc=0 sep
    local nl=$'\n' tab=$'\t' max=16384
    _readonly_tokens=()
    _readonly_tokens_cut=0
    [ "${#1}" -le "$max" ] || _readonly_tokens_cut=1
    while IFS= read -r -d '' -n 1 ch; do
        # esc 1: after an unquoted backslash; 2: after one inside "...",
        # which only escapes " \ $ ` and newline.
        if [ "$esc" -eq 1 ]; then
            esc=0
            [ "$ch" = "$nl" ] || word="$word$ch" invalue=1
            continue
        fi
        if [ "$esc" -eq 2 ]; then
            esc=0
            case "$ch" in
                '"' | \\ | '$' | '`') word="$word$ch" ;;
                "$nl") ;;
                *) word="$word\\$ch" ;;
            esac
            continue
        fi
        # quote is ' or " inside quotes, # inside a comment.
        case "$quote" in
            "'")
                if [ "$ch" = "'" ]; then quote=''; else word="$word$ch"; fi
                continue
                ;;
            '"')
                case "$ch" in
                    '"') quote='' ;;
                    \\) esc=2 ;;
                    *) word="$word$ch" ;;
                esac
                continue
                ;;
            '#')
                [ "$ch" = "$nl" ] || continue
                quote=''
                ;;
        esac
        case "$ch" in
            '<') lts=$((lts + 1)) ;;
            *)
                [ "$lts" -ne 2 ] || heredoc=1
                lts=0
                ;;
        esac
        sep=''
        case "$ch" in
            "'" | '"') quote="$ch" invalue=1 ;;
            \\) esc=1 ;;
            '#')
                if [ -z "$word" ] && [ "$invalue" -eq 0 ]; then
                    quote='#'
                else
                    word="$word$ch"
                fi
                ;;
            ' ' | "$tab") sep=word ;;
            "$nl") sep=line ;;
            '|' | ';') sep=segment ;;
            '&')
                case "$word" in
                    *'>' | *'<') word="$word$ch" ;;
                    *) sep=segment ;;
                esac
                ;;
            *) word="$word$ch" invalue=1 ;;
        esac
        [ -n "$sep" ] || continue
        if [ -n "$word" ] || [ "$invalue" -eq 1 ]; then
            _readonly_tokens+=("w$word")
        fi
        word='' invalue=0
        [ "$sep" != word ] || continue
        _readonly_tokens+=('|')
        if [ "$sep" = line ] && [ "$heredoc" -eq 1 ]; then
            _readonly_tokens_cut=1
            return 0
        fi
    done < <(printf '%s' "${1:0:$max}")
    [ "$_readonly_tokens_cut" -eq 0 ] || return 0
    if [ -n "$word" ] || [ "$invalue" -eq 1 ]; then
        _readonly_tokens+=("w$word")
    fi
}

# _readonly_readfile_arg <cut> <token...> — the readfile= value: the first
# argument shaped like a command-output name (*.log, *.output, *.out, *.err;
# a leading < redirection stripped) once every command in every segment is
# one of the reader tools readonly-path.md names, with no output redirection and
# no in-place edit (sed -i/-I/--in-place, and sort -o and gawk -i inplace,
# which write as well); empty when <cut> is 1, since the unscanned rest may
# hold a writer. A `>` anywhere in a word counts as a redirection, quoted or
# not: awk's own `print > "f"` writes, so a quoted `>` in a grep pattern
# costing readfile= is the safe side. A name holding a newline cannot be a
# key line's value and is passed over.
_readonly_readfile_arg() {
    local cut="$1" tok word first='' seg_first=1 seg_ok=1 all_ok=1 in_seg=0
    local candidate='' nl=$'\n'
    shift
    [ "$cut" -eq 0 ] || return 0
    for tok in ${1+"$@"} '|'; do
        if [ "$tok" = '|' ]; then
            [ "$in_seg" -eq 0 ] || [ "$seg_ok" -eq 1 ] || all_ok=0
            seg_first=1 seg_ok=1 in_seg=0
            continue
        fi
        word="${tok#w}"
        in_seg=1
        if [ "$seg_first" -eq 1 ]; then
            seg_first=0
            first="$word"
            case "$first" in
                cat | head | tail | grep | sed | awk | cut | sort | uniq \
                    | wc | tr | less) ;;
                *) seg_ok=0 ;;
            esac
        fi
        case "$first:$word" in
            sed:--in-place* | sed:-[iI]* | sed:-[!-]*[iI]* | sort:-o* \
                | sort:-[!-]*o* | sort:--output* | awk:-i* | awk:--include*)
                seg_ok=0
                ;;
        esac
        case "$word" in
            *'>'*)
                case "$word" in
                    [0-9]'>&'[0-9] | '>&'[0-9]) ;;
                    *) all_ok=0 ;;
                esac
                ;;
        esac
        case "$word" in
            *"$nl"* | -*) ;;
            *.log | *.output | *.out | *.err)
                [ -n "$candidate" ] || candidate="${word##*<}"
                ;;
        esac
    done
    [ "$all_ok" -eq 1 ] && [ -n "$candidate" ] && printf '%s\n' "$candidate"
    return 0
}

# _readonly_merge_segment <token...> — for the first segment that opens with
# `git`, after skipping its own global options, and runs merge, pull,
# checkout, switch, rebase or cherry-pick: the subcommand, then each
# following word up to a literal -- (readonly-path.md's target= "before any
# --"), each NUL-terminated; nothing when no segment matches.
_readonly_merge_segment() {
    local tok word state=start skip_next=0 sub=''
    local -a cands=()
    for tok in ${1+"$@"}; do
        if [ "$tok" = '|' ]; then
            case "$state" in
                collect | stop) break ;;
            esac
            state=start
            skip_next=0
            continue
        fi
        word="${tok#w}"
        case "$state" in
            start)
                if [ "$word" = git ]; then
                    state=skip
                else
                    state=skipseg
                fi
                ;;
            skip)
                if [ "$skip_next" -eq 1 ]; then
                    skip_next=0
                    continue
                fi
                case "$word" in
                    -C | -c | --git-dir | --work-tree | --namespace \
                        | --super-prefix)
                        skip_next=1
                        ;;
                    -*) : ;;
                    merge | pull | checkout | switch | rebase | cherry-pick)
                        sub="$word"
                        state=collect
                        ;;
                    *) state=skipseg ;;
                esac
                ;;
            collect)
                if [ "$word" = -- ]; then
                    state=stop
                else
                    cands+=("$word")
                fi
                ;;
        esac
    done
    [ -n "$sub" ] || return 0
    printf '%s\0' "$sub" ${cands[@]+"${cands[@]}"}
}
