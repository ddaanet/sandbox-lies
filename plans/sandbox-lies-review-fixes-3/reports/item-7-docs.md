# Items 7.1 to 7.7 — docs report

Every item ran `just format-docs` where it touched markdown, then
`just precommit` in the foreground (unsandboxed). Each exit status was 0 and
each recap line read: precommit passed: plugin.json, hooks.json, shellcheck,
bash -n, rumdl, line limits, links, python compile, tests (411 passed, 0
failed). No `# MUT` text anywhere; nothing under `memory/` touched.

| Item | File | Lines after | Precommit |
| --- | --- | --- | --- |
| 7.1 | docs/design.md | 394 (was 399) | exit 0 |
| 7.2 | docs/references/readonly-path.md | 221 | exit 0 |
| 7.3 | docs/references/lock-detectors.md | 176 | exit 0 |
| 7.4 | docs/references/detectors.md | 353 | exit 0 |
| 7.5 | docs/references/hook.md | 127 | exit 0 |
| 7.6 | docs/changelog.md | 354 | exit 0 |
| 7.7 | lib/probes.sh 349, lib/probes-readonly.sh 174, lib/verdicts.sh 316 | comments only | exit 0 |

## 7.1 docs/design.md

- Now: the `nopath` sentence is gone from Next.
- FR-4: clause "(a `path=` value is printed in `printf %q` form)".
- FR-10: rewritten shorter. Every section the plugin carries is retired; the
  memory file keeps the phantom-dotfile leak and the zellij section (checked by
  reading `memory/ddaanet/sandbox-effects.md`: its opening paragraph says it
  keeps those two). Deletion, index-line, inbound-link, `docs.bats` and
  `Item 8.2` clauses removed. Status Done. The file shrank by 5 lines.
- Status: the `Partial` sentence is dropped. The legend still lists `Partial`
  as a status word, which is a definition, not a claim.
- "Verified against": design.md holds no such text; the only dated
  verification is "Dogfooded 2026-09-27 on CC 2.1.283", a grounded claim about
  a run that was not repeated, so I left it. Nothing was bumped.

## 7.2 readonly-path.md

Probe paragraph: `path=` in `%q` form, C-locale pinned. The partial-checkout
residual became the resolution rule (verified against `probe_readonly_path`:
matching line alone decides; base is the nearest `.git` ancestor, file or
directory; none means cwd; other producers join onto cwd); `git -C` stays a
residual. New paragraph describing the five `nopath` shapes (none quoted),
why a path would not change the act, and the leaked-phantom-mask removal that
gets the futile re-run act. Table: `nopath` means no path extracted. Verdicts:
display rule (raw unless a control byte, then wire form; malformed value reads
as "The path"; never evaluated).

## 7.3 lock-detectors.md

The newline exception is replaced by the `%q` contract; an empty path prints
no `path=` line.

## 7.4 detectors.md

The phantom Verdict text was already the new wording (:83), and the
phantom-untracked Verdict inherits it by reference: no edit. Translation map:
intro no longer promises a deletion or names Item 8.2; the zellij row and a
new leak row say the section stays in memory.

## 7.5 hook.md

"names the project root, the usual case" replaced by "names no location, so it
holds under any working directory".

## 7.6 changelog.md

One entry, dated 2026-10-11: code changes (`%q` and decoder, resolution rule,
phantom wording, tokenizer with measured 31.7 s to 3.5 s on 3.2.0), test side
(locale and mtime helpers, line caps, new Python suites), Python tool fixes,
the reviewer-added guards (non-dict JSONL line in both tools, null text item),
and the closed items H and I with reasons.

## 7.7 comments

`lib/probes.sh` header (path= is `%q` form, no newline exception) and
`_probe_lock_at` comment; `lib/probes-readonly.sh` header and
`probe_readonly_path` contract comment; `lib/verdicts.sh`
`verdict_readonly_path` comment ("never eval; `%b` decodes an argument, never
a format"). The diff touches comment lines only (checked by filtering the diff
for non-comment lines: none).
