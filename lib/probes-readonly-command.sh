#!/usr/bin/env bash
# Node names cited here (readonly-path.md, detectors.md) are files of the plugin
# repository's docs/references/, which the plugin does not ship.
# lib/probes-readonly-command.sh — the shell-command scan behind
# _readonly_print_facts' readfile= and merge=1/target= facts (readonly-path.md's
# readonly-path Probe facts table): _readonly_tokenize splits
# tool_input.command into words and segments, _readonly_readfile_arg and
# _readonly_merge_segment read them. Sourced with
# lib/probes-readonly-facts.sh by lib/probes-readonly.sh, so no other caller needs a source
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
# 16384 characters, dropping the word cut there. That bound is NFR-3's.
# Characters are read one at a time from a pipe because ${cmd:i:1} rescans
# the string on every call (a 40 KB command took 20 s that way), and each
# lands in a pending run of about 256 characters (257 after a kept backslash
# pair) that joins `word` only when it fills or the word ends. A # or & never
# joins it: `invalue` stands for word's emptiness (0 means word and run are
# both empty) and `wlast` for the last character of what has joined, read only
# while the run is empty. The one copy that grows with the word is the
# 256-character join (at most 64 per word, under the 16384 cap), so a word
# dense in # or >& costs what a plain one does: 16384 characters of a letter
# then # took 1.3 s on bash 5.2 and 3.7 s on 3.2.0 in C.UTF-8 (5.5 s and 66.7 s
# before), and of >& 1.7 s and 4.6 s (3.9 s and 38.5 s before).
# Residuals: $'...', $( ), backticks, subshells and braces are not parsed, so
# their contents read as words of the enclosing command; any << ends the scan
# at its line, arithmetic's included; a reader behind a cd, or a reader or git
# behind a variable assignment or another prefix word, is not recognised
# (readonly-path.md).
_readonly_tokenize() {
    local ch word='' run='' invalue=0 quote='' esc=0 lts=0 heredoc=0 sep
    local wlast='' last
    local nl=$'\n' tab=$'\t' max=16384
    _readonly_tokens=()
    _readonly_tokens_cut=0
    [ "${#1}" -le "$max" ] || _readonly_tokens_cut=1
    while IFS= read -r -d '' -n 1 ch; do
        if [ "${#run}" -ge 256 ]; then
            wlast="${run: -1}"
            word="$word$run" run=''
        fi
        # esc 1: after an unquoted backslash; 2: after one inside "...",
        # which only escapes " \ $ ` and newline.
        if [ "$esc" -eq 1 ]; then
            esc=0
            [ "$ch" = "$nl" ] || run="$run$ch" invalue=1
            continue
        fi
        if [ "$esc" -eq 2 ]; then
            esc=0
            case "$ch" in
                '"' | \\ | '$' | '`') run="$run$ch" ;;
                "$nl") ;;
                *) run="$run\\$ch" ;;
            esac
            continue
        fi
        # quote is ' or " inside quotes, # inside a comment.
        case "$quote" in
            "'")
                if [ "$ch" = "'" ]; then quote=''; else run="$run$ch"; fi
                continue
                ;;
            '"')
                case "$ch" in
                    '"') quote='' ;;
                    \\) esc=2 ;;
                    *) run="$run$ch" ;;
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
                # invalue 0 means nothing has joined the word or the run:
                # every character they hold set invalue.
                if [ "$invalue" -eq 0 ]; then
                    quote='#'
                else
                    run="$run$ch"
                fi
                ;;
            ' ' | "$tab") sep=word ;;
            "$nl") sep=line ;;
            '|' | ';') sep=segment ;;
            '&')
                last="${run: -1}"
                [ -n "$run" ] || last="$wlast"
                case "$last" in
                    '>' | '<') run="$run$ch" ;;
                    *) sep=segment ;;
                esac
                ;;
            *) run="$run$ch" invalue=1 ;;
        esac
        [ -n "$sep" ] || continue
        word="$word$run" run=''
        if [ -n "$word" ] || [ "$invalue" -eq 1 ]; then
            _readonly_tokens+=("w$word")
        fi
        word='' invalue=0 wlast=''
        [ "$sep" != word ] || continue
        _readonly_tokens+=('|')
        if [ "$sep" = line ] && [ "$heredoc" -eq 1 ]; then
            _readonly_tokens_cut=1
            return 0
        fi
    done < <(printf '%s' "${1:0:$max}")
    [ "$_readonly_tokens_cut" -eq 0 ] || return 0
    word="$word$run"
    if [ -n "$word" ] || [ "$invalue" -eq 1 ]; then
        _readonly_tokens+=("w$word")
    fi
}

