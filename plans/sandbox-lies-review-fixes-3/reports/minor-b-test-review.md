# Minor batch B, test review (findings 24, 25)

Edits only in `tests/probes-readonly-resolve.bats` (new cases). Suite after:
13 passed, 3 failed; the red set is unchanged (the cp-phrase case, the
newline-top case, the empty-cwd walk case), each on its path assertion.
`tests/docs.bats` 2 passed.

## Verdicts on the RED cases

- cp phrase-in-path (24): genuine assertion red; only the join base moves the
  path line and outcome. Defect fixed: it tried one phrase of three, so a gate
  anchored on a single git prefix could pass. It now loops over all three
  phrases (`phrase_path <n>`, built from fragments).
- git's own line still joins onto the top (24 neighbour): kept, green now.
  Genuine-message coverage for the other shapes: the mkdir form is the existing
  second case; the create-file form yields nopath (unquoted path) and cannot
  pin a path. A fix rejecting genuine git lines fails this case or the
  existing ones.
- newline-ending top (25): genuine red, no other cause; a fix keeping the
  newline passes, and ordinary newline-free tops stay pinned by the existing
  cases.
- empty cwd walk (25): genuine red. The outline (section B) states no rule for
  an empty cwd; its only fallback is "with no .git ancestor it joins onto cwd
  as today". The test rests on `_probe_readonly_resolve`'s documented "empty
  cwd means the probe's working directory" plus section B's walk; I added the
  outline citation to its comment. Judgement call for the caller: if the
  intended fix is to leave empty cwd unwalked (as at HEAD), drop this case.

## Added neighbours (both green now, must stay green)

- `an empty cwd leaves a cp refusal joined onto the probe's working directory`:
  stops a fix that walks for non-partial-checkout lines under an empty cwd
  (cp must join onto `$PWD`, not the top above it).
- `an empty cwd with no .git above the working directory joins onto it`: the
  outline's no-ancestor fallback holds for an empty cwd (a fix inventing a
  different rule, such as failing or using the walk's root, goes red).

Not done: no mutation proof run for the two added neighbours (they are
regression pins on unchanged behaviour; the existing no-ancestor and cp cases
use the same mechanism).
