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
- **What is left is a lock gone by probe time.** The probe reads a missing lock
  as `mask` when the flag is absent and `gone` when it is true, so a covered
  `git` whose lock git had already cleaned reads `mask`. Its act, a re-run, is
  harmless: the lock is gone either way
  ([lock-detectors.md](lock-detectors.md)).
