# Minor batch B, RED (findings 24, 25)

Source untouched; nothing committed. Four cases appended to
`tests/probes-readonly-resolve.bats` (199 -> 280 lines; no existing case edited).
Both findings still hold at HEAD (confirmed by hand run: cp phrase path printed
`readonly` + `<repo>/unable to create file/x`; newline top lost its newline;
empty cwd joined onto `$PWD` unwalked).

Run: `scripts/run-bats.sh tests/probes-readonly-resolve.bats` -> 11 passed,
3 failed. `tests/docs.bats` -> 2 passed (phrase built from fragments).

## Cases

Finding 24 (git's prefixes: `error: unable to unlink old`, `error: unable to
create file`, `fatal: cannot create directory at`; the gate is
`_readonly_partial_checkout_text` in lib/probes-readonly-facts.sh, a `*phrase*`
glob on the line):

1. `a cp refusal whose path holds a partial-checkout phrase still joins onto the
   cwd` — RED, fails on `[ "$(path_line)" = "$expected" ]` (got
   `<repo>/unable\ to\ create\ file/x`, outcome readonly; wanted
   `<repo>/sub/...`). Failing world: cp refusal naming a relative quoted path
   containing the phrase, cwd `repo/sub` holding it, top lacking it. Else
   could produce the result: nothing other than the join base; the cp line is
   the cut fixture with only the path replaced, and the sub path exists so
   writable is expected.
2. `git's own partial-checkout line still joins onto the top beside a
   phrase-in-path cp case` — neighbour pin, GREEN now and must stay so (unlink
   line, cwd `repo/sub`, expected `repo/d/f`). Not a mutation-proof case: it is
   the pre-existing behaviour, equal in content to the first case in the file;
   if the fix anchors too tightly (e.g. wrong prefix) this goes red. The
   create-file form yields nopath (unquoted path) so it cannot pin a path; the
   mkdir form is pinned by the existing second case.

Finding 25:

3. `a worktree top whose name ends in a newline keeps it in the joined path` —
   RED on path assertion (got `.../top/d/f` without the newline). Failing
   world: top directory named `top\n` with `.git`, cwd inside. Else could
   produce it: none; the real top holds d/f, and `top` without newline does
   not exist.
4. `an empty cwd walks from the probe's working directory to the worktree top`
   — RED on `path=$repo/d/f` (got `$repo/sub/d/f`). Failing world: PWD =
   `repo/sub`, empty cwd, `sub/d/f` and `d/f` both exist so only the base
   differs.

## Judgement call for the caller

"Fallback" for an empty cwd: the only documented rule is
`_probe_readonly_resolve`'s ("the probe's own working directory when cwd is
missing or empty"). I read that as: empty cwd means `$PWD`, and the partial
checkout then walks from it like any cwd (the review's "is not walked ... while
a relative one is"). If instead the intended rule is "empty cwd joins onto
`$PWD` unwalked" (current behaviour), case 4 is wrong and should be dropped;
outline section B and readonly-path.md say nothing about an empty cwd.

No bsd-stub re-run added: the file already holds one (`partial-checkout path
resolves through BSD grep and sed`), and the new cases exercise the same
code path.
