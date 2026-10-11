# Minor batch B, code review (findings 24, 25)

Reviewed `git show 5de4695`. No defect found in the change; no edit to
`lib/` or `tests/`. One residual left open (below).

## Correctness

- `_probe_partial_checkout_line` anchors on `error: unable to unlink old`,
  `error: unable to create file` and `fatal: cannot create directory at`.
  `probe_readonly_path` only tests `$line`, which `_readonly_path_line`
  returns, and that matcher requires the line to open with one prefix run free
  of blanks, backticks, pipes and colons, then `: `. Git's genuine lines
  (`error:` for the unlink and create-file forms, `fatal:` for the directory
  form, as `tests/helpers/probes.bash` builds them) therefore reach the gate
  with `error:` or `fatal:` at column 0, which is what the anchor reads. No
  path prefix can sit before `error:` on a line the matcher accepts, so
  anchoring loses no genuine message. Wrapper lines such as `remote: error:
  ...` never carried git's checkout error and were never intended.
  Non-English git messages missed the old substring gate too.
- The `x` sentinel: the walk prints `dir\n`, the substitution appends `x`, and
  `${top%?x}` removes the shortest suffix of two characters ending in `x`,
  that is the walk's newline and the `x`. A top name ending in a newline keeps
  it. A failing walk makes the substitution non-zero, so `&&` skips the
  assignment and `base` stays `$cwd` (set -e safe: it is an and-list).
- Empty cwd: `start` falls back to `$PWD`; on a failed walk `base` stays empty
  and `_probe_readonly_resolve` joins onto `$PWD`, as before.
- bash 3.2: `local` with extra names, `case` with quoted needle, `%?x`, and
  `&&` after a command substitution assignment are all 3.2 constructs; the
  green report's hand-run under `/tmp/claude/bash32/bash` (both locales)
  matches. Nothing new to run.

## The residual: `_readonly_partial_checkout_text` in `lib/probes-readonly-facts.sh`

Not the same defect as finding 24, and it cannot reach a wrong `readonly`
outcome. Finding 24 is the join base for the path, which sets the outcome
(`writable` or `readonly`). The facts tail is printed only under `writable`
and `nopath` (`probe_readonly_path` skips `_readonly_print_facts` when the
outcome is `readonly`), and no fact feeds back into the outcome.

It does leave a wrong fact reachable: a cp refusal whose quoted path holds a
phrase, under a writable parent, prints `merge=1` and `partial=1`, so the
verdict can carry the "restore the files from HEAD" clause for a cp. Hand
run (cwd `repo/sub`, a directory named for the phrase under it, command
`cp x y`):

```
writable
path=<tmp>/repo/sub/<phrase directory>/x
merge=1
partial=1
```

Left open, deliberately. The fact gate reads the whole text by documented
contract (`docs/references/readonly-path.md`, `partial=1`: "the text holds
git's partial-checkout error ... under any command"; the changelog entry of
5de4695 records the same). Anchoring it per line changes that contract and
its tests (`tests/probes-readonly-facts.bats`, the three-errors case, and the
verdict tests), which is a design decision beyond finding 24's join scope. The
reachable input is a contrived path name, as finding 24 itself says.

## Test evidence

Suite before and after: `tests/probes-readonly-resolve.bats` 16 passed, 0
failed.

State of the world that fails each new case, and what else could produce it:

1. cp refusal with phrase-in-path (three phrases looped): a gate that matches
   the phrase anywhere on the line. Only the join base moves the path line.
2. git's own line joins onto the top: a gate rejecting genuine git lines.
3. top name ending in a newline: a substitution that strips it. The real top
   holds `d/f`, so only the lost newline moves the path.
4. empty cwd walks from `$PWD`: an unwalked empty cwd. `sub/d/f` exists too,
   so the path line tells the joins apart.
5. empty cwd cp refusal joins onto `$PWD`: a walk applied to every producer.
6. empty cwd, no `.git` above: a fallback other than the working directory.

## Mutation proof

Each mutation was an exact replacement of a string occurring once in
`lib/probes-readonly.sh`, shown landed by `command grep`, run with
`bats -f`, and restored by the swapped replacement. Final check: `command grep`
finds none of the mutation texts, `git diff --stat -- lib` is empty, and the
file's suite is 16 passed, 0 failed.

| Case | Mutation (line 61 or 64) | Red on |
|---|---|---|
| 1 cp phrase | `if _probe_partial_checkout_line "$line"; then` to `if _readonly_partial_checkout_text "$line"; then` | `[ "$(path_line)" = "$expected" ]` (test line 234) |
| 5 empty cwd cp | same line to `if true; then` | `[ "$(path_line)" = "path=$repo/sub/d/f" ]` (line 308) |
| 2 git's own line | same line to `if false; then` | `[ "$(path_line)" = "path=$repo/d/f" ]` (line 249) |
| 3 newline top | `top=$(_readonly_git_dir "$start" && printf x) && base="${top%?x}"` to `top=$(_readonly_git_dir "$start") && base="$top"` | `[ "$(path_line)" = "$expected" ]` (line 268) |
| 4 empty cwd walk | `[ -n "$start" ] \|\| start="$PWD"` to `... start=""` | `[ "$(path_line)" = "path=$repo/d/f" ]` (line 289) |
| 6 no `.git` above | `&& base="${top%?x}"` to `&& base="${top%?x}" \|\| base=/` | `[ "$(path_line)" = "path=$plain/sub/d/f" ]` (line 326) |

Each restore was followed by a landed-text check; the last run is green.

## Left open

- `partial=1` and `merge=1` facts for a non-git refusal whose path holds a
  phrase (above). Needs a decision on anchoring the fact gate per line.