# _readonly_readfile_arg <cut> <token...> — the readfile= value: the first
# input operand or < target shaped like a command-output name (*.log,
# *.output, *.out, *.err; text through the last < stripped), once every
# command in every segment is one of the reader tools readonly-path.md names,
# with no output redirection and no writer form (sed -i/-I/--in-place,
# sort -o/--output, awk -i/--include, uniq with a second operand); empty when
# <cut> is 1, since the unscanned rest may hold a writer. Never an input
# operand: a word opening with -, unless a < in it redirects; the
# first operand of grep, sed or awk, its pattern or program, unless an -e or
# -f came earlier in the segment; the word after a separate -e or -f, its
# argument. The name after a lone < is input, never the pattern. A `>`
# anywhere in a word counts as a redirection, quoted or not, except a
# descriptor duplication (2>&1, >&2): awk's own `print > "f"` writes, so a
# quoted `>` in a grep pattern costing readfile= is the safe side. A name
# holding a newline cannot be a key line's value and is passed over, and so
# is one holding *, ?, [, { or $, a glob, a brace or a $ expansion: quoted
# too, since the tokenizer has removed the quotes. A backtick substitution,
# which the scan does not parse, is not skipped. The rule's residuals (other options'
# separate arguments, clustered and long -e/-f forms, sed's w, a descriptor
# duplication in an operand slot, and more) are listed in readonly-path.md
# after its Probe facts table.
_readonly_readfile_arg() {
    local cut="$1" tok word first='' seg_first=1 seg_ok=1 all_ok=1 in_seg=0
    local candidate='' nl=$'\n' pat=0 lt=0 not_op uops=0 uend=0
    shift
    [ "$cut" -eq 0 ] || return 0
    for tok in ${1+"$@"} '|'; do
        if [ "$tok" = '|' ]; then
            [ "$in_seg" -eq 0 ] || [ "$seg_ok" -eq 1 ] || all_ok=0
            seg_first=1 seg_ok=1 in_seg=0 pat=0 lt=0 uops=0 uend=0
            continue
        fi
        word="${tok#w}"
        # not_op: the command word, or the name after a lone < (or 0<).
        in_seg=1 not_op=$lt lt=0
        case "$word" in
            *'<') lt=1 ;;
        esac
        if [ "$seg_first" -eq 1 ]; then
            seg_first=0 not_op=1
            first="$word"
            case "$first" in
                grep | sed | awk) pat=1 ;;
                cat | head | tail | cut | sort | uniq | wc | tr | less) ;;
                *) seg_ok=0 ;;
            esac
        fi
        case "$first:$word" in
            sed:--in-place* | sed:-[iI]* | sed:-[!-]*[iI]* | sort:-o* \
                | sort:-[!-]*o* | sort:--output* | awk:-i* | awk:--include*)
                seg_ok=0
                ;;
        esac
        # uniq's second operand is the file it writes. A lone - (stdin) is an
        # operand, and so is every word after --; a word holding > is a
        # redirection; in a word holding <, only text ahead of the first <
        # that is not a descriptor number is an operand (x in x<in.log).
        if [ "$not_op" -eq 0 ] && [ "$first" = uniq ]; then
            case "$uend:$word" in
                0:--) uend=1 ;;
                *'>'* | 0:-?*) ;;
                *'<'*)
                    case "${word%%<*}" in
                        *[!0-9]*) uops=$((uops + 1)) ;;
                    esac
                    ;;
                *) uops=$((uops + 1)) ;;
            esac
            [ "$uops" -lt 2 ] || seg_ok=0
        fi
        case "$word" in
            *'>'*)
                case "$word" in
                    [0-9]'>&'[0-9] | '>&'[0-9]) ;;
                    *) all_ok=0 ;;
                esac
                ;;
        esac
        # pat 1: the first operand of grep, sed or awk is the pattern or
        # program, never input. pat 2: the word after a separate -e or -f is
        # that option's argument, even one opening with -. In a word holding
        # <, only text ahead of the first < that is not a descriptor number is
        # an operand (x in x<in.log); a quoted < reads as a redirection too,
        # so '<div' is not taken as the pattern and the input after it is
        # lost, the safe side.
        if [ "$not_op" -eq 0 ] && [ "$pat" -ne 0 ]; then
            case "$pat:$word" in
                1:-*) ;;
                *'<'*)
                    case "${word%%<*}" in
                        *[!0-9]*) pat=0 ;;
                    esac
                    ;;
                *)
                    pat=0
                    continue
                    ;;
            esac
        fi
        # -e or -f, glued or not, supplies the pattern, so the first operand
        # after it is input. Clustered (-ne) and long forms are not
        # recognised.
        if [ "$not_op" -eq 0 ]; then
            case "$first:$word" in
                grep:-[ef] | sed:-[ef] | awk:-[ef]) pat=2 ;;
                grep:-[ef]?* | sed:-[ef]?* | awk:-[ef]?*) pat=0 ;;
            esac
        fi
        # A word opening with - is an option, never input, unless
        # a < in it redirects from the name after it, as wc -l<x.log does.
        case "$word" in
            *"$nl"*) ;;
            [!-]* | *'<'*)
                case "$word" in
                    *.log | *.output | *.out | *.err)
                        case "${word##*<}" in
                            *[*?[\{\$]*) ;;
                            *) [ -n "$candidate" ] || candidate="${word##*<}" ;;
                        esac
                        ;;
                esac
                ;;
        esac
    done
    [ "$all_ok" -eq 1 ] && [ -n "$candidate" ] && printf '%s\n' "$candidate"
    return 0
}

