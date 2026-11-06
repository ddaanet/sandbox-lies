#!/usr/bin/env bash
# SessionStart hook (hooks/hooks.json; D-12, the plugin repository's docs/references/hook.md). Speaks
# only when `jq` is not on PATH, because hooks/annotate.sh needs it and
# otherwise degrades with no sign. The JSON is printed from fixed text, so the
# notice needs no `jq`.
# Stdin is ignored, nothing is written, the exit status is always 0.
# `command -v`, not `type -P`: it resolves `jq` as annotate.sh's own call
# will, so an exported function named `jq` counts as present.
command -v jq >/dev/null && exit 0

# The format string turns `\\u001b` into the JSON escape `\u001b`; a raw ESC
# byte would be invalid JSON. The reset leads systemMessage to escape the
# dimming of ordinary hook output.
printf '{"systemMessage":"\\u001b[0msandbox-lies: jq not found on PATH — Bash result annotations are off until it is installed","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"sandbox-lies annotations are off: jq is not on PATH. Until it is, no Bash result carries a sandbox-lies note, so read a result without one as unchecked, not as undistorted."}}\n'
exit 0
