# Brief: on Linux, a dead sandbox leaves its masks as real files on disk

From a devddaanet session, 2026-11-14. Observed on the Debian host `dev`
(Claude Code command sandbox = bwrap).

## Observation

bwrap mounts each mask over a mount-point file it creates on the host
filesystem. For `.git/config.lock` that file is empty, mode `0444`, owned by
the user. When the sandboxed session dies uncleanly, the mount goes away and
the mount-point file **stays on disk**:

- `~/code/shell-gotchas/.git/config.lock` on dev: empty, `-r--r--r--`, dated
  2026-11-05, listed in no `/proc/*/mountinfo`. A plain `rm` removed it.
- `~/code/sandbox-lies/.git/config.lock`, same shape, dated 2026-11-13, *was*
  listed in several `/proc/*/mountinfo` (live sessions): a live mask, left
  alone.

While the leftover exists, every `git config` write in that repo, sandboxed or
not, fails with `error: could not lock config file .git/config: File exists`.
A caller that does `git config … || true` fails silently for as long as the
file stays (here, nine days, through repeated syncs).

## Why it matters to sandbox-lies

- It contradicts the macOS-observed rule (in the shared ddaanet memory
  `sandbox-effects`, and possibly the skill) that a mask outliving its command
  "is a leak, a restart clears it, and deleting it is neither possible nor the
  remedy". On Linux the leftover is a real file on disk and `rm` removes it.
  Whether a Claude Code restart would also have cleared it is untested: no
  restart is known to have happened on dev between 2026-11-05 and the removal,
  and nine days passed with the file in place.
- The symptom is a git lock error, not a phantom dotfile in `git status`, so
  nothing in the skill's mask material is reached from it today
  (`masks-and-gates.md` has no `config.lock` / Linux / bwrap mention).

## Proposed content (skill's call)

How to tell a leftover from a live mask, and the remedy:

```bash
ls -la <repo>/.git/config.lock                       # empty, 0444 → mask-shaped
grep -h "<repo>/.git/config.lock" /proc/*/mountinfo  # listed → live: leave it
rm <repo>/.git/config.lock                           # not listed → leftover: delete
```

Possibly a hook detector on `could not lock config file … File exists` that
points at this check. Whether other mask paths leave files the same way was
not checked.
