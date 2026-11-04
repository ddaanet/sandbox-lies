#!/usr/bin/env bats
# lib/probes-readonly-command.sh's _readonly_tokenize must not copy a growing
# word on every unquoted # or >&: a word dense in either took 3 to 5 s at 16384
# characters on bash 5.2 and 35 s on 3.2.0, against 1.3 to 3 s for a plain
# word (plans/sandbox-lies-review-fixes-3/reports/deliverable-review.md,
# finding 6). The pattern is tests/verdicts-readonly-path.bats's timing case.
# Its own file: the timings are slow. Under bats -j, setup_file below keeps this
# file's cases from racing one another; other files still run alongside them.
#
# Why the bound is on dense time over plain time at the SAME size, not on
# t(4N)/t(N): the scan stops at 16384 characters, so 4N tops out near 16000,
# where the copying is only part of the cost and the per-character read is the
# rest. On the unchanged code a dense word's t(4N)/t(N) is 7.4 to 10.3 on bash
# 5.2 and a plain word's 3.8 to 4.4, so no bound between 4 and 16 separates a
# fix from the defect. A 16000-character dense word over a 16000-character
# plain word, timed in the same run and locale, is 3.0 to 5.2 on the unchanged
# code and 1.0 to 1.2 on a tokenizer that appends without copying; the bound
# is 1.9, about the geometric mean, 1.6 times the worst fixed value and 1.6
# under the best defective one. The plain word is timed once, in setup_file, so
# it cancels only load that holds steady: other files' jobs under bats -j can
# still move a ratio.

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/locale

N=16000

setup_file() {
  local loc
  # Read by bats after setup_file returns. Concurrent dense cases would be timed
  # against a plain word that ran without them.
  export BATS_NO_PARALLELIZE_WITHIN_FILE=true
  loc=$(utf8_locale)
  # The plain word's timing, shared by the three cases.
  tokenize_seconds "$loc" plain "$N" >"$BATS_FILE_TMPDIR/plain"
}

# tokenize_seconds <locale> <shape> <chars> — the least wall seconds of three
# fresh bash runs of _readonly_tokenize over `cat <word> x`, the word <chars>
# characters of <shape>: plain (letters), hash (a letter then #s), mixed
# (a# repeated), redir (>& repeated). Every run's tokens are compared with
# wcat, w<word>, wx, so a tokenizer that returned nothing quickly cannot
# pass on speed; a mismatch exits non-zero with the shape named. python3's
# perf_counter is the clock: bash 3.2 has no EPOCHREALTIME and BSD date no %N.
tokenize_seconds() {
  # shellcheck disable=SC2016 # the Python source holds $1/$2 for bash -c
  python3 -I -c '
import os, subprocess, sys, time
loc, shape, n, lib = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
word = {
    "plain": "a" * n,
    "hash": "a" + "#" * (n - 1),
    "mixed": "a#" * (n // 2),
    "redir": ">&" * (n // 2),
}[shape]
want = ["wcat", "w" + word, "wx"]
env = dict(os.environ, LC_ALL=loc)
script = ". \"$1\"; _readonly_tokenize \"cat $2 x\"; printf \"%s\\n\" \"${_readonly_tokens[@]}\""
best = None
for _ in range(3):
    t0 = time.perf_counter()
    out = subprocess.run(["bash", "-c", script, "_", lib, word], env=env,
                         check=True, capture_output=True, text=True).stdout
    dt = time.perf_counter() - t0
    if out.split("\n")[:-1] != want:
        sys.exit("%s x %d: wrong tokens, got %d bytes" % (shape, n, len(out)))
    best = dt if best is None else min(best, dt)
print("%.4f" % best)
' "$1" "$2" "$3" "$ROOT/lib/probes-readonly-command.sh"
}

# assert_dense_near_plain <shape> — the shape's time at N characters over the
# plain word's at N stays under 1.9 (a linear scan about 1.0 to 1.2, the
# copying one 3.0 to 5.2 here).
assert_dense_near_plain() {
  local loc t p ratio
  loc=$(utf8_locale)
  p=$(cat "$BATS_FILE_TMPDIR/plain")
  t=$(tokenize_seconds "$loc" "$1" "$N")
  ratio=$(python3 -I -c 'import sys; print("%.2f" % (float(sys.argv[1]) / float(sys.argv[2])))' "$t" "$p")
  printf '%s: %s s over plain %s s at %s characters: ratio %s\n' \
    "$1" "$t" "$p" "$N" "$ratio" >&2
  python3 -I -c 'import sys; sys.exit(0 if float(sys.argv[1]) < 1.9 else 1)' "$ratio"
}

# N is 16000 characters: the scan's 16384 cap allows no more.
@test "_readonly_tokenize time stays near a plain word's for a word of # after one letter" {
  assert_dense_near_plain hash
}

@test "_readonly_tokenize time stays near a plain word's for a word dense in # and letters" {
  assert_dense_near_plain mixed
}

@test "_readonly_tokenize time stays near a plain word's for a word dense in >&" {
  assert_dense_near_plain redir
}
