#!/usr/bin/env bash
# lib/probes-readonly-facts.sh — the readfile=/merge=1/target=/match= facts
# _readonly_print_facts derives for probe_readonly_path under writable and
# nopath (detectors.md's readonly-path Probe facts table, Item 8.0 slice 3).
# Split out of lib/probes-readonly.sh to keep that file under the line cap;
# lib/probes-readonly.sh sources this file, so no other caller needs a
# source line of its own for it.
#
# set -u as in lib/probes-readonly.sh; bats does not set it, so setting it
# here keeps an unset variable an error when a caller sources this file
# directly.
set -u

# _readonly_print_facts <text> <command> <path> <cwd> — the writable/nopath
# tail of the A-3 contract (detectors.md's readonly-path Probe facts table):
# readfile=, merge=1, target= and match= lines, derived from <text> and
# <command> only — never from the outcome (D-1). <path> is the extracted
# refusal path, empty under nopath; the repository search starts there, or
# at <cwd> when there is none (detectors.md: "the path's nearest existing
# directory, else the cwd's" — walking up from <path> reaches the same
# first .git ancestor either way, since a check below a nonexistent
# directory can never succeed, so no separate existence walk is needed).
_readonly_print_facts() {
    local text="$1" command="$2" path="$3" cwd="$4"
    local readfile scan sub='' repo start line first=1 target
    local -a cands=()

    readfile=$(_readonly_readfile_arg "$command")
    [ -z "$readfile" ] || printf 'readfile=%s\n' "$readfile"

    scan=$(_readonly_merge_segment "$command")
    if [ -z "$scan" ] && ! _readonly_partial_checkout_text "$text"; then
        return 0
    fi
    printf 'merge=1\n'
    [ -n "$scan" ] || return 0

    while IFS= read -r line; do
        if [ "$first" -eq 1 ]; then
            sub="$line"
            first=0
        else
            cands+=("$line")
        fi
    done < <(printf '%s\n' "$scan")

    # target= is only attempted after these three subcommands (detectors.md);
    # pull, rebase and cherry-pick still fire merge=1 above but name no ref.
    case "$sub" in
        merge | checkout | switch) ;;
        *) return 0 ;;
    esac

    start="$path"
    [ -n "$start" ] || start="$cwd"
    repo=$(_readonly_git_dir "$start") || return 0

    target=$(_readonly_resolve_target "$repo" "${cands[@]}") || return 0
    printf 'target=%s\n' "$target"
    _readonly_print_matches "$repo" "$target"
}

# _readonly_readfile_arg <command> — the readfile= value: the first argument
# shaped like a command-output name (*.log, *.output, *.out, *.err) once
# every command in every pipeline and list of <command> is one of the reader
# tools detectors.md names, with no output redirection and, for sed, no
# in-place edit; empty otherwise.
_readonly_readfile_arg() {
    local cmd="$1" tok first_word='' seg_first=1 seg_ok=1 all_ok=1 in_seg=0
    local candidate=''
    while IFS= read -r tok; do
        if [ "$tok" = $'\001' ]; then
            [ "$in_seg" -eq 0 ] || [ "$seg_ok" -eq 1 ] || all_ok=0
            seg_first=1
            seg_ok=1
            in_seg=0
            first_word=''
            continue
        fi
        in_seg=1
        if [ "$seg_first" -eq 1 ]; then
            seg_first=0
            first_word="$tok"
            case "$first_word" in
                cat | head | tail | grep | sed | awk | cut | sort | uniq \
                    | wc | tr | less) ;;
                *) seg_ok=0 ;;
            esac
        fi
        if [ "$first_word" = sed ]; then
            case "$tok" in
                -i*) seg_ok=0 ;;
            esac
        fi
        case "$tok" in
            *'>'*)
                case "$tok" in
                    [0-9]'>&'[0-9] | '>&'[0-9]) ;;
                    *) all_ok=0 ;;
                esac
                ;;
        esac
        case "$tok" in
            *.log | *.output | *.out | *.err)
                [ -n "$candidate" ] || candidate="$tok"
                ;;
        esac
    done < <(_readonly_tokenize "$cmd")
    [ "$in_seg" -eq 0 ] || [ "$seg_ok" -eq 1 ] || all_ok=0
    [ "$all_ok" -eq 1 ] && [ -n "$candidate" ] && printf '%s\n' "$candidate"
    return 0
}

