#!/usr/bin/env bash
# Candidate sandbox-symptom matchers for the detector pilot.
#
# Each matcher reads a Bash tool result on stdin and exits 0 when the symptom
# is present, 1 when it is not. `detect` runs the set and prints one verdict
# name per firing matcher.
#
# The shapes here are not guesses: layer 1 replayed the naive forms over 21,272
# recorded Bash calls and each discriminator below is the one the corpus
# selected. See plans/2026-09-02-sandbox-detector-replay-results.md.
#
# bash 3.2 and BSD grep/sed: no -P, no \s, no \d, no GNU-only flags.

set -u

detect() {
    # Hold the text once; every matcher needs its own read of the same text.
    # `read -r -d ''` reads to EOF (its own exit status is EOF, not error,
    # and is not checked) without writing a file (NFR-4) and without the
    # NUL-byte warning `$(cat)` prints on stderr in bash >= 4.4.
    local text status
    IFS= read -r -d '' text
    status=1
    printf '%s\n' "$text" | match_git_lock && { printf 'git-lock\n'; status=0; }
    printf '%s\n' "$text" | match_config_lock && { printf 'config-lock\n'; status=0; }
    printf '%s\n' "$text" | match_phantom_chardev && { printf 'phantom-chardev\n'; status=0; }
    printf '%s\n' "$text" | match_phantom_untracked && { printf 'phantom-untracked\n'; status=0; }
    printf '%s\n' "$text" | match_phantom_gitadd && { printf 'phantom-gitadd\n'; status=0; }
    return "$status"
}

# `fatal: Unable to create '<path>.lock': File exists` names a concurrent git
# process that usually does not exist. The bare string is unusable as a
# trigger -- it fires on every read of the memory file that documents it, and
# on the bats fixtures and index lines that quote it (87 corpus hits, 13%
# precision). Requiring git's follow-on sentence *including its trailing
# `in this repository`* is what separates the diagnostic from the quotation:
# the prose quotations in the store all truncate before that clause.
#
# Exit status is deliberately NOT used as the gate. It cuts the corpus hits to
# 7 but drops two real failures where the git call was piped through `tail`,
# which reports the pipeline's status. See fire-lock-piped-tail.
#
# The follow-on is assembled from two fragments so this file never holds the
# sentence whole and does not fire on itself.
match_git_lock() {
    local text follow
    follow='Another git process seems to be running'
    follow="$follow in this repository"
    text=$(cat)
    printf '%s\n' "$text" \
        | grep -q "[Uu]nable to create '.*\.lock': File exists" || return 1
    printf '%s\n' "$text" | grep -qF "$follow"
}

# The `git config` / `git remote add` / `just update-plugin-dev` shape, from
# the harness mounting `.git/config` busy.
#
# Line anchoring, not the `error: ` prefix, is the discriminator. The prefix
# alone looks sufficient and is not: the only false positive this matcher has
# in the corpus is the pilot's own layer-1 report echoing recorded hits, and
# that text carries the prefix too. Anchoring suppresses it, and every one of
# the four real failures puts `error: ` at the head of a line.
#
# The current store does not fire the bare string either, but only because
# its hard-wrap splits `could not lock / config file` across two lines -- an
# accident, not a property. The anchor does not depend on it.
match_config_lock() {
    grep -qE '^error: could not lock config file .*: File exists'
}

# A `/dev/null` bind-mount stats as a character device. Every one of the 17
# corpus hits was genuine, across eight repos, and about half were incidental
# `ls -la` where the agent was not investigating the sandbox at all.
#
# A real character device in a listing (`ls -la /dev`) would also match; no
# such call exists in the corpus, and anchoring the hook to CLAUDE_PROJECT_DIR
# closes it.
match_phantom_chardev() {
    grep -qE '^[[:space:]]*c[rwx-]{9}[.+@]?[[:space:]]'
}

# The 22 paths measured 2026-08-15 as masked in a session's project root.
_masked_alternation() {
    printf '%s' \
'\.bash_profile|\.bashrc|\.gitconfig|\.idea|\.mcp\.json|\.profile|\.ripgreprc|\.vscode|\.zprofile|\.zshrc|\.claude/agents|\.claude/commands|\.claude/hooks|\.claude/launch\.json|\.claude/loop\.md|\.claude/output-styles|\.claude/routines|\.claude/scheduled_tasks\.json|\.claude/skills|\.claude/workflows|\.git/config\.lock|\.git/config\.worktree'
}

# Masked names shown as untracked by the `git status` family. The precision
# comes from the line shape, not the name list: counting these names anywhere
# in the output gives 207 corpus hits and is unusable, while requiring them to
# stand alone on a status line gives 41 hits and no false positive.
#
# The threshold is 2 and buys nothing above that -- >=2 gives 41 hits, >=5
# gives 40. The mask set appears wholesale or not at all. It stays at 2 for
# the case that does not: see fire-masks-two-names, a real listing with only
# `.bash_profile` and `.bashrc`.
match_phantom_untracked() {
    local alt count
    alt=$(_masked_alternation)
    count=$(grep -Eo "^(\?\?[[:space:]]+|[[:space:]]+)(${alt})/?[[:space:]]*\$" \
        | sed -E 's/^[[:space:]?]+//; s|/?[[:space:]]*$||' \
        | sort -u | grep -c .)
    [ "$count" -ge 2 ]
}

# `git add` refusing a masked path. Layer 1 called this subsumed by the other
# two; the fixtures show it is not -- a `git add -A` that aborts prints neither
# a listing nor a char device, so nothing else in this file sees it.
#
# Line-anchoring is the discriminator, and here it is the only one available:
# the store's changelog quotes the error AND git's `fatal: adding files failed`
# follow-on in the same sentence, so the follow-on test that rescues
# match_git_lock does not separate these. Live git puts each on its own line.
# Residual: output that begins a line with this text for some other reason
# would match. No such call exists in the 21,272-call corpus.
match_phantom_gitadd() {
    grep -qE '^error: .*: can only add regular files, symbolic links or git-directories'
}

# Running the file directly reads stdin and reports the verdict.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect
fi
