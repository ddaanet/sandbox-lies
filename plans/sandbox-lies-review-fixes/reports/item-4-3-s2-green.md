# Item 4.3 slice 2 — GREEN

## Changed

`hooks/check-jq.sh` replaces the stub: `command -v jq >/dev/null && exit 0`,
else one `printf` of fixed JSON (format string, so `\\u001b` prints as the JSON
escape `\u001b`, never a raw ESC byte), then `exit 0`. Stdin ignored, nothing
written, no external tools, no `2>/dev/null`. Tests not edited.

## Notice text

- `systemMessage`: `\u001b[0m` then "sandbox-lies: jq is not installed, so its
  Bash result annotations are off this session until jq is on PATH."
- `additionalContext`: "sandbox-lies annotations are off this session because
  jq is missing from PATH. Read Bash results without them: do not expect a
  sandbox note after a failure. Tell the user to install jq if a result looks
  distorted."
- `hookSpecificOutput.hookEventName`: `SessionStart`.

## Order made to pass

All three failing cases reddened on the same missing output, so one script made
them pass together: case 2 (notice), then case 3 (missing TMPDIR; no temp file
used), then case 4 (BSD stubs; no tool used). Case 1 stayed green.

## Results

`bats tests/check-jq.bats`: 4/4 ok. `shellcheck hooks/check-jq.sh
tests/check-jq.bats`: clean.
