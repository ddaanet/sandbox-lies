# Sandbox-detector pilot, layer 2 corpus replay

2026-09-03. Measures the shipped shell matchers
(`plans/sandbox-detector-pilot/matchers.sh`) against the full local transcript
corpus, running the real shell code — not a Python re-implementation — as the
arbiter on every candidate. Harness:
`plans/2026-09-03-sandbox-matcher-corpus-eval.py` (`extract` / `aggregate`
subcommands); matcher pass driven by a plain bash loop over the extraction's
survivor files. Reproduction:

```sh
OUT="$TMPDIR/sbx-eval"
python3 plans/2026-09-03-sandbox-matcher-corpus-eval.py extract --outdir "$OUT"
: >"$OUT/verdicts.tsv"
for f in "$OUT"/survivors/*; do
  v=$(bash plans/sandbox-detector-pilot/matchers.sh <"$f")
  [ -n "$v" ] && printf '%s\t%s\n' "$(basename "$f")" "$(printf '%s' "$v" | tr '\n' ' ')" >>"$OUT/verdicts.tsv"
done
python3 plans/2026-09-03-sandbox-matcher-corpus-eval.py aggregate --outdir "$OUT"
```

## 1. Denominators

| | count |
|---|---:|
| JSONL files under `~/.claude/projects` | 1,682 |
| project directories | 35 (with transcripts) |
| Bash `tool_use` blocks | 21,460 |
| Bash `tool_use`/`tool_result` pairs | 21,453 |
| unparsable JSONL lines | 0 |
| **prefilter survivors** (over-broad substring test) | **810** |
| survivors with a matcher verdict | **92** |

The prefilter (`File exists`, `could not lock config file`,
`can only add regular files`, `crw-`, plus each of the 22 masked dotfile names
as a bare substring) is strictly broader than any of the five real matchers: it
passed 810 candidates to `matchers.sh`, of which only 92 (11.4%) actually fired.
Every candidate the shell code could catch was still in front of it — the gap
between 810 and 92 is line-shape and anchoring the shell code applies that a
bare substring test cannot.

The corpus grew since layer 1 (1,678 → 1,682 JSONL; 21,272 → 21,453 pairs) — new
sessions from 2026-09-02 and 2026-09-03, including this pilot's own layer-2
work.

## 2. Hit count per verdict

| verdict | hits | top 3 projects |
|---|---:|---|
| `config-lock` | 4 | prohibitions:3, onekeys:1 |
| `git-lock` | 11 | edify:6, gitlore:2, claude-plugin-dev:1 |
| `phantom-chardev` | 17 | prohibitions:4, edify:3, gitlore:3 |
| `phantom-gitadd` | 3 | edify:1, gitlore:1, micro:1 |
| `phantom-untracked` | 57 | gitlore:25, micro:16, claude-plugin-dev:5 |
| **total** | **92** | |

## 3. Delta against layer 1

Layer 1 (naive Python regexes, unanchored where noted): `git-lock` 11,
`config-lock` 5 (unanchored), `phantom-chardev` 17, `phantom-untracked` 41,
`phantom-gitadd` 4 (unanchored).

