# Verdict wording

The argument behind `docs/design.md` D-7; read it before writing or changing
verdict text.

## D-7 — Verdict wording follows the directive rules

`additionalContext` is a directive channel, so imperative acts are correct
there: "re-run the same command unsandboxed", "stage explicit paths". Mechanism,
rationale and prohibitions naming things the agent could not otherwise reach are
cut. Where an omission would read as failure, one clause of reassurance stays
("git cleaned it after the failure"). No verdict tells the agent to remove a
lock or a file, even conditionally: agents remove orphan locks eagerly enough,
and a verdict that reports the lock's state is the whole of what they lack. The
one exception keeps that true: a verdict may hand the user an `rm` of a lock
that refused the re-run, telling the agent to leave the lock. `config-lock`'s
`mask` verdict is the only one that does, for the user to run once they have
checked no sandboxed command is running ([lock-detectors.md](lock-detectors.md),
config-lock). `systemMessage` is one lowercase clause with an em-dash, no
instruction. Neither channel spells a diagnostic and its follow-on on one line —
the corpus eval report fires `git-lock` on itself for exactly that.
