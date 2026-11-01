#!/usr/bin/env bats
# bin/sandbox-lies-recover: recovery of a `git checkout <branch>` or
# `git merge --ff-only <commit-ish>` that a read-only directory (chmod 555,
# standing in for the sandbox's refusal) killed part-way. Each case builds a
# scratch repo, runs the refused command while the directory is read-only,
# makes it writable again (the script runs unsandboxed in real use), runs the
# script with --apply, and asserts the branch or HEAD is at the target, that
# `git status` lists only the work that was kept, and that work is intact.
#
# Contract: plans/2026-11-01-recovery-script.md. No git diagnostic is quoted
# here (self-quiet, FR-11): the refusals are asserted by exit status and HEAD
# position, as the observation table in
# skills/sandbox-lies/references/refused-merge-recovery.md records them.

# shellcheck disable=SC2030,SC2031 # state set in a @test body is read by the helpers below

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env

RECOVER="$BATS_TEST_DIRNAME/../bin/sandbox-lies-recover"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  BASEBR=main
  git config --file "$GIT_CONFIG_GLOBAL" init.defaultBranch main
}

# A frozen directory is not removable by bats; make the whole tree writable.
teardown() {
  chmod -R u+w "$BATS_TEST_TMPDIR" 2>/dev/null || true
}

# ---- the cases -------------------------------------------------------------

# The eight cells of the observation table.

@test "checkout, target changes a file in a read-only directory" {
  cell checkout change
}

@test "checkout, target adds a file in a read-only directory" {
  cell checkout add
}

@test "checkout, target deletes a file in a read-only directory" {
  cell checkout delete
}

@test "checkout, target adds a directory under a read-only directory" {
  cell checkout adddir
}

@test "merge --ff-only, target changes a file in a read-only directory" {
  cell merge change
}

@test "merge --ff-only, target adds a file in a read-only directory" {
  cell merge add
}

@test "merge --ff-only, target deletes a file in a read-only directory" {
  cell merge delete
}

@test "merge --ff-only, target adds a directory under a read-only directory" {
  cell merge adddir
}

# Mixed and neighbouring states.

@test "checkout: a path staged with the target's content then edited further is kept" {
  scenario checkout change
  printf 'f v3 mine\n' >"$REPO/d/f"
  apply_ok
  [[ "$output" == *"keep d/f"* ]]
  assert_reached
  assert_status ' M d/f'
  assert_bytes d/f $'f v3 mine\n'
}

@test "checkout: an untracked leftover edited after the refusal is kept" {
  scenario checkout delete
  printf 'f v1 edited\n' >"$REPO/d/f"
  apply_ok
  [[ "$output" == *"keep d/f"* ]]
  assert_reached
  assert_status '?? d/f'
  assert_bytes d/f $'f v1 edited\n'
}

@test "checkout of a branch at the current commit, refused on index.lock, ends at exit 0" {
  build_repo same
  PRE=$(g rev-parse HEAD)
  TARGET=$PRE
  VERB=checkout
  : >"$REPO/.git/index.lock"
  run git -C "$REPO" checkout feat
  [ "$status" -ne 0 ]
  [ "$(g symbolic-ref -q HEAD)" = refs/heads/main ]
  # The lock is the sandbox's doing; the script runs unsandboxed without it.
  rm "$REPO/.git/index.lock"
  apply_ok
  assert_reached
  assert_status
}

@test "H1: the checkout re-run by hand before recovery still recovers" {
  scenario_up checkout change
  run git -C "$REPO" checkout feat
  [ "$status" -eq 0 ]
  [ "$(g reflog -1 --format=%gs)" = "checkout: moving from feat to feat" ]
  thaw
  apply_ok
  assert_reached
  assert_status
}

@test "M1: a file added inside a new directory, under checkout" {
  cell checkout m1
}

@test "M1: a file added inside a new directory, under merge --ff-only" {
  cell merge m1
}

@test "M1: a deleted directory, under checkout" {
  cell checkout deldir
}

@test "M1: a deleted directory, under merge --ff-only" {
  cell merge deldir
}

@test "M5: a rename out of a refused directory, under checkout" {
  cell checkout rename
}

@test "M5: a rename out of a refused directory, under merge --ff-only" {
  cell merge rename
}

@test "M6: an untracked leftover identical to pre is removed" {
  scenario checkout delete
  [ "$(cat "$REPO/d/f")" = "f v1" ]
  [ "$(g status --porcelain -uall)" = "?? d/f" ]
  apply_ok
  [[ "$output" == *"remove d/f"* ]]
  [ ! -e "$REPO/d/f" ]
  assert_reached
  assert_status
}

