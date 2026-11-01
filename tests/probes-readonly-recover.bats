#!/usr/bin/env bats
# lib/probes-readonly-facts.sh's recover= fact: printed beside target= when the
# segment's subcommand lets the recovery script name an invocation
# (checkout/switch onto a local branch, or merge), absent otherwise. New file:
# tests/probes-readonly-facts.bats sits near the line cap. Every case runs the
# real probe over a scratch repository (helpers/probes make_scratch_repo).

ROOT="${BATS_TEST_DIRNAME}/.."

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/probes

setup() {
  source "$ROOT/lib/probes.sh"
  REPO="$BATS_TEST_TMPDIR/scratch repo"
  make_scratch_repo "$REPO"
  TEXT=$(readonly_path_text fire-readonly-path-cp-tmp "'$REPO'")
}

# probe_facts <command> — runs the probe in the scratch repo over <command>
# into $output and $stderr, and asserts it read as writable with merge=1.
probe_facts() {
  run_probe_command probe_readonly_path false "$REPO" "$1" "$TEXT"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
  [ "${output%%$'\n'*}" = writable ]
  printf '%s\n' "$output" | grep -qxF 'merge=1'
}

@test "checkout of a local branch prints recover=checkout beside target=" {
  probe_facts 'git checkout feat'
  printf '%s\n' "$output" | grep -qxF 'target=feat'
  printf '%s\n' "$output" | grep -qxF 'recover=checkout'
  run ! grep -qxF 'recover=merge' <<<"$output"
}

@test "switch onto a local branch prints recover=checkout" {
  probe_facts 'git switch feat'
  printf '%s\n' "$output" | grep -qxF 'target=feat'
  printf '%s\n' "$output" | grep -qxF 'recover=checkout'
}

@test "merge prints recover=merge" {
  probe_facts 'git merge --ff-only feat'
  printf '%s\n' "$output" | grep -qxF 'target=feat'
  printf '%s\n' "$output" | grep -qxF 'recover=merge'
  run ! grep -qxF 'recover=checkout' <<<"$output"
}

@test "merge of a ref that is not a local branch still prints recover=merge" {
  git -C "$REPO" tag v1 feat
  probe_facts 'git merge v1'
  printf '%s\n' "$output" | grep -qxF 'target=v1'
  printf '%s\n' "$output" | grep -qxF 'recover=merge'
}

@test "checkout of a path-restoring HEAD prints no recover=" {
  probe_facts 'git checkout HEAD -- a'
  run ! grep -q '^recover=' <<<"$output"
}

@test "checkout of a remote-tracking ref, a tag or a sha prints no recover=" {
  local cmd
  git -C "$REPO" update-ref refs/remotes/origin/x feat
  git -C "$REPO" tag v1 feat
  for cmd in 'git checkout origin/x' 'git checkout v1' \
    "git checkout $(git -C "$REPO" rev-parse feat)"; do
    probe_facts "$cmd"
    # target= resolves, so the absence is the fact's own rule.
    printf '%s\n' "$output" | grep -q '^target='
    run ! grep -q '^recover=' <<<"$output"
  done
}

@test "a literal -- in the segment suppresses recover= though target= prints" {
  probe_facts 'git checkout main -- a'
  printf '%s\n' "$output" | grep -qxF 'target=main'
  run ! grep -q '^recover=' <<<"$output"
}

@test "no resolved target prints no recover=" {
  probe_facts 'git checkout no-such-ref-xyz'
  run ! grep -q '^target=' <<<"$output"
  run ! grep -q '^recover=' <<<"$output"

  probe_facts 'git merge no-such-ref-xyz'
  run ! grep -q '^recover=' <<<"$output"
}

@test "pull, rebase and cherry-pick print no recover=" {
  local cmd
  for cmd in 'git pull' 'git rebase feat' 'git cherry-pick feat'; do
    probe_facts "$cmd"
    run ! grep -q '^recover=' <<<"$output"
  done
}

@test "recover= survives BSD grep, sed, stat and wc" {
  local bsd="$BATS_TEST_TMPDIR/bsdtools"
  make_bsd_stubs "$bsd" grep sed stat wc
  PATH="$bsd:$PATH" probe_facts 'git checkout feat'
  printf '%s\n' "$output" | grep -qxF 'recover=checkout'
}
