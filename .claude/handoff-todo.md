## Open decisions

- Delete the scratch transcripts the m-3 resume probing left in `~/.claude/projects/-tmp-claude-resume-probe-A/` and `-B/` (outside the repo, in the Claude config). Default: delete them, unsandboxed.
- FR-5's list of suites pairing both flag values omits `tests/hook-resume.bats`, deferred by the build's docs review because `docs/design.md` sits at 399 of its 400-line cap. Default: fold into the next review cycle.
- `skills/sandbox-lies/references/excluded-commands.md` keeps facts sourced only from a separate-session brief, relabelled as observed vs read from the CC 2.1.289 bundle. Keep or drop (default: keep).
- Publishing the sandbox-lies plugin: it has no git remote; README and plugin.json presuppose github.com/ddaanet/sandbox-lies. Default: a separate session; the host is my human partner's choice.
- The held /gitlore:push stays held until the plugin installs in the other ddaanet repos, unless my human partner releases it (default: held).
- Whether to comment on anthropics/claude-code#96225 with the named-vs-unnamed delegate probe (outward-facing: my human partner's call).

## Remaining

- A SessionStart notice from some installed plugin warns that ~/.claude/settings.json lacks `git:*`, `find:*`, `ls:*`, `claude:*` and `just release:*` under sandbox.excludedCommands, checking the legacy `:*` syntax while my human partner writes `git *`. Identify the emitting plugin and leave a note in its repo (read-only: a note only).
- Probe `path=` lines: replace the newline guards (readonly `nopath`, the dropped lock `path=`) with an encoding that carries newlines; candidate: raw path when it has no control characters, `printf %q` form only when it does.
- Deferred items from the first review: m-1 quadratic tokenizer, m-7 line-cap gate coverage, m-8 corpus-eval idempotency, m-9 extract-fixtures robustness, Tests m-6 (suite on macOS).
- Later work from plans/sandbox-lies/reports/build-finish.md §Carry-forward: readonly-path nopath shapes, partial-checkout relative-path resolution from a subdirectory, the phantom "project root" wording, Item 8.2's deferred remainder.
