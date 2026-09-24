# Item 2.3 slice 10 — GREEN and item close

## Test

`tests/hook.bats` is committed as the test review left it (`hook under BSD
stubs`, stubbing `grep sed`, `expected` pinned by `jq -e` on the gitadd
`systemMessage`). No implementation change: `scripts/run-bats.sh
tests/hook.bats` — 13 passed, 0 failed.

## Memory retirement — `memory/ddaanet/sandbox-effects.md`

Phantom dotfiles section, paragraph by paragraph:

1. Masks paragraph (bind-mount list, 22 paths, project-root scope, `.git/`
   entries): **removed**, except its zero-byte sentence, which **stays** as
   the section's first paragraph. It was rewritten from "A second masking
   shape exists: since 2026-07-20 …" to "Besides the `/dev/null`
   character-device masks, since 2026-07-20 deny-listed paths have also
   appeared as **zero-byte read-only regular files** …", because the "second"
   referred back to text that is gone.
2. Who sees them (`ls -a`, `find`, `rg`, the `git status` family):
   **removed**.
3. `git add -A` refusal: **removed**.
4. Porcelain cleanliness gate: **kept**, unchanged. Its opening "They" now
   follows the section heading and the zero-byte paragraph.
5. Visible unsandboxed: **removed**.
6. `## Context` is a Bash call: **kept**, unchanged.

`/tmp reads full while du finds little`: the whole section is **removed**.

Routing:

- Symptom table: the `/tmp` row is **removed**. The first phantom row loses
  `can only add regular files` (retired) and now reads "`.bashrc`/`.zshrc`/
  `.claude/skills` untracked or zero-byte; a porcelain gate reports DIRTY".
  That routes to the zero-byte and porcelain paragraphs. The `## Context` row
  is unchanged.
- Frontmatter `description` and the index line in both `memory/MEMORY.md` and
  `memory/ddaanet/MEMORY.md`, with identical text in all three:
  - "phantom dotfiles as char devices or zero-byte files (break `git add -A`;
    a porcelain cleanliness gate reads their `??` as DIRTY; one clean reading
    proves nothing)" becomes "phantom dotfiles as zero-byte files, or a
    porcelain cleanliness gate reading their `??` as DIRTY".
  - The `/tmp "No space left"/du≪df` clause is dropped.

No other section is touched. The file is 29,465 bytes. It was far over the
4 KB recall cap before this change as well. Per the memory-writing skill, the
hub split is a separate decision, so it is not done here.

## Translation map

In `docs/references/detectors.md`, the masks row now ends with `;
zero-byte shape → skill`.

## Status flips — `docs/design.md`

The mapping table decides each flip, together with what is pinned today:

- **FR-1 → Partial (dogfood: Item 8.1).** `hooks.json` registers both events
  and `tests/hook.bats` pins the key set. The mapping also gives FR-1 to Item
  8.1.
- **FR-3 → Partial (probe call: Item 4.1).** The pipeline from payload to
  text to `detect` to JSON is pinned, including the malformed cases. The
  probe call is not.
- **FR-5 → Partial (lock, candidate, `readonly-path` policies: Items 4.1,
  4.2, 6.1).** Only the phantom policy (ignore the flag) exists, and it is
  pinned by `phantom verdicts ignore the flag`.
- **FR-6 → Partial (lock, candidate, `readonly-path` verdicts: Items 4.1,
  4.2, 6.1).** The phantom text, the 400-character limit, silence and the
  2 KB cap are pinned.
- **FR-10 → Partial (phantom sections retired; the rest: Items 4.1, 4.2, 6.1,
  7.1, 8.2).**
- **NFR-2:** already `Done`. Slice 10 adds this suite's stubbed case, so
  there is no flip.
- **NFR-3 → Done (100 ms bound measured, not gated).** The mapping gives it
  to Item 2.3 alone. Its pin clause (the `hooks.json` timeout, and empty
  stdout on quiet fixtures) is checked by `hooks.json names both events` and
  `every quiet fixture is silent`. The 100 ms figure is a recorded
  measurement, and the runbook says it is not gated, so the parenthetical
  says exactly that.
- **NFR-4 → Done.** The mapping gives it to Item 2.3 alone. **This is the one
  edit outside a status word:** its pin clause said "review; no test", which
  cannot sit beside `Done` under the legend. It now names `tests/hook.bats`
  and `tests/matchers.bats` running the hook and `detect` with `TMPDIR`
  naming a missing directory (the slice 8 cases `hook needs no temp dir` and
  `detect needs no temp dir`).

Line budget: written in full, the parentheticals put the doc at 404 lines
after `just format-docs`. I made them terse and it is now 399, at or under
400. No other prose was shortened.

Not touched, and stale: the top `**Status:** Planned. Nothing in this
document is live …` line and `## Now`. Item 8.2 owns `## Now`, and the brief
limited this item to the requirement status sentences.

## Wall times — `docs/changelog.md`

Method: `bash hooks/annotate.sh`, mean of 30 runs, `PostToolUse` payloads
built as `tests/helpers/hook.bash` builds them. Run inside the command sandbox
on a 2-core Debian 13 box (Linux 6.12.96, GNU bash 5.2.37, load average ~2.1).

| payload | pass 1 mean | pass 2 mean (recorded) |
|---|---|---|
| `quiet-clean-status` | 61 ms | 52 ms |
| `fire-masks-porcelain` | 61 ms | 64 ms |
| quiet 25,000-char stdout (the quiet fixture repeated) | 52 ms | 54 ms |

In pass 1, one `fire-masks-porcelain` run took 169 ms. The changelog entry
says the 100 ms bound holds for the mean, not for every run on a loaded box.
Before timing, I confirmed that the quiet payloads give empty stdout and the
fire payload gives the verdict JSON.

## Runbook

The Item 2.3 slice 10 text is corrected on three points:

- The stub is `make_bsd_stubs grep sed`.
- The unstubbed output is pinned with `jq -e`.
- `annotate.sh` calls no `sed`, but `detect`'s `match_phantom_untracked`
  does.

It also names the absolute-path residual.

## Gates

- `just format-docs`: clean (design.md 399 lines).
- `scripts/run-bats.sh tests/`: 95 passed, 0 failed.
- `just precommit`: passed: plugin.json, hooks.json, shellcheck, bash -n,
  rumdl, line limits, links, tests.
- Commit: **blocked** by gitlore's pre-commit approval gate ("memory is dirty
  and has no approved commit summary"). The nine paths are staged by name;
  nothing is committed. The summary needs my human partner's approval before
  it is written to `.claude/gitlore-memory-message`.

Draft memory summary for approval:

> Retire the phantom-dotfile and /tmp sections now carried by sandbox-lies
>
> **Reduce ddaanet/sandbox-effects:** the Phantom dotfiles section no longer
> lists the `/dev/null` mask set and scope, which commands see the masks, the
> `git add -A` refusal, or the masks' visibility to unsandboxed readers — the
> sandbox-lies hook's `phantom-chardev`, `phantom-untracked` and
> `phantom-gitadd` verdicts now deliver those at the moment the symptom
> appears. It keeps the zero-byte read-only mask shape (no verdict matches
> it; it moves to the sandbox-lies skill later), the porcelain-gate
> paragraph and the `## Context` paragraph. The `/tmp reads full` section is
> removed as not a sandbox effect, per the sandbox-lies design. The symptom
> table and index line drop the retired symptoms.
