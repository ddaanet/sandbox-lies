# Minor batch B, GREEN (findings 24, 25)

## Changes

Only `lib/probes-readonly.sh` and `docs/changelog.md` (one dated bullet). No
test edited. `docs/references/readonly-path.md` is unchanged: its text stays
true (the join still applies to the matching line alone; it says nothing about
an empty cwd or a phrase in a path).

- Finding 24. `probe_readonly_path` decides the join with a new
  `_probe_partial_checkout_line`, which anchors on git's three messages at the
  line start (`error: unable to unlink old`, `error: unable to create file`,
  `fatal: cannot create directory at`), each built from fragments. A cp refusal
  naming a path with a phrase no longer qualifies.
- Finding 25, newline. The walk's output goes through `$(...)` with a trailing
  `x`; `base="${top%?x}"` removes the walk's own newline and the `x`, so a top
  named `top<newline>` keeps its newline.
- Finding 25, empty cwd. When the cwd is empty and the line is partial-checkout,
  the walk starts at `$PWD`, so the join is walked like any other cwd. Other
  producers with an empty cwd still join onto `$PWD` unwalked, as before.
- One subshell per partial-checkout call, as before (`$(...)` already forked);
  no new fork on the other paths.

Not touched: `_readonly_partial_checkout_text` in
`lib/probes-readonly-facts.sh`, which still gates `partial=1` on the whole text
by substring. That file is outside the allowed edit list, so a cp refusal whose
path holds a phrase still gets `partial=1` in its facts tail. Residual, to be
raised as its own item if wanted.

Judgement call from the RED report kept as written: an empty cwd means
`$PWD`, and the walk applies from it (case 4). Dropping that case would leave
the empty-cwd walk unspecified.

## Test runs (one process at a time, foreground)

- `tests/probes-readonly-resolve.bats`: 16 passed, 0 failed (was 11 + 3 red).
- `tests/probes-readonly.bats`: 17 passed, 0 failed.
- `tests/probes-readonly-facts.bats`: 15 passed, 0 failed.
- `tests/probes-readonly-globs.bats`: 14 passed, 0 failed.
- `tests/probes-readonly-members.bats`: 13 passed, 0 failed.
- `tests/probes-readonly-operands.bats`: 20 passed, 0 failed.
- `tests/probes-readonly-pins.bats`: 15 passed, 0 failed.
- `tests/probes-readonly-tokenize-time.bats`: 3 passed, 0 failed.

## bash 3.2.0 hand-run

Script under `$TMPDIR`, sourcing `lib/probes-readonly.sh` and running six
shapes through `probe_readonly_path`. Command:
`/tmp/claude/bash32/bash <script> <scratch>` (run as `env LC_ALL=C` and
`env LC_ALL=C.UTF-8`, from `/`). Output is identical under both locales and
matches bash 5.2 (`bash <script>`):

```
GNU bash, version 3.2.0(1)-release (x86_64-unknown-linux-gnu)
1 anchored: yes / cp: no
2 git unlink:      writable  path=<scratch>/t/repo/d/f
3 cp phrase:       readonly  path=<scratch>/t/repo/sub/unable\ to\ create\ file/x
4 newline top:     writable  path=$'<scratch>/t/top\n/d/f'
5 empty cwd:       writable  path=<scratch>/t/repo/d/f
6 empty cwd cp:    writable  path=<scratch>/t/repo/sub/d/f
```

The one stderr line from the script (`No such file or directory` for
`<scratch>/t/repo/sub/d/f`) is a stray `: >` in the throwaway setup, before its
`mkdir`; it is not from the probe.

Timing: the changed lines add no loop; the walk and the anchored gate each run
once per call. Not timed separately; the full suite run under bash 5.2 is the
timing record.

## Precommit

`just precommit`, unsandboxed, foreground: exit 0.

Recap: plugin.json and hooks.json parse; shellcheck; `bash -n`; rumdl wrap
check; line limits; links; Python compile; tests (438 passed, 0 failed,
`tests/`). `just format-docs` ran before it, clean.