@test "paths with a space and with a newline, under checkout" {
  cell checkout odd
}

@test "paths with a space and with a newline, under merge --ff-only" {
  cell merge odd
}

@test "paths with a space and with a newline are kept byte for byte when edited" {
  scenario checkout odd
  printf 'sp mine\n' >"$REPO/d/sp ace.txt"
  printf 'nl mine\n' >"$REPO/d/nl"$'\n'"file.txt"
  apply_ok
  [[ "$output" == *"keep d/sp ace.txt"* ]]
  assert_reached
  assert_status " M d/nl"$'\n'"file.txt" ' M d/sp ace.txt'
  assert_bytes "d/sp ace.txt" $'sp mine\n'
  assert_bytes "d/nl"$'\n'"file.txt" $'nl mine\n'
}

@test "an unrelated uncommitted change survives, under checkout" {
  UNRELATED=1
  scenario checkout change
  apply_ok
  assert_reached
  assert_status ' M other.txt' '?? scratch.txt'
  assert_bytes other.txt $'other v1\nmine\n'
  assert_bytes scratch.txt $'scratch\n'
}

@test "an unrelated uncommitted change survives, under merge --ff-only" {
  UNRELATED=1
  scenario merge add
  apply_ok
  assert_reached
  assert_status ' M other.txt' '?? scratch.txt'
  assert_bytes other.txt $'other v1\nmine\n'
  assert_bytes scratch.txt $'scratch\n'
}

@test "an unrelated change next to kept work: both stay" {
  UNRELATED=1
  scenario checkout change
  printf 'f v3 mine\n' >"$REPO/d/f"
  apply_ok
  [[ "$output" == *"keep d/f"* ]]
  assert_reached
  assert_status ' M d/f' ' M other.txt' '?? scratch.txt'
  assert_bytes d/f $'f v3 mine\n'
  assert_bytes other.txt $'other v1\nmine\n'
}

# Dry run.

@test "a dry run changes nothing under checkout and prints the plan" {
  scenario checkout change
  local before after
  before=$(snap)
  run rec dry checkout feat
  [ "$status" -eq 0 ]
  [[ "$output" == *"restore d/f"* ]]
  after=$(snap)
  [ "$before" = "$after" ]
}

@test "a dry run changes nothing under merge and ends the plan with the re-run" {
  scenario merge m1
  local before after
  before=$(snap)
  run rec dry merge feat
  [ "$status" -eq 0 ]
  [[ "$output" == *"remove a/new/x"* ]]
  [[ "${lines[$((${#lines[@]} - 1))]}" == *"git merge --ff-only feat" ]]
  after=$(snap)
  [ "$before" = "$after" ]
}

@test "--apply prints each act and the re-run it runs" {
  scenario merge m1
  apply_ok
  [[ "$output" == *"remove a/new/x"* ]]
  [[ "$output" == *"git merge --ff-only feat"* ]]
  assert_reached
  assert_status
}

# Exit codes.

@test "exit 0 and no change when the recovery has already been done" {
  scenario checkout change
  apply_ok
  assert_reached
  assert_status
  local before after
  before=$(snap)
  apply_ok
  after=$(snap)
  [ "$before" = "$after" ]
  assert_status
}

@test "exit 1 when the re-run is refused again, and HEAD stays" {
  build_repo same
  PRE=$(g rev-parse HEAD)
  : >"$REPO/.git/index.lock"
  run git -C "$REPO" checkout feat
  [ "$status" -ne 0 ]
  run rec apply checkout feat
  [ "$status" -eq 1 ]
  [ "$(g symbolic-ref -q HEAD)" = refs/heads/main ]
  [ "$(g rev-parse HEAD)" = "$PRE" ]
}

@test "exit 1 when kept work blocks the re-run, which leaves HEAD and the work alone" {
  scenario merge add
  printf 'mine\n' >"$REPO/d/new"
  run rec apply merge feat
  [ "$status" -eq 1 ]
  [[ "$output" == *"keep d/new"* ]]
  [ "$(g rev-parse HEAD)" = "$PRE" ]
  [ "$(g symbolic-ref -q HEAD)" = refs/heads/main ]
  assert_status '?? d/new'
  assert_bytes d/new $'mine\n'
}

@test "exit 2 without arguments" {
  build_repo plain
  run in_repo
  [ "$status" -eq 2 ]
}

@test "exit 2 for an unknown subcommand" {
  build_repo plain
  run in_repo --apply rebase feat
  [ "$status" -eq 2 ]
}

