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
