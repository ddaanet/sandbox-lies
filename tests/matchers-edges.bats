#!/usr/bin/env bats
# lib/matchers.sh on input built at run time rather than cut from the corpus:
# near-miss pairs pinning one discriminator rule each, where no recorded
# fixture isolates the rule, and detect's handling of a NUL and a closed
# stdin. tests/matchers.bats holds the recorded fixtures.
#
# Every diagnostic here is assembled from fragments, so no source line reads
# a firing line whole and the self-quiet sweep (FR-11, tests/sweep-code.bats) stays
# quiet on this file.

ROOT="${BATS_TEST_DIRNAME}/.."
MATCHERS="$ROOT/lib/matchers.sh"
FIXTURES="$ROOT/tests/fixtures"

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/probes

# assert_verdict <want> <text> — detect on <text> prints exactly <want>, one
# verdict name, or nothing and exits 1 when <want> is empty.
assert_verdict() {
  local want="$1" text="$2"
  run bash "$MATCHERS" <<< "$text"
  [ "$output" = "$want" ] || {
    echo "want [$want] got [$output] on: $text" >&2
    return 1
  }
  if [ -n "$want" ]; then [ "$status" -eq 0 ]; else [ "$status" -eq 1 ]; fi
}

# ------------------------------------------- one rule per near-miss pair
#
# Each pair differs only in the trigger of the rule it names, so the negative
# cannot pass because the matcher is absent: the positive over the same text
# goes red first.

# item-4-2-s1-code-review.md gap (b), the quote-free-words rule: words ahead
# of the opening quote carry no straight quote of their own, so prose that
# single-quotes an unrelated command ahead of a refusal stays quiet.
tmpdir_unset_quoted_words_pair() {
  local q enoent
  q="'"
  enoent='No such file'
  enoent="$enoent or directory"
  assert_verdict tmpdir-unset \
    "Error: \`cp /a b\` said cp: cannot stat ${q}/a${q}: ${enoent}"
  assert_verdict '' \
    "Error: \`cp ${q}/a${q} b\` said cp: cannot stat ${q}/a${q}: ${enoent}"
}

@test "tmpdir-unset stays quiet when words before the quote hold a quote" {
  tmpdir_unset_quoted_words_pair
}

@test "tmpdir-unset stays quiet on a relative path after the prefix" {
  # item-4-2-s1-code-review.md gap (b): the bare alternative's root slash.
  local enoent
  enoent='No such file'
  enoent="$enoent or directory"
  assert_verdict tmpdir-unset "bash: /move-strays.sh: ${enoent}"
  assert_verdict '' "bash: move-strays.sh: ${enoent}"
}

@test "resume-lost stays quiet on a grep -n locator quoting the id whole" {
  # item-4-2-s1-code-review.md gap (c): quiet-resume-lost-index-line is also
  # quieted by its tail (the id is ellipsis-truncated); this pins the
  # line-start anchor alone, a numeric locator ahead of a whole id.
  local line
  line='No conversation found with session ID'
  line="$line: 1234abcd-5678-90ef-cdef-000011112222"
  assert_verdict resume-lost "$line"
  assert_verdict '' "42:$line"
}

@test "seccomp-init stays quiet on a grep -n locator quoting the failure whole" {
  # item-4-2-s1-code-review.md gap (c): as resume-lost, against the heading
  # fixture, which its heading marker and trailing backtick both quiet.
  local line
  line='apply-seccomp: unshare(CLONE_NEWUSER)'
  line="$line: Invalid argument"
  assert_verdict seccomp-init "$line"
  assert_verdict '' "7:$line"
}

@test "readonly-path fires on a refusal at line start, not quoted mid-line" {
  # quiet-readonly-path-index-line is quieted three ways at once: a slash,
  # not ": ", ahead of the message, prose after it, and no tool prefix at
  # line start. Dropping the line-start anchor leaves it quiet. Here the
  # refusal is whole and ends its line, behind a grep -n locator and prose,
  # which the anchor alone rejects -- for both alternatives.
  local erofs tool py
  erofs='Read-only'
  erofs="$erofs file system"
  tool="mv: cannot move 'a' to 'b': $erofs"
  py="OSError: [Errno 30] $erofs: 'hooks/hooks.json'"
  assert_verdict readonly-path "$tool"
  assert_verdict '' "48:- \`just release\` dies at the bump on $tool"
  assert_verdict readonly-path "$py"
  assert_verdict '' "48:- the hooks rewrite died with $py"
}