# _readonly_tokenize <command> — <command>'s words, one per line, single and
# double quotes stripped and their content kept verbatim including blanks; a
# line holding only \001 marks a boundary between pipeline or list segments
# (an unquoted |, ; or &, except an & right after > or < in the same word,
# which keeps a duplication form like 2>&1 or >&2 one word). Residual: a
# reader behind a cd or a variable assignment is not recognised
# (detectors.md); this scan does not model those either.
_readonly_tokenize() {
    local cmd="$1" i=0 len ch word='' invalue=0 quote=''
    local -a out=()
    len=${#cmd}
    while [ "$i" -lt "$len" ]; do
        ch="${cmd:$i:1}"
        if [ -n "$quote" ]; then
            if [ "$ch" = "$quote" ]; then
                quote=''
            else
                word="$word$ch"
            fi
            i=$((i + 1))
            continue
        fi
        case "$ch" in
            "'" | '"')
                quote="$ch"
                invalue=1
                ;;
            ' ' | $'\t')
                if [ -n "$word" ] || [ "$invalue" -eq 1 ]; then
                    out+=("$word")
                fi
                word=''
                invalue=0
                ;;
            '&')
                case "$word" in
                    *'>' | *'<')
                        word="$word$ch"
                        ;;
                    *)
                        if [ -n "$word" ] || [ "$invalue" -eq 1 ]; then
                            out+=("$word")
                        fi
                        word=''
                        invalue=0
                        out+=($'\001')
                        ;;
                esac
                ;;
            '|' | ';')
                if [ -n "$word" ] || [ "$invalue" -eq 1 ]; then
                    out+=("$word")
                fi
                word=''
                invalue=0
                out+=($'\001')
                ;;
            *)
                word="$word$ch"
                invalue=1
                ;;
        esac
        i=$((i + 1))
    done
    if [ -n "$word" ] || [ "$invalue" -eq 1 ]; then
        out+=("$word")
    fi
    printf '%s\n' "${out[@]}"
}

# _readonly_merge_segment <command> — the first pipeline-or-list segment of
# <command> that opens with `git`, after skipping its own global options,
# and runs merge, pull, checkout, switch, rebase or cherry-pick: the
# subcommand on line 1, then each following word up to a literal -- on its
# own line (detectors.md's target= "before any --"); nothing, exit 1, when
# no segment matches. A caller only needing merge=1 reads the exit status; a
# caller resolving target= reads the candidate words after line 1.
_readonly_merge_segment() {
    local cmd="$1" tok state=start skip_next=0 sub=''
    local -a cands=()
    while IFS= read -r tok; do
        if [ "$tok" = $'\001' ]; then
            case "$state" in
                collect | stop) break ;;
            esac
            state=start
            skip_next=0
            continue
        fi
        case "$state" in
            stop) continue ;;
            start)
                if [ "$tok" = git ]; then
                    state=skip
                else
                    state=skipseg
                fi
                ;;
            skipseg) : ;;
            skip)
                if [ "$skip_next" -eq 1 ]; then
                    skip_next=0
                    continue
                fi
                case "$tok" in
                    -C | -c | --git-dir | --work-tree | --namespace \
                        | --super-prefix)
                        skip_next=1
                        ;;
                    -*) : ;;
                    merge | pull | checkout | switch | rebase | cherry-pick)
                        sub="$tok"
                        state=collect
                        ;;
                    *)
                        state=skipseg
                        ;;
                esac
                ;;
            collect)
                if [ "$tok" = -- ]; then
                    state=stop
                else
                    cands+=("$tok")
                fi
                ;;
        esac
    done < <(_readonly_tokenize "$cmd")
    [ -n "$sub" ] || return 1
    printf '%s\n' "$sub" "${cands[@]}"
}

