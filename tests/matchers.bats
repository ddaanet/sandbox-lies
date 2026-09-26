#!/usr/bin/env bats
# Layer 2 of the sandbox-detector pilot: recorded output in, decision out.
#
# Every fixture under fixtures/ is a verbatim Bash tool result cut from
# ~/.claude/projects by extract-fixtures.py. The ordering is load-bearing:
# layer 1's replay produced these, so they encode what the output *is* rather
# than what it was expected to look like.
#
# `fire-*` fixtures must produce exactly the named verdicts; `quiet-*` must
# produce none. Each case asserts the FULL verdict set, so a matcher that
# starts firing on another detector's symptom fails here rather than silently
# double-reporting.

ROOT="${BATS_TEST_DIRNAME}/.."
MATCHERS="$ROOT/lib/matchers.sh"
FIXTURES="$ROOT/tests/fixtures"

# `run !` needs 1.5.0; without this bats warns BW02 on every such case.
bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/spy

# fixture name -> expected verdicts, newline-separated, empty for quiet.
expected_for() {
  case "$1" in
    fire-lock-commit-amend)        printf 'git-lock\n' ;;
    fire-lock-restore)             printf 'git-lock\n' ;;
    fire-lock-rebase-inline)       printf 'git-lock\n' ;;
    fire-lock-piped-tail)          printf 'git-lock\n' ;;
    fire-lock-add-commit)          printf 'git-lock\n' ;;
    fire-configlock-remote-add)    printf 'config-lock\n' ;;
    fire-configlock-fetch)         printf 'config-lock\n' ;;
    fire-masks-porcelain)          printf 'phantom-untracked\n' ;;
    fire-masks-two-names)          printf 'phantom-untracked\n' ;;
    fire-masks-chardev-explicit)   printf 'phantom-chardev\n' ;;
    fire-masks-chardev-incidental) printf 'phantom-chardev\n' ;;
    fire-masks-gitadd-refused)     printf 'phantom-gitadd\n' ;;
    quiet-memory-file-read)        : ;;
    quiet-index-line-read)         : ;;
    quiet-bats-fixture-grep)       : ;;
    quiet-clean-status)            : ;;
    quiet-clean-ls)                : ;;
    quiet-heredoc-claude-p)        : ;;
    quiet-pilot-report-echo)       : ;;
    # Candidates recorded `ships` in docs/references/detectors.md, built by
    # Item 4.2 (zellij-socket stays a candidate and has no fixture).
    fire-tmpdir-unset-redirect)    printf 'tmpdir-unset\n' ;;
    fire-tmpdir-unset-cp-stat)     printf 'tmpdir-unset\n' ;;
    fire-tmpdir-unset-bash-bare)   printf 'tmpdir-unset\n' ;;
    quiet-tmpdir-unset-deep-path)  : ;;
    fire-resume-lost-two-turn)     printf 'resume-lost\n' ;;
    quiet-resume-lost-index-line)  : ;;
    fire-seccomp-init-sed)         printf 'seccomp-init\n' ;;
    quiet-seccomp-init-heading)    : ;;
    # readonly-path, built by Item 4.3.
    fire-readonly-path-cp-tmp)       printf 'readonly-path\n' ;;
    fire-readonly-path-task-output)  printf 'readonly-path\n' ;;
    fire-readonly-path-python-errno) printf 'readonly-path\n' ;;
    fire-readonly-path-git-busy)     printf 'readonly-path\n' ;;
    quiet-readonly-path-index-line)  : ;;
    *) return 1 ;;
  esac
}

# A quiet fixture exits 1, which errexit would turn into a test abort.
verdicts_for() { bash "$MATCHERS" < "$FIXTURES/$1.txt" || true; }

assert_fixture() {
  local name="$1" got want
  got=$(verdicts_for "$name")
  want=$(expected_for "$name")
  [ "$got" = "$want" ] || {
    echo "fixture $name: expected [${want//$'\n'/,}] got [${got//$'\n'/,}]" >&2
    return 1
  }
}

