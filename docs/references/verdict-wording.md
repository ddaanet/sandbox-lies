# Verdict wording

The argument behind `docs/design.md` D-7; read it before writing or changing
verdict text.

## D-7 — Verdict wording follows the directive rules

`additionalContext` is a directive channel, so imperative acts are correct
there: "re-run the same command unsandboxed", "stage explicit paths". Mechanism,
rationale and prohibitions naming things the agent could not otherwise reach are
cut. Where an omission would read as failure, one clause of reassurance stays
("the repository is healthy"). No verdict instructs removing a lock or a file,
even conditionally: agents remove orphan locks eagerly enough, and a verdict
that reports the lock's state is the whole of what they lack. `systemMessage` is
one lowercase clause with an em-dash, no instruction. Neither channel spells a
diagnostic and its follow-on on one line — the corpus eval report fires
`git-lock` on itself for exactly that.
