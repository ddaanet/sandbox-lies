# Item 5.1 (second dispatch) — skill exclusion rule per revised D1

Status: done. Five skill files edited, `just format-docs` run, `just precommit`
exit 0. Evidence for the revised D1 is `item-5-1.md` probes 2–4 (left as is).

## Changes per file

### `skills/sandbox-lies/SKILL.md`

- §Tell a sandboxed call from an unsandboxed one, first bullet: flipped from
  "treat every call as sandboxed" to "unsandboxed only with the flag or an entry
  covering every command"; names the forfeiting shapes and git's absolute,
  `~`-led or `..`-bearing paths; cites the CC 2.1.289 bare-`git status` versus
  `true && git status` observation; the re-probe is that bare covered
  `git status` from the project root; earlier "not honoured" probes called
  confounded.
- §Writing an `excludedCommands` entry: the "where honoured" opener and the
  "one matching segment unsandboxes the whole call" claim replaced by CC's
  every-command rule; `git *` syntax with `git:*` as legacy; the decoy bullet
  dropped; new bullets for the documented forfeiting shapes and for git's `-C`
  and path-argument exception; pointer line extended to the node's new content.
- §Leaving the sandbox for one call: standing escape scoped to fully covered
  calls (no "where honoured"); strict mode named as
  `sandbox.allowUnsandboxedCommands: false`, Strict sandbox mode in `/sandbox`;
  classifier bullet now says "unless the read-only validator clears it" and
  carries the one batching rule ("even where batching would save a call"),
  matching the node.
- §Keeping the working directory at the project root: persisted `cd` qualified
  to the main session, a subagent's cwd resetting per call; order re-ranked to
  absolute paths / `git -C`, then subshell (its `cd` cannot persist), then a
  trailing `cd <root>`; the subshell's "misses an honoured exclusion" reason
  removed; closing paragraph says `git -C`, a `cd` and a subshell each keep the
  call sandboxed under any entry, and with the flag each costs a classifier call.
- `description`: unchanged.

### `skills/sandbox-lies/references/excluded-commands.md`

- Title: "whole-call semantics" → "an entry must cover every command in the
  call".
- Opening: the D1 rule, cited to the settings reference.
- New §Observed on CC 2.1.289: probes 2–4 of `item-5-1.md` plus probe 1
  (`git config --file /tmp/…` sandboxed); the bare-`git status` re-probe and its
  one-way reading.
- New §Earlier probes that read "not honoured": the 2.281 `touch` probe (its
  uncovered `touch` keeps it sandboxed either way; the injected-config note
  kept), the 2.288 and 2.289 `git init -q /tmp/…` probes, all recorded as
  confounded; whether `git:*` was honoured on 2.288 stated as not settled.
- §The baseline: entries now `git *` (`git:*` through 2.288); "every top-level
  segment runs outside" replaced by "a call made of those commands alone".
- §Matching: a lead sentence marks the 2.233 decompile as predating the rule;
  pattern bullet in `foo bar *` syntax, `git -C` stays sandboxed under any
  entry; new bullet listing the documented forfeiting shapes (sudo/eval/xargs
  head, cd/pushd/popd, substitution, subshell, if/for, non-duplication
  redirection, variable command name, git path rule, `git -C`) plus the
  observed `git config --file`; new bullet for the separately reported
  shapes (hedged, below); comparison bullet no longer puts redirections and
  `VAR=` outside the compared span — `VAR=` stripping placed at 2.233 only;
  "one matching segment unsandboxes the entire call" and the decoy removed,
  leaving "Nothing records the outcome"; "Settings reload live" kept, marked
  observed before the 2.289 probes with the version not recorded.
- §Approval: one sentence added that read-only commands wait for server-side
  review where the session has it (link to `escapes-and-costs.md`); the closing
  sentence notes the three cwd shapes forfeit an exclusion as well.
- §Why `git *` rather than a rewriting hook (was `git:*`): the residue paragraph
  rewritten under D1 — the exclusion frees only a fully covered call, lists the
  git shapes that stay sandboxed, and says both the old subshell wrap and the
  current trailing `cd <root>` of `cwd-safety` keep the call sandboxed.

### `skills/sandbox-lies/references/escapes-and-costs.md`

- Opening: "where it is honoured at all, which CC 2.1.281 does not do" replaced
  by "for a call whose every command an entry covers".
- §Strict mode: names `sandbox.allowUnsandboxedCommands: false` and the
  Overrides-tab label; the "exclusions still apply where honoured" clause
  replaced by the documented "sandboxed unless they match an entry"; "check the
  key".
- §The read-only-inspection default: `git:*` baseline → `git *`, which frees
  only fully covered calls; symptom list adds a git beside an uncovered command
  or after a `cd`.
- §Cost (classifier): the three exceptions the sandboxing doc lists (plan mode,
  per-command allowed domains, server-side review of sandboxed commands) and the
  permission-modes decision order for read-only commands; the 2026-08-16
  observation marked as not recording how each call left the sandbox; one
  batching rule (own call, even where batching saves a call); "no generation"
  and the `git -C … ; git -C …` batching example dropped.
- Recipe line: `git:*` → `git *`, with `just release *` named as the entry that
  covers a recipe.

### `skills/sandbox-lies/references/masks-and-gates.md`

- cwd paragraph: main-session qualifier and subagent reset added; order
  re-ranked as in the hub; exclusion wording per D1.
- `` !`cmd` `` paragraphs: the match frees an expansion only when it covers
  every command; "where the exclusion is honoured the listing is real" replaced
  by: even a fully covered expansion can list a concurrent sibling block's
  masks, so never act on the injected listing.

### `skills/sandbox-lies/references/recipes-and-claude.md`

- Opening paragraph and the unsandboxed-flow list: `claude:*` → `claude *`,
  under the every-command rule.

## Line counts (after `just format-docs`)

- `SKILL.md`: 185 (cap 200)
- `references/excluded-commands.md`: 160
- `references/escapes-and-costs.md`: 87
- `references/masks-and-gates.md`: 66
- `references/recipes-and-claude.md`: 68

## Runbook bullets not satisfied

None.

Outside the named sections and left unchanged: the hub's §Writing a recipe line
"the top-level segment is the recipe runner" is still true under D1 and was not
in the item's section list.

## Hedged statements

- `excluded-commands.md` §Matching, "Seen beyond the documented list": `2>&1`, a
  glob argument, an unquoted `$HOME`, a `VAR=` prefix outside a short allowlist,
  and the value-taking git options before the subcommand — stated as seen on CC
  2.1.289 in a separate session and not re-probed. No text promises that a
  descriptor duplication keeps an exclusion: the hub gives the documented rule
  only, and the node pairs it with the `2>&1` observation.
- Whether the legacy `git:*` form was honoured on CC 2.1.288: stated as not
  settled.
- The 2.1.233 decompile detail: stated as predating the documented rule, which
  governs where they differ; it is not asserted that 2.1.233 behaved otherwise.
- "Settings reload live": observed before the 2.1.289 probes, version not
  recorded.
- The 2026-08-16 classifier refusals: how each call left the sandbox is stated
  as not recorded.
- The git path-argument exception is given as the docs' list "among others",
  plus the observed `git config --file`; which other git shapes stay sandboxed
  is not claimed.