| verdict | layer 1 | layer 2 (shell, real matcher) | delta | explanation |
|---|---:|---:|---:|---|
| `config-lock` | 5 | 4 | −1 | The one false positive layer 1 found — this session's own 2026-09-02T21:07 replay of `plans/2026-09-02-sandbox-detector-hits.jsonl` — is a `> `-quoted excerpt inside a JSON-escaped string. `match_config_lock`'s `^error: could not lock config file` anchor requires the line to *start* with `error:`; the quoted line starts with `> ` or `Exit code NNN\n`, so it no longer matches. Net: same 4 true positives, the anchor removed exactly the false positive it was built to remove. **No regression.** |
| `git-lock` | 11 | 11 | 0 | Same count, same composition: 9 true positives (8 distinct live incidents — one, `claudeutils` 2026-01-27, is duplicated verbatim across two entries in the same session JSONL, a transcript artifact, not a matcher issue) and 2 self-reference false positives (§5). The corpus grew, but no new organic `git-lock` incident and no new self-reference source landed for this matcher between layer 1 and now. `match_git_lock` is unanchored by design (the discriminator is the follow-on sentence, not `^`), so the anchoring changes elsewhere don't touch it. **No regression.** |
| `phantom-chardev` | 17 | 17 | 0 | Identical: same 17 true positives, matcher unchanged. **No regression.** |
| `phantom-gitadd` | 4 | 3 | −1 | Composition changed, not just count. Layer 1's 4 hits were 2 true positives (edify, micro — both present here as `000122`/`000713`) and 2 self-reference false positives: a 2026-08-25 `grep` over `justfile_gates.bats` that surfaced a changelog table row quoting the string, and the same 2026-09-02T21:07 hits-jsonl replay session as above. **Both of those are gone here** — not because the underlying transcript text changed, but because `match_phantom_gitadd`'s `^error: .*: can only add regular files` anchor correctly excludes them: the changelog row is a markdown table cell (`| ... can only add regular files | Phantom dotfiles |`), not a line starting with `error:`; the hits-jsonl replay is the same `> `/`Exit code`-prefixed shape as the config-lock case. **A genuinely new** self-reference false positive appeared in their place: this pilot's own 2026-09-02T21:41 session `cat`-ing `plans/sandbox-detector-pilot/fixtures/fire-masks-gitadd-refused.txt` verbatim. Net: 2 old false positives removed by the anchor (as designed, no regression), 1 new false positive introduced by the pilot's own fixture-inspection traffic (§5). |
| `phantom-untracked` | 41 | 57 | +16 | **+1 corpus growth, +15 matcher improvement.** Layer 1's Python required four or more whitespace characters before the name (`\s{4,}`) or a literal `new file:`; `match_phantom_untracked` accepts `[[:space:]]+`. A single tab is what `git status` long format actually emits, so the shell matcher reaches the tab-indented `Untracked files:` block that the Python form skipped. Verified by running both over one extraction of the current corpus: Python 42, shell 57, 15 disagreements, all shell-only. All 15 were opened and every one is a real tab-indented `Untracked files:` section listing masked dotfiles, in `claude-plugin-dev`, `edify`, `gitlore` and `handoff`, from `git status`, `git commit` template echoes and `git add memory && git commit`. **Layer 1's 41 is an undercount, not a baseline.** No regression; the shell matcher is strictly better here. |

No case here is "a tightened matcher losing a hit layer 1 classified as a true
positive." Every true positive layer 1 counted is still caught. The only losses
are false positives the anchors were built to remove, and they were removed
correctly.

## 4. Classification and per-matcher precision

| matcher | hits | true positive | false positive | precision |
|---|---:|---:|---:|---:|
| `match_config_lock` | 4 | 4 | 0 | 100% |
| `match_git_lock` | 11 | 9 | 2 | 81.8% |
| `match_phantom_chardev` | 17 | 17 | 0 | 100% |
| `match_phantom_gitadd` | 3 | 2 | 1 | 66.7% |
| `match_phantom_untracked` | 57 | 56 | 1 | 98.2% |
| **total** | **92** | **88** | **4** | **95.7%** |

All 4 false positives are the self-reference class (§5); there is no false
positive here of the "genuinely unrelated prose" kind layer 1 found in the naive
bare-string forms — the anchors are doing that job. Excerpts:

**`match_config_lock`** — 0 false positives; all 4 hits are the `git config` /
`git remote add` / `just update-plugin-dev` shape: `onekeys`
(`git config fetch.recurseSubmodules no` → `git subtree pull`), `prohibitions`
×3 (`git remote add origin ...`, `just update-plugin-dev v0.5.1`,
`just update-plugin-dev v0.5.2`).

**`match_git_lock`** — 2 false positives, both self-reference (§5, full excerpts
there): the pilot's own 2026-09-02T21:06 hits-jsonl replay (`gitlore`), and a
`shell-gotchas` fault-injection probe
(`bash /tmp/claude/index-handoff-probe.sh`) that deliberately reproduces the
lock error rather than hitting it organically.

**`match_phantom_chardev`** — 0 false positives; all 17 hits are
`crw-rw-rw-  1 nobody nogroup 1, 3 Jul 23 21:28 <name>` lines from real `ls -la`
calls across 8 projects (Emploi, claude-plugin-dev, edify, gitlore, gitmoji,
handoff, onekeys, prohibitions), about half incidental (the agent was not
investigating the sandbox).

**`match_phantom_gitadd`** — 1 false positive: `gitlore`, command
`cd plans/sandbox-detector-pilot/fixtures && ... cat fire-masks-gitadd-refused.txt`,
excerpt
`error: .claude/launch.json: can only add regular files, symbolic links or git-directories`
— the pilot's own fire-fixture, verbatim. The 2 true positives: `edify`
`git add -A`, `micro` `(git add -A && git commit -q -F - <<'MSG' ...)`.

