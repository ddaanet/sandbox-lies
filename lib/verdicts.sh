#!/usr/bin/env bash
# Agent paragraph and human line per verdict. `verdict_<name> [outcome]`
# reads the probe's key=value lines on stdin (empty when the detector has no
# probe), and prints the agent paragraph on line 1, the human line on line 2.
# Phantom verdicts take no outcome argument. verdict_git_lock and
# verdict_config_lock also take the flag as a second argument (D-17): absent
# reads false, and it words the mask/orphan/unknown re-run/retry clause per
# lock-detectors.md's flag table. Text from docs/references/detectors.md,
# except git_lock and config_lock, whose text comes from
# docs/references/lock-detectors.md, and readonly_path, whose text comes from
# docs/references/readonly-path.md.
set -u

verdict_phantom_chardev() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s\n' 'The character-device entries in this listing are sandbox masks, not files in the repository. Leave them out of every add, delete and report. With no sandboxed command running in the background, `ls -a` and `git status` run unsandboxed show the real tree.'
  printf '%s\n' 'phantom dotfiles — sandbox masks in listing'
}

verdict_phantom_untracked() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s\n' 'The dotfile entries in this listing are sandbox masks, not files in the repository. Leave them out of every add, delete and report. With no sandboxed command running in the background, `ls -a` and `git status` run unsandboxed show the real tree. A cleanliness check that reads these `??` lines as dirty is reading the sandbox, not the tree.'
  printf '%s\n' 'phantom dotfiles — masks listed as untracked'
}

verdict_phantom_gitadd() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s\n' '`git add` aborted on a sandbox mask, not a file. Stage explicit paths, or re-run the same command unsandboxed.'
  printf '%s\n' 'git add — refused a sandbox mask'
}

# `_lock_rerun <flag>` / `_lock_retry <flag>` — lock-detectors.md's
# *Re-run*/*Retry* flag table. Any value but "true" reads as false.
# _lock_rerun's result is a full sentence (trailing period), _lock_retry's is
# a clause fragment its caller finishes.
# shellcheck disable=SC2016 # backticks are literal prose, not expansion
_lock_rerun() {
  case "$1" in
    true) printf 'Re-run the same command once no sandboxed command is running.' ;;
    *) printf 'Re-run the same command with `dangerouslyDisableSandbox: true`.' ;;
  esac
}

# shellcheck disable=SC2016 # backticks are literal prose, not expansion
_lock_retry() {
  case "$1" in
    true) printf 'Retry the command once' ;;
    *) printf 'Retry the command with `dangerouslyDisableSandbox: true`' ;;
  esac
}

# `verdict_git_lock <outcome> [flag]`
verdict_git_lock() {
  local outcome="$1" flag="${2:-false}"
  case "$outcome" in
    mask)
      printf '%s\n' "The lock in this error is a sandbox artefact and the repository is healthy. $(_lock_rerun "$flag") A repeat failure on a commit whose hook stages files is that hook leaking \`GIT_INDEX_FILE\`, not the sandbox."
      printf '%s\n' 'index.lock — sandbox mask, not a real lock'
      ;;
    gone)
      # shellcheck disable=SC2016 # backticks are literal prose, not expansion
      printf '%s\n' 'No lock exists now; git cleaned it after the failure. Retry once. A repeat failure on a commit whose hook stages files is that hook leaking `GIT_INDEX_FILE`, not the sandbox.'
      printf '%s\n' 'index.lock — cleared after failure'
      ;;
    *) _verdict_lock_present index.lock "$outcome" "$flag" ;;
  esac
}

# `verdict_config_lock <outcome> [flag]` — mask reads the probe's path= line
# on stdin: a `.claude/settings.json.lock` path swaps in the update-config act
# for *Re-run*, under either flag (lock-detectors.md's config-lock Verdicts);
# any other path, or none, keeps *Re-run*, worded by the flag as git_lock's is.
verdict_config_lock() {
  local outcome="$1" flag="${2:-false}" line wire='' act
  case "$outcome" in
    mask)
      while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
          path=*) wire=${line#path=} ;;
        esac
      done
      # no decodable path leaves _verdict_path_raw empty: the paragraph still prints
      _verdict_path_read "$wire" || :
      case "$_verdict_path_raw" in
        */.claude/settings.json.lock)
          # shellcheck disable=SC2016 # backticks are literal prose, not expansion
          act='Write `.claude/settings.json` through the `update-config` skill.'
          ;;
        *) act=$(_lock_rerun "$flag") ;;
      esac
      printf '%s\n' "The \`config.lock\` behind this error is a sandbox artefact and the repository is healthy. ${act}"
      printf '%s\n' 'config.lock — sandbox mask, not a real lock'
      ;;
    gone)
      printf '%s\n' 'No lock exists now; git cleaned it after the failure. Retry once.'
      printf '%s\n' 'config.lock — cleared after failure'
      ;;
    *) _verdict_lock_present config.lock "$outcome" "$flag" ;;
  esac
}

