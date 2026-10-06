# Review: finishing review gate — group "skill"

Written by the orchestrator from the findings `plugin-dev:skill-reviewer`
returned (report-only reviewer: Read, Grep and Glob only). The fixes were
applied in the orchestrating session.

- **Scope**: `skills/sandbox-lies/SKILL.md` and its four `references/` nodes —
  Item 5.1's edits under D1 as revised 2026-10-05, and the skill's consistency
  as a whole.
- **Date**: 2026-10-06
- **Reviewer verdict**: Needs Improvement, no blockers. No UNFIXABLE.

## Deliverables

Every Item 5.1 sub-bullet has its deliverable (hub §Tell, §Writing, §Leaving,
§Keeping; description unchanged; the four node edits). Strict mode is named
`sandbox.allowUnsandboxedCommands: false` in both places; the re-probe is the
bare covered `git status`. Line counts after the fixes: `SKILL.md` 190 of 200;
nodes 167, 88, 67, 68.

## Findings and dispositions

Each claim that cites the separate-session report was checked against that
report before the fix; each other claim against the cited lines.

### Major

1. **M1 — the cwd advice omitted D1's own exception.** `SKILL.md` §Keeping and
   `masks-and-gates.md` listed `git -C`, a `cd` and a subshell as keeping a
   call sandboxed, but not a git absolute-path argument, which the hub's
   §Writing names. FIXED in both: the list gains "a git absolute-path
   argument"; combined with m8 below.
2. **M2 — provenance mislabelled in `excluded-commands.md` "Seen beyond the
   documented list".** The separate session observed only `2>&1`, a glob
   argument and an unquoted `$HOME` keeping a covered call sandboxed; the
   `VAR=` allowlist and the value-taking git options were read from the CC
   2.1.289 bundle, not observed. FIXED: split into an observed bullet and a
   "Read from the CC 2.1.289 bundle … not observed" bullet (with the
   `--no-pager` note). The reviewer left keeping a brief-sourced bullet at all
   to my human partner, default keep relabelled; kept relabelled.
3. **M3 — stale quoted-argument claim.** `excluded-commands.md` §Matching
   stated the CC 2.1.233 "quoted arguments defeat the match" as current, and
   `escapes-and-costs.md` repeated it as a live symptom; the same separate
   session saw a covered call with a quoted argument run unsandboxed on CC
   2.1.289. FIXED: the decompile sentence is dated to CC 2.1.233 with the 2.289
   observation beside it, and the observed bullet records the quoted-argument,
   `\.` and trailing-comment shapes that ran unsandboxed;
   `escapes-and-costs.md`'s symptom list now reads "a glob argument, `2>&1`, a
   double space, `/bin/ls`".

### Minor

1. **m1** `SKILL.md` §Writing: "a redirection other than a descriptor
   duplication" read as promising `2>&1` safe. FIXED: "a redirection (a
   descriptor duplication such as `2>&1` is documented as fine, but was seen to
   keep a call sandboxed on CC 2.1.289)".
2. **m2** `SKILL.md` §Writing omitted the `sudo`, `eval` or `xargs` head the
   node lists. FIXED.
3. **m3** `SKILL.md` "sandboxed like a typed call" read as always sandboxed.
   FIXED: "goes through the same sandbox decision as a typed call", masks its
   own or a concurrent sibling's.
4. **m4** `masks-and-gates.md`: "confirmed live 2026-08-16" over-claimed the
   every-command rule. FIXED: "Observed 2026-08-16: an excluded bare
   `git status` expansion saw the real tree…".
5. **m5** `excluded-commands.md`: "silently sets `dangerouslyDisableSandbox`"
   contradicted `sandbox-state.md` D-8 (the payload carries no flag). FIXED:
   "runs the call as if it carried `dangerouslyDisableSandbox`; the flag in the
   hook payload stays unset".
6. **m6** `excluded-commands.md`: the `Bash(sudo:*)` deny example proves
   nothing under D1. FIXED: qualified "observed before the every-command rule;
   version not recorded".
7. **m7** `SKILL.md`: "before any classifier call" too strong where the session
   has server-side review. FIXED: "unless the session has server-side review".
8. **m8** `SKILL.md` and `masks-and-gates.md`: "each forfeits the read-only
   auto-allow" broader than the validator, which rejects a `cd` only beside
   git, and does not reject an absolute path. FIXED: "`git -C`, a subshell and
   a `cd` beside git each forfeit the read-only auto-allow".
9. **m9** `escapes-and-costs.md` symptom list omitted `-C` and an absolute path
   argument. FIXED.
10. **m10** `excluded-commands.md` baseline omitted `just release *`, present at
    the CC 2.1.289 probes. FIXED.

## Checked and clean (reviewer)

The description (third person, trigger-rich, no whole-call semantics; long but
the runbook keeps it); hub-to-node routing and every link; no `git:*` or
`claude:*` outside history and legacy notes; the same cwd preference order in
the hub and `masks-and-gates.md`; the batching rule word for word in the hub and
`escapes-and-costs.md`.

## Gate

`just format-docs`, then `just precommit` in the foreground before the commit
that carries this report.
