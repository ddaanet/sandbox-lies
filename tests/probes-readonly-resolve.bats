#!/usr/bin/env bats
# lib/probes-readonly.sh's probe_readonly_path: where a relative path joins
# (design section B). A path named by git's own partial-checkout refusal is
# relative to the worktree top, not to the cwd the command ran in; every other
# producer (cp, mv, touch, bash) resolves against its own process cwd. The
# facts the probe prints after path= are pinned in
# tests/probes-readonly-facts.bats, the plain join in
# tests/probes-readonly.bats.
#
# The partial-checkout lines come from helpers/probes.bash's
# partial_checkout_*_error, built from two fragments each around erofs_message,
# so no source line here holds git's diagnostic whole (self-quiet, FR-11).

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/probes

# path= is printed in printf %q form, so the literal expected lines below hold
# only while BATS_TEST_TMPDIR holds no byte %q escapes.
setup() {
  source "$ROOT/lib/probes.sh"
  [ "$(LC_ALL=C printf %q "$BATS_TEST_TMPDIR")" = "$BATS_TEST_TMPDIR" ]
}

# path_line — the one path= line of the last probe run, empty when none.
path_line() {
  printf '%s\n' "$output" | grep '^path=' || :
}

@test "partial-checkout path joins onto the worktree top, not the cwd" {
  local repo="$BATS_TEST_TMPDIR/repo" text
  mkdir -p "$repo/.git" "$repo/sub" "$repo/d"
  : >"$repo/d/f"

  text=$(partial_checkout_unlink_error d/f)
  run_probe_command probe_readonly_path false "$repo/sub" 'just sync' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$(path_line)" = "path=$repo/d/f" ]
  [ "${output%%$'\n'*}" = writable ]
}

# The create-directory shape names a path that does not exist yet: the
# worktree top's d decides, and d/n does not. The cwd sits two levels below the
# top, so a join onto the cwd's parent does not pass for the top.
@test "partial-checkout directory path joins onto the worktree top" {
  local repo="$BATS_TEST_TMPDIR/repo" text
  mkdir -p "$repo/.git" "$repo/sub/deep" "$repo/d"

  text=$(partial_checkout_mkdir_error d/n)
  run_probe_command probe_readonly_path false "$repo/sub/deep" 'just sync' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$(path_line)" = "path=$repo/d/n" ]
  [ "${output%%$'\n'*}" = writable ]
}

# A linked worktree's .git is a file. The worktree sits inside the main
# repository, so the walk meets the worktree's own .git entry first and the
# main repository's after it: joining onto the outer one names main/d/f. The
# cwd sits two levels below the worktree top, as in the case above.
@test "partial-checkout path joins onto a linked worktree's top from a subdirectory" {
  local main="$BATS_TEST_TMPDIR/main" wt text
  wt="$main/wt"
  git init -q -b main "$main"
  git -C "$main" commit -q --allow-empty -m init
  git -C "$main" worktree add -q "$wt" -b wtbranch
  [ -f "$wt/.git" ]
  mkdir -p "$wt/sub/deep" "$wt/d" "$main/d"
  : >"$wt/d/f"
  : >"$main/d/f"

  text=$(partial_checkout_unlink_error d/f)
  run_probe_command probe_readonly_path false "$wt/sub/deep" 'just sync' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$(path_line)" = "path=$wt/d/f" ]
  [ "${output%%$'\n'*}" = writable ]
}

# The cwd is the linked worktree's own top, so its .git entry is the first one
# the walk meets. Walking from the cwd's parent would meet the main checkout's
# .git instead and name main/d/f; the top's own d/f is the answer.
@test "partial-checkout path joins onto a linked worktree's top when the cwd is that top" {
  local main="$BATS_TEST_TMPDIR/main" wt text
  wt="$main/wt"
  git init -q -b main "$main"
  git -C "$main" commit -q --allow-empty -m init
  git -C "$main" worktree add -q "$wt" -b wtbranch
  [ -f "$wt/.git" ]
  mkdir -p "$wt/d" "$main/d"
  : >"$wt/d/f"
  : >"$main/d/f"

  text=$(partial_checkout_unlink_error d/f)
  run_probe_command probe_readonly_path false "$wt" 'just sync' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$(path_line)" = "path=$wt/d/f" ]
  [ "${output%%$'\n'*}" = writable ]
}

