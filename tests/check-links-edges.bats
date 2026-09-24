#!/usr/bin/env bats
# Item 2.2: scripts/check-links.sh on whitespace and edge inputs. The external
# contract, scope and link parsing are in tests/check-links.bats.

load helpers/fixture-root
load helpers/bsd-stubs

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