# `_verdict_lock_present <lock file> <outcome> <flag>` — the held, orphan and
# unknown verdicts, whose text the two lock detectors share but for the file
# they name and the flag they word orphan/unknown's *Retry* clause by (held
# ignores it). Interpolates pid=/bytes=/age= from the probe's remaining lines
# on stdin (path= and any other key ignored). A key that is absent, or whose
# value is not all digits as the probe contract has it, drops its clause
# rather than leaving an empty or foreign value. Any other outcome prints
# nothing.
_verdict_lock_present() {
  local lock="$1" outcome="$2" flag="$3" line pid='' bytes='' age='' size=''
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *=*[!0-9]*) ;;
      pid=*) pid=${line#pid=} ;;
      bytes=*) bytes=${line#bytes=} ;;
      age=*) age=${line#age=} ;;
    esac
  done
  if [ -n "$bytes" ]; then
    size=" (${bytes} bytes${age:+, age ${age}s})"
  elif [ -n "$age" ]; then
    size=" (age ${age}s)"
  fi
  case "$outcome" in
    held)
      printf '%s\n' "A process${pid:+ (pid ${pid})} holds the lock. Wait for it, then retry."
      printf '%s\n' "${lock} — held${pid:+ by pid ${pid}}"
      ;;
    orphan)
      printf '%s\n' "The lock exists outside the sandbox${size} and no process holds it. $(_lock_retry "$flag"); a second identical failure means the lock predates this session."
      printf '%s\n' "${lock} — present, no holder"
      ;;
    unknown)
      printf '%s\n' "The lock exists outside the sandbox${size}; no holder check is available here. $(_lock_retry "$flag")."
      printf '%s\n' "${lock} — present, holder unknown"
      ;;
  esac
}