**`match_phantom_untracked`** — 1 false positive: `gitlore`, command
`cd plans/sandbox-detector-pilot/fixtures && ... cat fire-masks-two-names.txt | head -20`,
excerpt `?? .bash_profile` / `?? .bashrc` — the pilot's own fire-fixture,
verbatim (this is the exact fixture the matcher's `>= 2` threshold comment in
`matchers.sh` names). The other 56 hits are all real
`git status`/`git status --porcelain`/`git status --short` output across 6
projects, one of them a verbatim-duplicate transcript entry (`micro`,
2026-07-20T20:25:42, same session, command and timestamp recorded twice).

## 5. Self-reference from this pilot's own artifacts

Layer 1 named self-reference — the store, and now the pilot itself, quoting the
exact diagnostics the matchers look for — as the largest false-positive class,
and warned the pilot's own artifacts would enlarge it. Measured directly:
**4 of the 92 hits (4.3%) are self-reference**, none of them a "nothing fires"
failure — all 4 are prevented by the anchors already, this section is
enumerating what they correctly caught, not what leaked through:

1. **`git-lock`, `000607`**, `gitlore`, 2026-09-02T21:06:34Z. Command:
   `python3 - <<'EOF' ... json.load(open("plans/2026-09-02-sandbox-detector-hits.jsonl")) ...`
   — this session reading back layer 1's own hit-sample file. Excerpt (one line,
   JSON-escaped `\n` printed literally):
   `fatal: Unable to create '/Users/david/code/gitlore/.git/index.lock': File exists.\n\nAnother git process seems to be running in this repository, e.g.\n...`.
   Fires because the JSON-escaped `\n`s keep the diagnostic and its follow-on
   sentence on one printed line — the same shape a live failure produces,
   reconstructed from stored data rather than a real lock.
2. **`git-lock`, `000803`**, `shell-gotchas`, 2026-08-28T07:31:21Z. Command:
   `bash /tmp/claude/index-handoff-probe.sh 2>&1`. Excerpt:
   `add-after-unset: fatal: Unable to create '/tmp/claude-1000/index-handoff-repo/.git/index.lock': File exists.` +
   `add-after-unset: Another git process seems to be running in this repository...`.
   A deliberate fault-injection probe script that reproduces the symptom on
   purpose to test a hook's env-leak handling — real git output, but engineered,
   not an organic sandbox collision. (Layer 1 classified the same instance as
   self-reference for the same reason; carried forward here.)
3. **`phantom-gitadd`, `000612`**, `gitlore`, 2026-09-02T21:41:03Z. Command:
   `cd plans/sandbox-detector-pilot/fixtures && ... cat fire-masks-gitadd-refused.txt`.
   Excerpt:
   `error: .claude/launch.json: can only add regular files, symbolic links or git-directories`.
   This pilot's own layer-2 fixture, read back during fixture review.
4. **`phantom-untracked`, `000611`**, `gitlore`, 2026-09-02T21:39:02Z. Command:
   `cd plans/sandbox-detector-pilot/fixtures && ... cat fire-masks-two-names.txt | head -20`.
   Excerpt: `?? .bash_profile` / `?? .bashrc`. This pilot's own layer-2 fixture,
   read back during fixture review.

