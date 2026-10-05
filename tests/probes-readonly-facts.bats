#!/usr/bin/env bats
# lib/probes-readonly.sh's probe_readonly_path: the readfile=/merge=1/
# target=/match= facts it prints after path=, under writable and nopath only
# (Item 8.0 slice 3, docs/references/readonly-path.md readonly-path Probe facts
# table and the paragraph after it). tests/probes-readonly.bats already sits
# at the line cap, so this is a new file; it reuses that file's fixtures and
# helpers rather than duplicating them.
#
# The partial-checkout error lines are built from two fragments each around
# erofs_message (partial_checkout_unlink_error, partial_checkout_create_error),
# as helpers/probes.bash's git_lock_error is, so no source line here holds
# git's diagnostic whole (self-quiet, FR-11).

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
}

# git's partial-checkout lines under a read-only mount, in the shapes git's
# own format strings give them (git 2.47): the unlink form single-quotes the
# path, the create form does not, so the first reads writable and the second
# nopath.
partial_checkout_unlink_error() {
  local msg='error: unable to unlink '
  msg="${msg}old '$1': $(erofs_message)"
  printf '%s\n' "$msg"
}

partial_checkout_create_error() {
  local msg='error: unable to create '
  msg="${msg}file $1: $(erofs_message)"
  printf '%s\n' "$msg"
}

# git's third partial-checkout line (verified live, git 2.47.3): a missing
# directory under a read-only mount, its path single-quoted.
partial_checkout_mkdir_error() {
  local msg='fatal: cannot create '
  msg="${msg}directory at '$1': $(erofs_message)"
  printf '%s\n' "$msg"
}

@test "readfile reports a command-output path from a single reader" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'cat /w/build.log' "$text"

  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=/w/build.log'
}

@test "readfile reports a quoted command-output path from a reader pipeline" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'tail -n 50 "/w/a b.output" | grep -i error' "$text"

  [ "${output%%$'\n'*}" = nopath ]
  printf '%s\n' "$output" | grep -qxF 'readfile=/w/a b.output'
}

@test "facts appear only under writable and nopath, never readonly" {
  local file="$BATS_TEST_TMPDIR/locked" text cmd
  : >"$file"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$file'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'cat build.log' "$text"
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'readfile=build.log'

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'git pull' "$text"
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'

  chmod 444 "$file"
  if [ -w "$file" ]; then
    skip "chmod 444 not enforced for this user"
  fi
  for cmd in 'cat build.log' 'git pull'; do
    run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
      "$cmd" "$text"
    [ "${output%%$'\n'*}" = readonly ]
    [ "$(printf '%s\n' "$output" | wc -l)" -eq 2 ]
  done
}

@test "readfile requires a command-output extension" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'cat notes.md' "$text"
  run ! grep -q '^readfile=' <<<"$output"

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'cat build.log' "$text"
  printf '%s\n' "$output" | grep -qxF 'readfile=build.log'
}

@test "readfile excludes an in-place editor and redirected output" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'sed -i s/a/b/ build.log' "$text"
  run ! grep -q '^readfile=' <<<"$output"

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'sed s/a/b/ build.log' "$text"
  printf '%s\n' "$output" | grep -qxF 'readfile=build.log'

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'cat build.log > copy.txt' "$text"
  run ! grep -q '^readfile=' <<<"$output"

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'cat build.log' "$text"
  printf '%s\n' "$output" | grep -qxF 'readfile=build.log'
}

@test "readfile requires every command in a pipeline or list to be a reader" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'make 2>&1 | tee build.log' "$text"
  run ! grep -q '^readfile=' <<<"$output"

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'tail build.log | grep -i error' "$text"
  printf '%s\n' "$output" | grep -qxF 'readfile=build.log'

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'npm test && cat build.log' "$text"
  run ! grep -q '^readfile=' <<<"$output"

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'head build.log && cat build.log' "$text"
  printf '%s\n' "$output" | grep -qxF 'readfile=build.log'
}

# No repository holds $BATS_TEST_TMPDIR, so no ref resolves: merge=1 alone,
# and a probe that runs git there must keep git's refusal off stderr.
@test "merge=1 fires for a git merge-style command segment" {
  local text cmd
  assert_no_git_above "$BATS_TEST_TMPDIR"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  for cmd in 'git merge --ff-only feat' 'git -C /r/repo checkout feat' \
    'git pull'; do
    run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
      "$cmd" "$text"
    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
    printf '%s\n' "$output" | grep -qxF 'merge=1'
  done
}

@test "merge=1 does not fire for a non-merge command or an echoed mention" {
  local text
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/x'")

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'git merge feat' "$text"
  printf '%s\n' "$output" | grep -qxF 'merge=1'

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'git log --merges' "$text"
  run ! grep -q '^merge=1$' <<<"$output"

  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'echo git merge feat' "$text"
  run ! grep -q '^merge=1$' <<<"$output"
}

