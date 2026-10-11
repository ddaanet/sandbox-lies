## Open decisions

- Whether the remaining Minor findings of the deliverable review (2 to 4, 7 to 11, 13 to 30, less whatever the mutation pins close) are fixed before the release or left. Default: leave them, apart from those a mutation pin closes.

## Remaining

- Fix M1 (stderr never captured in the "silently" case of `tests/verdicts-readonly-path.bats`), M2 (no case reads a word over 256 characters, so Item 4.1's pending-run flush is unpinned) and M3 (`plans/` and `plugin-dev/` exclusions unpinned for the four new line-cap types).
- Fix finding 5 (`_verdict_path_read` quadratic in the number of escapes: 31.8 s for a 3873-byte CJK path on bash 3.2.0 under `C.UTF-8`, against the hook's 10 s timeout).
- Fix finding 6 (`_readonly_tokenize` copies the pending run on every unquoted `#` and `>&`; the header's "no copy grows with the word" is untrue for those shapes).
- Fix finding 12 (`tests/check-line-limits.bats` parked at exactly 400 lines, a comment shortened to stay there: split the file and restore the comment).
- Pin the surviving mutations of the report's `## Mutations` tables not already closed by the fixes above: 1.1/3, the gate fix's `a b f r v` arm, 2.1/1, 6.1/2, 6.1/3, 6.2/1, 6.2/2.
- Publish once the fix pass is complete, in this order: `/gitlore:push` (the `sandbox-effects.md` reword is committed in the `ddaanet` tier and not on its remote), then the repo push to `origin` (https://github.com/ddaanet/sandbox-lies; nothing pushed yet), then the release.