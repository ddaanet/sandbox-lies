# Review — Item 1.2 (formatter and gate)

Reviewed: the HEAD commit (`📦️ Item 1.2 — rumdl formatter and the precommit
gate`) against runbook Item 1.2, the Cross-cutting section, and the recall
entries `markdown-formatter-choice`, `uv-direnv-venv`, `cc-grep-shell-function`.

**Verdict: no issues found; no fixes applied.** The working tree is left
unchanged (only the sandbox's phantom dotfiles show as untracked).

## Spec conformance

- `pyproject.toml`: non-package (`[tool.uv] package = false`), `dev` group
  `rumdl>=0.2.74`; `uv.lock` committed, pins rumdl 0.2.77.
- `.envrc`: `source_up_if_exists` first, `PATH_add .gitlore/bin` kept, then
  `export VIRTUAL_ENV=$PWD/.venv` and `PATH_add .venv/bin`. There is no `uv run`
  or `uvx` anywhere in the justfile.
- `.gitignore` gains `.venv/`.
- `.rumdl.toml`: ports edify's MD013 `normalize` config. Scope is
  `skills/**/*.md`, `docs/**/*.md`, `/*.md`, with no `exclude`, and the comment
  is rewritten for this repo. The comment's forward reference to
  `scripts/check-line-limits.sh` belongs to Item 2.1.
- `justfile`:
  - `format-docs` is `rumdl fmt -q --no-cache`.
  - `test` is `scripts/run-bats.sh tests/`.
  - `precommit` runs these checks in the specified order: `jq empty` on
    plugin.json, shellcheck over tracked `*.sh`/`*.bash`/`*.bats`, `bash -n`
    over tracked `*.sh`, `rumdl fmt --check -q --no-cache`, then `just test`.
  - Each check runs through `report`, and a clean run prints the recap line.
- The NFR-5 status flip in `docs/design.md` says Partial and names what is
  still pending.
- Item report: `design.md` has 389 lines after the reflow and had 399 before.
  The report explains why the "exactly 400" in the runbook was already 399 at
  HEAD~1 (Item 1.1's status flips). I checked the 399 with
  `git show HEAD~1:docs/design.md | wc -l`.

## Verification run

- **Gate on the real tree** (venv on `PATH` by hand): exit 0,
  `precommit passed: plugin.json, shellcheck, bash -n, rumdl, tests`, 26 bats
  cases passed.
- **Reflow render-preservation**:
  - Method: rendered HEAD~1 and HEAD of all four files with `markdown_it`
    (CommonMark plus tables) and compared the whitespace-collapsed HTML.
  - Result: `BRIEF.md`, `docs/changelog.md` and `docs/references/detectors.md`
    render identically, and their whitespace-collapsed text is identical.
  - `docs/design.md` differs only by the NFR-5 flip. With the flip inverted,
    both its render and its text are identical to HEAD~1.
  - A separate line scan found no line newly beginning with a list, quote,
    heading or table marker in any of the four files.
- **Scratch repo** (`/tmp/claude/item-1-2-review/`, now removed) running the
  `precommit` recipe body verbatim with a stub `test` recipe:
  - Clean run: exit 0 with the full recap. An untracked-scope
    `plans/long.md` holding a 300-character line stayed out of the rumdl check,
    so the `/*.md` anchoring holds.
  - Shellcheck fault in `sub dir/a b.sh` (space in both the directory and the
    file name): the gate stopped at shellcheck with SC2086 on the full spaced
    path and exited 1.
  - Syntax fault in the same spaced path, with shellcheck stubbed so the gate
    reached `bash -n`: it stopped with
    `sub dir/a b.sh: line 3: syntax error` and exited 2.
  - Malformed `plugin.json`: `jq` parse error, exit 5.
  - FR-1's paragraph in `docs/design.md` re-wrapped at 60 columns (the probe
    asserted that the text had changed): exit 1 with a unified diff restoring
    the 80-column fill.
  - In every faulting case, no recap line was printed.

## Considered, not changed

- **Empty `files` under bash ≤ 4.3 with `set -u`.** Expanding an empty
  `"${files[@]}"` is an unbound-variable error on bash 3.2. It only happens
  with zero tracked `*.sh`, which cannot occur here because `lib/matchers.sh`
  and `scripts/run-bats.sh` are permanent. Adding a guard would only protect
  against a state that cannot arise.
- **Unquoted `export VIRTUAL_ENV=$PWD/.venv`.** bash does not word-split
  assignment arguments of `export`. A probe with `x="/a b"` confirmed this and
  yielded `[/a b/.venv]`. The line matches gitlore, cwd-safety and
  claude-plugin-dev. Quoting it would re-hash `.envrc` and cost another
  `direnv allow` for no behaviour change.
- **Venv `python3` shadowing** (`uv-direnv-venv`). The only Python on the
  gate's path is `tests/*.py`, which imports stdlib only. The dev group needs
  nothing more.
- **`just test` echoes its command line inside the gate.** This is just's
  default recipe echo, it matches `format-docs`, and the spec gives the recipe
  body verbatim. It is one line of noise, not an ambiguity.

## Outside this item (not flagged, for the lead)

- `scripts/run-bats.sh` names its log `gitlore-bats.XXXXXX`, a leftover from
  the port. It belongs to Item 1.1's file.
