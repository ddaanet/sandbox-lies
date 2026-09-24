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

@test "the live memory file's quotation never carries the full follow-on clause" {
  # This is exactly what match_git_lock leans on, and it holds for a reason
  # worth naming: the store is hard-wrapped (this repo's `format-docs` does not
  # reach memory/), which splits `Another git process / seems to be running`
  # across two lines. A future edit that lands the whole clause on one line
  # breaks the discriminator, and this goes red before the matcher does.
  local store="$BATS_TEST_DIRNAME/../memory/ddaanet/sandbox-effects.md"
  [ -f "$store" ] || skip "ddaanet memory tier not mounted yet; activates at repo init"
  local follow='Another git process seems to be running'
  follow="$follow in this repository"
  grep -q 'Another git process' "$store"
  run ! grep -qF "$follow" "$store"
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