@test "partial-checkout path resolves through BSD grep and sed" {
  local repo="$BATS_TEST_TMPDIR/repo" text bsd="$BATS_TEST_TMPDIR/bsdtools"
  mkdir -p "$repo/.git" "$repo/sub" "$repo/d"
  : >"$repo/d/f"
  make_bsd_stubs "$bsd" grep sed
  text=$(partial_checkout_unlink_error d/f)

  PATH="$bsd:$PATH" run_probe_command probe_readonly_path false "$repo/sub" \
    'just sync' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$(path_line)" = "path=$repo/d/f" ]
  [ "${output%%$'\n'*}" = writable ]
}

# Regression: cp resolves a relative operand against its own cwd, so its
# refusal keeps joining onto the cwd even inside a repository. d/f exists at
# both places so the outcome cannot tell the joins apart; the path does.
@test "a cp refusal naming a relative path still joins onto the cwd" {
  local repo="$BATS_TEST_TMPDIR/repo" text
  mkdir -p "$repo/.git" "$repo/sub/d" "$repo/d"
  : >"$repo/sub/d/f"
  : >"$repo/d/f"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'d/f'")

  run_probe_command probe_readonly_path false "$repo/sub" 'cp x d/f' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$(path_line)" = "path=$repo/sub/d/f" ]
  [ "${output%%$'\n'*}" = writable ]
}

# The rule reads the matching line alone: a partial-checkout line elsewhere in
# the result does not move a cp refusal's join.
@test "a partial-checkout line elsewhere in the text does not move a cp refusal's join" {
  local repo="$BATS_TEST_TMPDIR/repo" text
  mkdir -p "$repo/.git" "$repo/sub/d" "$repo/d"
  : >"$repo/sub/d/f"
  : >"$repo/d/f"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'d/f'")
  text="$text"$'\n'"$(partial_checkout_unlink_error d/g)"

  run_probe_command probe_readonly_path false "$repo/sub" 'cp x d/f' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$(path_line)" = "path=$repo/sub/d/f" ]
  [ "${output%%$'\n'*}" = writable ]
}

# No .git entry above the cwd: there is no worktree top to join onto.
@test "a partial-checkout path with no .git above the cwd joins onto the cwd" {
  local plain="$BATS_TEST_TMPDIR/plain" text
  mkdir -p "$plain/sub/d" "$plain/d"
  : >"$plain/sub/d/f"
  : >"$plain/d/f"
  assert_no_git_above "$plain/sub"
  text=$(partial_checkout_unlink_error d/f)

  run_probe_command probe_readonly_path false "$plain/sub" 'just sync' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$(path_line)" = "path=$plain/sub/d/f" ]
  [ "${output%%$'\n'*}" = writable ]
}

# Under errexit a text with no matching line must still reach nopath: grep's
# status 1 is caught on the line's own assignment, so the probe does not abort.
@test "probe_readonly_path under set -e prints nopath and exits 0 when no line matches" {
  run bash -c 'set -e; source "$1"; printf "%s\n" "$2" | probe_readonly_path false "$3" x' _ \
    "$ROOT/lib/probes.sh" "plain text, no refusal" "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = nopath ]
}

@test "probe_readonly_path under set -e prints nopath through BSD grep and sed" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed

  PATH="$bsd:$PATH" run bash -c 'set -e; source "$1"; printf "%s\n" "$2" | probe_readonly_path false "$3" x' _ \
    "$ROOT/lib/probes.sh" "plain text, no refusal" "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [ "${output%%$'\n'*}" = nopath ]
}

# phrase_path <n> — a relative path whose name holds the n-th of git's three
# partial-checkout phrases, built from fragments (self-quiet, FR-11).
phrase_path() {
  local phrase
  case "$1" in
    1) phrase='unable to unlink'; phrase="$phrase old" ;;
    2) phrase='unable to create'; phrase="$phrase file" ;;
    3) phrase='cannot create'; phrase="$phrase directory at" ;;
  esac
  printf '%s\n' "$phrase/x"
}

# A cp refusal is not git's: its line opens with the tool name, so a phrase
# inside the quoted path does not make it a partial-checkout line. The cwd sub
# holds the named directory, the worktree top does not: a join onto the top
# names a path whose parent is missing and reads readonly; the cwd join reads
# writable. Nothing but the join's base moves that outcome and the path line.
# Each of the three phrases is tried, so a gate anchored on one prefix only
# still fails on the others.
@test "a cp refusal whose path holds a partial-checkout phrase still joins onto the cwd" {
  local repo="$BATS_TEST_TMPDIR/repo" text rel expected n
  for n in 1 2 3; do
    rm -rf "$repo"
    rel=$(phrase_path "$n")
    mkdir -p "$repo/.git" "$repo/sub/${rel%/*}"
    : >"$repo/sub/$rel"
    text=$(readonly_path_text fire-readonly-path-cp-tmp "'$rel'")
    LC_ALL=C printf -v expected 'path=%q' "$repo/sub/$rel"

    run_probe_command probe_readonly_path false "$repo/sub" "cp x '$rel'" "$text"

    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
    [ "$(path_line)" = "$expected" ]
    [ "${output%%$'\n'*}" = writable ]
  done
}