@test "readonly-path fires on Python's busy-device form, errno 16" {
  # No corpus call carries errno 16. Derived from the cut errno 30 line, so
  # the Python alternative's second errno and message are pinned too.
  local busy text
  busy='Device or resource'
  busy="$busy busy"
  text=$(sed "s/Errno 30\] Read-only file system/Errno 16] $busy/" \
    "$FIXTURES/fire-readonly-path-python-errno.txt")
  grep -qF "[Errno 16] $busy: " <<< "$text"
  run ! grep -qF 'Errno 30' <<< "$text"
  assert_verdict readonly-path "$text"
}

# ---------------------------- readonly-path: git's operation-not-permitted shapes
#
# Five git heads, each a whole line ending in the message, take the third
# alternative (eperm_shape_line builds them). Each shape's case pairs the fire
# with the near-misses of its line anchor, so the quiet half cannot pass
# because the matcher is absent.

# eperm_shape_case <n> <path> — shape <n> fires at the line start and with
# trailing blanks, and stays quiet behind a grep -n locator and mid-line.
eperm_shape_case() {
  local line
  line=$(eperm_shape_line "$1" "$2")
  assert_verdict readonly-path "$line"
  assert_verdict readonly-path "$line   "
  assert_verdict '' "48:$line"
  assert_verdict '' "- the checkout died with $line"
}

@test "readonly-path fires on git's create-file refusal, not behind a locator" {
  eperm_shape_case 1 .claude/agents/commit.md
}

@test "readonly-path fires on git's unlink-old refusal, not behind a locator" {
  eperm_shape_case 2 .claude/settings.json
}

@test "readonly-path fires on git's unlink warning, not behind a locator" {
  eperm_shape_case 3 .claude/agents/tdd-task.md
}

@test "readonly-path fires on git's config-write refusal, not behind a locator" {
  eperm_shape_case 4 .git/config
}

@test "readonly-path fires on git's index-lock refusal, not behind a locator" {
  eperm_shape_case 5 /r/.git/index.lock
}

@test "readonly-path stays quiet on other tools' lines ending in the message" {
  # A cp refusal ends the same way and the corpus holds ~90 of them: the
  # message alone is no signal, only the five git heads carry it.
  local cp
  cp="cp: cannot create special file '/r/x': $(eperm_message)"
  assert_verdict '' "$cp"
  assert_verdict '' "mv: cannot move 'a' to 'b': $(eperm_message)"
}

@test "readonly-path stays quiet on git heads outside the five shapes" {
  local msg head
  msg=$(eperm_message)
  head='error: could not lock '
  assert_verdict '' "${head}config file .git/config: $msg"
  head='fatal: cannot '
  assert_verdict '' "${head}unlink '.claude/x': $msg"
  head='error: cannot lock ref '
  assert_verdict '' "${head}'HEAD': Unable to create '/r/.git/HEAD.lock': $msg"
}

@test "readonly-path stays quiet on the lock head when the path is no index lock" {
  assert_verdict '' "$(eperm_shape_line 5 /idx.lock)"
  assert_verdict '' "$(eperm_shape_line 5 /r/.git/HEAD.lock)"
  assert_verdict '' "$(eperm_shape_line 5 /r/index.lock)"
}

@test "readonly-path stays quiet on each git head ending in another errno" {
  # The message is bound to the head: a third errno that is neither the
  # read-only-filesystem nor the busy-device message leaves each head quiet.
  local n path nospace
  nospace='No space'
  nospace="$nospace left on device"
  for n in 1 2 3 4 5; do
    path=/r/x
    [ "$n" -ne 5 ] || path=/r/.git/index.lock
    assert_verdict '' "$(eperm_shape_line "$n" "$path" "$nospace")"
  done
}

# ------------------------------------- FR-7: curly quotes, tab-indented names

@test "tmpdir-unset fires on a GNU refusal with the path in curly quotes" {
  # GNU coreutils quotes the path U+2018 ... U+2019 after the tool's own
  # words. The bytes are spelled out so the file holds no locale-dependent
  # literal. Dropping both curly quotes from the alternation leaves the
  # straight-quoted and bare alternatives, neither of which matches here.
  local lq rq enoent
  lq=$'\xe2\x80\x98'
  rq=$'\xe2\x80\x99'
  enoent='No such file'
  enoent="$enoent or directory"
  assert_verdict tmpdir-unset \
    "cp: cannot stat ${lq}/a${rq}: ${enoent}"
  # The same refusal on a deeper path is the near-miss and stays quiet.
  assert_verdict '' \
    "cp: cannot stat ${lq}/a/b${rq}: ${enoent}"
}

