# Item 4.2 docs — absolute `match=` names

## What changed

`docs/references/readonly-path.md` only (183 lines after `just format-docs`,
cap 400):

- Probe facts table: the key is now `match=<repo>/<file>`, and the row says the
  file is named by absolute path — the repository root, trailing slashes
  stripped, then the file's name within it.
- Residuals paragraph under the table, merged into the existing newline
  sentence rather than added as a new list: a repository root holding a newline
  gives no `target=` or `match=` at all, since, like a newline-bearing file
  name, it would split a `match=` line and forge the key line after it; a
  repository at `/` gives `match=//<file>`.
- Verdicts, the `match=` lines clause: each name is its `match=` line's absolute
  path, so the clause names the same files from any working directory; a
  backtick in a name closes its code span early, bytes intact.

Not touched: the `readfile=` row and its residual list (Item 4.1), `mv`'s `to`
wording (Item 5.2), `docs/design.md`, other docs, code, tests. The `path=`
newline issue (code-review Recommendations 1) is not documented, as the
dispatch directs. `rg 'match='` over `docs/`, `README.md` and `skills/` finds
no other mention to update.

## How each statement was verified

- Absolute `<repo>/<name>`: `lib/probes-readonly-facts.sh`
  `_readonly_repo_facts` merge pass appends `match=${repo}/${files[$i]}`;
  pinned by `tests/probes-readonly-members.bats` "match= names are absolute from
  a subdirectory cwd" and "git switch feat in a scratch repo gives target=feat
  and an absolute match=".
- Trailing slashes stripped: `_readonly_git_dir` strips them before the walk
  (`while [ "${dir%/}" != "$dir" ]`), restoring `/` when empty; pinned by
  "match= names carry no doubled slash from a cwd with a trailing slash".
- Newline in the root gives no `target=` or `match=`: `_readonly_repo_facts`
  returns 0 on `*$'\n'*` right after `shift`, before any `target=` is printed;
  pinned by "a repository root holding a newline gives no target= or match=".
  The file-name guard (`*$'\n'*) continue`) is the pre-existing one the
  sentence already covered.
- `/` gives `//<file>`: `_readonly_git_dir` prints `/` for a root at `/`
  (`[ -n "$dir" ] || dir=/`), and the merge pass joins `/` + `/` + name. Read
  from the code; not run (no repository at `/` here).
- Clause names absolute paths: `verdict_readonly_path` stores
  `${line#match=}` whole and `_readonly_match_list` wraps each in backticks by
  plain expansion; pinned end to end by `tests/hook-writes.bats` "hook restore
  clause names the match by absolute path" (payload cwd `<repo>/sub`).
- Backtick residual: `_readonly_match_list` joins `` \`$m\` `` with no escaping,
  so a backtick in the root or file name ends the span; `readonly-path.md` did
  not document this for names before (only `lib/verdicts.sh`'s comment states
  it, for `path=`), so it is added rather than merged.

## Gate

`just precommit` exit 0: `bats: 301 passed, 0 failed`; `precommit passed:
plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links,
tests`.
