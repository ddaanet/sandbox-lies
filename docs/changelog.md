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