@test "phantom-untracked fires on a long-format status block, tab-indented" {
  # Long-format `git status` indents each untracked name with a tab and
  # prints a directory with a trailing slash; only the porcelain form
  # carries the two-character prefix. Dropping the whitespace alternative
  # leaves the porcelain form alone.
  local block
  block=$(printf '%s\n' 'On branch main' 'Untracked files:')
  block="$block"$'\n'"  (use \"git add <file>...\" to include in what will be committed)"
  block="$block"$'\n'$(printf '\t%s\n' .bashrc .claude/skills/ .gitconfig)
  [ "$(command grep -c $'^\t' <<< "$block")" -eq 3 ]
  assert_verdict phantom-untracked "$block"
  # One masked name alone stays under the threshold of two.
  assert_verdict '' "$(printf 'Untracked files:\n\t%s\n' .bashrc)"
}

@test "phantom-untracked counts a slash-suffixed name toward the threshold" {
  # Exactly two masked names, one carrying the trailing slash. Only the
  # slash-suffixed line is matched through the `/?` in the grep pattern, so
  # dropping it leaves a count of one.
  local block
  block=$(printf 'Untracked files:\n\t%s\n\t%s\n' .bashrc .claude/skills/)
  [ "$(command grep -c $'^\t' <<< "$block")" -eq 2 ]
  assert_verdict phantom-untracked "$block"
}

@test "phantom-untracked counts one name once, with and without the slash" {
  # The same name twice, spelled both ways, is one name. Dropping the `/?`
  # from the sed strip leaves two distinct spellings and the count reaches
  # the threshold.
  local block
  block=$(printf 'Untracked files:\n\t%s\n\t%s\n' .claude/skills .claude/skills/)
  [ "$(command grep -c $'^\t' <<< "$block")" -eq 2 ]
  assert_verdict '' "$block"
}

# --------------------------------------------------------------- portability

@test "a near-miss pair survives BSD grep and sed" {
  # The quoted-words pair: tmpdir-unset's regex is the most intricate of the
  # candidates' (two alternatives, bracket negations, a curly-quote
  # alternation).
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed
  PATH="$bsd:$PATH" tmpdir_unset_quoted_words_pair
}

# --------------------------------------------- slice 9: NUL and closed stdin

@test "detect sees past a NUL" {
  # item-2-3-s8-code-review.md F1: `read -r -d ''` stops at the first NUL, a
  # silent false negative for a firing line that arrives after one. The
  # firing line is assembled from two fragments at run time, never written
  # whole to this file, so the self-quiet sweep (FR-11, tests/sweep-code.bats)
  # stays quiet under this test too.
  local frag1 frag2 input_file
  frag1='could not lock config file .git/config: File'
  frag2=' exists'
  input_file="$BATS_TEST_TMPDIR/nul-then-firing.txt"
  printf 'quiet preamble text\n\000error: %s%s\n' "$frag1" "$frag2" \
    > "$input_file"
  # Without the NUL this is a plain firing case; pin that it is there.
  [ "$(LC_ALL=C tr -cd '\000' < "$input_file" | wc -c)" -eq 1 ]

  run --separate-stderr bash "$MATCHERS" < "$input_file"
  [ "$status" -eq 0 ]
  [ "$output" = "config-lock" ]
  [ -z "$stderr" ]
}

@test "detect on closed stdin" {
  # item-2-3-s8-code-review.md F3: a read failure must not hang, and reports
  # once on stderr rather than as one `text: unbound variable` per matcher.
  # stdin is closed by an inner `bash -c 'bash "$1" <&-'`: closed on the
  # outer `run` line instead, the freed fd 0 is taken by run's own capture
  # pipe (F3's mechanism, one level up), so the SUT would start with stdin
  # open on that pipe rather than closed. `timeout` bounds a hang.
  command -v timeout >/dev/null \
    || skip "no timeout on PATH; cannot bound a hang"
  # shellcheck disable=SC2016 # $1 is the inner bash -c's own arg, expanded there
  run --separate-stderr timeout 5 bash -c 'bash "$1" <&-' _ "$MATCHERS"
  [ "$status" -ne 124 ]
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  # shellcheck disable=SC2154 # set by bats' run --separate-stderr
  [ "${#stderr_lines[@]}" -eq 1 ]
}