# `_verdict_path_read <wire>` — decodes a probe's `path=` value (the
# `printf %q` form) without eval into `_verdict_path_raw`, and sets
# `_verdict_path_shown` to what the verdict prints: the decoded bytes, or the
# wire form when they hold a control byte, which would split the verdict's
# paragraph from its human line. Returns 1 with both empty for a value that
# is neither form, which reads as no path.
_verdict_path_read() {
  local wire="$1" body tail
  # The regex sits in a variable, used unquoted on the right of =~: bash
  # versions differ in how a quoted string there is read, and the unquoted
  # variable is read as a regex on all of them. It admits the whole $'...'
  # form: no bare quote, and a backslash taking any one character.
  local re="^\\\$'([^'\\\\]|\\\\.)*'\$"
  _verdict_path_raw='' _verdict_path_shown=''
  case "$wire" in
    /*)
      # an odd run of trailing backslashes is a lone escape, which the read
      # below would drop, returning the path short
      tail=${wire##*[!\\]}
      [ $((${#tail} % 2)) -eq 0 ] || return 1
      # read without -r drops each escaping backslash; the process
      # substitution keeps the value off disk and out of eval.
      # shellcheck disable=SC2162 # -r would keep the backslashes
      IFS= read _verdict_path_raw < <(printf '%s\n' "$wire")
      ;;
    \$\'*)
      [[ $wire =~ $re ]] || return 1
      body=${wire#\$\'}
      body=${body%\'}
      _verdict_unescape "$body" || return 1
      # a relative value, and the empty $'' one, read as no path
      case $_verdict_path_raw in
        /*) ;;
        *) _verdict_path_raw=''; return 1 ;;
      esac
      ;;
    *) return 1 ;;
  esac
  _verdict_path_shown=$_verdict_path_raw
  if _verdict_has_control "$_verdict_path_raw"; then
    _verdict_path_shown=$wire
  fi
}

# `_verdict_unescape <body>` — the escape loop of _verdict_path_read's $'...'
# arm, decoding into _verdict_path_raw; returns 1 with it empty on an escape
# printf %q never writes. LC_ALL=C makes the split and every index count
# bytes, which is all the wire form holds. The caller's locale is put back on
# every return: a `local LC_ALL=C` is not undone on return under bash 3.2.0,
# which leaves the calling process in the C locale.
#
# One escape at a time: %b reads \0 plus up to three digits, so the \0NN %q
# writes for a control byte would take a following digit with it. A \NNN is
# read as \0NNN, three digits and no more. The body is split once on its
# backslashes, each later field being the text after one, so the work is
# linear in the escapes: re-slicing the remaining body per escape was
# quadratic, and 30 s on 3873 bytes of CJK under bash 3.2.0 in a UTF-8 locale.
# The x sentinel keeps read from dropping a trailing empty field; -d '' lets a
# body holding a newline through whole, and its end-of-input status is not a
# failure.
_verdict_unescape() {
  local body="$1" saved=${LC_ALL-} had=${LC_ALL+x} rc=0 oct='^[0-7]{3}'
  local esc parts n i part rest
  # shellcheck disable=SC2141 # the separator is the backslash itself
  local IFS=\\
  LC_ALL=C
  _verdict_path_raw=''
  read -r -d '' -a parts < <(printf '%sx' "$body") || :
  n=${#parts[@]}
  _verdict_path_raw=${parts[0]}
  i=1
  while [ "$i" -lt "$n" ]; do
    part=${parts[i]}
    i=$((i + 1))
    if [ -z "$part" ]; then
      # an empty field is a \\ pair: the next field is plain text
      _verdict_path_raw=$_verdict_path_raw\\${parts[i]}
      i=$((i + 1))
      continue
    fi
    if [[ $part =~ $oct ]]; then
      printf -v esc %b "\\0${part:0:3}"
      rest=${part:3}
    else
      esc=\\${part:0:1}
      rest=${part:1}
      case $esc in
        # \" and \e are accepted though %q never writes them (it writes \E
        # and a bare "): both are valid in bash's $'...' grammar.
        \\\'|\\\") esc=${esc:1} ;;
        \\[abEefnrtv]) printf -v esc %b "$esc" ;;
        *) _verdict_path_raw=''; rc=1; break ;;
      esac
    fi
    _verdict_path_raw=$_verdict_path_raw$esc$rest
  done
  if [ "$rc" -eq 0 ]; then
    _verdict_path_raw=${_verdict_path_raw%x}
  fi
  if [ -n "$had" ]; then LC_ALL=$saved; else unset LC_ALL; fi
  return "$rc"
}

# `_verdict_has_control <text>` — succeeds when text holds a byte in
# \001-\037 or \177. LC_ALL=C keeps [:cntrl:] to those bytes: a UTF-8 locale
# would add the C1 range, which is valid text in a path. The caller's locale
# is put back on return (see _verdict_unescape).
_verdict_has_control() {
  local saved=${LC_ALL-} had=${LC_ALL+x} rc=1
  LC_ALL=C
  case "$1" in
    *[[:cntrl:]]*) rc=0 ;;
  esac
  if [ -n "$had" ]; then LC_ALL=$saved; else unset LC_ALL; fi
  return "$rc"
}

# `verdict_readonly_path <outcome>` — writable and readonly open with the
# probe's path= stdin line in backticks, or with "The path" when that line is
# missing, empty or malformed. The decoded path (_verdict_path_read) is joined
# by plain expansion — never eval; `%b` decodes an argument, never a format —
# so blanks, `&`, `%`, `\1` or a leading `-` pass through byte-exact; a
# backtick in it closes the code span early, bytes intact. The exception is a
# path holding a control byte: the line shows the probe's wire form, not the
# decoded bytes (_verdict_path_read). nopath has no path= line under the
# contract and opens with its own sentence.
#
# writable and nopath then carry the tail readonly-path.md's readonly-path
# Verdicts compose from the probe's other stdin facts (readfile=, merge=1,
# partial=1, target=, recover=, match=): one act; a merge clause replaces it,
# and a read act follows the clause as its own sentence. readonly ignores
# every fact but path=. An outcome with no text here prints nothing, as an
# unmatched lock outcome does.
verdict_readonly_path() {
  local outcome="$1" line path='' readfile='' merge='' partial='' target=''
  local recover='' matches=() subject act clause rest
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      path=*) path=${line#path=} ;;
      readfile=*) readfile=${line#readfile=} ;;
      merge=*) merge=${line#merge=} ;;
      partial=*) partial=${line#partial=} ;;
      target=*) target=${line#target=} ;;
      recover=*) recover=${line#recover=} ;;
      match=*) matches+=("${line#match=}") ;;
    esac
  done
  if _verdict_path_read "$path"; then
    subject="\`$_verdict_path_shown\`"
  else
    subject='The path'
  fi

  case "$outcome" in
    writable | nopath)
      if [ -n "$readfile" ]; then
        act="Re-run the command that wrote \`$readfile\`."
      else
        case "$merge:$outcome:$_verdict_path_raw" in
          :writable:*/.claude/settings.json)
            # shellcheck disable=SC2016 # backticks are literal prose, not expansion
            act='Write `.claude/settings.json` through the `update-config` skill.'
            ;;
          *)
            # shellcheck disable=SC2016 # backticks are literal prose, not expansion
            act='Re-run the whole call with `dangerouslyDisableSandbox: true`.'
            ;;
        esac
      fi
      rest=" $act"
      if [ -n "$merge" ] && { [ -n "$partial" ] || [ "${#matches[@]}" -gt 0 ]; }; then
        if [ -n "$recover" ] && [ -n "$target" ]; then
          clause="Before any re-run, run \`sandbox-lies-recover $recover $target\` with \`dangerouslyDisableSandbox: true\` and read its plan: the git command may have stopped part-way. The \`sandbox-lies:sandbox-lies\` skill says how to carry the plan out."
        else
          # shellcheck disable=SC2016 # backticks are literal prose, not expansion
          clause='Before any re-run, follow the `sandbox-lies:sandbox-lies` skill'"'"'s recovery of a refused merge or checkout: the git command may have stopped part-way.'
        fi
        rest=" $clause"
        [ -z "$readfile" ] || rest=" $clause $act"
      fi
      ;;
  esac

  case "$outcome" in
    writable)
      printf '%s\n' "$subject is writable outside the sandbox, whose allowlist refused it.$rest"
      printf '%s\n' 'read-only — sandbox allowlist, writable outside'
      ;;
    readonly)
      printf '%s\n' "$subject is not writable outside the sandbox either; this is not a sandbox effect. Unsandboxing will not help: write somewhere writable, or ask before changing its permissions."
      printf '%s\n' 'read-only — real'
      ;;
    nopath)
      printf '%s\n' "The sandbox's write allowlist most likely refused this write.$rest"
      printf '%s\n' 'read-only — probably the sandbox, path not checked'
      ;;
  esac
}

