# Item 4.1 slice 9 — GREEN

Executed in session by the orchestrator: the implementation is one line.
`hooks/annotate.sh` joins human lines with `; ` instead of a space
(`human="${human:+$human; }$line"`), with a two-line comment giving the
reason. Skip-and-continue past an over-cap paragraph already existed (Item
2.3) and is proven by mutation in `item-4-1-s9-red.md` and
`item-4-1-s9-test-review.md`.

`bats tests/hook-cap.bats`: 6 of 6 pass, `cap skips and continues` among them.
`direnv exec . just precommit`: `bats: 148 passed, 0 failed`;
`precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line
limits, links, tests`.

Deferred from this slice's commit: the Item 4.1 memory retirement (the
`.git/index.lock` section), the `tests/matchers.bats` live-file case it reds,
and the FR-3/4/5/6 status flips. Memory commits pass the gitlore approval
gate, so they are batched with Item 4.2's retirement into one commit and one
approval (see `build-phase-4.md`).