# _readonly_partial_checkout_text <text> — true when <text> holds git's
# "unable to unlink old" or "unable to create file" refusal (a checkout or
# merge that only wrote some of the target's files before the mount refused
# the rest), each built from two fragments so this file holds neither
# phrase whole (self-quiet, FR-11, as tests/helpers/probes.bash's
# git_lock_error does for git's own lock text). `case` glob matching, not
# grep: `*` matches across the embedded newlines <text> may hold.
_readonly_partial_checkout_text() {
    local text="$1" needle
    needle='unable to unlink'
    needle="$needle old"
    case "$text" in
        *"$needle"*) return 0 ;;
    esac
    needle='unable to create'
    needle="$needle file"
    case "$text" in
        *"$needle"*) return 0 ;;
    esac
    return 1
}

# _readonly_git_dir <dir> — the nearest ancestor of <dir>, <dir> included,
# holding a .git entry (worktree or gitlink); empty, exit 1, when none
# exists up to /. One `[ -e ]` per ancestor, no process.
_readonly_git_dir() {
    local dir="$1"
    [ -n "$dir" ] || return 1
    while :; do
        if [ -e "$dir/.git" ]; then
            printf '%s\n' "$dir"
            return 0
        fi
        [ "$dir" = / ] && return 1
        dir="${dir%/*}"
        [ -n "$dir" ] || dir=/
    done
}

# _readonly_resolve_target <repo> <candidate...> — the first <candidate>
# that resolves to a commit in <repo>, empty and exit 1 when none does
# (detectors.md's target=). `--verify --quiet` alone, with no leading --,
# is git's own idiom for testing a name that may itself look like an
# option (`--ff-only^{commit}`): it fails quietly rather than being parsed
# as a flag. GIT_OPTIONAL_LOCKS=0: the probe reads only (NFR-4).
_readonly_resolve_target() {
    local repo="$1" cand
    shift
    for cand in "$@"; do
        if GIT_OPTIONAL_LOCKS=0 git -C "$repo" rev-parse --verify --quiet \
            "$cand^{commit}" >/dev/null; then
            printf '%s\n' "$cand"
            return 0
        fi
    done
    return 1
}

# _readonly_print_matches <repo> <target> — match=<file> for each file that
# differs from HEAD in <repo>'s working tree, staged or not, and whose
# current bytes equal <target>'s blob for that file (detectors.md's
# match=). The file list comes from one whole-repo `diff --name-only`,
# never a per-file `git diff <ref> -- <file>` (which rewrites the index on
# git 2.47 even under GIT_OPTIONAL_LOCKS=0); content is then compared
# through `cat-file blob`, which touches only the object database.
# GIT_OPTIONAL_LOCKS=0 throughout: the probe reads only (NFR-4).
# NUL-delimited (`-z`, `read -r -d ''`): a blank in a name is safe; a name
# holding a newline cannot appear in a match= line and is skipped
# (detectors.md's residual).
_readonly_print_matches() {
    local repo="$1" target="$2" file
    while IFS= read -r -d '' file; do
        [ -n "$file" ] || continue
        case "$file" in
            *$'\n'*) continue ;;
        esac
        [ -f "$repo/$file" ] || continue
        # cat-file -e's exit status alone says whether <target>:<file>
        # exists; its stderr on failure ("Not a valid object name") adds
        # nothing the status does not already carry, so it is discarded
        # here rather than reaching the probe's own stderr.
        if ! GIT_OPTIONAL_LOCKS=0 git -C "$repo" cat-file -e \
            "$target:$file" 2>/dev/null; then
            continue
        fi
        if GIT_OPTIONAL_LOCKS=0 git -C "$repo" cat-file blob \
            "$target:$file" | cmp -s - "$repo/$file"; then
            printf 'match=%s\n' "$file"
        fi
    done < <(GIT_OPTIONAL_LOCKS=0 git -C "$repo" diff --name-only -z HEAD)
}
