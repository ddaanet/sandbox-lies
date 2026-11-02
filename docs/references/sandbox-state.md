# Sandbox state from the payload

The argument for `docs/design.md` D-8: how a detector learns whether the call it
annotates ran sandboxed, and the case it cannot tell. Each detector's flag
policy is in [detectors.md](detectors.md),
[lock-detectors.md](lock-detectors.md) and [readonly-path.md](readonly-path.md).

**D-8 — Sandbox state from the payload.** `tool_input.dangerouslyDisableSandbox`
is on stdin. A lock error on an unsandboxed call is a real lock or the hook-env
leak, not a mask. Detectors read the flag and either change wording or stay
silent.

Accepted tradeoff: a call unsandboxed by `excludedCommands`, one whose every
command an entry covers, carries no flag and nothing in the payload records it,
so that case is indistinguishable from a sandboxed one. Exclusions are honoured
for a fully covered call, so this case is live, and the skill's documented
baseline excludes `claude` as well as `git`. What it costs, per detector:

- **`resume-lost` does not depend on the flag.** Its probe tests whether a
  transcript exists for each session id the refusal names, and the verdict
  follows that fact under either flag
  ([detectors.md](detectors.md#resume-lost)). A covered `claude --resume`
  refused although its transcript exists therefore reads `found`, not a
  transcript the sandbox lost.
- **A lock that exists outside the sandbox** is reported as such whichever way
  the call ran: `held`, `orphan` and `unknown` come from the probe, not the
  flag.
- **`tmpdir-unset` is silent.** It fires only when the flag is true, and a
  covered call carries none, so an empty `$TMPDIR` in one draws no verdict.
- **The lock verdicts word their re-run for a sandboxed call.** With the flag
  absent, a lock that exists outside the sandbox draws the clause telling the
  agent to add `dangerouslyDisableSandbox: true`, to a call that already ran
  unsandboxed.
- **A flagged `--resume` of an id that never existed** reads `lost`: the flag
  policy that kept the detector silent on it is gone
  ([detectors.md](detectors.md#resume-lost), Corpus).
- **What is left is a lock gone by probe time.** The probe reads a missing lock
  as `gone` under either flag, and the flag words the verdict. With the flag
  absent the paragraph names both causes, a sandbox mask or a lock its holder
  has since released, because nothing in the payload records an exclusion and a
  released lock leaves nothing at the path. Its act, a retry with
  `dangerouslyDisableSandbox: true`, is harmless on a covered call
  ([lock-detectors.md](lock-detectors.md)).
