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

```sh
git clone https://github.com/ddaanet/sandbox-lies.git
claude --plugin-dir "$PWD/sandbox-lies"
```

Load it with `--plugin-dir` for now, from a plain clone: the plugin does not
need the `memory` submodule. A marketplace install clones submodules too, and
that submodule's url is a local placeholder such a clone cannot resolve, so the
install aborts until the url is fixed.

The hooks load at session start: restart Claude Code after installing or
updating the plugin.

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
- `resume-lost` — a `claude --resume` whose transcript the sandbox never let
  persist.
- `seccomp-init` — the sandbox failing to start before the command ran.

The matchers, probes, verdict text, flag policies and the corpus precision each
detector was measured at are in
[docs/references/detectors.md](docs/references/detectors.md).

## The skill

What the sandbox does without any symptom in the output cannot be annotated:
which calls `excludedCommands` really unsandboxes, what each escape costs, why
`$TMPDIR` does not survive a call, how masks break a cleanliness gate. The
`sandbox-lies:sandbox-lies` skill carries that knowledge and triggers while an
agent is writing an exclusion, a recipe, a cleanliness gate or a directive with
a scratch path, before any output exists.

## Design

[docs/design.md](docs/design.md) holds the requirements, decisions and
limitations; [docs/references/hook.md](docs/references/hook.md) describes the
hook at run time.

## License

MIT — see [LICENSE](LICENSE).
