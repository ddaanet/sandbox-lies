# Item 2.3 slice 2 — GREEN

Mode: GREEN. Only `hooks/annotate.sh` changed; `lib/` byte-identical to HEAD.

## Change

Added a `PostToolUse)` arm to the `case "$event"` block that builds `text` as
`tool_response.stdout`, a newline, `tool_response.stderr` — the correct
rebuild identified as variant A/J in the test review's probe table:

```sh
PostToolUse)
  text=$(printf '%s' "$payload" | jq -r \
    '.tool_response.stdout // empty, .tool_response.stderr // empty') \
    || exit 0
  ;;
```

`jq -r` with the comma operator prints each output on its own line, so the
newline separator falls out of the rebuild itself rather than needing a
literal `"\n"` join — no unquoted expansion, no extra process. `// empty`
guards a null/absent field the same way the existing `PostToolUseFailure` arm
does; an actual empty string (the recorded payload shape) passes through
unchanged, matching D-13's "byte-identical to the tool result" contract.

Updated the header comment (previously "a PostToolUse payload contributes
none") to describe both events, mirroring the phrasing in
`docs/references/detectors.md`'s Conventions section.

## Order worked

Wrote the `PostToolUse)` arm and the header-comment update together (a single
coherent change to the case block and the sentence describing it), then ran
the three new cases plus the full hook suite in one pass — all green on the
first attempt, no intermediate failing case. `nl`, the verdict-loop, and the
final `jq -n` were untouched; only the event dispatch and the header comment
changed.

## Verification

- `scripts/run-bats.sh tests/hook.bats`: 6 passed, 0 failed (the three
  preexisting cases plus the three new ones from RED).
- `scripts/run-bats.sh tests/`: 74 passed, 0 failed.
- `just precommit` (via `direnv exec .`): `precommit passed: plugin.json,
  hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`.

## Scope held

No type guard on `tool_response` (slice 6), no shared chardev/untracked
paragraph consolidation (slice 3), no 2 KB cap (slice 7), no flag policy
(slice 4). The `PostToolUse` arm reads `tool_response.stdout`/`.stderr`
directly; a string or scalar `tool_response` reaching this jq expression is
left for slice 6 to guard.