@test "exit 2 for an unknown option" {
  build_repo plain
  run in_repo --force checkout feat
  [ "$status" -eq 2 ]
}

@test "exit 2 for checkout without a branch" {
  build_repo plain
  run in_repo checkout
  [ "$status" -eq 2 ]
}

@test "exit 2 for -C naming a directory that is no repository" {
  mkdir "$BATS_TEST_TMPDIR/empty"
  run "$RECOVER" -C "$BATS_TEST_TMPDIR/empty" checkout feat
  [ "$status" -eq 2 ]
}

@test "exit 2 and nothing touched when a reached checkout has no move in the reflog" {
  cannot_tell_repo
  g symbolic-ref HEAD refs/heads/feat
  [ "$(g symbolic-ref -q HEAD)" = refs/heads/feat ]
  local before after
  before=$(snap)
  run in_repo --apply checkout feat
  [ "$status" -eq 2 ]
  [ -n "$output" ]
  after=$(snap)
  [ "$before" = "$after" ]
}

@test "exit 2 and nothing touched when a reached merge has no fast-forward in the reflog" {
  cannot_tell_repo
  local before after
  before=$(snap)
  run in_repo --apply merge main
  [ "$status" -eq 2 ]
  [ -n "$output" ]
  after=$(snap)
  [ "$before" = "$after" ]
}

# -C, linked worktree, portability.

@test "-C from an unrelated directory, to a repository whose path has a space" {
  REPO="$BATS_TEST_TMPDIR/my repo"
  USE_C=1
  cell checkout change
}

@test "-C names a linked worktree" {
  build_repo change
  local wt="$BATS_TEST_TMPDIR/wt tree"
  g worktree add -q -b wtb "$wt" main
  REPO=$wt
  BASEBR=wtb
  VERB=checkout
  PRE=$(g rev-parse HEAD)
  TARGET=$(g rev-parse feat)
  refuse
  thaw
  USE_C=1
  apply_ok
  assert_reached
  assert_status
}

@test "under BSD stubs on PATH: a merge with a removal and a re-run" {
  make_bsd_stubs "$BATS_TEST_TMPDIR/stubs" sed grep mktemp stat wc
  STUBS="$BATS_TEST_TMPDIR/stubs"
  scenario merge m1
  apply_ok
  [[ "$output" == *"remove a/new/x"* ]]
  assert_reached
  assert_status
}

# ---- scenario helpers ------------------------------------------------------

# One table cell: refuse, thaw, recover, assert a clean end at the target.
cell() {
  scenario "$1" "$2"
  apply_ok
  assert_reached
  assert_status ${UNRELATED:+' M other.txt' '?? scratch.txt'}
}

# Build the repo, run the refused command frozen, thaw.
scenario() {
  scenario_up "$@"
  thaw
}

# Build the repo and run the refused command, leaving the directory frozen.
scenario_up() {
  VERB=$1
  build_repo "$2"
  KIND=$2
  PRE=$(g rev-parse HEAD)
  TARGET=$(g rev-parse feat)
  if [ -n "${UNRELATED-}" ]; then
    printf 'mine\n' >>"$REPO/other.txt"
    printf 'scratch\n' >"$REPO/scratch.txt"
  fi
  refuse
}

# Run the refused command with d read-only and check it refused as the table
# says, so a case cannot pass on a setup that never refused.
refuse() {
  local want_status want_pos
  read -r want_status want_pos <<<"$(refusal_expect "$VERB" "${KIND-}")"
  [ -n "$want_status" ]
  chmod 555 "$REPO/d"
  if [ "$VERB" = checkout ]; then
    run git -C "$REPO" checkout feat
  else
    run git -C "$REPO" merge --ff-only feat
  fi
  [ "$status" -eq "$want_status" ]
  if [ "$want_pos" = moved ]; then
    if [ "$VERB" = checkout ]; then
      [ "$(g symbolic-ref -q HEAD)" = refs/heads/feat ]
    else
      [ "$(g rev-parse HEAD)" = "$TARGET" ]
    fi
  else
    [ "$(g rev-parse HEAD)" = "$PRE" ]
    [ "$(g symbolic-ref -q HEAD)" = "refs/heads/$BASEBR" ]
  fi
}

