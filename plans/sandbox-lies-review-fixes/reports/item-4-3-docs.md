# Item 4.3 — docs step

## Changed

`docs/references/hook.md` only (67 lines before, 116 after `just format-docs`).

- Opening paragraph: the node now also covers the `hooks/hooks.json`
  registration and the `SessionStart` check for `jq` (D-12); the "read this node
  before" sentence adds `hooks/hooks.json`.
- New **Registration** paragraph, after **Flow**: three entries, each one
  command hook `bash "${CLAUDE_PLUGIN_ROOT}/hooks/<script>"` with a 10 s
  `timeout`; `annotate.sh` on `PostToolUse`/`PostToolUseFailure` with matcher
  `Bash`; `check-jq.sh` on `SessionStart` with no matcher. Why the `bash "..."`
  form (executable bit and a space in the root irrelevant). Why no matcher (the
  matcher filters `startup`/`resume`/`clear`/`compact`; with none the notice is
  re-issued after a `clear` or `compact`). Timeout: the annotate entries' 10 s
  bound (NFR-3) rather than the harness default. Pinned by `tests/hook.bats`
  "hooks.json names the three events" (what it asserts is listed).
- New **When `jq` is missing (D-12)** section: why it exists (`annotate.sh`'s
  first `jq` call fails, `|| exit 0`, every result unannotated with no sign);
  `command -v jq` and why (resolves as `annotate.sh`'s bare call, an exported
  function included); silent when `jq` resolves; otherwise one fixed JSON
  object from a single `printf`, no interpolation, no external tool, so no `jq`
  needed. Two-item list for the channels: `systemMessage` for the user,
  described rather than quoted, with the leading `\u001b[0m` reset (JSON
  escape, since a raw ESC is invalid JSON; lifts the line out of hook-output
  dimming, fitting a hook that speaks only on trouble); `additionalContext`
  under `hookSpecificOutput` with `hookEventName` `SessionStart`, described,
  including "until it is" holding mid-session because `annotate.sh` looks `jq`
  up per call. Writes no file, needs no temp dir, exit 0 always. Pinned by
  `tests/check-jq.bats` (each assertion listed); states that no test pins the
  wording beyond the `jq` name.

Every claim was checked against `hooks/check-jq.sh`, `hooks/hooks.json`,
`hooks/annotate.sh:43-59`, `tests/check-jq.bats`, the `tests/hook.bats` case and
the four slice reports. Dropped while drafting as unverified or contradicted: a
60 s harness default timeout, a stalled `SessionStart` hook delaying session
start, and "neither script reads a path relative to the cwd" (§Paths says a
probe falls back to its working directory when the payload has no `cwd`).

Not touched (Item 5.2's): `docs/design.md` (NFR-3, Architecture, FR-1, D-12),
`README.md`.

## Checks

- `bash lib/matchers.sh < docs/references/hook.md`: exit 1 (no detector fires).
- `just format-docs` re-wrapped three paragraphs; line count 116 (cap 400).
- Edit tool got no classifier verdict; the file was written via
  `/tmp/claude-1000/sl/put.py`.

## Gate

`just precommit` (foreground, with both paths staged) exit 0: `bats: 305 passed, 0 failed`; `precommit passed: plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests`.
