#!/usr/bin/env bats
# FR-11: no live file in this repository fires a detector when read back.
#
# Every tracked regular file is piped through lib/matchers.sh. Fixtures are
# recorded tool results and fire by design; the exemptions below are dated
# pilot evidence that quotes live diagnostics whole and is frozen.

ROOT="${BATS_TEST_DIRNAME}/.."
MATCHERS="$ROOT/lib/matchers.sh"

load helpers/bsd-stubs
load helpers/git-env

EXEMPT=(
  plans/2026-09-02-sandbox-detector-replay.py
  plans/2026-09-02-sandbox-detector-hits.jsonl
  plans/2026-09-03-sandbox-matcher-corpus-eval.md
)

is_exempt() {
  local e
  for e in "${EXEMPT[@]}"; do [ "$1" = "$e" ] && return 0; done
  return 1
}

@test "no tracked file outside the fixtures fires a detector" {
  local index="$BATS_TEST_TMPDIR/index" meta path mode verdicts firing=""
  local checked=0 e status
  # The exemptions quote live diagnostics whole: each must still fire, or the
  # sweep below could be passing because the matchers never ran.
  for e in "${EXEMPT[@]}"; do
    [ -n "$(bash "$MATCHERS" <"$ROOT/$e")" ] || {
      echo "exempt file no longer fires: $e" >&2
      return 1
    }
  done
  git -C "$ROOT" ls-files -z -s >"$index"
  [ -s "$index" ]
  # `-s` prefixes each path with `<mode> <object> <stage>` and a tab;
  # 120000 is a symlink and 160000 a gitlink, neither of them a file to read.
  while IFS= read -r -d '' meta; do
    path=${meta#*$'\t'}
    mode=${meta%% *}
    case "$mode" in 120000|160000) continue ;; esac
    case "$path" in tests/fixtures/*) continue ;; esac
    is_exempt "$path" && continue
    status=0
    verdicts=$(bash "$MATCHERS" <"$ROOT/$path") || status=$?
    checked=$((checked + 1))
    [ -z "$verdicts" ] ||
      firing="$firing"$'\n'"  $path: ${verdicts//$'\n'/, }"
    # `detect` exits 1 when quiet; above that bash itself failed on this
    # file (126, 127), which must not read as quiet.
    [ "$status" -le 1 ] ||
      firing="$firing"$'\n'"  $path: matchers exited $status"
  done <"$index"
  [ "$checked" -gt 0 ]
  [ -z "$firing" ] || {
    echo "files firing a detector or failing the matchers:$firing" >&2
    return 1
  }
}

# A stub either refuses or runs the real tool, so under the stubs a file can
# fire only where it fires plainly: a second sweep would find nothing the
# first misses. What the stubs add is the refusal, on stderr whether or not
# its matcher would have fired, and every matcher runs on every input. The
# exempt files reach git-lock's follow-on grep; lib/ and hooks/, which hold
# the matchers' own patterns, reach the other matchers' later stages.
@test "the matchers give the plain verdicts and refuse no BSD sed or grep call" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools" err="$BATS_TEST_TMPDIR/stubbed-err"
  local path plain stubbed
  local -a inputs=("${EXEMPT[@]}")
  make_bsd_stubs "$bsd" sed grep
  while IFS= read -r -d '' path; do
    inputs+=("$path")
  done < <(git -C "$ROOT" ls-files -z -- lib hooks)
  [ "${#inputs[@]}" -gt "${#EXEMPT[@]}" ]
  for path in "${inputs[@]}"; do
    # `detect` exits 1 when nothing fires: that must reach the comparison.
    plain=$(bash "$MATCHERS" <"$ROOT/$path") || :
    stubbed=$(PATH="$bsd:$PATH" bash "$MATCHERS" <"$ROOT/$path" 2>"$err") || :
    if is_exempt "$path"; then [ -n "$plain" ]; fi
    [ "$stubbed" = "$plain" ] || {
      echo "$path: stubbed [$stubbed], plain [$plain]" >&2
      return 1
    }
    [ ! -s "$err" ] || { echo "$path:" >&2; cat "$err" >&2; return 1; }
  done
}
