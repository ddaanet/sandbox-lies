# Item 1.2 — formatter and gate

- `pyproject.toml` (non-package, `dev` group `rumdl>=0.2.74`), `uv.lock`
  (rumdl 0.2.77), `.envrc` (`VIRTUAL_ENV` and `PATH_add .venv/bin` after the
  existing two lines), `.venv/` in `.gitignore`, `.rumdl.toml` ported from
  edify with scope `skills/**/*.md`, `docs/**/*.md`, `/*.md` and no `exclude`.
- `justfile`: `format-docs`, `test`, and `precommit` as a bash recipe whose
  `report` helper accumulates check names and prints
  `precommit passed: plugin.json, shellcheck, bash -n, rumdl, tests`. Tracked
  paths come from `git ls-files -z` read NUL-delimited.
- `uv sync` ran once unsandboxed.
- `just format-docs` reflowed `BRIEF.md`, `docs/changelog.md`,
  `docs/design.md` and `docs/references/detectors.md`. Every file's
  whitespace-collapsed text is identical before and after, and no reflowed line
  starts a new list, quote, heading or table marker.
- **`docs/design.md` post-reflow: 389 lines** (399 before, after Item 1.1's
  status flips). `detectors.md`: 309.
- NFR-5 status flipped to Partial.

## Verification

- Gate green: `precommit passed: plugin.json, shellcheck, bash -n, rumdl,
  tests` (26 bats cases).
- Fault: FR-1's paragraph in `docs/design.md` hand-wrapped at 60 columns (the
  script asserted the text changed before the run). The gate exited non-zero
  and printed the unified diff restoring 80-column wrapping. After the file was
  restored, the gate went green again.

## Deviation

`direnv exec . just precommit` refuses to run: editing `.envrc` revoked
direnv's approval, and `direnv exec` needs it as well. The gate ran with
`VIRTUAL_ENV=$PWD/.venv PATH=$PWD/.venv/bin:$PATH` set by hand, which is
exactly what `.envrc` exports. `direnv allow` is still my human partner's step.
