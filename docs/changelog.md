# Changelog

Design-significant changes only; git history is the full record.

## 2026-09-22 — design written

Repository initialised, release toolkit vendored, `ddaanet` memory tier mounted,
`docs/design.md` written from `BRIEF.md`, the pilot brief and the
`sandbox-effects` memory file. The pilot's decision rule — three detectors must
hold — resolved as two held, one dead for a reason specific to its shape (D-1);
this repository is the answer. Eleven detectors catalogued in
`references/detectors.md`, five measured, six candidates; the `ps` case needs
the command word and goes to the skill; the symptom-less knowledge assigned to
one skill (D-9); memory retirement sequenced after dogfooding (D-11).

## 2026-09-22 — outline review: failures fire a different event

The outline review found, and a read of the CC 2.1.280 bundle confirmed, that a
Bash call exiting non-zero dispatches `PostToolUseFailure` with the result text
in an `error` string, and `PostToolUse` only on success. The design had named
one event; it now registers one script on both (D-13). The same review added the
probe output contract (FR-4), the per-detector flag policy (FR-5), the verdict
composition rule (FR-6), the `unknown` lock outcome (D-14), the second
self-reference residual (D-10, FR-11) and the translation map in
`references/detectors.md`.

## 2026-09-22 — decisions taken at outline validation

Skill named `sandbox-lies` (D-9). No verdict instructs a removal (D-7).
Retirement per section, immediate, in the commit that lands each translation
(D-11 reversed from wait-for-dogfood). Candidate ship rule by false-positive
classification, not a precision floor (D-15). `tmp-full` dropped as not a
sandbox effect. Dogfood through a `.bin/claude` shim (D-16). Line cap and link
check added as NFR-5.

## 2026-09-23 — live payloads: one merged stream

Recording both events from a nested `claude -p` on CC 2.1.280 showed the Bash
tool merging stderr into stdout in emission order, sandboxed and unsandboxed:
`tool_response.stderr` arrives empty, and `error` is the exit-code line followed
by that merged output. The bundle reading behind D-13 had described separate
streams and an exit-line, stderr, stdout order; D-13 now states the recorded
shape. Its reopen-if did not fire — both payloads are byte-identical to the tool
result the model sees, which is the text the fixtures were cut from. The flag is
absent from `tool_input` when unset, and a sandboxed write refused by the
allowlist carried no sandbox-violation annotation (L-5).

## 2026-09-24 — the hook ships with the phantom verdicts

Item 2.3 landed `hooks/annotate.sh` on both events with the three `phantom-*`
verdicts, and retired the memory file's phantom-dotfile masks, who-sees-them,
`git add -A` and visible-unsandboxed paragraphs and its `/tmp reads full`
section; the zero-byte mask shape has no verdict and goes to the skill. Wall
time of `bash hooks/annotate.sh`, mean of 30 runs, `PostToolUse` payloads built
as `tests/helpers/hook.bash` builds them, on a 2-core Debian 13 box (Linux 6.12,
GNU bash 5.2.37, load average ~2.1) inside the command sandbox: 52 ms on
`quiet-clean-status`, 64 ms on `fire-masks-porcelain` (a verdict without a
probe, against NFR-3's 100 ms bound), 54 ms on a quiet 25,000-character
`tool_response.stdout`. A first pass gave 61, 61 and 52 ms, with one
`fire-masks-porcelain` run at 169 ms: the bound holds for the mean, not for
every run on a loaded box. Nothing gates these figures.
