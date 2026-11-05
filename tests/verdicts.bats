#!/usr/bin/env bats
# lib/verdicts.sh: verdict_<name> [outcome] -> agent paragraph (line 1),
# human line (line 2). Row-table length, quiet and no-removal properties
# across every verdict, plus the phantom/candidate/readonly-path text
# transcriptions. Lock-verdict tests live in tests/verdicts-locks.bats and
# tests/verdicts-locks-flags.bats.

bats_require_minimum_version 1.5.0

load helpers/bsd-stubs
load helpers/git-env
load helpers/verdicts

@test "verdicts under 400 chars" {
  local name outcome flag text line1 line2 defined rowed
  # "Every row" means every verdict only if no verdict function lacks a row.
  defined=$(bash -c '. "$1" && declare -F' _ "$VERDICTS" \
    | awk '$3 ~ /^verdict_/ { sub(/^verdict_/, "", $3); print $3 }' | sort -u)
  rowed=$(rows | awk 'NF { print $1 }' | sort -u)
  [ -n "$defined" ]
  [ "$defined" = "$rowed" ]
  while read -r name outcome flag; do
    [ -n "$name" ] || continue
    text=$(verdict_text "$name" "$outcome" "$flag")
    # Exactly two lines, both non-empty: an empty verdict or paragraph must
    # fail here, not slip through as vacuously short.
    [ "$(printf '%s\n' "$text" | awk 'END { print NR }')" -eq 2 ]
    line1=$(printf '%s\n' "$text" | sed -n '1p')
    line2=$(printf '%s\n' "$text" | sed -n '2p')
    [ -n "$line1" ]
    [ "${#line1}" -lt 400 ]
    printf '%s' "$line2" | grep -qF -- ' — '
  done < <(rows)
}

