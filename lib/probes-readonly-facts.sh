#!/usr/bin/env bash
# Node names cited here (readonly-path.md, detectors.md) are files of the plugin
# repository's docs/references/, which the plugin does not ship.
# lib/probes-readonly-facts.sh — the readfile=/merge=1/partial=1/target=/
# recover=/repo=/match= facts _readonly_print_facts derives for probe_readonly_path under
# writable and nopath (readonly-path.md's readonly-path Probe facts table),
# reading the command through lib/probes-readonly-command.sh's scan. Sourced
# with lib/probes-readonly-command.sh by lib/probes-readonly.sh, which sources both, so no other caller needs a source
# line of its own for them.
#
# set -u as in lib/probes-readonly.sh; bats does not set it, so setting it
# here keeps an unset variable an error when a caller sources this file
# directly. Under set -u, bash before 4.4 (macOS's 3.2, NFR-2) calls an empty
# array unbound, so every array that can be empty expands as
# ${a[@]+"${a[@]}"} or behind a count check.
set -u

# _readonly_print_facts <text> <command> <path> <cwd> — the writable/nopath
# tail of the A-3 contract (readonly-path.md's readonly-path Probe facts table):
# readfile=, merge=1, partial=1, target=, recover=, repo= and match= lines, derived from
# <text> and <command> only — never from the outcome (D-1). <path> is the
# extracted refusal path, empty under nopath; the repository search starts
# there, or at <cwd> when there is none (readonly-path.md: "the path's nearest
# existing directory, else the cwd's" — walking up from <path> reaches the
# same first .git ancestor either way, since a check below a nonexistent
# directory can never succeed, so no separate existence walk is needed).
# _readonly_tokens and _readonly_tokens_cut are _readonly_tokenize's output.
_readonly_print_facts() {
    local text="$1" command="$2" path="$3" cwd="$4" readfile word sub='' sole=''
    local start repo recover='' _readonly_tokens_cut=0 partial=0 pathspec=0
    local -a _readonly_tokens=() cands=()

    _readonly_tokenize "$command"
    readfile=$(_readonly_readfile_arg "$_readonly_tokens_cut" \
        ${_readonly_tokens[@]+"${_readonly_tokens[@]}"})
    [ -z "$readfile" ] || printf 'readfile=%s\n' "$readfile"

    while IFS= read -r -d '' word; do
        if [ -z "$sub" ]; then
            sub="$word"
        elif [ -z "$sole" ]; then
            sole="$word"
        elif [ "$word" = -- ]; then
            pathspec=1
        else
            cands+=("$word")
        fi
    done < <(_readonly_merge_segment \
        ${_readonly_tokens[@]+"${_readonly_tokens[@]}"})
    if _probe_partial_checkout_text "$text"; then
        partial=1
    fi
    if [ -z "$sub" ] && [ "$partial" -eq 0 ]; then
        return 0
    fi
    printf 'merge=1\n'
    [ "$partial" -eq 0 ] || printf 'partial=1\n'

    # target= is only attempted after these three subcommands (readonly-path.md);
    # pull, rebase and cherry-pick still fire merge=1 above but name no ref.
    case "$sub" in
        merge | checkout | switch) ;;
        *) return 0 ;;
    esac
    [ "${#cands[@]}" -gt 0 ] || return 0
    if [ "$sole" = 1 ] && [ "$pathspec" -eq 0 ] \
        && [ "$_readonly_tokens_cut" -eq 0 ]; then
        recover=$(_readonly_recover_kind "$sub" "${cands[@]}")
    fi
    start="$path"
    [ -n "$start" ] || start="$cwd"
    repo=$(_readonly_git_dir "$start") || return 0
    [ -z "$recover" ] || [ "$(_readonly_git_dir "$cwd")" = "$repo" ] \
        || recover=''
    _readonly_repo_facts "$repo" "$recover" "${cands[@]}"
}

# _readonly_recover_kind <sub> <word...> — the script's subcommand for a segment
# whose words name exactly what it can repeat, else nothing. recover= prints only
# when all of these hold, the script's own invocation being then the command the
# call ran: the call holds one merge-style segment and its scan was not cut; git
# runs where the probe looks, every earlier segment being a git command with no
# -C, --git-dir or --work-tree (any other earlier segment may have moved the cwd),
# since git's partial-checkout paths are relative and the probe joins them onto the cwd, and the refused path's repository is the cwd's; no literal --;
# (these three checked by the caller) exactly one
# non-option word, the target, a word holding > or < being a redirection and not
# counted; the only options are -q, --quiet and --ff-only; for a checkout or
# switch, refs/heads/<target> exists (_readonly_repo_facts).
_readonly_recover_kind() {
    local sub="$1" word n=0
    shift
    for word in "$@"; do
        case "$word" in
            *[\<\>]* | -q | --quiet | --ff-only) ;;
            -*) return 0 ;;
            *) n=$((n + 1)) ;;
        esac
    done
    [ "$n" -eq 1 ] || return 0
    case "$sub" in
        merge) printf merge ;;
        checkout | switch) printf checkout ;;
    esac
}

