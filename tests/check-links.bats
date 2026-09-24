#!/usr/bin/env bats
# Item 2.2 slice 1: scripts/check-links.sh's external contract. Whitespace
# and edge inputs are in tests/check-links-edges.bats.

load helpers/fixture-root
load helpers/bsd-stubs

SCRIPT="$ROOT/scripts/check-links.sh"

@test "resolving link passes" {
  local dir
  dir=$(make_fixture_root resolving)
  mkdir -p "$dir/docs"
  printf '[b](b.md)\n' >"$dir/docs/a.md"
  # Only docs/b.md exists — no root-level b.md. A script resolving the link
  # against ROOT or CWD instead of the linking file's own directory (docs/)
  # would look for a b.md that is not there and report it broken.
  : >"$dir/docs/b.md"
  git -C "$dir" add docs/a.md docs/b.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

@test "broken link is reported" {
  local dir
  dir=$(make_fixture_root broken)
  mkdir -p "$dir/docs"
  # The one link in the fixture, and the only broken one — nothing else in
  # the tree to source a second report line from.
  printf '[m](missing.md)\n' >"$dir/docs/a.md"
  # Decoys: a missing.md that exists, but at ROOT and in the CWD (see setup)
  # rather than beside the linking file. A script resolving against either,
  # falling back to either, or accepting a file of that name anywhere in the
  # tree finds one of these and reports nothing.
  : >"$dir/missing.md"
  : >"$BATS_TEST_TMPDIR/missing.md"
  git -C "$dir" add docs/a.md missing.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> missing.md" ]
}

# Item 2.2 slice 2: the tracked markdown scope, added from Item 2.1's
# reviews — the scope is where its gaps were.

@test "broken links in scope are reported" {
  local dir
  dir=$(make_fixture_root scope-in)
  mkdir -p "$dir/docs/plans" "$dir/skills/x/references" \
    "$dir/skills/plugin-dev"
  # One broken link each, one per scope arm: root, docs/, skills/ itself,
  # and skills/ at a deeper nesting.
  printf '[m](missing.md)\n' >"$dir/README.md"
  printf '[m](missing.md)\n' >"$dir/docs/a.md"
  printf '[m](missing.md)\n' >"$dir/skills/x/SKILL.md"
  printf '[m](missing.md)\n' >"$dir/skills/x/references/n.md"
  # Directly under skills/, in no skill directory: rules out a skills arm
  # narrowed to `skills/*/…` that the two files above both satisfy.
  printf '[m](missing.md)\n' >"$dir/skills/top.md"
  # A plans/ and a plugin-dev/ below an in-scope directory: only the
  # root-level ones are excluded, so an unanchored `*plans/*` or
  # `*plugin-dev/*` exclusion drops one of these. docs/plans/a.md also
  # rules out a docs arm stopping at docs/'s own files.
  printf '[m](missing.md)\n' >"$dir/docs/plans/a.md"
  printf '[m](missing.md)\n' >"$dir/skills/plugin-dev/SKILL.md"
  git -C "$dir" add README.md docs/a.md skills/x/SKILL.md \
    skills/x/references/n.md skills/top.md docs/plans/a.md \
    skills/plugin-dev/SKILL.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  # `git ls-files` order: bytewise, so README.md sorts first ('R' < 'd'),
  # skills/x/SKILL.md before skills/x/references/n.md ('S' < 'r').
  [ "$output" = "broken-link: README.md -> missing.md
broken-link: docs/a.md -> missing.md
broken-link: docs/plans/a.md -> missing.md
broken-link: skills/plugin-dev/SKILL.md -> missing.md
broken-link: skills/top.md -> missing.md
broken-link: skills/x/SKILL.md -> missing.md
broken-link: skills/x/references/n.md -> missing.md" ]
}

@test "markdown out of scope is ignored" {
  local dir
  dir=$(make_fixture_root scope-out)
  mkdir -p "$dir/plans" "$dir/plugin-dev" "$dir/lib/skills/y" \
    "$dir/.claude/skills/y" "$dir/docs"
  printf '[m](missing.md)\n' >"$dir/plans/x.md"
  printf '[m](missing.md)\n' >"$dir/plugin-dev/x.md"
  printf '[m](missing.md)\n' >"$dir/lib/x.md"
  # skills/ nested under a dot-directory, not at the root: out of scope the
  # same way `markdown elsewhere is out of scope` pins it for Item 2.1.
  printf '[m](missing.md)\n' >"$dir/.claude/skills/y/SKILL.md"
  # The same, under a plain directory: pins the skills arm's root anchor on
  # its own. The dot-directory file alone lets an unanchored `*skills/*`
  # arm pass behind a dot-directory skip.
  printf '[m](missing.md)\n' >"$dir/lib/skills/y/SKILL.md"
  # Not markdown, in an in-scope directory: the scope is markdown files, not
  # every file under docs/ or skills/.
  printf '[m](missing.md)\n' >"$dir/docs/x.txt"
  git -C "$dir" add plans/x.md plugin-dev/x.md lib/x.md \
    .claude/skills/y/SKILL.md lib/skills/y/SKILL.md docs/x.txt
  # Untracked, in an otherwise in-scope directory: proves the walk itself
  # excludes it, not just the scope check.
  printf '[m](missing.md)\n' >"$dir/docs/u.md"

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -z "$stderr" ]
}

# Item 2.2 slice 3: non-file targets, and slice 1's code-review fix pinned by
# mutation.

@test "urls and anchors ignored" {
  local dir
  dir=$(make_fixture_root urls)
  mkdir -p "$dir/docs"
  # None of these targets resolve as a path relative to docs/ — an http(s),
  # mailto or anchor target that is still checked as a literal path would
  # report every one of these as broken. The broken link last is the
  # sentinel: a skip that abandons the rest of the file (`return` or `break`
  # in place of `continue`) would drop its line along with the skipped ones.
  printf '%s\n' '[h](http://example.org/x)' '[s](https://example.com/x)' \
    '[m](mailto:person@example.com)' '[a](#section)' '[x](missing.md)' \
    >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> missing.md" ]
  [ -z "$stderr" ]
}

@test "colon or double slash in a relative target is not mistaken for a URL" {
  local dir
  dir=$(make_fixture_root colon-decoy)
  mkdir -p "$dir/docs"
  # Neither target has a URL scheme: a scheme is a leading "name:" before
  # any "/" (RFC 3986 4.2), and here the colon follows one; the double slash
  # has no scheme before it. A scheme test
  # broader than that (bare "contains a colon", a letter-led `[a-z]*:*`
  # glob, "contains //") would wrongly skip these and miss that both are
  # broken. A colon in the first segment ("note:x.md") is deliberately not
  # used: per RFC 3986 it is a URI with scheme "note", so skipping it is as
  # defensible as checking it, and the test must not pick between the two.
  printf '%s\n' '[n](sub/a:missing.md)' '[d](sub//missing.md)' \
    >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> sub/a:missing.md
broken-link: docs/a.md -> sub//missing.md" ]
}

@test "link with an anchor checks only the file part" {
  local dir
  dir=$(make_fixture_root anchor-part)
  mkdir -p "$dir/docs"
  # b.md exists, so a script checking the whole "b.md#part" string literally
  # would find no such path and wrongly report it. c.md is missing, so a
  # script that drops every link holding a "#" would wrongly stay silent.
  printf '%s\n' '[b](b.md#part)' '[c](c.md#part)' >"$dir/docs/a.md"
  : >"$dir/docs/b.md"
  git -C "$dir" add docs/a.md docs/b.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  # The report shows the target as written, "#part" included, matching the
  # existing broken-link lines' use of the target as written in the link.
  [ "$output" = "broken-link: docs/a.md -> c.md#part" ]
}

@test "link text does not cut the target" {
  local dir
  dir=$(make_fixture_root text-shape)
  mkdir -p "$dir/docs"
  # Parenthesised link text must not cut the target at the text's own "(",
  # and bracketed link text must not hide the link behind an unmatched "]".
  # x.md exists, so the first line's target resolves; missing.md does not,
  # so the second line's is the only line in the report.
  printf '%s\n' '[a (b)](x.md)' '[a [b] c](missing.md)' >"$dir/docs/a.md"
  : >"$dir/docs/x.md"
  git -C "$dir" add docs/a.md docs/x.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> missing.md" ]
}

# Item 2.2 slice 4: code spans and fenced blocks are not links.

@test "link inside a code span or fence ignored" {
  local dir
  dir=$(make_fixture_root code-fence)
  mkdir -p "$dir/docs"
  # Broken targets inside an inline code span and inside fenced blocks must
  # not be checked — they are code, not markdown links. Each ignored line
  # rules out a narrower reading of "code":
  # - span: text around the link inside the backticks, so skipping only a
  #   link the backticks wrap exactly still reports it;
  # - fence: opened with an info string, as most of this repo's fences
  #   are, so recognising only a bare ``` opener reports it;
  # - fence-tilde: a ~~~ line inside a ``` fence is content, not a close
  #   (CommonMark closes on the opener's own character), so toggling on
  #   any fence marker reports it;
  # - tilde: a ~~~ fence, so recognising ``` alone reports it;
  # - indented: a fence indented under a list item, as this repo's are, so
  #   matching markers only at column 0 reports it.
  # Decoys pin the edges: after-span sits on the SAME line as a span but
  # outside its backticks, so dropping every line holding a backtick, or
  # everything from the first backtick on, drops it too; after-fence is the
  # first line past a closing ```, so never leaving "fence mode" skips it.
  # The sentinel is last: an early return/break in place of continue would
  # drop it along with the fenced lines before it.
  # shellcheck disable=SC2016 # literal backticks in fixture data, not command substitution
  printf '%s\n' \
    '`see [a](span-missing.md) here`' \
    '`code` [b](after-span-missing.md)' \
    '```bash' \
    '[c](fence-missing.md)' \
    '~~~' \
    '[d](fence-tilde-missing.md)' \
    '```' \
    '[e](after-fence-missing.md)' \
    '~~~' \
    '[f](tilde-missing.md)' \
    '~~~' \
    '- item' \
    '  ```' \
    '  [g](indented-missing.md)' \
    '  ```' \
    '[z](sentinel-missing.md)' \
    >"$dir/docs/a.md"
  git -C "$dir" add docs/a.md

  run --separate-stderr "$SCRIPT" "$dir"
  [ "$status" -eq 1 ]
  [ "$output" = "broken-link: docs/a.md -> after-span-missing.md
broken-link: docs/a.md -> after-fence-missing.md
broken-link: docs/a.md -> sentinel-missing.md" ]
  [ -z "$stderr" ]
}