@test "merge=1 fires from git's partial-checkout error in the text, under any command" {
  local text

  text=$(partial_checkout_unlink_error "$BATS_TEST_TMPDIR/a")
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'just sync' "$text"
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'

  text=$(partial_checkout_create_error "$BATS_TEST_TMPDIR/b")
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'just sync' "$text"
  [ "${output%%$'\n'*}" = nopath ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'

  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/a'")
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'just sync' "$text"
  [ "${output%%$'\n'*}" = writable ]
  run ! grep -q '^merge=1$' <<<"$output"
}

@test "partial=1 fires with merge=1 for each of git's three partial-checkout errors, not for another tool's refusal" {
  local text

  text=$(partial_checkout_unlink_error "$BATS_TEST_TMPDIR/a")
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'just sync' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'
  printf '%s\n' "$output" | grep -qxF 'partial=1'

  text=$(partial_checkout_create_error "$BATS_TEST_TMPDIR/b")
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'just sync' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = nopath ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'
  printf '%s\n' "$output" | grep -qxF 'partial=1'

  # The third needle alone, under a non-merge command, still gives merge=1.
  text=$(partial_checkout_mkdir_error "$BATS_TEST_TMPDIR/c")
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'just sync' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'
  printf '%s\n' "$output" | grep -qxF 'partial=1'

  # negative control: a merge-style command whose text holds only another
  # tool's refusal gives merge=1 from the command shape alone, no partial=1.
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$BATS_TEST_TMPDIR/a'")
  run_probe_command probe_readonly_path false "$BATS_TEST_TMPDIR" \
    'git merge feat' "$text"
  printf '%s\n' "$output" | grep -qxF 'merge=1'
  run ! grep -q '^partial=1$' <<<"$output"
}

# The index is back-dated so that a rewrite moves its mtime even within the
# second the fixture was made in, and snapshotted around the probe call only.
@test "target and match select files at the resolved ref, staged or not, never one edited otherwise" {
  local repo="$BATS_TEST_TMPDIR/scratch repo" text facts before_mtime

  make_scratch_repo "$repo"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$repo'")
  touch -t 200001010000 "$repo/.git/index"
  cp "$repo/.git/index" "$BATS_TEST_TMPDIR/index-before"
  before_mtime=$(index_mtime "$repo/.git/index")

  run_probe_command probe_readonly_path false "$repo" 'git checkout feat' \
    "$text"

  facts=$output
  cmp -s "$repo/.git/index" "$BATS_TEST_TMPDIR/index-before"
  [ "$(index_mtime "$repo/.git/index")" = "$before_mtime" ]
  [ ! -e "$repo/.git/index.lock" ]
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${facts%%$'\n'*}" = writable ]
  printf '%s\n' "$facts" | grep -qxF 'merge=1'
  printf '%s\n' "$facts" | grep -qxF 'target=feat'
  printf '%s\n' "$facts" | grep -qxF "match=$repo/a"
  printf '%s\n' "$facts" | grep -qxF "match=$repo/b"
  printf '%s\n' "$facts" | grep -qxF "match=$repo/e f"
  run ! grep -qxF "match=$repo/c" <<<"$facts"
  run ! grep -qxF "match=$repo/d" <<<"$facts"
}

@test "an unresolvable ref gives merge=1 and no target" {
  local repo="$BATS_TEST_TMPDIR/scratch repo" text

  make_scratch_repo "$repo"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$repo'")

  run_probe_command probe_readonly_path false "$repo" 'git merge feat' "$text"
  printf '%s\n' "$output" | grep -qxF 'target=feat'

  run_probe_command probe_readonly_path false "$repo" \
    'git merge no-such-ref-xyz' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'
  run ! grep -q '^target=' <<<"$output"
}

# The cwd is a second repository without feat, so a probe preferring the
# cwd's repository over the path's finds no target.
@test "the repository is the path's nearest existing directory's, not the cwd's" {
  local repo="$BATS_TEST_TMPDIR/scratch repo" text
  local cwd="$BATS_TEST_TMPDIR/other repo"

  make_scratch_repo "$repo"
  git init -q -b main "$cwd"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$repo/missing'")

  run_probe_command probe_readonly_path false "$cwd" 'git checkout feat' \
    "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'target=feat'
  printf '%s\n' "$output" | grep -qxF "match=$repo/a"
}

@test "nopath falls back to the cwd's repository" {
  local repo="$BATS_TEST_TMPDIR/scratch repo" text
  make_scratch_repo "$repo"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "")

  run_probe_command probe_readonly_path false "$repo" 'git checkout feat' \
    "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = nopath ]
  printf '%s\n' "$output" | grep -qxF 'target=feat'
  printf '%s\n' "$output" | grep -qxF "match=$repo/a"
}

# The facts through BSD grep, sed, stat and wc (NFR-2): one call per kind of
# fact the probe derives — the ref and files, the quoted reader argument, the
# partial-checkout text.
@test "the facts survive BSD grep, sed, stat and wc" {
  local repo="$BATS_TEST_TMPDIR/scratch repo" bsd="$BATS_TEST_TMPDIR/bsdtools"
  local text
  make_scratch_repo "$repo"
  make_bsd_stubs "$bsd" grep sed stat wc

  text=$(readonly_path_text fire-readonly-path-cp-tmp "'$repo'")
  PATH="$bsd:$PATH" run_probe_command probe_readonly_path false "$repo" \
    'git checkout feat' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'target=feat'
  printf '%s\n' "$output" | grep -qxF "match=$repo/a"
  printf '%s\n' "$output" | grep -qxF "match=$repo/e f"

  text=$(readonly_path_text fire-readonly-path-cp-tmp "")
  PATH="$bsd:$PATH" run_probe_command probe_readonly_path false \
    "$BATS_TEST_TMPDIR" 'tail -n 50 "/w/a b.output" | grep -i error' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'readfile=/w/a b.output'

  text=$(partial_checkout_unlink_error "$BATS_TEST_TMPDIR/a")
  PATH="$bsd:$PATH" run_probe_command probe_readonly_path false \
    "$BATS_TEST_TMPDIR" 'just sync' "$text"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'
}