# _readonly_git_dir <dir> — the nearest ancestor of <dir>, <dir> included,
# holding a .git entry (worktree or gitlink); empty, exit 1, when none
# exists up to /. A relative <dir> joins onto $PWD first, as
# _probe_readonly_resolve joins a relative cwd: stripping /-suffixes from a
# relative name would never reach /. Trailing slashes go before the walk, so
# the root printed and joined into match=<repo>/<file> never ends in one
# (bar / itself). One `[ -e ]` per ancestor, no process.
_readonly_git_dir() {
    local dir="$1"
    [ -n "$dir" ] || return 1
    case "$dir" in
        /*) ;;
        *) dir="$PWD/$dir" ;;
    esac
    while [ "${dir%/}" != "$dir" ]; do
        dir="${dir%/}"
    done
    [ -n "$dir" ] || dir=/
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

# _readonly_repo_facts <repo> <recover> <candidate...> — target= for the first
# <candidate> naming a commit in <repo>, then recover=<recover> and repo=<repo>
# in printf %q form when <recover> names a ref sandbox-lies-recover can take (a
# checkout or switch onto a local branch, or a merge; _readonly_recover_kind
# holds the rule), then match=<repo>/<file> for each
# regular file differing from HEAD in the working tree, staged or not, whose
# bytes equal the target's blob (readonly-path.md's target= and match=), named
# by absolute path so the verdict's clause reads from any cwd; nothing when no
# candidate resolves or <repo> holds a newline. A subshell, so the
# environment edits stay here:
# repository variables inherited from the hook's own environment (a claude
# started inside a git hook) would point every read at another repository.
#
# Bounded (NFR-3): five git processes whatever the file count (the fifth is
# show-ref, run only for a checkout), and past 1000 modified files no target=
# either, so the verdict's generic clause — printed only when the text itself
# gave partial=1 — stands in for a list it could not build in time.
# Writes nothing (NFR-4): optional locks off; diff-index compares stat data
# without refreshing the index (a porcelain `git diff` refresh can rewrite
# it) and with fsmonitor off (its daemon writes an IPC socket under .git);
# hash-object runs without -w and without filters (an LFS clean filter
# stores objects), comparing raw bytes as `cat-file blob | cmp` would.
# stderr is discarded on each git call: git reports a repository it cannot
# open (not a repository, a broken gitlink, dubious ownership, a corrupt
# index) and an ambiguous short id there, each meaning no fact, and the
# probe's stderr has no reader; each call's own output is checked instead.
# A candidate git's revision syntax would not read as a plain name is
# skipped: a leading -, a blank (no ref holds one, so a newline cannot forge
# a key line), a : (a path), and @{ or ^{ (a reflog past its end kills
# cat-file; ^{/re} walks history).
_readonly_repo_facts() (
    local repo="$1" recover="$2" cand type target='' meta file rec n=0 complete=0
    local wt i=0 j=0 out='' quoted
    local -a names=() files=() heads=() shas=() tpaths=() tshas=()
    shift 2
    # Every match= line opens with <repo>: a newline in it would split the
    # line and forge the key line after it, as for a file name below. A
    # refused path comes off one line of the text, so only the cwd, joined
    # on or fallen back to, can bring one.
    case "$repo" in
        *$'\n'*) return 0 ;;
    esac
    unset GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG GIT_CONFIG_PARAMETERS \
        GIT_CONFIG_COUNT GIT_OBJECT_DIRECTORY GIT_DIR GIT_WORK_TREE \
        GIT_IMPLICIT_WORK_TREE GIT_GRAFT_FILE GIT_INDEX_FILE \
        GIT_NO_REPLACE_OBJECTS GIT_REPLACE_REF_BASE GIT_PREFIX \
        GIT_SHALLOW_FILE GIT_COMMON_DIR
    export GIT_OPTIONAL_LOCKS=0 LC_ALL=C
    for cand in "$@"; do
        case "$cand" in
            -* | *[[:space:]]* | *:* | *@\{* | *^\{*) ;;
            *) names+=("$cand") ;;
        esac
    done
    [ "${#names[@]}" -gt 0 ] || return 0

    # HEAD first: an unborn HEAD answers missing, and diff-index needs one.
    # ^{} rather than ^{commit}: a tree or blob answers its type, not an
    # error.
    {
        IFS= read -r type && [ "$type" = commit ] || return 0
        for cand in "${names[@]}"; do
            IFS= read -r type || return 0
            if [ "$type" = commit ]; then
                target="$cand"
                break
            fi
        done
    } < <(printf '%s^{}\n' HEAD "${names[@]}" \
        | git -C "$repo" cat-file --batch-check='%(objecttype)' 2>/dev/null)
    [ -n "$target" ] || return 0

    # diff-index's raw records, `:<mode> <mode> <HEAD sha> <sha> <status>`
    # then the name, come in index order; the empty record after them, which
    # git never prints, says the list is complete.
    while IFS= read -r -d '' meta; do
        if [ -z "$meta" ]; then
            complete=1
            break
        fi
        IFS= read -r -d '' file || break
        n=$((n + 1))
        [ "$n" -le 1000 ] || return 0
        case "$file" in
            *$'\n'*) continue ;;
        esac
        if [ -f "$repo/$file" ] && [ ! -L "$repo/$file" ] \
            && [ -r "$repo/$file" ]; then
            meta="${meta#* }"
            meta="${meta#* }"
            files+=("$file")
            heads+=("${meta%% *}")
        fi
    done < <(git -c core.fsmonitor=false -C "$repo" diff-index -z \
        --ignore-submodules HEAD 2>/dev/null && printf '\0')
    [ "$complete" -eq 1 ] || return 0

    if [ "${#files[@]}" -gt 0 ]; then
        # ./ keeps a name opening with " from being read C-quoted.
        wt=$(printf './%s\n' "${files[@]}" | git -C "$repo" hash-object \
            --no-filters --stdin-paths 2>/dev/null) || return 0
        # Split on newlines alone, globbing off: a sha line is never empty.
        set -f
        IFS=$'\n'
        # shellcheck disable=SC2206 # the split above is the intent
        shas=($wt)
        IFS=$' \t\n'
        [ "${#shas[@]}" -eq "${#files[@]}" ] || return 0
        # One ls-tree over the listed names, `<mode> <type> <sha>\t<name>`,
        # rather than a `<target>:<name>` lookup each, which re-reads the
        # name's whole directory every time. Its records come in tree
        # order, which is the index's (byte order of the full name, as
        # [[ < ]] compares under LC_ALL=C), so one merge pass pairs them;
        # -r lists a name that is a directory at the target as its blobs,
        # which the pass skips.
        complete=0
        while IFS= read -r -d '' rec; do
            if [ -z "$rec" ]; then
                complete=1
                break
            fi
            case "$rec" in
                *" blob "*) ;;
                *) continue ;;
            esac
            tpaths+=("${rec#*$'\t'}")
            rec="${rec%%$'\t'*}"
            tshas+=("${rec##* }")
        done < <(git --literal-pathspecs -C "$repo" ls-tree -r -z \
            --full-tree "$target" -- "${files[@]}" 2>/dev/null \
            && printf '\0')
        [ "$complete" -eq 1 ] || return 0
    fi
    while [ "$i" -lt "${#files[@]}" ] && [ "$j" -lt "${#tpaths[@]}" ]; do
        if [ "${tpaths[$j]}" = "${files[$i]}" ]; then
            if [ "${shas[$i]}" = "${tshas[$j]}" ] \
                && [ "${shas[$i]}" != "${heads[$i]}" ]; then
                out="${out}match=${repo}/${files[$i]}"$'\n'
            fi
            i=$((i + 1))
            j=$((j + 1))
        elif [[ "${tpaths[$j]}" < "${files[$i]}" ]]; then
            j=$((j + 1))
        else
            i=$((i + 1))
        fi
    done
    # A checkout's recover= is kept only for a local branch, which
    # sandbox-lies-recover can take. target=, then recover=, then match= is
    # printing order alone: target= no longer means no clause is possible,
    # since recover=, repo= and target= set one, and the verdict reads them whole.
    if [ "$recover" = checkout ] \
        && ! git -C "$repo" show-ref -q --verify "refs/heads/$target" 2>/dev/null; then
        recover=''
    fi
    printf 'target=%s\n' "$target"
    if [ -n "$recover" ]; then
        # LC_ALL=C from above, as _probe_path_line pins it: a non-ASCII byte
        # takes the $'...' form, which stays runnable in the verdict's command.
        printf -v quoted %q "$repo"
        printf 'recover=%s\nrepo=%s\n' "$recover" "$quoted"
    fi
    printf '%s' "$out"
)