# The shipped candidates. Each takes no outcome, as the phantom verdicts do,
# except resume_lost: its probe's lost or found picks the text, and any other
# outcome prints nothing. Text from docs/references/detectors.md's Verdict
# paragraphs, transcribed verbatim.
verdict_tmpdir_unset() {
  # shellcheck disable=SC2016 # backticks are literal prose, not expansion
  printf '%s\n' '`$TMPDIR` expanded empty in this unsandboxed call, so the path collapsed to `/`. Use the literal scratch path `/tmp/claude/<job>` (create it with `mkdir -p`) in this and every unsandboxed or delegated command.'
  # shellcheck disable=SC2016 # $TMPDIR is literal prose, not expansion
  printf '%s\n' '$TMPDIR — expanded empty, path collapsed to /'
}

verdict_resume_lost() {
  case "${1-}" in
    lost)
      # shellcheck disable=SC2016 # backticks are literal prose, not expansion
      printf '%s\n' 'The transcript was never written: `~/.claude/projects` is read-only inside the sandbox. Run the entire multi-turn flow in one unsandboxed call.'
      printf '%s\n' '--resume — transcript not persisted in sandbox'
      ;;
    found)
      # shellcheck disable=SC2016 # backticks are literal prose, not expansion
      printf '%s\n' 'A transcript for this session exists, so the sandbox did not lose it and an unsandboxed retry will not help. `--resume` finds a session from any working directory: check that this call reads the config directory that holds the transcript (`CLAUDE_CONFIG_DIR`, else `~/.claude`).'
      printf '%s\n' '--resume — transcript exists, not the sandbox'
      ;;
  esac
}

verdict_seccomp_init() {
  printf '%s\n' 'The sandbox failed to initialise before the command ran; this is transient. Retry the identical command once; if it fails the same way, split it into smaller calls. Escape the sandbox only after both.'
  printf '%s\n' 'sandbox init failed — transient, retry'
}