# _readonly_merge_segment <token...> — for the first segment that opens with
# `git`, after skipping its own global options, and runs merge, pull,
# checkout, switch, rebase or cherry-pick: the subcommand; then 1 when that
# segment is the call's only such segment and git runs where the probe looks
# (no -C, --git-dir or --work-tree on it, no cd or pushd word in an earlier
# segment), else 0; then each following word up to and including a literal --
# (readonly-path.md's target= "before any --", which the -- record ends), each
# NUL-terminated; nothing when no segment matches.
_readonly_merge_segment() {
    local tok word state=start skip_next=0 sub='' moved=0 seg_moved=0 sole=1
    local -a cands=()
    for tok in ${1+"$@"}; do
        if [ "$tok" = '|' ]; then
            state=start
            skip_next=0
            seg_moved=0
            continue
        fi
        word="${tok#w}"
        case "$state" in
            start)
                case "$word" in
                    git) state=skip ;;
                    cd | pushd)
                        [ -n "$sub" ] || moved=1
                        state=skipseg
                        ;;
                    *) state=skipseg ;;
                esac
                ;;
            skipseg)
                # any cd or pushd word before the git segment, however the
                # segment opens ({ cd x; ... }), moves git conservatively
                case "$word" in
                    cd | pushd) [ -n "$sub" ] || moved=1 ;;
                esac
                ;;
            skip)
                if [ "$skip_next" -eq 1 ]; then
                    skip_next=0
                    continue
                fi
                case "$word" in
                    -C | --git-dir | --work-tree)
                        seg_moved=1
                        skip_next=1
                        ;;
                    -c | --namespace | --super-prefix) skip_next=1 ;;
                    --git-dir=* | --work-tree=*) seg_moved=1 ;;
                    -*) : ;;
                    merge | pull | checkout | switch | rebase | cherry-pick)
                        if [ -n "$sub" ]; then
                            sole=0
                            break
                        fi
                        sub="$word"
                        [ "$seg_moved" -eq 0 ] || moved=1
                        state=collect
                        ;;
                    *) state=skipseg ;;
                esac
                ;;
            collect)
                cands+=("$word")
                if [ "$word" = -- ]; then
                    state=stop
                fi
                ;;
        esac
    done
    [ -n "$sub" ] || return 0
    [ "$moved" -eq 0 ] || sole=0
    printf '%s\0' "$sub" "$sole" ${cands[@]+"${cands[@]}"}
}
