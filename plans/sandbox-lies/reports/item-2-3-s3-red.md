# Item 2.3 slice 3 — RED

Mode: RED. Nothing committed. `hooks/` and `lib/` are byte-identical to HEAD
(`git diff --quiet hooks lib` exits 0). `tests/hook.bats` and
`tests/verdicts.bats` changed.

## Pre-check: the concatenation really fires both detectors

Before writing the test, confirmed directly against `lib/matchers.sh` (a
script, not the Bash tool's `grep` shell function — `cc-grep-shell-function.md`)
that concatenating the two fixtures fires both listing detectors:

```
bash -c '. lib/matchers.sh; detect' < <(cat tests/fixtures/fire-masks-chardev-explicit.txt tests/fixtures/fire-masks-porcelain.txt)
# phantom-chardev
# phantom-untracked
# exit=0
```

Then re-checked with the exact bash construction the test uses
(`$(cat file1)$(cat file2)`, which strips trailing newlines rather than raw
`cat file1 file2`) — same result, both fire. `fire-masks-chardev-explicit.txt`
has no trailing newline of its own, so its last line merges with the
porcelain fixture's first line either way; the matchers still fire on the
remaining standalone lines in each listing.

## Tests added

1. **`both listing verdicts share one paragraph`** (`tests/hook.bats`,
   inserted before `hooks.json names both events`) — a `PostToolUse` payload
   whose `tool_response.stdout` is
   `fire-masks-chardev-explicit.txt`'s text concatenated with
   `fire-masks-porcelain.txt`'s. Asserts `additionalContext` equals exactly
   line 1 of `verdict_phantom_untracked` (sourced live from the copied
   `lib/verdicts.sh`, not a literal in the test) and `systemMessage` equals
   its line 2. Comparing against the live function rather than a substring
   is deliberate: `verdict_phantom_untracked`'s paragraph already restates
   `verdict_phantom_chardev`'s, so "chardev's paragraph is absent" cannot be
   asserted by substring — only "nothing besides untracked's own output" can.

2. **`verdict text matches detectors.md`** (`tests/verdicts.bats`) — for each
   of the three phantom rows, line 1 and line 2 equal expected strings
   transcribed by hand from `docs/references/detectors.md`'s Verdict
   paragraphs (not copied from `lib/verdicts.sh`). The `phantom-untracked`
   expected line 1 is built as detectors.md documents it — `chardev_para`
   (transcribed from the `phantom-chardev` entry) plus a space plus the
   `addition` sentence transcribed from the `phantom-untracked` entry's "As
   `phantom-chardev`, with: …" — rather than transcribing that sentence
   literally.

## Genuine red / pass

`scripts/run-bats.sh tests/hook.bats tests/verdicts.bats`:

```
not ok 6 both listing verdicts share one paragraph
# (in test file tests/hook.bats, line 137)
#   `[ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.additionalContext')" \' failed

bats: 10 passed, 1 failed
```

`both listing verdicts share one paragraph` reds genuinely, for the reason
the item names: `hooks/annotate.sh`'s dispatch loop (`hooks/annotate.sh:44-52`)
calls `verdict_<name>` for every name `detect` prints with no
chardev/untracked special-case, so for this payload it calls
`verdict_phantom_chardev` **and** `verdict_phantom_untracked` and joins both
paragraphs with a newline — `additionalContext` is two paragraphs, not
`verdict_phantom_untracked`'s one. This is the "hook calls both verdicts
today" behaviour the dispatch predicted.

`verdict text matches detectors.md` passed on first run (the shipped
`lib/verdicts.sh` text already matches `detectors.md`) — no difference to
report. Proven non-vacuous by mutation, one exact-string cut per row, each
run in isolation (`--filter "verdict text matches detectors.md"`):

- `phantom_chardev`: dropped the trailing `` `ls -a` and `git status` run
  unsandboxed show the real tree.`` sentence → red on the `line1 =
  chardev_para` assertion (`tests/verdicts.bats:97`). Restored; `git diff
  --quiet lib/verdicts.sh` confirmed clean before the next mutation.
- `phantom_untracked`: changed the line-2 em dash to a hyphen → red on the
  `line2` assertion (`tests/verdicts.bats:103`). Restored; confirmed clean.
- `phantom_gitadd`: dropped the trailing `Stage explicit paths, or re-run the
  same command unsandboxed.` clause → red on the `line1` assertion
  (`tests/verdicts.bats:108`). Restored.

`scripts/run-bats.sh tests/docs.bats`: 1 passed, 0 failed (self-quiet holds
over both edited test files — the transcribed strings never quote a
diagnostic whole).

## Untouched

`hooks/annotate.sh`, `hooks/hooks.json`, `lib/verdicts.sh`, `lib/matchers.sh`
byte-identical to HEAD (`git diff --quiet hooks lib` exits 0, confirmed after
the mutation/restore cycle). Untracked zero-byte/char-device dotfiles at the
repo root are sandbox masks from this session, not real files — left alone.