@test "verdict text is quiet" {
  local all
  all=$(all_verdict_text)
  # An empty verdict set must fail here, not read as trivially quiet.
  [ -n "$(printf '%s' "$all" | tr -d '[:space:]')" ]
  run bash -c 'printf "%s\n" "$1" | bash "$2"' _ "$all" "$MATCHERS"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "verdict text matches detectors.md" {
  # Transcribed from docs/references/detectors.md's Verdict paragraphs, not
  # copied from lib/verdicts.sh: a mismatch between the two must red here.
  # The phantom-untracked paragraph is documented there as "As
  # `phantom-chardev`, opening "The dotfile entries", with: <addition>" —
  # the chardev paragraph under that subject plus the addition, not that
  # sentence transcribed literally.
  local chardev_para untracked_para addition line1 line2
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  chardev_para='The character-device entries in this listing are sandbox masks, not files in the repository. Leave them out of every add, delete and report. With no sandboxed command running in the background, `ls -a` and `git status` run unsandboxed show the real tree.'
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  addition='A cleanliness check that reads these `??` lines as dirty is reading the sandbox, not the tree.'

  line1=$(verdict_text phantom_chardev - | sed -n '1p')
  line2=$(verdict_text phantom_chardev - | sed -n '2p')
  [ "$line1" = "$chardev_para" ]
  [ "$line2" = 'phantom dotfiles — sandbox masks in listing' ]

  line1=$(verdict_text phantom_untracked - | sed -n '1p')
  line2=$(verdict_text phantom_untracked - | sed -n '2p')
  untracked_para=${chardev_para/#The character-device entries/The dotfile entries}
  [ "$untracked_para" != "$chardev_para" ]
  [ "$line1" = "${untracked_para} ${addition}" ]
  [ "$line2" = 'phantom dotfiles — masks listed as untracked' ]

  line1=$(verdict_text phantom_gitadd - | sed -n '1p')
  line2=$(verdict_text phantom_gitadd - | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`git add` aborted on a sandbox mask, not a file. Stage explicit paths, or re-run the same command unsandboxed.' ]
  [ "$line2" = 'git add — refused a sandbox mask' ]
}

# No location is named, so the sentence holds under any cwd. Pinned apart from
# the whole-paragraph transcription above, which also reds on the untracked
# paragraph, so this opening sentence reds on its own.
@test "phantom-untracked opens without naming a location" {
  local line1 opening
  opening='The dotfile entries in this listing are sandbox masks, not files in the repository.'

  line1=$(verdict_text phantom_untracked - | sed -n '1p')
  [ "${line1:0:${#opening}}" = "$opening" ]
  [ "${line1:${#opening}:1}" = ' ' ]
  case "$line1" in
    *'project root'*) return 1 ;;
  esac
}

@test "candidate verdict text matches detectors.md" {
  # Transcribed from docs/references/detectors.md's tmpdir-unset, resume-lost
  # and seccomp-init Verdict paragraphs, not copied from lib/verdicts.sh.
  local line1 line2

  line1=$(verdict_text tmpdir_unset - | sed -n '1p')
  line2=$(verdict_text tmpdir_unset - | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = '`$TMPDIR` expanded empty in this unsandboxed call, so the path collapsed to `/`. Use the literal scratch path `/tmp/claude/<job>` (create it with `mkdir -p`) in this and every unsandboxed or delegated command.' ]
  # shellcheck disable=SC2016 # $TMPDIR is literal prose, not expansion
  [ "$line2" = '$TMPDIR — expanded empty, path collapsed to /' ]

  line1=$(verdict_text resume_lost lost | sed -n '1p')
  line2=$(verdict_text resume_lost lost | sed -n '2p')
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  [ "$line1" = 'The transcript was never written: `~/.claude/projects` is read-only inside the sandbox. Run the entire multi-turn flow in one unsandboxed call.' ]
  [ "$line2" = '--resume — transcript not persisted in sandbox' ]

  line1=$(verdict_text seccomp_init - | sed -n '1p')
  line2=$(verdict_text seccomp_init - | sed -n '2p')
  [ "$line1" = 'The sandbox failed to initialise before the command ran; this is transient. Retry the identical command once; if it fails the same way, split it into smaller calls. Escape the sandbox only after both.' ]
  [ "$line2" = 'sandbox init failed — transient, retry' ]
}

@test "resume-lost found verdict prints the paragraph then the human line" {
  local expected
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  expected='A transcript for this session exists, so the sandbox did not lose it and an unsandboxed retry will not help. `--resume` finds a session from any working directory: check that this call reads the config directory that holds the transcript (`CLAUDE_CONFIG_DIR`, else `~/.claude`).
--resume — transcript exists, not the sandbox'
  run bash -c '. "$1"; verdict_resume_lost found' _ "$VERDICTS"
  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

@test "resume-lost verdict prints nothing for an outcome it has no text for" {
  # verdict_text maps `-` to a call with no argument; this passes the
  # literal `-`, the outcome the verdict used to be called with, and
  # `unknown`, the one the probe prints when it could not search.
  local outcome
  for outcome in - unknown; do
    run bash -c '. "$1"; verdict_resume_lost "$2"' _ "$VERDICTS" "$outcome"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "text for '$outcome': $output" >&2; return 1; }
  done
}

@test "readonly-path writable verdict text matches readonly-path.md" {
  # Transcribed from docs/references/readonly-path.md's readonly-path Verdicts
  # list, <path> substituted by the probe's path= stdin line. The path holds
  # a blank and the characters a sed replacement or an eval would act on, as
  # an extracted path may; the stdin line carries it in the probe's printf %q
  # form and the verdict shows it decoded. The path renders in backticks, as
  # the doc writes the placeholder; with no path= line it is "The path".
  local p wire rest text line1 line2
  p='/r/a b&c\1/x'
  wire='/r/a\ b\&c\\1/x'
  rest=" is writable outside the sandbox, whose allowlist refused it.$(readonly_path_tail)"
  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
  text=$(printf '%s\n' "path=$wire" | ( . "$VERDICTS"; verdict_readonly_path writable ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  [ "$line1" = "\`$p\`$rest" ]
  [ "$line2" = 'read-only — sandbox allowlist, writable outside' ]

  line1=$(verdict_text readonly_path writable | sed -n '1p')
  [ "$line1" = "The path$rest" ]
}

@test "readonly-path readonly verdict text matches readonly-path.md" {
  # Transcribed from docs/references/readonly-path.md's readonly-path Verdicts
  # list, <path> interpolated in backticks as the writable case does, and
  # "The path" with no path= line (outside the probe contract, as the
  # row-driven cases call it), so no subjectless sentence. The stdin line is
  # the printf %q form of p, as in the writable case.
  local p wire text line1 line2
  p='/r/a b&c\1/x'
  wire='/r/a\ b\&c\\1/x'

  # shellcheck disable=SC1090 # $VERDICTS is lib/verdicts.sh, resolved above
  text=$(printf '%s\n' "path=$wire" | ( . "$VERDICTS"; verdict_readonly_path readonly ))
  line1=$(printf '%s\n' "$text" | sed -n '1p')
  line2=$(printf '%s\n' "$text" | sed -n '2p')
  [ "$line1" = "\`$p\` is not writable outside the sandbox either; this is not a sandbox effect. Unsandboxing will not help: write somewhere writable, or ask before changing its permissions." ]
  [ "$line2" = 'read-only — real' ]

  line1=$(verdict_text readonly_path readonly | sed -n '1p')
  [ "$line1" = 'The path is not writable outside the sandbox either; this is not a sandbox effect. Unsandboxing will not help: write somewhere writable, or ask before changing its permissions.' ]
}

@test "readonly-path nopath verdict text matches readonly-path.md" {
  # Transcribed from docs/references/readonly-path.md's readonly-path Verdicts
  # list: nopath's opening sentence, then the tail, which with no facts on
  # stdin is the whole-call re-run alone. No path= line: the probe contract
  # gives none for nopath.
  local line1 line2
  line1=$(verdict_text readonly_path nopath | sed -n '1p')
  line2=$(verdict_text readonly_path nopath | sed -n '2p')
  [ "$line1" = "The sandbox's write allowlist most likely refused this write.$(readonly_path_tail)" ]
  [ "$line2" = 'read-only — probably the sandbox, path not checked' ]
}

@test "no removal instruction" {
  local all stripped phrase
  all=$(all_verdict_text)
  # An empty verdict set must fail here, not read as vacuously clean.
  [ -n "$(printf '%s' "$all" | tr -d '[:space:]')" ]
  # D-7: the one sanctioned "delete" (detectors.md's phantom-chardev
  # verdict, "every add, delete and report") is stripped before checking.
  phrase="add, delete and report"
  stripped=$(printf '%s' "$all" | sed "s/${phrase}//g")
  # `rm ` only as a word: "confirm " and "form " are not instructions. Status
  # 1 exactly, so a grep that errored cannot read as "no match".
  run bash -c 'printf "%s" "$1" | grep -qiE "(^|[^[:alpha:]])rm |remove|delete"' \
    _ "$stripped"
  [ "$status" -eq 1 ]
}
