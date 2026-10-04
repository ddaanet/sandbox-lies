## Open decisions

- Publishing the sandbox-lies plugin: it has no git remote. Pick a host now or in a separate session (default: separate session; the host is my human partner's choice). README and plugin.json presuppose github.com/ddaanet/sandbox-lies.
- The held /gitlore:push stays held until the plugin installs in the other ddaanet repos, unless my human partner releases it (default: held).
- Whether to comment on anthropics/claude-code#96225 with the named-vs-unnamed delegate probe (outward-facing: my human partner's call).

## Remaining

- Delegate /edify:build of plans/sandbox-lies-review-fixes, then re-apply the .bin/claude shim-disable patch (task file).
- A SessionStart notice from some installed plugin warns that ~/.claude/settings.json lacks `git:*`, `find:*`, `ls:*`, `claude:*` and `just release:*` under sandbox.excludedCommands. It checks the legacy `:*` syntax, and my human partner now writes `git *`. Identify the emitting plugin and leave a note in its repo (read-only: a note only). Exclusions were observed not honoured under either syntax on CC 2.1.289.
- Deferred review items: m-1 quadratic tokenizer, m-7 line-cap gate coverage, m-8 corpus-eval idempotency, m-9 extract-fixtures robustness, Tests m-6 (suite on macOS).
- Later work from plans/sandbox-lies/reports/build-finish.md §Carry-forward: readonly-path nopath shapes, partial-checkout relative-path resolution from a subdirectory, the phantom "project root" wording, Item 8.2's deferred remainder, and the TDD audit's proposal to the edify build skill (read-only repo: a note or brief only).
