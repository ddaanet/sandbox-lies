# Minor batch C, test review (findings 9, 29)

Verdict: no defects found, no edits made. Re-ran both suites in the
foreground, one at a time. Red set unchanged: corpus-eval.bats 6 pass / 4 fail
(aggregate no-tab, list tool_use id, list tool_use_id, subdirectory);
extract-fixtures.bats 4 pass / 4 fail (list id, list tool_use_id, integer
timestamp, integer text item). Each failure is a genuine assertion or `run -0`
status mismatch against unchanged code, with the expected TypeError,
ValueError or IsADirectoryError as the cause, not a missing file or helper.

## Finding 9

- Treatment matches the tool: `cmd_aggregate` already counts a verdict line
  whose file is not in the manifest as skipped; a no-tab line has no manifest
  entry either, so the exact-line count of 1 is the consistent behaviour.
- Wrong fixes caught: a broad try/except that drops the line uncounted (count
  0 fails), a fix that raises or exits non-zero, a fix that skips the valid
  neighbour (the `-> 000001.txt` hit assertion fails).
- Valid neighbour pinned: the well-formed `000001.txt<TAB>ro` line still yields
  its hit.

## Finding 29

- List-valued `id` and `tool_use_id`: each test also carries a sibling normal
  call that must still survive, so aborting the file or clearing state fails.
  Extract-fixtures cases require the cut to equal the sibling's output
  verbatim.
- Subdirectory: a stale regular file must still be removed and the new
  survivor cut, so skipping the whole unlink loop or stopping at the directory
  fails. The test deliberately does not pin whether the directory is left or
  removed (the finding text is silent); a fix that rmtree's it or skips it
  both pass, and neither reads it as a survivor.
- Integer text/timestamp for `cmd_extract` were found already guarded (per the
  RED report), so no case exists there; the finding's claim does not hold for
  that tool, only for `extract-fixtures.py`.
