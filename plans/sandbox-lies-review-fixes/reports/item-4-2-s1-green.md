# Item 4.2 slice 1 - GREEN

## Change

`lib/probes-readonly-facts.sh`: the merge pass emits
`match=${repo}/${files[$i]}`; the `_readonly_repo_facts` header comment says
names are absolute so the verdict's clause reads from any cwd.

## Order

1. "match= names are absolute from a subdirectory cwd" (members.bats): green
   with the one-line SUT change.
2. "hook restore clause names the match by absolute path" (hook-writes.bats):
   green with the same change.
3. Migration, then the four affected files re-run: no `not ok`.

## Migrated assertions (to `"match=$repo/<name>"`, negatives included)

- probes-readonly-facts.bats: a, b, e f, c (neg), d (neg); the path's-repo,
  nopath and BSD-stub cases (a; a, e f).
- probes-readonly-pins.bats: a, d (neg), f1000, z, z.
- probes-readonly-members.bats: switch case a (title reworded to "... and an
  absolute match="), BSD-tools case a.
- Left: verdicts-readonly.bats, hook-candidates.bats. Grep of `tests/*.bats`
  shows no bare probe-output `match=` assertion remains.
- New tests unedited.

## Full suite

See the precommit result in the commit step; recorded below.

Precommit: exit 0; bats 299 passed, 0 failed.
