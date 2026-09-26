# Item 6.1 slice 2 — GREEN: writable outcome through the hook

Mode: GREEN. Implemented `verdict_readonly_path` in `lib/verdicts.sh` for the
`writable` outcome only, replacing the RED-stub `verdict_readonly_path()
{ cat >/dev/null; }` at the end of the file.

## Implementation

Placed the new function between `_verdict_lock_present` and the "shipped
candidates" comment block — matching `docs/references/detectors.md`'s order
of candidates (readonly-path precedes tmpdir-unset, resume-lost,
seccomp-init there), while leaving the "shipped candidates" comment
accurate for the outcome-less trio that follows it (readonly-path takes an
outcome, so it does not belong under that comment).

`verdict_readonly_path <outcome>` reads the probe's `key=value` stdin lines
with the same `while IFS= read -r line || [ -n "$line" ]` loop
`_verdict_lock_present` uses, picking out `path=`. For `writable` it prints:

```
printf '%s' "$path"
printf '%s\n' ' is writable outside the sandbox, whose allowlist refused the write. Re-run the whole call with `dangerouslyDisableSandbox: true` or, if it only read a command-output file such as a `*.log`, the command that wrote that file. For `.claude/settings.json`, use the `update-config` skill. A merge or checkout that died here may be partial: compare modified files against the target first.'
printf '%s\n' 'read-only — sandbox allowlist, writable outside'
```

with the `# shellcheck disable=SC2016` comment on the second `printf`, as
the file's other literal-backtick lines carry. Interpolation is plain
variable expansion (`printf '%s' "$path"` then a separate single-quoted
`printf '%s\n'` for the rest) — never sed or eval — so `path=/r/a b&c\1/x`
passes through byte-exact: nothing in that value is ever placed inside a
substitution pattern or a double-quoted string where a backslash or
backtick could be reinterpreted. `readonly` and `nopath` fall through the
`case` unmatched and print nothing, exactly as an unmatched lock outcome
does in `_verdict_lock_present` (scope: slice 3).

**Empty-stdin choice (row-driven cases).** The row-driven cases in
`tests/verdicts.bats` (`rows()`'s `readonly_path writable` row, read by
`verdict_text`/`all_verdict_text`, which explicitly redirect
`</dev/null`) call `verdict_readonly_path writable` with no `path=` line.
`path` then stays `''`, and the function prints the same paragraph with
nothing interpolated — a leading space before "is writable outside the
sandbox…" — rather than inventing substitute text (e.g. "this path") that
`detectors.md` does not carry. This keeps the row-driven text identical
to the real paragraph, just short one clause, matching how
`_verdict_lock_present` drops a clause when a key is absent instead of
inserting a placeholder.

## Tests made to pass, in order

1. `tests/verdicts.bats::readonly-path writable verdict text matches
   detectors.md` — transcription case; asserts line 1 equals
   `$p$rest` (or the backticked rendering) and line 2 equals `read-only —
   sandbox allowlist, writable outside`, `$p` = `/r/a b&c\1/x`. Passed on
   the first implementation (bare-path rendering, no backticks).
2. `tests/verdicts.bats::verdicts under 400 chars` — the `readonly_path
   writable` row now yields two non-empty lines, line 1 under 400 chars,
   line 2 containing ` — `.
3. `tests/hook-candidates.bats::writable outcome through the hook` — the
   hook case: probe stub `readonly_path writable path=/r/x`; asserts the
   probe was reached, `additionalContext` contains `/r/x`, `is writable
   outside the sandbox` and `compare modified files against the target`,
   and `systemMessage` equals `read-only — sandbox allowlist, writable
   outside`.
4. `tests/verdicts.bats::verdict text is quiet` and `no removal
   instruction` — previously erroring on `verdict_readonly_path: command
   not found` via the RED stub's absence; now pass on an assertion (the
   real paragraph is quiet and carries no removal word — it was already
   passing under the RED-stub's inert text per the test review, and stays
   passing with real text).

Ran each bats file after each edit (foreground,
`direnv exec . scripts/run-bats.sh <file>`):

- `tests/hook-candidates.bats` — 5 passed, 0 failed.
- `tests/verdicts.bats` — 9 passed, 0 failed.

## Full suite, lint, precommit

`direnv exec . just test`: `bats: 191 passed, 0 failed`.

No `just lint` recipe exists in this repo's `justfile` (checked: `just
lint` → `error: Justfile does not contain recipe 'lint'`); the dispatch's
own done condition names the `just precommit` gate, which subsumes
`shellcheck`, `bash -n` and `rumdl`.

`cd /Users/david/code/sandbox-lies && direnv exec . just precommit >
"$TMPDIR/pc.out" 2>&1; echo "exit=$?"; tail -3 "$TMPDIR/pc.out"`:

```
exit=0
scripts/run-bats.sh tests/
bats: 191 passed, 0 failed — full log: /tmp/claude-1000/sandbox-lies-bats.QPdper
precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests
```

No warnings emitted by any check (shellcheck, rumdl, line limits, links all
clean — nothing to record for the code review's judgement call).

## Files changed (implementation)

- `lib/verdicts.sh` (141 lines) — `verdict_readonly_path` real
  implementation for `writable`, replacing the RED stub.

No test file was edited in this dispatch; the slice's tests
(`tests/hook-candidates.bats`, `tests/helpers/hook.bash`,
`tests/hook-locks.bats`, `tests/verdicts.bats`) were left exactly as the
test review delivered them.
