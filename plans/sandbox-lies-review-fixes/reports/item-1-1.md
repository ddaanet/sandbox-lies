# Item 1.1 report

Moved the readonly-path entry (old lines 131-269 of `docs/references/detectors.md`)
to the new `docs/references/readonly-path.md`. The new node has a title, a short
provenance paragraph modelled on `lock-detectors.md`'s, then the entry with its
heading promoted from `###` to `##`. The moved text has no wording change.

Line counts: `detectors.md` 399 -> 270; `readonly-path.md` 148 (new).

In `detectors.md`:

- A stub `### readonly-path` entry now points at `readonly-path.md#readonly-path`.
- The opening paragraph's "read before" sentence names both nodes.

In `hook.md`, the opening paragraph lists `readonly-path.md` beside `lock-detectors.md`.

Prose citations repointed to `readonly-path.md`:

- `lib/matchers.sh`: the `### readonly-path` pointer, now `## readonly-path`.
- `lib/probes-readonly.sh`: header, and the flag policy note.
- `lib/probes-readonly-command.sh`: header, tokenizer residuals, reader tools,
  and the merge-segment `target=` comment.
- `lib/probes-readonly-facts.sh`: header, `_readonly_print_facts` (two), the
  `target=` subcommand note, and `_readonly_repo_facts`' match comment.
- `lib/verdicts.sh`: the header's "Text from" now also names `readonly-path.md`;
  the readonly tail comment; `_readonly_match_list`.
- `tests/verdicts.bats`: the three readonly-path case names and the first
  comment's source path.
- `tests/verdicts-readonly.bats`: header and the five-names comment.
- `tests/probes-readonly-facts.bats`: header.
- `tests/helpers/verdicts.bash`: `readonly_path_tail`.
- `tests/extract-fixtures.py`: the git-mkdir SPEC comment.

No test reads the doc by section; the verdict text is transcribed in the cases.

Citations of other detectors stay: `hooks/annotate.sh` 84 and 90,
`lib/verdicts.sh` 242, `tests/corpus-eval.py` 50, `tests/extract-fixtures.py` 83,
`tests/matchers.bats` 46, `tests/verdicts.bats` 45-46, 77-78, 157, and
`tests/hook.bats` 248.

`just format-docs` and `scripts/check-links.sh` ran clean.

Gate: `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests` (bats: 251 passed, 0 failed).
