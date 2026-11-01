# Rejected alternatives

The arguments for the rejected alternatives `docs/design.md` names: each option
considered for this plugin and not taken, and why. The hub keeps every name with
a one-line conclusion, under D-9 where an alternative protects that decision and
in its §Rejected alternatives list otherwise.

**A `PreToolUse` matcher that unsandboxes the call.** The retired
`unsandbox-git-status` plugin pre-approved anything chained beside the
`git status` it rewrote. A `git *` exclusion needs no hook and approves nothing,
but frees only a call whose every command it covers; git with `-C` or an
absolute, `~`-led or `..`-bearing path argument stays sandboxed under it.

**Prompt-based hooks.** Non-deterministic, a model call per Bash result, and the
discriminators are exact strings a regex settles for free.

**A home in `craft` or `prohibitions`.** `craft` is the wrong trigger axis
(D-9). Every `prohibitions` item forbids an action the agent is about to take;
an annotator enriches a result instead.

**Splitting `sandbox-effects` into hub and siblings first.** The content
survives either route; the file layout would be thrown away. It remains the
fallback if dogfooding shows the hook not firing.

**Filtering phantom names out of a cleanliness gate.** The mask set is
version-dependent and a filter hides real untracked files with those names. The
gate runs unsandboxed or scopes to tracked paths; that is skill content, not a
hook.

**`PostToolBatch`.** A batch carries several results; the verdict must attach to
the one call it explains.

**A `tmp-full` detector.** The one observed event — `/tmp` at 100% with `du`
accounting for a fraction — was read as other sandboxes pinning the tmpfs, but
it cannot be reproduced on demand, and a small tmpfs fills on its own often
enough to explain it. Not a sandbox lie; the memory section retires
untranslated.

**`sandbox-gotchas`, `sandbox-effects` as names.** The first promises a
catalogue, which is what moving this knowledge into hooks stops it being; the
second is the memory file's name and both would exist during the transition.

**D-9 — The skill lives here and carries the plugin's name.** `craft`'s premise
is facts that fire on a design moment with no token to match; the escapes
knowledge has a moment (writing an exclusion, a recipe, a gate) that is
sandbox-specific, and this repository is the one place that knowledge is
maintained. Sending it to `craft` would split the retirement across two repos,
one of which is read-only from here. As the plugin's only skill it is
`sandbox-lies:sandbox-lies`; a second name would add nothing.

*Rejected:* a home in `craft` (the wrong trigger axis) or `prohibitions` (it
forbids actions; this enriches results); `sandbox-gotchas` or `sandbox-effects`
as names — a catalogue, and the memory file's own name.
