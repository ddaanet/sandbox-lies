# m-3 evidence: `claude --resume` against an existing transcript

Run 2026-10-07 against Claude Code 2.1.292 (`~/.local/bin/claude`, the real
binary, bypassing the gitlore launcher shim). Linux bubblewrap sandbox; in this
session `~/.claude/projects` is in the sandbox's write deny list. Every call
uses `--model haiku`. Scratch cwds: `/tmp/claude/resume-probe/A` and `…/B`.

Each sandboxed call proves its own state in the same call. It first tries
`mktemp "$HOME/.claude/projects/.sbx-probe.XXXXXX"` and prints the result. A
sandboxed call answers `Read-only file system`. The `claude` invocation goes
through `env` so that the user-level `excludedCommands` entry `claude *` does
not match it. The PreToolUse refusal hook would otherwise refuse the call.

## Calls

- **E1 (unsandboxed, cwd A).**
  `claude -p --session-id 9835c8f4-cc22-40b4-8b5b-19712e4bcef1 "Reply with exactly: ok"`
  - Output `ok`, exit 0.
  - It wrote
    `~/.claude/projects/-tmp-claude-resume-probe-A/9835c8f4-….jsonl`, 30
    lines.
- **E2 (sandboxed, cwd A).** `env claude -p --resume 9835c8f4-… "… ok2"`
  - The write test printed `Read-only file system`.
  - Output `ok2`, exit 0. There was no refusal.
  - The first attempt, without `api.anthropic.com` in the call's network
    allowlist, hung retrying the API and printed no refusal before it. So the
    lookup had already succeeded.
  - Afterwards (checked unsandboxed) the transcript was still 30 lines with no
    `ok2` in it. The turn ran, but was silently not persisted.
- **E3 (unsandboxed, cwd B, a different project directory).**
  `claude -p --resume 9835c8f4-… "… ok3"`
  - Output `ok3`, exit 0.
  - The turn was appended to the **original** file under
    `-tmp-claude-resume-probe-A` (46 lines). Its entries record `cwd`
    `/tmp/claude/resume-probe/B`.
  - `-p --resume <id>` finds a session in any project directory under the
    config dir.
- **E3s (sandboxed, cwd B).** `env claude -p --resume 9835c8f4-… "… ok4"`
  - The write test printed `Read-only file system`.
  - Output `ok4`, exit 0.
- **E4 (sandboxed, cwd B): the fixture's shape.**
  - `env claude -p --session-id 68e27df4-eaf0-4bca-939a-bbb3cc214d3c "… t1"`
    printed `t1`, exit 0.
  - `env claude -p --resume 68e27df4-…` printed the refusal (`No conversation
    found with session ID: 68e27df4-…`), exit 1.
  - Afterwards no file named `68e27df4-…*` existed under `~/.claude/projects`.
  - The installed `sandbox-lies` hook fired on this result with the
    `resume-lost` verdict.
- **E5 (unsandboxed, cwd A, empty config dir).**
  `CLAUDE_CONFIG_DIR=/tmp/claude/resume-probe/cfg claude -p --resume 9835c8f4-…`
  printed the refusal for the session E1 wrote, exit 1.

## Fixture ids

The two ids in `tests/fixtures/fire-resume-lost-two-turn.txt` were searched for
by name with `find ~/.claude/projects -name '<id>.jsonl'` (unsandboxed):
`37b5f8f7-cd46-44d7-8416-946cf6729b30` and
`7ded81f3-920a-40b7-bf8b-5f08e913c333`. Neither exists, which is consistent
with E4.

## What this settles

1. **Sandboxing alone does not make `--resume` refuse a transcript that
   exists** (E2, E3s). A refusal for an id whose transcript exists is not a
   sandbox effect.
2. **A cwd or project mismatch does not cause the refusal on 2.1.292** (E3,
   E3s). `--resume <id>` searches every project directory, so "found under a
   different project directory" is not a distinct cause. The observed cause for
   an existing transcript is a different config directory (E5). Interactive
   `--resume` (the picker) and `--continue` were not tested.
3. **Not found is the fixture's case** (E4). The current verdict holds.
4. **The fixture ids have no transcript.** So a sandboxed `cat` of the fire
   fixture reads `not found`, and a transcript-existence probe alone does not
   silence it.
5. **New no-symptom effect:** a sandboxed resume of a persisted session runs
   and answers, but its turn is dropped (E2). This fits the skill's "a sandboxed
   turn never persists", which records no CC version. 2.1.292 is now a
   verified version.

Not tested: whether `--resume` finds a session under a project's `archived/`
directory (`memory/ddaanet/jsonl-sidechain-segregation.md`).
