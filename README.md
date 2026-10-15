# sandbox-lies

A Claude Code plugin for the results the command sandbox distorts. Some Bash
output under the sandbox is confidently and specifically wrong, and nothing in
it marks it as an artefact: a commit reports a lock held by a process that does
not exist, `git status` lists dotfiles that are really `/dev/null` masks, a
merge dies on a healthy repository. An agent that trusts that output deletes a
lock that is not stale, commits phantom files, or "fixes" a hook that is not
broken.

The plugin watches every Bash result. When one matches a known sandbox
distortion, it annotates that result: a short paragraph for the agent, carried
as hook context, saying what the output really means and what to do instead, and
a one-line note for the human. Where the answer depends on the machine's state,
the hook first checks outside the sandbox — whether the lock exists and who
holds it, whether the refused path is writable there. The hook never blocks,
rewrites or unsandboxes anything, and a result that matches nothing passes
through with no output.

## Install

```
/plugin marketplace add ddaanet/claude-plugins
/plugin install sandbox-lies@ddaanet
```

The hook needs `jq` on `PATH`: without it, it stays silent and every Bash result
goes unannotated. A `SessionStart` check then says so at each session start, to
you and to the agent, and stays silent once `jq` is found.

The hooks load at session start: restart Claude Code after installing or
updating the plugin.

The symptoms, discriminators and corpus figures were recorded on Linux, where
the command sandbox is bubblewrap. The scripts are written to run under macOS's
bash 3.2 and BSD tools as well, and the test suite passes on macOS under Apple's
bash 3.2.57, but the macOS sandbox's messages and masks have not been verified.

## Detectors

Each detector reads the tool result's text, never the command, and fires only on
the tool's own diagnostic shape. Nine ship:

- `git-lock` and `config-lock` — git's lock refusal; the hook checks the lock
  outside the sandbox and reports whether it is a sandbox mask, gone, held, or
  present with no holder.
- `phantom-chardev`, `phantom-untracked` and `phantom-gitadd` — sandbox masks
  over dotfiles shown in a listing, in `git status`, or refused by `git add`.
- `readonly-path` — a write refused as read-only; the hook checks whether the
  path is writable outside the sandbox.
- `tmpdir-unset` — an unsandboxed call whose `$TMPDIR` path collapsed to `/`.
- `resume-lost` — `claude`'s resume refusal; the hook checks outside the sandbox
  whether the transcript exists and reports one the sandbox never let persist,
  or one that exists, so the sandbox is not the cause.
- `seccomp-init` — the sandbox failing to start before the command ran.

The matchers, probes, verdict text, flag policies and the corpus precision each
detector was measured at are in
[docs/references/detectors.md](docs/references/detectors.md).

## The skill

What the sandbox does without any symptom in the output cannot be annotated:
that an `excludedCommands` entry unsandboxes only a call whose every command it
covers, what each escape costs, why `$TMPDIR` does not survive a call, how masks
break a cleanliness gate. The `sandbox-lies:sandbox-lies` skill carries that
knowledge and triggers while an agent is writing an exclusion, a recipe, a
cleanliness gate or a directive with a scratch path, before any output exists.

## Design

[docs/design.md](docs/design.md) holds the requirements, decisions and
limitations; [docs/references/hook.md](docs/references/hook.md) describes the
hook at run time.

## License

MIT — see [LICENSE](LICENSE).