# ---------------------------------------------------------------- invocation

@test "matchers.sh is executable and runs as a command" {
  [ -x "$MATCHERS" ]
  run bash -c "printf 'nothing here\n' | '$MATCHERS'"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "every fixture on disk has an expectation in this suite" {
  local f name missing=""
  for f in "$FIXTURES"/*.txt; do
    name=$(basename "$f" .txt)
    expected_for "$name" >/dev/null 2>&1 || missing="$missing $name"
  done
  [ -z "$missing" ] || { echo "fixtures with no case:$missing" >&2; return 1; }
}

@test "every expectation in this suite has a fixture on disk" {
  local name missing=""
  for name in $(grep -Eo '^    (fire|quiet)-[a-z-]+\)' "$BATS_TEST_FILENAME" \
                | tr -d ' )'); do
    [ -f "$FIXTURES/$name.txt" ] || missing="$missing $name"
  done
  [ -z "$missing" ] || { echo "cases with no fixture:$missing" >&2; return 1; }
}

@test "the fixture set covers both directions" {
  local f fire=0 quiet=0
  for f in "$FIXTURES"/fire-*.txt; do [ -f "$f" ] && fire=$((fire + 1)); done
  for f in "$FIXTURES"/quiet-*.txt; do [ -f "$f" ] && quiet=$((quiet + 1)); done
  [ "$fire" -ge 10 ]
  [ "$quiet" -ge 5 ]
}

# ------------------------------------------------------- detector A: locks

@test "git-lock fires on a plain failing commit" {
  assert_fixture fire-lock-commit-amend
}

@test "git-lock fires on git restore" {
  assert_fixture fire-lock-restore
}

@test "git-lock fires when git prefixes the diagnostic with rebase progress" {
  # `Rebasing (2/7)error: Unable to create ...` -- the same line. A line-anchored
  # matcher misses this; the corpus has two of them.
  assert_fixture fire-lock-rebase-inline
  grep -q 'Rebasing' "$FIXTURES/fire-lock-rebase-inline.txt"
}

@test "git-lock fires when the git call was piped and the status is 0" {
  # `git commit --amend --no-edit 2>&1 | tail -20` reports tail's status, so an
  # exit-status gate goes quiet on a real failure. This is why there is none.
  assert_fixture fire-lock-piped-tail
  run ! grep -q '^Exit code [1-9]' "$FIXTURES/fire-lock-piped-tail.txt"
}

@test "git-lock fires on the stranded-lock add+commit pair" {
  assert_fixture fire-lock-add-commit
}

@test "config-lock fires on git remote add" {
  assert_fixture fire-configlock-remote-add
}

@test "config-lock fires on a git config write during a subtree pull" {
  assert_fixture fire-configlock-fetch
}

# ---------------------------------------------- detector B: phantom dotfiles

@test "phantom-untracked fires on a full masked porcelain listing" {
  assert_fixture fire-masks-porcelain
}

@test "phantom-untracked fires on a listing carrying only two masked names" {
  # The threshold is 2 for this case; the corpus otherwise shows the mask set
  # appearing wholesale.
  assert_fixture fire-masks-two-names
  [ "$(grep -c '^?? \.' "$FIXTURES/fire-masks-two-names.txt")" -eq 2 ]
}

@test "phantom-chardev fires on a deliberate stat of masked paths" {
  assert_fixture fire-masks-chardev-explicit
}

@test "phantom-chardev fires on an incidental ls -la in an unrelated repo" {
  # The valuable case: the agent was not investigating the sandbox.
  assert_fixture fire-masks-chardev-incidental
}

@test "phantom-gitadd fires on git add refusing a masked path" {
  # Not subsumed by the other two: this output has no listing and no char
  # device, so nothing else in matchers.sh sees it.
  assert_fixture fire-masks-gitadd-refused
  run ! grep -qE '^[[:space:]]*c[rwx-]{9}' \
    "$FIXTURES/fire-masks-gitadd-refused.txt"
}

# ------------------------------------------- detector D: shipped candidates

@test "tmpdir-unset fires on a bash redirect collapsed under root" {
  assert_fixture fire-tmpdir-unset-redirect
}

@test "tmpdir-unset fires on a cp stat of a path collapsed under root" {
  assert_fixture fire-tmpdir-unset-cp-stat
}

@test "tmpdir-unset fires on the bare shape directly after the tool prefix" {
  # item-4-2-s1-code-review.md gap (a): no "line N:" locator between the
  # prefix and the root slash -- the bare shape Critical 1 fixed.
  assert_fixture fire-tmpdir-unset-bash-bare
  grep -qE '^bash: /[^/]+: No such file' "$FIXTURES/fire-tmpdir-unset-bash-bare.txt"
}

@test "resume-lost fires on a lost transcript refusal" {
  assert_fixture fire-resume-lost-two-turn
}

@test "seccomp-init fires on a sandbox init failure" {
  assert_fixture fire-seccomp-init-sed
}

# Each quiet fixture carries its detector's phrase, never where the matcher
# anchors it: without the pin a hollowed fixture would stay quiet vacuously.

@test "tmpdir-unset stays quiet on a refusal naming a deeper path" {
  local f="$FIXTURES/quiet-tmpdir-unset-deep-path.txt"
  assert_fixture quiet-tmpdir-unset-deep-path
  grep -qE "^ls: cannot access '/[^/']+/[^']+': No such file" "$f"
}

@test "resume-lost stays quiet on the index line quoting the refusal" {
  local f="$FIXTURES/quiet-resume-lost-index-line.txt"
  assert_fixture quiet-resume-lost-index-line
  grep -qF 'No conversation found' "$f"
  run ! grep -q '^No conversation found' "$f"
}

@test "seccomp-init stays quiet on a heading quoting the failure" {
  local f="$FIXTURES/quiet-seccomp-init-heading.txt"
  assert_fixture quiet-seccomp-init-heading
  grep -qF 'unshare(CLONE_NEWUSER)' "$f"
  run ! grep -q '^apply-seccomp' "$f"
}

# --------------------------------------- detector E: readonly-path (matcher)
#
# The quiet fixture is quieted by more than the line-start anchor;
# tests/matchers-edges.bats pins that anchor alone.

@test "readonly-path fires on a quoted cp refusal under /tmp" {
  assert_fixture fire-readonly-path-cp-tmp
}

@test "readonly-path fires on a background task's output file read" {
  assert_fixture fire-readonly-path-task-output
}

@test "readonly-path fires on a Python OSError errno 30 refusal" {
  assert_fixture fire-readonly-path-python-errno
}

@test "readonly-path fires on git's busy-device refusal" {
  assert_fixture fire-readonly-path-git-busy
}

@test "readonly-path stays quiet on the memory index line naming the message" {
  assert_fixture quiet-readonly-path-index-line
  local f="$FIXTURES/quiet-readonly-path-index-line.txt"
  grep -qF 'inter-device move failed' "$f"
  grep -qF 'Read-only file system' "$f"
}

# --------------------------------------------------- the store's own strings

@test "nothing fires on reading the memory file that documents the symptoms" {
  # sandbox-effects.md quotes the lock error and the masked names. It is the
  # single largest false-positive source in the corpus. This fixture is the
  # 2026-07-31 snapshot, before the config-lock section existed; the current
  # store is covered by its own case below.
  assert_fixture quiet-memory-file-read
  grep -q "Unable to create '.git/index.lock': File exists" \
    "$FIXTURES/quiet-memory-file-read.txt"
  grep -q 'crw-rw-rw-' "$FIXTURES/quiet-memory-file-read.txt"
}

@test "the live memory file still fires nothing" {
  # The fixture is a 2026-07-31 snapshot; this is the current store. Layer 1's
  # largest false-positive class was the store documenting its own error
  # strings, so the file the hook would replace must stay quiet as it is
  # edited. If it ever fires, the hook's injected text would too.
  local store="$BATS_TEST_DIRNAME/../memory/ddaanet/sandbox-effects.md"
  [ -f "$store" ] || skip "ddaanet memory tier not mounted yet; activates at repo init"
  run bash "$MATCHERS" < "$store"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "nothing fires on reading the always-loaded memory index" {
  assert_fixture quiet-index-line-read
  grep -q 'Unable to create' "$FIXTURES/quiet-index-line-read.txt"
}

@test "nothing fires on prose quoting the git add refusal and its follow-on" {
  # The changelog quotes `error: ... can only add regular files` AND
  # `fatal: adding files failed` in one sentence, so the follow-on test that
  # rescues match_git_lock cannot separate these. Line anchoring does.
  assert_fixture quiet-bats-fixture-grep
  grep -q 'can only add regular files' "$FIXTURES/quiet-bats-fixture-grep.txt"
  grep -q 'adding files failed' "$FIXTURES/quiet-bats-fixture-grep.txt"
}

@test "nothing fires on a report echoing recorded symptom output" {
  # The pilot's own layer-1 report quotes four `error: could not lock config
  # file ... File exists` lines and several lock diagnostics, each indented
  # behind a `> ` marker. Any session that reports on these symptoms produces
  # this shape, so it is a recurring class and not a self-inflicted one-off.
  assert_fixture quiet-pilot-report-echo
  [ "$(grep -c 'error: could not lock config file' \
       "$FIXTURES/quiet-pilot-report-echo.txt")" -ge 4 ]
  run ! grep -qE '^error: could not lock config file' \
    "$FIXTURES/quiet-pilot-report-echo.txt"
}

# ------------------------------------------------------------ healthy output

@test "nothing fires on a clean git status" {
  assert_fixture quiet-clean-status
  grep -q '^?? ' "$FIXTURES/quiet-clean-status.txt"
}

@test "nothing fires on a clean ls -la" {
  assert_fixture quiet-clean-ls
  grep -q '^-rw' "$FIXTURES/quiet-clean-ls.txt"
}

@test "nothing fires on prose containing a nested claude -p invocation" {
  # Detector C's false-positive class, kept as evidence: layer 1 found no true
  # positive for it, so no matcher here reads commands at all.
  assert_fixture quiet-heredoc-claude-p
  grep -q 'claude -p ping' "$FIXTURES/quiet-heredoc-claude-p.txt"
}

# --------------------------------------------------------------- portability

@test "the whole fixture sweep survives BSD grep, sed and mktemp" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools" f name
  make_bsd_stubs "$bsd" grep sed mktemp
  for f in "$FIXTURES"/*.txt; do
    name=$(basename "$f" .txt)
    PATH="$bsd:$PATH" assert_fixture "$name"
  done
}

# ------------------------------------------------------------ NFR-4: hermetic

@test "detect needs no temp dir" {
  # NFR-4: detect writes nothing. TMPDIR names a directory that does not
  # exist, so a buffer under it fails outright -- mktemp's X's randomise only
  # the leaf name, never the parent. The mktemp spy on PATH records any call
  # at all, so a buffer that falls back to /tmp when TMPDIR fails reds on the
  # last assertion. Residual: a write that calls no mktemp -- a hard-coded
  # path, or a here-document, which bash spools to a temp file (falling back
  # to /tmp itself) before 5.1 and above the pipe size after -- is unseen.
  local nonexistent="$BATS_TEST_TMPDIR/does-not-exist"
  local spy="$BATS_TEST_TMPDIR/spy" calls="$BATS_TEST_TMPDIR/spy-calls"
  make_spy "$spy" "$calls" mktemp
  run --separate-stderr env PATH="$spy:$PATH" TMPDIR="$nonexistent" \
    "$MATCHERS" < "$FIXTURES/fire-lock-add-commit.txt"
  [ "$status" -eq 0 ]
  [ "$output" = "git-lock" ]
  [ ! -e "$calls" ] || { cat "$calls" >&2; return 1; }
}
