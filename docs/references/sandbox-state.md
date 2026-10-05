# Sandbox state from the payload

The argument for `docs/design.md` D-8: how a detector learns whether the call it
annotates ran sandboxed, and the case it cannot tell. Each detector's flag
policy is in [detectors.md](detectors.md),
[lock-detectors.md](lock-detectors.md) and [readonly-path.md](readonly-path.md).

**D-8 — Sandbox state from the payload.** `tool_input.dangerouslyDisableSandbox`
is on stdin. A lock error on an unsandboxed call is a real lock or the hook-env
leak, not a mask; a `No conversation found` on an unsandboxed call is not the
transcript-persistence failure. Detectors read the flag and either change
wording or stay silent. Accepted tradeoff: a call unsandboxed by
`excludedCommands`, one whose every command an entry covers, carries no flag and
nothing in the payload records it, so that case is indistinguishable from a
sandboxed one; the probes cover the verdicts where it matters (a lock that
exists outside the sandbox is reported as such whichever way the call ran).
