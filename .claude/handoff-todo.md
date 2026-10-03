## Open decisions

- Fix scope: the 6 Majors only, or Majors plus the 30 Minors (default: Majors plus every Minor that is a mechanical doc, comment or test fix; leave tooling robustness in tests/corpus-eval.py and tests/extract-fixtures.py for later).
- Major 2, surfacing a missing jq: a README install note only, or also a runtime signal (SessionStart check, or a one-time systemMessage from the hook) (default: README note plus a SessionStart check).
- Major 1, the skill's excludedCommands text: rewrite it to the documented every-command rule now, or first probe whether `git *` (current syntax) is honoured where `git:*` was not on CC 2.1.283 (default: probe first in a main session, single covered command writing outside the allowlist, then rewrite).
- Memory commit for memory/ddaanet/classifier-no-verdict-plugin-dir.md and its MEMORY.md line: approve the summary "Add classifier-no-verdict-plugin-dir: a Write in a --plugin-dir . checkout gets no classifier verdict; write via a Python script in $TMPDIR" (default: approve; write it to .claude/gitlore-memory-message, no parent commit needed).
- Publishing the sandbox-lies plugin: it has no git remote; pick a host now or in a separate session (default: separate session; the host is my human partner's choice). README and plugin.json presuppose github.com/ddaanet/sandbox-lies.
- The held /gitlore:push: stays held until the plugin installs in the other ddaanet repos, unless my human partner releases it (default: held).

## Remaining

- Delegate /edify:build of the deliverable-review fixes, scoped by the decisions above.
- Later work from plans/sandbox-lies/reports/build-finish.md §Carry-forward: readonly-path nopath shapes, partial-checkout relative-path resolution from a subdirectory, the phantom "project root" wording, the detectors.md split of §readonly-path at its next addition, Item 8.2's deferred remainder, and the TDD audit's proposal to the edify build skill (read-only repo: a note or brief only).
- Decide whether to comment on anthropics/claude-code#96225 with the named-vs-unnamed delegate probe (outward-facing: my human partner's call).