All 4 are 2026-09-02 sessions in the `gitlore`/`shell-gotchas` projects,
produced by *this pilot's own* replay, probe, and fixture-inspection work —
confirming the concern the dispatch raised: the corpus now contains the pilot's
own artifacts, and reading them back organically reproduces the matched shapes.
In every one of the 4 cases the anchor (line-start for
`config-lock`/`phantom-gitadd`, the `>= 2` threshold for `phantom-untracked`,
the unanchored-but-two-substring design for `git-lock`) either already
suppresses it (`config-lock`'s analogous case, §3) or the hit is counted here as
a false positive precisely because no further discriminator exists to suppress
it. None of the 4 required inventing a new check to explain — each is either a
`> `/`Exit code`-prefixed quote the existing anchor doesn't reach for a
different matcher (git-lock is unanchored by design) or a direct fixture read
that necessarily reproduces the fixture's designed-to-fire shape.

## 6. Recommendation per matcher

- **`match_config_lock` — ship as is.** 4/4 true positives, 0 false positives,
  and the one self-reference case layer 1 found is now structurally excluded by
  the anchor. No open risk in this corpus.
- **`match_git_lock` — ship as is.** 9/11 (81.8%), unchanged from layer 1. Both
  false positives are self-reference from artifacts this replay itself is part
  of (a fault-injection probe and a hits-jsonl replay), not organic quotation
  risk from prose/docs — the class the memory store's own documentation posed in
  layer 1 is still absent here. No further tightening is indicated; the
  follow-on-sentence discriminator is carrying its weight at the same rate two
  corpus snapshots apart.
- **`match_phantom_chardev` — ship as is.** 17/17 (100%), unchanged. No false
  positives in either snapshot.
- **`match_phantom_gitadd` — ship as is, with the self-reference risk noted as
  inherent rather than fixable.** 2/3 (66.7%) on a 3-hit sample is a thin base
  rate — precision here is one hit away from swinging 33 points either way — but
  every false positive across both layers has been a `> `-quoted or
  fixture-verbatim self-reference, and the anchor already removed the two
  layer-1 instances it could reach. The remaining risk (a fixture or report file
  landing at the start of a line, unquoted) is a property of running this
  detector inside the same store that documents it, not a defect in the regex.
  No matcher change indicated.
- **`match_phantom_untracked` — ship as is.** 56/57 (98.2%), consistent with
  layer 1's 100% before this pilot's own fixture-inspection traffic entered the
  corpus. The design note in `matchers.sh` about `fire-masks-two-names`
  anticipated exactly this shape firing on a direct read: the false positive
  here is that fixture being `cat`ed, not a new failure mode.

## 7. Re-measurement, 2026-09-03

Run again after the counts above, against a single extraction (824 prefilter
survivors) with the shell matchers as arbiter:

| verdict | count | dated 2026-09-02 or later |
|---|---:|---|
| `config-lock` | 4 | none |
| `phantom-chardev` | 17 | none |
| `phantom-gitadd` | 3 | 1 (2026-09-02) |
| `phantom-untracked` | 57 | 3 (2026-09-02) |
| `git-lock` | 14 | 4 (1 on 09-02, **3 on 09-03**) |

`git-lock` moved 11 -> 14 in under a day, and all three additions are this
pilot's own traffic: a session reading this report and the cross-check output it
prompted. Nothing organic changed.

**This report is itself a `git-lock` false positive.** Running the matchers over
`plans/2026-09-03-sandbox-matcher-corpus-eval.md` returns `git-lock`, because §5
quotes the diagnostic with literal `\n` escapes, which puts the error and its
follow-on clause on one physical line — the exact shape a live failure produces.
The other three pilot documents
(`2026-09-02-sandbox-detector-replay-results.md`, the pilot `README.md`, the
brief) fire nothing, because `just format-docs` wraps their prose and splits the
clause.

That is the layer-1 design constraint arriving as a measurement rather than a
prediction: **a document about these symptoms must not spell the diagnostics out
on one line.** It binds the hook's injected text first, and this file second.
The escape is to quote the error and the follow-on in separate fragments, or to
let the formatter wrap them.

**Self-pollution rate.** Four hits across the corpus come from commands touching
this pilot's own artifacts — a `python3` replay of the layer-1 hits file, two
`cat`s of `fixtures/fire-masks-*.txt`, and a `shell-gotchas` fault-injection
probe — plus the three from 2026-09-03 above. The corpus is not a fixed
population: each session that studies these detectors adds hits to them, and the
additions land on `git-lock` and `phantom-gitadd`, the two thinnest matchers.
Any future precision figure needs its measurement date and a note on how much
pilot traffic the corpus had absorbed by then.

**Cross-cutting**: every false positive in this replay (4/4) is self-reference
to this pilot's own artifacts, and every one of them is already structurally
distinguishable from a live symptom (it is either a `cat`/`head` of a path under
`plans/sandbox-detector-pilot/fixtures/`, a fault-injection probe script, or a
Python replay of a named `*-hits.jsonl` file) — reachable if a future hook
wanted to suppress it, but not attempted here since it is out of scope for
matcher content per the dispatch's constraints. No matcher requires a shape
change on this evidence; the one number worth re-measuring after the pilot's own
transcripts stop growing is `match_phantom_gitadd`'s precision, since its
true-positive base rate (2) is too small for this run to rule out drift either
way.
