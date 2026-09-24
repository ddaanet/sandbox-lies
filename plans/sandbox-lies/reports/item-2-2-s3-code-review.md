# Item 2.2 slice 3: code review

Scope: `git show HEAD -- scripts/check-links.sh` (the slice 3 GREEN), read
as part of the whole `check_links_in`. The fix is in `scripts/check-links.sh`
and is not committed.

## Findings

1. **Major (fixed): the scheme allowlist rested on a false premise and was
   too narrow for a hard gate.** The GREEN comment said a `case` glob cannot
   express an RFC 3986 scheme without `[[ =~ ]]`. It can. A `[A-Za-z]*:*`
   arm, then the text before the first `:` (`${target%%:*}`) is tested
   against `*[!A-Za-z0-9+.-]*`. A `/` before the colon fails that character
   test, so it also covers the "no slash before the first colon" rule. The
   cited source was also wrong. `shell-gotchas` and its references have no
   `=~` entry. The allowlist's cost was more than a loud residual. This is
   a precommit gate with no exception mechanism, so a doc linking `ftp://`,
   `tel:`, `data:`, `file:`, `svn+ssh://` or even `HTTP://` (schemes are
   case-insensitive) blocked every commit. It also had a false negative:
   `[x](a:b.md)` beside an existing `a:b.md` passed, but RFC 3986 §4.2 makes
   it a URI with scheme `a`, which a renderer does not resolve to the file.
   The RFC form costs six lines and removes both errors. **Fix:** the RFC
   3986 match replaces the list, `scheme` is added to the `local` line, and
   the comment now states the rule, cites §4.2 on `./a:b.md`, and names the
   residual that remains (next point).

2. **Minor (fixed, documented): bash 3.2 glob ranges follow the locale.**
   Without `globasciiranges`, which is on by default only from bash 5.0,
   `[A-Za-z]` in a UTF-8 locale can match accented letters. As a result a
   target such as `é:x` may be skipped as a scheme. That target is not a
   valid relative reference without `./` anyway. Stated as a residual in
   the comment rather than fixed with a locale change.

3. **Minor (fixed): comment wording.** "A pure `#section` target is its own
   arm, distinct from `dir/target` decisions below" did not say what it
   meant. "Matching the existing lines' use of the target as written" did
   not say why the target should be printed as written. Both are rewritten.
   The first comment now opens by naming the two non-file classes (an
   anchor into this file, or a URI with a scheme). The anchor-strip comment
   now reads: only the part before `#` must exist, and the report prints the
   target as written, the string a reader finds in the linking file.

4. **No change: empty targets.** `[x]()` gives the target `""`. It is not
   an anchor or a scheme, so the script tests `-e "$ROOT/$dir/"`, the
   linking file's own directory, and passes. CommonMark reads an empty
   destination as a link to the current document, so passing is the right
   result. It gets there by way of the directory test rather than an
   explicit arm. `[x](#)` hits the `'#'*` arm and is skipped (top of page),
   which is also correct.

5. **Note, out of scope: other loud false positives.** These were probed
   against the fixed script and each is reported broken although it
   resolves when rendered: `b.md?x` and `?q` (the query is not stripped),
   `b.md "t"` (a link title), `<b.md>` (an angle-bracket destination) and
   `/docs/b.md` (root-relative, which GitHub resolves from the repository
   root). All fail loud, so none is silent. Link titles are the most likely
   to show up in real docs. No slice in the runbook covers them, so they are
   worth adding to slice 5's edge inputs or to a residual list.
   `${target%%#*}` on `?query` is not wrong: it leaves the target unchanged,
   and it is the missing query strip that makes these fail.

6. **No issue: portability and whitespace.** Nested `case` with a `[!…]`
   bracket, `${var%%:*}` and `continue` inside a `case` inside `while` are
   all POSIX and valid in bash 3.2. Every expansion is quoted. Targets and
   file names containing spaces were probed (`[sp](a b.md)` beside `a b.md`)
   and resolve correctly.

## Probe (fixed script, scratch repo)

Silent (skipped or resolving): `ftp://h/x`, `tel:+123`, `HTTP://X`,
`svn+ssh://h`, `a1+.-:x`, `x:y.md` (a scheme per RFC), `./x:y.md`
(exists), `a b.md` (exists), `b.md#p`, empty `()`, `(#)`.

Reported: `sub/a:b.md`, `1a:b` (a scheme must start with a letter),
`b.md?x`, `?q`, `b.md "t"`, `/docs/b.md`, `<b.md>`.

## Mutation run (one, in place)

`*[!A-Za-z0-9+.-]*) ;;` was changed to `*[!A-Za-z0-9+./-]*) ;;`, which lets
a `/` into the scheme and so skips `sub/a:missing.md`:

```text
not ok 6 colon or double slash in a relative target is not mistaken for a URL
#   `[ "$output" = "broken-link: docs/a.md -> sub/a:missing.md' failed
bats: 7 passed, 1 failed
```

It was restored by the inverse replacement. `git diff --quiet scripts/`
cannot prove the restore, because the review fix is itself a diff under
`scripts/`. Instead, `cmp` against a copy of the fixed script taken before
mutating showed the files identical.

## Gates (foreground)

- `scripts/run-bats.sh tests/`: 51 passed, 0 failed.
- `just precommit`: passed (plugin.json, shellcheck, bash -n, rumdl, line
  limits, tests).
- `scripts/check-links.sh`: exit 0.

## Test gaps

- **Nothing pins the scheme rule beyond http, https and mailto.** The
  allowlist the GREEN shipped and the RFC match both pass the whole suite,
  as the test review's S1 and S2 showed. Reverting this fix would go
  unnoticed. Proposed: add `[f](ftp://h/x)` and `[H](HTTP://X)` to the
  `urls and anchors ignored` fixture ahead of the sentinel. Optionally add
  `[b](x:y.md)` beside no such file, which the RFC match skips, to pin the
  §4.2 reading.
- The empty-target behaviour (finding 4) is unpinned. It is low value,
  because a regression would fail loud.

## Refactor flag

None needed.

## Files changed

- `scripts/check-links.sh`: the RFC 3986 scheme match replaces the
  allowlist, `scheme` is added to the locals, and the two comments are
  rewritten.
