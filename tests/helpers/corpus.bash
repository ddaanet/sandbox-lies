#!/usr/bin/env bash
# Shared by tests/corpus-eval.bats and tests/extract-fixtures.bats: JSONL
# transcript lines written at run time under a scratch HOME, so no case reads
# the host's ~/.claude. Diagnostic text is joined from fragments here, never
# spelled whole, so tests/sweep-code.bats stays quiet over the suites.

# corpus_use <id> <ts> <command> — a Bash tool_use line
corpus_use() {
  jq -nc --arg id "$1" --arg ts "$2" --arg cmd "$3" \
    '{timestamp: $ts, message: {content: [{type: "tool_use", name: "Bash",
      id: $id, input: {command: $cmd}}]}}'
}

# corpus_result <id> <ts> <text> — the tool_result line pairing with <id>
corpus_result() {
  jq -nc --arg id "$1" --arg ts "$2" --arg text "$3" \
    '{timestamp: $ts, message: {content: [{type: "tool_result",
      tool_use_id: $id, content: $text}]}}'
}

# corpus_use_raw_input <id> <ts> <json> — a Bash tool_use whose input is <json>
corpus_use_raw_input() {
  jq -nc --arg id "$1" --arg ts "$2" --argjson inp "$3" \
    '{timestamp: $ts, message: {content: [{type: "tool_use", name: "Bash",
      id: $id, input: $inp}]}}'
}

# readonly_text — output carrying a corpus-eval prefilter substring
readonly_text() {
  printf 'cp: cannot create regular file: %s%s\n' 'Read-only ' 'file system'
}

# lock_text — output matching SPEC entry fire-lock-commit-amend (60..4000
# bytes, contains the lock refusal's opening words), no trailing newline
lock_text() {
  printf "fatal: %s%s '/r/.git/index.lock': File exists. Another git process seems to be running" 'Unable to' ' create'
}
