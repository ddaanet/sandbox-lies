#!/usr/bin/env bash
# The shipped sandbox-symptom matchers, one per detector
# (docs/references/detectors.md and its per-detector nodes).
#
# Each matcher reads a Bash tool result on stdin and exits 0 when the symptom
# is present, 1 when it is not. `detect` runs the set and prints one verdict
# name per firing matcher.
#
# The shapes here are not guesses: layer 1 replayed the naive forms over 21,272
# recorded Bash calls and each discriminator below is the one the corpus
# selected. manual/detectors.md describes each shape.
#
# bash 3.2 and BSD grep/sed: no -P, no \s, no \d, no GNU-only flags.

set -u

detect() {
    # Hold the text once in memory, never in a file (NFR-4); every matcher
    # needs its own read of the same text. A bash string cannot hold a NUL, so
    # `tr` drops them first: `$(cat)` would warn on stderr in bash >= 4.4, and
    # `read -d ''` would stop at the first one and miss a firing line after it.
    # `read -d ''` also reads a pipe one byte per syscall, which costs more on
    # a 30 KB result than this fork does (measured). LC_ALL=C: BSD tr can
    # refuse invalid UTF-8 under a UTF-8 locale.
    #
    # stdin reaches tr through fd 3. With fd 0 closed, the substitution's own
    # pipe takes fd 0 and a bare `tr` reads it and hangs; the group's `3<&0`
    # fails first instead. That failure, or tr's read error, leaves the text
    # empty, so nothing fires and the error reaches stderr.
    local text='' status
    { text=$(LC_ALL=C tr -d '\000' <&3); } 3<&0
    status=1
    # Process substitution, not a pipeline: the matcher runs in this shell,
    # which saves one fork per matcher.
    match_git_lock < <(printf '%s\n' "$text") && { printf 'git-lock\n'; status=0; }
    match_config_lock < <(printf '%s\n' "$text") && { printf 'config-lock\n'; status=0; }
    match_phantom_chardev < <(printf '%s\n' "$text") && { printf 'phantom-chardev\n'; status=0; }
    match_phantom_untracked < <(printf '%s\n' "$text") && { printf 'phantom-untracked\n'; status=0; }
    match_phantom_gitadd < <(printf '%s\n' "$text") && { printf 'phantom-gitadd\n'; status=0; }
    match_readonly_path < <(printf '%s\n' "$text") && { printf 'readonly-path\n'; status=0; }
    match_tmpdir_unset < <(printf '%s\n' "$text") && { printf 'tmpdir-unset\n'; status=0; }
    match_resume_lost < <(printf '%s\n' "$text") && { printf 'resume-lost\n'; status=0; }
    match_seccomp_init < <(printf '%s\n' "$text") && { printf 'seccomp-init\n'; status=0; }
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
# A real character device in a listing (`ls -la /dev`) would also match. That
# false positive is an accepted residual: no such call exists in the corpus,
# nothing narrows the matcher to the project root, and
# docs/references/detectors.md names it.
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

# _readonly_path_line -- prints stdin's first line match_readonly_path
# accepts, nothing when there is none. Shared with probe_readonly_path
# (lib/probes-readonly.sh, sourced there) so the discriminator lives in one
# place rather than as two copies that could drift apart. LC_ALL=C: under a
# UTF-8 locale GNU grep reads a line holding an invalid byte as binary, and
# on a Python refusal (whose alternative stops before the path) it exits 0
# but prints "binary file matches" to stderr in place of the line, so the
# matcher fired while the probe read no path.
_readonly_path_line() {
    LC_ALL=C grep -m1 -E \
        '^[^`|:[:space:]]+: .*: (Read-only file system|Device or resource busy)[[:space:]]*$'\
'|^[A-Za-z]+Error: \[Errno (30|16)\] (Read-only file system|Device or resource busy):'
}

# A line that opens with a tool's own prefix (a run free of blanks,
# backticks, pipes and colons, then ": ", as `cp`, `mv`, git's `error` and
# bash's own `/bin/bash: line N:` all print it) and ends in the kernel's
# read-only-filesystem or busy-device message, trailing blanks allowed. Or
# Python's: an exception name ending in `Error`, `[Errno 30]` or
# `[Errno 16]`, the same message, then a colon -- the quoted path that
# follows is not required, since the discriminator anchors at the message,
# not the line end, for this alternative.
#
# Anchoring at line start is what the corpus needed (99% precision, 162
# hits): the memory store and this suite's own index/heredoc lines quote
# both messages mid-line or mid-word, never as a bare refusal starting a
# line of their own. See docs/references/readonly-path.md's `## readonly-path`
# entry for the corpus figures this discriminator was measured against.
match_readonly_path() {
    _readonly_path_line >/dev/null
}

# The shape an empty $TMPDIR expansion produces, as the replay selected it: a
# tool's own prefix (as readonly-path: a run free of blanks, backticks, pipes
# and colons, then ": "), then a path of exactly one component under root,
# ending in ": " and the permission-denied or missing-file message. The path
# is either bare, directly after the prefix or bash's "line N: " locator
# (BSD `cat`, bash's redirect), or single-quoted, straight or GNU curly,
# after the tool's own words (GNU `cp`, `ls`); those words hold no straight
# quote, so prose that single-quotes a command ahead of a refusal stays
# quiet. A deeper or relative path is the near-miss: the bare path must open
# with its root slash right after the prefix or locator, and no slash may sit
# inside the quotes.
match_tmpdir_unset() {
    grep -qE "^[^\`|:[:space:]]+: ((line [0-9]+: )?/[^/:[:space:]]+|[^']*('|‘)/[^/']+('|’)[^']*): (Permission denied|No such file or directory)[[:space:]]*\$"
}

# `claude`'s resume refusal, printed with no prefix of its own, then the
# session id (hex digits and hyphens) and nothing but trailing blanks. The
# store's index line quotes the refusal mid-line and truncates the id with
# an ellipsis, so anchoring to the line start is what separates a live
# refusal from the quotation.
#
# The line shape is held once, in _RESUME_LOST_LINE, with the id as its one
# group: probe_resume_lost (lib/probes.sh) extracts the ids with the same
# text, so the probe cannot drift from what the matcher detected and print
# unknown on a refusal the matcher fired on.
_RESUME_LOST_LINE='^No conversation found with session ID: ([0-9a-fA-F-]+)[[:space:]]*$'
match_resume_lost() {
    grep -qE "$_RESUME_LOST_LINE"
}

# Live, the seccomp apply failure is the whole result: alone on its line from
# its start. The store's index line and section heading both quote it after a
# line-number prefix or a heading marker, never at the line start.
match_seccomp_init() {
    grep -qE '^apply-seccomp: unshare\(CLONE_NEWUSER\): Invalid argument[[:space:]]*$'
}

# Running the file directly reads stdin and reports the verdict.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    detect
fi
