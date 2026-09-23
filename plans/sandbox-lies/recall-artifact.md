# Recall Artifact: sandbox-lies

Read each file listed below — do not rely on inline summaries.

## Entries

memory/ddaanet/sandbox-effects.md — the source: twelve symptom-keyed sections this plugin translates, then retires
memory/ddaanet/git-hook-env-leak.md — the other bug that shares the index.lock error string; the git-lock verdict must not absorb it
memory/ddaanet/git-subtree-ensure-clean-unscoped.md — why phantom `??` lines break subtree pulls; a consumer of the phantom verdict
memory/ddaanet/cc-grep-shell-function.md — `grep` in the Bash tool is ugrep; matcher probes must use `command grep` or a script

## Skills to load before executing

plugin-craft:hook-authoring — channels, deny/directive split, additionalContext spill, hooks run outside the sandbox
craft:directive-writing — verdict text: acts only, withhold identifiers, curt systemMessage
plugin-dev:hook-development — hooks.json plugin format, CLAUDE_PLUGIN_ROOT, stdin fields
shell-scripting:shell-gotchas — bash 3.2 and BSD grep/sed/mktemp contract for every script here
craft:test-discipline — fault-injection standard the suite inherits from the pilot

## Implementation entries (added by /runbook)

memory/ddaanet/jsonl-reader-type-guard.md — `select(type == "object")` after the parse; a scalar payload otherwise kills the hook on every call (Item 3.1 malformed-payload slice)
memory/ddaanet/no-stderr-suppression.md — no blanket `2>/dev/null` in the hook or probes; the probes' `stat`/`lsof`/`fuser` failures are guarded, not silenced
memory/ddaanet/markdown-formatter-choice.md — rumdl `fmt --check -q --no-cache` ahead of the line-limit check; `/*.md` for root files (Item 1.2)
memory/ddaanet/uv-direnv-venv.md — rumdl comes from a `uv sync` venv activated by `.envrc`, never `uvx` under Claude (Item 1.2)
memory/ddaanet/extracting-memory-into-skills.md — the skill ships: grep it for FR/NFR/D ids and foreign paths before commit (Item 7.1)
memory/ddaanet/plugin-recurse-clone.md — why dogfooding goes through the shim and why `--plugin-dir` cannot catch the `.gitmodules` url (Item 8.1)

## Reference implementations

/Users/david/code/edify/scripts/check_line_limits.sh — port source for scripts/check-line-limits.sh (drop the allowlist)
/Users/david/code/edify/.rumdl.toml — port source for .rumdl.toml (scope: skills/, docs/, root `/*.md`)