# The neighbour: git's own line, same phrase at its prefix, still joins onto
# the worktree top (the cwd holds no d/f).
@test "git's own partial-checkout line still joins onto the top beside a phrase-in-path cp case" {
  local repo="$BATS_TEST_TMPDIR/repo" text
  mkdir -p "$repo/.git" "$repo/sub" "$repo/d"
  : >"$repo/d/f"
  text=$(partial_checkout_unlink_error d/f)

  run_probe_command probe_readonly_path false "$repo/sub" 'just sync' "$text"

  [ "$(path_line)" = "path=$repo/d/f" ]
  [ "${output%%$'\n'*}" = writable ]
}

# The top's name ends in a newline: a command substitution around the walk
# strips it, so the join names a sibling directory that does not exist (read
# as readonly). The real top holds d/f, so only the lost newline moves the
# outcome and the path line.
@test "a worktree top whose name ends in a newline keeps it in the joined path" {
  local top="$BATS_TEST_TMPDIR/top"$'\n' text expected
  mkdir -p "$top/.git" "$top/sub" "$top/d"
  : >"$top/d/f"
  text=$(partial_checkout_unlink_error d/f)
  LC_ALL=C printf -v expected 'path=%q' "$top/d/f"

  run_probe_command probe_readonly_path false "$top/sub" 'just sync' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$(path_line)" = "$expected" ]
  [ "${output%%$'\n'*}" = writable ]
}

# An empty cwd stands for the probe's own working directory, as
# _probe_readonly_resolve documents (outline section B has no empty-cwd rule of
# its own, so the walk applies from that directory like any other cwd); the worktree top is then the nearest .git
# above that directory. Joining onto the bare working directory names sub/d/f,
# which exists too, so the path line tells the joins apart.
@test "an empty cwd walks from the probe's working directory to the worktree top" {
  local repo="$BATS_TEST_TMPDIR/repo" text
  mkdir -p "$repo/.git" "$repo/sub/d" "$repo/d"
  : >"$repo/sub/d/f"
  : >"$repo/d/f"
  text=$(partial_checkout_unlink_error d/f)

  cd "$repo/sub"
  run_probe_command probe_readonly_path false "" 'just sync' "$text"

  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "$(path_line)" = "path=$repo/d/f" ]
  [ "${output%%$'\n'*}" = writable ]
}

# Outline section B: a relative path joins onto `cwd` unless the line is git's
# partial-checkout text, and "with no .git ancestor it joins onto cwd as today".
# An empty cwd stands for $PWD (_probe_readonly_resolve), so a cp refusal from
# an empty cwd joins onto $PWD itself, not onto the worktree top above it.
@test "an empty cwd leaves a cp refusal joined onto the probe's working directory" {
  local repo="$BATS_TEST_TMPDIR/repo" text
  mkdir -p "$repo/.git" "$repo/sub/d" "$repo/d"
  : >"$repo/sub/d/f"
  : >"$repo/d/f"
  text=$(readonly_path_text fire-readonly-path-cp-tmp "'d/f'")

  cd "$repo/sub"
  run_probe_command probe_readonly_path false "" 'cp x d/f' "$text"

  [ "$status" -eq 0 ]
  [ "$(path_line)" = "path=$repo/sub/d/f" ]
  [ "${output%%$'\n'*}" = writable ]
}

# The outline's fallback for no .git ancestor holds for an empty cwd too: the
# join lands on the probe's working directory.
@test "an empty cwd with no .git above the working directory joins onto it" {
  local plain="$BATS_TEST_TMPDIR/plain" text
  mkdir -p "$plain/sub/d" "$plain/d"
  : >"$plain/sub/d/f"
  : >"$plain/d/f"
  assert_no_git_above "$plain/sub"
  text=$(partial_checkout_unlink_error d/f)

  cd "$plain/sub"
  run_probe_command probe_readonly_path false "" 'just sync' "$text"

  [ "$status" -eq 0 ]
  [ "$(path_line)" = "path=$plain/sub/d/f" ]
  [ "${output%%$'\n'*}" = writable ]
}
