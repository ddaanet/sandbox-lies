#!/usr/bin/env bash
# Loaded by tests/recover.bats: builds the scratch repos, runs the refused
# command and the script, and asserts the end state. REPO, VERB, KIND, PRE,
# TARGET, BASEBR and the optional UNRELATED, STUBS and USE_C are set by the
# suite's setup and @test bodies.

# shellcheck disable=SC2030,SC2031,SC2154 # state set in a @test body is read here

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
  # The working copy holds what git writes on checkout: CRLF, while the blobs
  # hold LF, so a byte comparison with a blob never matches.
  if [ "$kind" = crlf ]; then
    printf '* text eol=crlf\n' >"$REPO/.gitattributes"
    printf 'f v1\r\n' >"$REPO/d/f"
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
    crlf) printf 'f v2\r\n' >"$REPO/d/f" ;;
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
