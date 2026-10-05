# Item 4.3 slice 1 — GREEN

## Changed

`hooks/hooks.json`: added `SessionStart`, one entry with no `matcher`, one
hook `{type: command, command: bash "${CLAUDE_PLUGIN_ROOT}/hooks/check-jq.sh",
timeout: 10}`, as the test review pinned. `PostToolUse` and
`PostToolUseFailure` unchanged in content. The stub `hooks/check-jq.sh` stays
inert; no test edited. (Edit tool got no classifier verdict; the file was
written via `put.py` from a staged copy.)

## Tests, in the order made to pass

1. `check-jq.bats` "jq present: the registered SessionStart command is
   silent" and `hook.bats` "hooks.json names the three events" both turned on
   from the single registration edit (one change satisfies both).

`bats tests/check-jq.bats tests/hook.bats`: 14 of 14 ok.

## Full suite and gate

See the result line below.

Full suite: bats 302 passed, 0 failed. `just precommit` exit 0 (plugin.json, hooks.json, shellcheck, bash -n, rumdl, line limits, links, tests); no warnings.
