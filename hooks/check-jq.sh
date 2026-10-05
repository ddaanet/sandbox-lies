#!/usr/bin/env bash
# SessionStart hook (hooks/hooks.json), outline D2. Speaks only when `jq` is
# not on PATH, because hooks/annotate.sh needs it and otherwise degrades with
# no sign. The JSON is printed from fixed text, so the notice needs no `jq`.
# Stdin is ignored, nothing is written, the exit status is always 0.
command -v jq >/dev/null && exit 0

# The format string turns `\\u001b` into the JSON escape `\u001b`; a raw ESC
# byte would be invalid JSON. The reset leads systemMessage to escape the
# dimming of ordinary hook output.
printf '{"systemMessage":"\\u001b[0msandbox-lies: jq is not installed, so its Bash result annotations are off this session until jq is on PATH.","hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"sandbox-lies annotations are off this session because jq is missing from PATH. Read Bash results without them: do not expect a sandbox note after a failure. Tell the user to install jq if a result looks distorted."}}\n'
exit 0