# status and HEAD position of the refused command, per the observation table.
refusal_expect() {
  case "$1/$2" in
    checkout/adddir | merge/adddir) echo "128 unmoved" ;;
    checkout/*) echo "0 moved" ;;
    merge/change | merge/add | merge/m1 | merge/odd) echo "1 unmoved" ;;
    merge/delete | merge/deldir | merge/rename) echo "0 moved" ;;
  esac
}

thaw() {
  chmod -R u+w "$REPO"
}

build_repo() {
  local kind=$1
  mkdir -p "$REPO/d"
  printf 'f v1\n' >"$REPO/d/f"
  printf 'g v1\n' >"$REPO/d/g"
  printf 'other v1\n' >"$REPO/other.txt"
  if [ "$kind" = odd ]; then
    printf 'sp v1\n' >"$REPO/d/sp ace.txt"
    printf 'nl v1\n' >"$REPO/d/nl"$'\n'"file.txt"
  fi
  g init -q -b main
  g add -A
  g commit -q -m base
  case $kind in
    plain) return 0 ;;
    same) g branch feat; return 0 ;;
  esac
  g checkout -q -b feat
  case $kind in
    change) printf 'f v2\n' >"$REPO/d/f" ;;
    add) printf 'new\n' >"$REPO/d/new" ;;
    delete) g rm -q d/f ;;
    adddir) mkdir "$REPO/d/sub"; printf 'x\n' >"$REPO/d/sub/x" ;;
    m1)
      mkdir -p "$REPO/a/new"
      printf 'x\n' >"$REPO/a/new/x"
      printf 'y\n' >"$REPO/a/new/y"
      printf 'z\n' >"$REPO/d/z"
      ;;
    deldir) g rm -q -r d ;;
    rename) mkdir "$REPO/e"; g mv d/f e/f ;;
    odd)
      printf 'sp v2\n' >"$REPO/d/sp ace.txt"
      printf 'nl v2\n' >"$REPO/d/nl"$'\n'"file.txt"
      ;;
  esac
  g add -A
  g commit -q -m target
  g checkout -q main
}

# Two commits on main, a branch on the first, and no move recorded in the HEAD
# reflog beyond the commits themselves.
cannot_tell_repo() {
  build_repo plain
  printf 'second\n' >"$REPO/other.txt"
  g commit -q -a -m second
  g branch feat HEAD~1
}

g() {
  git -C "$REPO" "$@"
}

# ---- running and asserting -------------------------------------------------

# Run the script from inside the repository, or from an unrelated directory
# with -C when USE_C is set. rec <apply|dry> <checkout|merge> <ref>.
rec() {
  local apply=--apply
  [ "$1" = apply ] || apply=
  if [ -n "${USE_C-}" ]; then
    cd "$BATS_TEST_TMPDIR" && "$RECOVER" ${apply:+"$apply"} -C "$REPO" "$2" "$3"
  else
    cd "$REPO" && "$RECOVER" ${apply:+"$apply"} "$2" "$3"
  fi
}

# The script from inside the repository, arguments as given.
in_repo() {
  cd "$REPO" && "$RECOVER" "$@"
}

# --apply for the scenario's verb, exit 0 required. A STUBS dir goes first on
# PATH for the script only.
apply_ok() {
  PATH="${STUBS:+$STUBS:}$PATH" run rec apply "$VERB" feat
  [ "$status" -eq 0 ] || { printf '%s\n' "$output" >&2; return 1; }
}

# HEAD at the target; a checkout switched to the branch, a merge advanced the
# current branch, and neither moved a branch it should not have.
assert_reached() {
  [ "$(g rev-parse HEAD)" = "$TARGET" ]
  [ "$(g rev-parse feat)" = "$TARGET" ]
  if [ "$VERB" = checkout ]; then
    [ "$(g symbolic-ref -q HEAD)" = refs/heads/feat ]
    [ "$(g rev-parse "$BASEBR")" = "$PRE" ]
  else
    [ "$(g symbolic-ref -q HEAD)" = "refs/heads/$BASEBR" ]
  fi
}

# `git status --porcelain -uall` lists exactly the given entries (none: clean).
# NUL-delimited, so a newline in a path is told from a separator.
assert_status() {
  local got want e
  got=$(g status --porcelain -uall -z | tr '\0' '|')
  want=
  for e in "$@"; do want="$want$e|"; done
  [ "$got" = "$want" ] || { printf 'status: got [%s] want [%s]\n' "$got" "$want" >&2; return 1; }
}

assert_bytes() {
  printf '%s' "$2" >"$BATS_TEST_TMPDIR/want"
  cmp -s "$REPO/$1" "$BATS_TEST_TMPDIR/want"
}

# Everything a recovery could change: HEAD, refs, the index's content, and the
# working tree (names, modes, bytes, mtimes) outside .git.
snap() {
  g rev-parse HEAD
  g symbolic-ref -q HEAD || echo detached
  g for-each-ref
  g ls-files -s -z | cksum
  tar -C "$REPO" --exclude=.git -cf - . | cksum
}
