#!/usr/bin/env bats
# Item 2.2: scripts/check-links.sh on whitespace and edge inputs. The external
# contract, scope and link parsing are in tests/check-links.bats.

load helpers/fixture-root
load helpers/bsd-stubs
load helpers/git-env

SCRIPT="$ROOT/scripts/check-links.sh"

# Item 2.2 slice 5: whitespace and edge inputs, from slices 1, 3 and 4's code
# reviews.

@test "linking file with whitespace" {
  local dir tab=$'\t'
  dir=$(make_fixture_root linking-space)
  mkdir -p "$dir/docs/s p"
  # Each file fails a different whitespace-unsafe script, which then skips
  # it: ` lead.md` (leading space) an `IFS=`-less read, which trims it;
  # `docs/a<TAB>b.md` a newline-delimited walk, since `git ls-files` without
  # `-z` C-quotes a tab; `docs/s p/a b.md` an unquoted handler argument,
  # which word-splits it, and an unquoted existence test on its directory.
  # Its first link resolves beside it, so a script taking its directory
  # unquoted (`$(dirname $file)`) reports that link broken.
  printf '[m](missing.md)\n' >"$dir/ lead.md"
  printf '[m](missing.md)\n' >"$dir/docs/a${tab}b.md"
  printf '%s\n' '[b](b.md)' '[m](missing.md)' >"$dir/docs/s p/a b.md"
  : >"$dir/docs/s p/b.md"
  git -C "$dir" add " lead.md" "docs/a${tab}b.md" "docs/s p/a b.md" \
    "docs/s p/b.md"

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  # `git ls-files` order: bytewise, so the leading space sorts first.
  [ "$output" = "broken-link:  lead.md -> missing.md
broken-link: docs/a${tab}b.md -> missing.md
broken-link: docs/s p/a b.md -> missing.md" ]
}

@test "deleted tracked file is skipped" {
  local dir
  dir=$(make_fixture_root deleted)
  mkdir -p "$dir/docs"
  printf '[m](missing.md)\n' >"$dir/docs/gone.md"
  # A present file after it in `git ls-files` order, holding the one broken
  # link to report: a walk that yields nothing, or a skip that ends the walk
  # (`break` for `continue`), drops its line.
  printf '[m](missing.md)\n' >"$dir/docs/sentinel.md"
  git -C "$dir" add docs/gone.md docs/sentinel.md
  # Removed from the work tree only, so it stays in the index: `git ls-files`
  # still lists it, and walk_tracked_files's `[ ! -f … ]` guard must skip it.
  rm "$dir/docs/gone.md"

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/sentinel.md -> missing.md" ]
  [ -z "$stderr" ]
}

@test "unreadable file exits 2" {
  if [ "$(id -u)" -eq 0 ]; then
    skip "running as root: chmod 000 does not block reads"
  fi
  local dir
  dir=$(make_fixture_root unreadable)
  mkdir -p "$dir/docs"
  printf '[m](missing.md)\n' >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md
  chmod 000 "$dir/docs/a.md"

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

@test "extra argument exits 2" {
  local dir
  dir=$(make_fixture_root extra-arg)
  mkdir -p "$dir/docs"
  # A broken link, so a script that ignored the extra argument, or checked
  # it only after the walk, would print a broken-link line: the empty
  # stdout below then pins the refusal to before the walk.
  printf '[m](missing.md)\n' >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  # The extra argument is itself a valid root, so no failure but the
  # argument check can exit 2 — a second, unrelated argument would also
  # exit 2 from a script that took the last argument as ROOT and failed
  # `git ls-files` on it. Joining the arguments into one ROOT ("$*") still
  # fails there, so stderr names the refusal.
  run --separate-stderr "$SCRIPT" "$dir" "$dir"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [ "$stderr" = "check-links: unexpected extra argument: $dir" ]
}

@test "any URI scheme is skipped" {
  local dir
  dir=$(make_fixture_root scheme-any)
  mkdir -p "$dir/docs"
  # ftp, and HTTP (schemes are case-insensitive), and a bare "name:value"
  # relative target (RFC 3986 4.2 reads it as a URI with scheme "x", not a
  # path) — ahead of the sentinel. A scheme check narrower than RFC 3986
  # (limited to http/https/mailto, or case-sensitive) would report one of
  # the first three as broken instead of skipping it.
  printf '%s\n' '[f](ftp://h/x)' '[u](HTTP://X)' '[x](x:y.md)' \
    '[z](sentinel-missing.md)' >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> sentinel-missing.md" ]
}

@test "CRLF fence closes" {
  local dir
  dir=$(make_fixture_root crlf-fence)
  mkdir -p "$dir/docs"
  # A CRLF file: the closing fence line ends "```\r". A closer that does
  # not treat \r as trailing whitespace never matches it, so the fence
  # stays open and swallows the sentinel after it.
  # shellcheck disable=SC2016 # literal backticks in fixture data, not command substitution
  printf '```\r\n[c](fence-missing.md)\r\n```\r\n[z](sentinel-missing.md)\r\n' \
    >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> sentinel-missing.md" ]
}

@test "code span at line start is not a fence" {
  local dir
  dir=$(make_fixture_root span-at-start)
  mkdir -p "$dir/docs"
  # A line opening with a code span, not a fence: CommonMark disallows a
  # backtick inside a fence's info string, so a line starting "```x``` " is
  # a paragraph. An opener that does not check the rest of the line for a
  # backtick treats it as a fence and swallows the sentinel after it.
  # shellcheck disable=SC2016 # literal backticks in fixture data, not command substitution
  printf '%s\n' '```x``` text' '[z](sentinel-missing.md)' >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> sentinel-missing.md" ]
}

@test "name=value ROOT is a path" {
  local dir
  dir=$(make_fixture_root "x=y")
  mkdir -p "$dir/docs"
  printf '[m](missing.md)\n' >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  # A relative ROOT named x=y: POSIX awk reads a "name=value"-shaped
  # operand as a variable assignment, not a file, when the file is passed
  # as an operand instead of by redirection. stdin from /dev/null keeps a
  # script that falls back to reading stdin from hanging instead of
  # passing silently.
  run --separate-stderr "$SCRIPT" "x=y" </dev/null
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> missing.md" ]
}

# Item 2.2 slice 6: the shared walk (scripts/lib/tracked.sh), bare-name
# invocation, a missing helper, and BSD tools — slices 6-7 merged, since
# neither adds behaviour of its own.

@test "tracked symlink is skipped" {
  local dir
  dir=$(make_fixture_root symlink-skip)
  mkdir -p "$dir/docs"
  # The target is untracked, so nothing but the symlink itself walks it. A
  # walk that does not skip a tracked symlink follows it and reports the
  # target's broken link under the symlink's own path.
  printf '[t](target-missing.md)\n' >"$dir/docs/untracked-target.md"
  ln -s untracked-target.md "$dir/docs/l.md"
  printf '[m](missing.md)\n' >"$dir/docs/sentinel.md"
  git -C "$dir" add docs/l.md docs/sentinel.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/sentinel.md -> missing.md" ]
}

@test "bare-name invocation" {
  local dir
  dir=$(make_fixture_root bare-name)
  mkdir -p "$dir/docs"
  printf '[m](missing.md)\n' >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  # `cd` into scripts/ so `${BASH_SOURCE[0]}` is the slash-less
  # "check-links.sh", the shape that once sourced "check-links.sh/lib/…".
  cd "$ROOT/scripts" || return
  run --separate-stderr bash check-links.sh "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> missing.md" ]
}

@test "missing helper exits 2" {
  local dir copy
  dir=$(make_fixture_root missing-helper)
  mkdir -p "$dir/docs"
  printf '[m](missing.md)\n' >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  # No lib/ at all beside the copy: the `source` fails. The awk guard after
  # it would exit 2 as well, so only stderr shows which of the two fired:
  # bash's own diagnostic alone, after its `<script>: line <n>: ` prefix.
  copy="$BATS_TEST_TMPDIR/copy-no-lib"
  mkdir -p "$copy"
  cp "$ROOT/scripts/check-links.sh" "$copy/check-links.sh"

  run --separate-stderr bash "$copy/check-links.sh" "$dir"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [ "${stderr#*: line *: }" = \
    "$copy/lib/tracked.sh: No such file or directory" ]

  # lib/ holds tracked.sh but not strip-code.awk: the `source` succeeds and
  # the readability guard must catch the awk lib on its own.
  copy="$BATS_TEST_TMPDIR/copy-no-awk"
  mkdir -p "$copy/lib"
  cp "$ROOT/scripts/check-links.sh" "$copy/check-links.sh"
  cp "$ROOT/scripts/lib/tracked.sh" "$copy/lib/tracked.sh"

  run --separate-stderr bash "$copy/check-links.sh" "$dir"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [ "$stderr" = "check-links: cannot read $copy/lib/strip-code.awk" ]

  # Paired: the same copy with its lib/ complete reports the broken link, so
  # the exits above come from the missing files and not from the copying.
  cp "$ROOT/scripts/lib/strip-code.awk" "$copy/lib/strip-code.awk"

  run --separate-stderr bash "$copy/check-links.sh" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> missing.md" ]
}

@test "unmerged path walked once" {
  local dir base_branch
  dir=$(make_fixture_root unmerged)
  mkdir -p "$dir/docs"
  # The link sits on a line neither branch's conflicting edit touches, so
  # it survives the merge unchanged and appears in the working tree exactly
  # once — the conflict itself is forced on the line above it.
  printf '%s\n' common '[m](missing.md)' >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md
  git -C "$dir" -c user.name=t -c user.email=t@example.com \
    commit -q -m base
  base_branch=$(git -C "$dir" symbolic-ref --short HEAD)

  git -C "$dir" checkout -q -b feature
  printf '%s\n' common-feature '[m](missing.md)' >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md
  git -C "$dir" -c user.name=t -c user.email=t@example.com \
    commit -q -m feature

  git -C "$dir" checkout -q "$base_branch"
  printf '%s\n' common-main '[m](missing.md)' >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md
  git -C "$dir" -c user.name=t -c user.email=t@example.com \
    commit -q -m main

  # The merge is expected to fail on the real conflict; guard its non-zero
  # status so the fixture setup does not abort, then prove the conflict:
  # a merge that went through cleanly leaves one stage, nothing to walk
  # twice, and the test green with the deduplication deleted.
  git -C "$dir" -c user.name=t -c user.email=t@example.com \
    merge --no-edit feature || true
  run git -C "$dir" ls-files -u -- docs/a.md
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> missing.md" ]
}

@test "broken link survives BSD grep and mktemp" {
  local dir bsd
  dir=$(make_fixture_root bsd-tools)
  mkdir -p "$dir/docs"
  printf '[m](missing.md)\n' >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  # The grep half is proven by mutation: `-aoE` -> `-aoP` on the extraction
  # grep, or a `\b` in its pattern, is silent under GNU grep (the rest of the
  # suite stays green) but the BSD stub refuses it, so the capture fails and
  # the script exits 2 instead of 1. The mktemp half is a smoke run: the
  # stub refuses a template without trailing Xs only when its literal path
  # already exists, and one run's EXIT trap removes the path it created.
  bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep mktemp

  PATH="$bsd:$PATH" run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> missing.md" ]
}

@test "git ls-files failure exits 2" {
  local dir stub
  dir=$(make_fixture_root ls-files-fails)
  mkdir -p "$dir/docs"
  # A broken link, so a walk that swallowed the failure and read an empty
  # list would exit 0; a stub on PATH rather than a non-repository root,
  # which a repository above $BATS_TEST_TMPDIR would answer.
  printf '[m](missing.md)\n' >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  stub="$BATS_TEST_TMPDIR/gitfail"
  mkdir -p "$stub"
  printf '#!/bin/sh\nexit 128\n' >"$stub/git"
  chmod 755 "$stub/git"

  PATH="$stub:$PATH" run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [ "$stderr" = "check-links: git ls-files failed under $dir" ]
}
