# Item 2.2 slice 4: test review

Scope: `link inside a code span or fence ignored` in `tests/check-links.bats`
and `plans/sandbox-lies/reports/item-2-2-s4-red.md`. `scripts/` was mutated
in place to probe and then restored; it is byte-identical to HEAD. Nothing
was committed.

## Mechanical check

The RED as delivered failed on its `$output` assertion (line 255), not on an
execution error: 8 passed, 1 failed. The RED report's account is accurate:
HEAD has no code awareness, so it reports all six missing targets.

## Findings

The RED fixture caught 7 of the 11 wrong implementations I probed (table
below). Four passed it, all plausible and all within "a broken target inside
backticks or a fenced block":

1. **Major: info-string opener not recognised (W2).** Every fence in the
   fixture was a bare ```` ``` ````. In the repo's tracked markdown, 21 of the
   104 fence lines carry an info string (```` ```js ````, ```` ```sh ````,
   …). Closers are always bare, so that is roughly 40% of openers, and
   a checker matching only a bare marker line would flood the gate with
   false broken-link reports on real docs.
2. **Major: fence indented under a list item (W3).** An implementation that
   matches markers only at column 0 passed. The repo already has indented
   fences in list items (for example in
   `plans/sandbox-lies/reports/item-2-2-s2-green.md`), and CommonMark allows
   0–3 spaces at top level too.
3. **Major: mismatched close marker (W1).** Toggling fence mode on any
   ```` ``` ```` or `~~~` line passed. The ```` ``` ```` and `~~~` fences
   were separate and each closed with its own marker, so nothing
   distinguished "close on the same character" from "close on any marker".
4. **Minor: span check keyed on backticks wrapping the link exactly (W6).**
   The only code span was `` `[a](span-missing.md)` ``, with the link filling
   the whole span. An implementation that only skips a link with a backtick
   immediately before `[` and after `)` passed.

The lead asked about two other wrong implementations. The fixture already
caught both:

- **~~~ fences ignored entirely (W4):** caught by `tilde-missing`. The
  `~~~` block does discriminate from the ```` ``` ```` block.
- **Span stripped from the first backtick to end of line (W5):** caught by
  `after-span-missing`.
- **A span holding `]` or `(`:** a span that contains a link holds both. No
  plausible stripper breaks on those characters specifically, apart from the
  exact-wrap one in finding 4.

## Fixes

I rebuilt the fixture in place under the same test name:

```text
`see [a](span-missing.md) here`      span: text around the link (W6)
`code` [b](after-span-missing.md)    decoy, reported (W5, W9)
```bash                              info-string opener (W2)
[c](fence-missing.md)
~~~                                  wrong-marker line is content (W1)
[d](fence-tilde-missing.md)
```
[e](after-fence-missing.md)          decoy, reported (W7)
~~~                                  tilde fence (W4)
[f](tilde-missing.md)
~~~
- item
  ```                                fence indented in a list item (W3)
  [g](indented-missing.md)
  ```
[z](sentinel-missing.md)             sentinel, reported (W8)
```

The expected output is unchanged: `after-span`, `after-fence`, `sentinel` in
file order. I added `[ -z "$stderr" ]` after the output assertion, matching
`urls and anchors ignored`. The comment now names the narrower reading of
"code" that each ignored line rules out, instead of describing only the
decoys.

## Split considered, not applied

The test now covers six rules (span, info string, same-character close,
tilde, indentation, leaving the fence), and a failure prints only the
equality line. Splitting it into span and fence tests would only say which
half failed; the specific rule is still visible only in `$output`. The
target names label the rules (`fence-tilde-missing`, `indented-missing`, …),
so one run of the script over the fixture identifies it. The runbook names a
single test, and the suite's other multi-case tests (`broken links in scope
are reported`) use the same exact-block form. I kept it as one test.

## Left out (residuals, not in the fixture)

These are CommonMark rules outside the slice's plausible-and-present bar.
None of these forms appear in the tracked markdown today:

- A fence closed by a shorter marker of the same character: a
  ```` ```` ```` fence closed by ```` ``` ````. No four-backtick fences are
  tracked yet.
- Double-backtick spans (the naive `` `[^`]*` `` stripper fails them).
- Code spans that cross a line break.
- Unclosed fences.
- Indented (4-space) code blocks. These are not fenced blocks, and the RED
  report had already left them out.

If any of these forms appear in scope, a line-based implementation reports
the link inside, loudly rather than silently.

## Probe table

The mutation was one exact replacement in `check_links_in`. I replaced

    -- "$ROOT/$file") || status=$?

with

    -- <(awk -f "$PROBE_AWK" "$ROOT/$file")) || status=$?

Each `W*.awk` was a throwaway filter that blanks what it treats as code.
Restore was the inverse replacement: `PROBE_AWK` count 0, then
`git diff --quiet scripts/` printed "byte-identical".

"RED fixture" is the test as delivered and "Rebuilt" is after the fixes.
Every failure in the rebuilt column is on the `$output` assertion (line
270), never on status or stderr.

| Probe | Wrong implementation | RED fixture | Rebuilt | Reported by the rebuilt fixture |
|---|---|---|---|---|
| W0 | reference: CommonMark-ish fences + single-backtick spans | ok | ok | after-span, after-fence, sentinel |
| W1 | toggle on any ```` ``` ```` / `~~~` line | **ok** | not ok | after-span, fence-tilde, tilde, indented |
| W2 | bare marker line only, no info string | **ok** | not ok | after-span, fence, tilde |
| W3 | markers at column 0 only | **ok** | not ok | after-span, after-fence, indented, sentinel |
| W4 | ```` ``` ```` fences only, `~~~` ignored | not ok | not ok | after-span, after-fence, tilde, sentinel |
| W5 | span stripped from first backtick to EOL | not ok | not ok | after-fence, sentinel |
| W6 | span skipped only when it wraps the link exactly | **ok** | not ok | span, after-span, after-fence, sentinel |
| W7 | never leaves fence mode | not ok | not ok | after-span |
| W8 | stops reading at the first fence | not ok | not ok | after-span |
| W9 | drops every line holding a backtick | not ok | not ok | after-fence, sentinel |
| W10 | fences right, no span awareness | not ok | not ok | span, after-span, after-fence, sentinel |
| W11 | spans right, no fence awareness | not ok | not ok | after-span, fence, fence-tilde, after-fence, tilde, indented, sentinel |

W0 passing the rebuilt test shows it can be satisfied. Every wrong
implementation fails it on the output assertion.

## Final red run (unmodified SUT)

```text
$ scripts/run-bats.sh tests/check-links.bats
not ok 9 link inside a code span or fence ignored
# (in test file tests/check-links.bats, line 270)
#   `[ "$output" = "broken-link: docs/a.md -> after-span-missing.md' failed

bats: 8 passed, 1 failed
rc=1
```

- `shellcheck tests/check-links.bats`: clean.
- `git status --porcelain --untracked-files=no`: ` M tests/check-links.bats`
  only.
- `git diff --quiet scripts/`: byte-identical to HEAD.
