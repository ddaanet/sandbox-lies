# Minor pass summary

Findings 4, 7-11, 13-25, 29, 30 of `reports/deliverable-review.md`. Every
batch: implementer, review, one commit plus one review commit. Reports are
`reports/minor-<batch>-<role>.md` (A to C, tdd roles) and `minor-d`, `minor-e`,
`minor-f` with their `-review` files. Details and mutation proof are in each
report.

## Per finding

| Finding | Commit | What changed | Evidence |
| --- | --- | --- | --- |
| 4 | 235c2d1 | `verdict_config_lock` prints its paragraph under `set -e` with no decodable `path=` | new case in `verdicts-locks.bats`; mutation (bare call restored) red; hand-run on 5.2 and 3.2.0 |
| 7 | 235c2d1 | `_verdict_has_control` and the `$'...'` decoder save and restore `LC_ALL` | `verdicts-readonly-path.bats` case runs `/tmp/claude/bash32/bash`; length `1 3` before, `1 1` after under C.UTF-8; either half-fix stays red |
| 8 | 235c2d1 | `$''`, relative `$'...'`, `/` value ending in a lone backslash read as no path | three cases plus neighbours pinned; each shape mutation red |
| 24 | 5de4695 | partial-checkout join gated on git's three messages anchored at line start | six cases mutation-proved; 3.2.0 hand-run |
| 25 | 5de4695 | trailing newline in the top's name kept; empty `cwd` walks `$PWD` (outline section B fallback) | same |
| 9 | 142140a | tab-less verdict line is skipped and counted, as an unknown file name already is | case with a manifest-named line; mutation red |
| 29 | 142140a | non-string `id`, `tool_use_id`, `timestamp`, `text` item skipped; directories in `survivors/` left alone | per-shape cases, mutation-proved |
| 10 | 065f7c4 | vacuous BSD-stub case removed, reason in header | `lib/verdicts.sh` forks no tool |
| 11 | 065f7c4 | one helper guards the encoded `BATS_TEST_TMPDIR` literals; unfailable assertions removed | helper mutation-proved (fc254ad) |
| 13-16, 30 | 904af8a, 6b0febc | comments corrected; `\"` and `\e` kept, reason stated and verified on 5.2 and 3.2.0 | comments only, rechecked against code |
| 17-23 | 70632d1, d908a68 | docs corrected | reviewer checked each claim against source |

Also: `docs/changelog.md` was parked at its cap after batch C; the code review
split it (`docs/changelog-2026-09.md` holds the 2026-09 entries verbatim).

Round trip of encoder and decoder after batch A: see `minor-a-green.md` for the
command and 0-mismatch result on 5.2 and 3.2.0, default locale and C.UTF-8.

## Decisions and deviations

- Finding 17: FR-10 is `Done (prose)`, the legend's status for a requirement
  no test or gate re-checks. This reverses what the outline asked (`Done`).
- Finding 8 made one existing case (forged value, relative) contradict the
  spec. Its forged value was made absolute (`$'/a\'...'`). The first attempt
  was refused by the classifier and was not routed around; my human partner
  approved the one-line edit.
- Finding 20: `lock-detectors.md` never used the three terms; they are
  defined once in `readonly-path.md`, and the lock side gained only the
  decoded-value note.
- Finding 18: no dogfood run is recorded after 2026-09-27; the Status wording
  says so instead of inventing one.
- Finding 9 went "skipped and counted".
- Haiku GREEN stalled on batches A (agent approval not counted as consent) and
  C (shellcheck directive in a test); both finished by Sonnet.

## Left open

- `lib/probes-readonly-facts.sh` `partial=1` gate still matches the phrases
  anywhere in the text. It cannot change the `readonly`/`writable` outcome,
  but a cp refusal whose quoted path holds a phrase prints wrong
  `merge=1`/`partial=1` facts. Anchoring it per line changes a documented
  whole-text contract (`readonly-path.md`), beyond finding 24's scope.

## Last `just precommit`

Exit 0 on d908a68's tree (446 bats cases): plugin.json, hooks.json,
shellcheck, bash -n, rumdl, line limits, links, python compile, tests.
