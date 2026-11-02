#!/usr/bin/env python3
"""Cut layer-2 fixtures out of the transcript corpus.

Layer 1 replayed candidate matchers over ~/.claude/projects and classified the
hits; this pulls the *recorded output* of a curated subset back out, verbatim,
as one file per case. The ordering matters: hand-writing these first would
encode what the output was expected to look like rather than what it is.

Each SPEC entry names a project, a day, a substring of the Bash command, and a
substring the recorded output must contain -- enough to identify one call
uniquely without pinning a session id.

Usage: python3 tests/extract-fixtures.py [NAME...]

With names, only those fixtures are cut. The corpus keeps growing, so an
entry with no day, or with a size preference, can pick a different call on a
later run; naming the new fixtures leaves the committed ones as recorded.
"""

import json
import sys
from pathlib import Path

PROJECTS = Path.home() / ".claude" / "projects"
OUT = Path(__file__).resolve().parent / "fixtures"

# name, project, day, command substring, required output substring, and a size
# window (min, max) with "short"/"long" preference inside it. A fire fixture
# wants the least incidental content that still carries the symptom; a quiet
# fixture wants realistic bulk, since its job is to survive a matcher.
SPEC = [
    # --- detector A: lockfiles, must fire ---
    ("fire-lock-commit-amend", "-Users-david-code-claude-plugin-dev", "2026-08-13",
     "git commit --amend --no-edit", "Unable to create", "short", 60, 4000),
    ("fire-lock-restore", "-Users-david-code-edify", "2026-01-27",
     "rm -rf plans/docs-to-skills", "Unable to create", "short", 60, 4000),
    ("fire-lock-rebase-inline", "-Users-david-code-edify", "2026-01-28",
     "git rebase -i HEAD~7", "Rebasing", "short", 60, 4000),
    ("fire-lock-piped-tail", "-Users-david-code-gitlore", "2026-08-13",
     "git commit --amend --no-edit 2>&1 | tail", "Unable to create", "short", 60, 4000),
    ("fire-lock-add-commit", "-Users-david-code-micro", "2026-07-20",
     "git add tools/ghmem && git commit", "Unable to create", "short", 60, 4000),
    ("fire-configlock-remote-add", "-Users-david-code-prohibitions", "2026-08-11",
     "git remote add origin", "could not lock config file", "short", 60, 4000),
    ("fire-configlock-fetch", "-Users-david-code-onekeys", "2026-08-13",
     "git config fetch.recurseSubmodules no", "could not lock config file", "short", 60, 4000),
    # flag absent, yet unsandboxed: `excludedCommands` covers the recipe, whose
    # preflight refuses a sandbox, and the lock was gone a moment later
    ("fire-lock-release-excluded", "-Users-david-code-sandbox-lies", "2026-11-01",
     "just release minor", "Unable to create", "short", 60, 4000),

    # --- detector B: phantom dotfiles, must fire ---
    ("fire-masks-porcelain", "-Users-david-code-gitlore", "2026-08-13",
     "git status --porcelain", "?? .bash_profile", "short", 60, 4000),
    ("fire-masks-two-names", "-Users-david-code-micro", "2026-09-02",
     "git mv docs/superpowers/specs", "?? .bash_profile", "short", 60, 4000),
    ("fire-masks-chardev-explicit", "-Users-david-code-gitlore", "2026-08-15",
     "ls -la /Users/david/code/gitlore/.bashrc", "crw-rw-rw-", "short", 60, 4000),
    ("fire-masks-chardev-incidental", "-Users-david-code-Emploi", "2026-08-10",
     "ls -la /Users/david/code/Emploi/", "crw-rw-rw-", "short", 60, 4000),
    ("fire-masks-gitadd-refused", "-Users-david-code-edify", "2026-08-10",
     "git add -A", "can only add regular files", "short", 60, 4000),

    # --- must NOT fire: the store documenting its own error strings ---
    ("quiet-memory-file-read", "-Users-david-code-micro", "2026-07-31",
     "cat sandbox-effects.md", "Unable to create", "long", 4000, 40000),
    ("quiet-index-line-read", "-Users-david-code-onekeys", None,
     "memory/MEMORY.md", "Unable to create", "short", 3000, 40000),
    ("quiet-bats-fixture-grep", "-Users-david-code-gitlore", "2026-08-25",
     "grep -n \"justfile\" tests/justfile_gates.bats", "can only add regular files", "long", 1000, 20000),

    # --- must NOT fire: healthy output of the same commands ---
    ("quiet-clean-status", "-Users-david-code-gitlore", None,
     "git status --porcelain", "?? plans/", "long", 200, 4000),
    ("quiet-clean-ls", "-Users-david-code-gitlore", None,
     "ls -la", None, "long", 200, 4000),

    # --- a report *about* the symptoms, which is a recurring class ---
    ("quiet-pilot-report-echo", "-Users-david-code-gitlore", "2026-09-02",
     "python3 - <<", "A2_configlock", "long", 500, 20000),

    # --- detector C's false-positive class, kept as evidence ---
    ("quiet-heredoc-claude-p", "-Users-david-code-prohibitions", "2026-08-27",
     "claude -p ping)", None, "long", 200, 4000),

    # --- candidates shipping under D-15 (Item 3.2), each a fire and a
    # near-miss the discriminator in docs/references/detectors.md (for
    # readonly-path, docs/references/readonly-path.md) rejects ---
    ("fire-tmpdir-unset-redirect", "-Users-david-code-devddaanet", "2026-09-02",
     '> "$TMPDIR/live.conf"', "/live.conf: Permission denied",
     "short", 40, 4000),
    ("fire-tmpdir-unset-cp-stat", "-Users-david-code-micro", "2026-07-04",
     'cp "$TMPDIR/micro-build"', "/micro-build'", "short", 40, 4000),
    # the bare-after-prefix shape with no "line N:" locator
    # (item-4-2-s1-code-review.md gap a)
    ("fire-tmpdir-unset-bash-bare", "-Users-david-code-devddaanet", "2026-09-13",
     "move-strays.sh", "No such file or directory", "short", 40, 4000),
    # a missing-file refusal on a path deeper than one component, flag set
    ("quiet-tmpdir-unset-deep-path", "-Users-david-code-micro", "2026-07-22",
     "ls -la /Users/david/code/micro/.git/index.lock 2>&1 ||",
     "No such file or directory", "short", 40, 4000),
    ("fire-resume-lost-two-turn", "-Users-david-code-gitlore", "2026-07-17",
     "mkdir -p restest", "No conversation found with session ID",
     "short", 60, 4000),
    # the memory index line naming the refusal mid-line
    ("quiet-resume-lost-index-line", "-Users-david-code-handoff", "2026-09-20",
     'echo "=== index line:"', "No conversation found", "short", 60, 4000),
    ("fire-seccomp-init-sed", "-Users-david-code-edify", "2026-08-14",
     "sed -n '543,590p' docs/design.md", "apply-seccomp", "short", 40, 4000),
    # the memory file's section heading quoting the failure
    ("quiet-seccomp-init-heading", "-Users-david-code-gitlore", "2026-09-01",
     'grep -n "^## " memory/ddaanet/sandbox-effects.md', "apply-seccomp",
     "short", 60, 4000),
    # a quoted path, as the Item 4.3 probe tests reuse
    ("fire-readonly-path-cp-tmp", "-Users-david-code-handoff", "2026-09-18",
     "cp scripts/checkpoint.py /tmp/checkpoint.py.orig",
     "'/tmp/checkpoint.py.orig'", "short", 40, 4000),
    # a background task's output file read back: a true positive
    ("fire-readonly-path-task-output", "-Users-david-code-gitlore",
     "2026-09-07", "bo7z9uyq2.output", "gitlore-precommit-item11s1.log",
     "short", 40, 4000),
    ("fire-readonly-path-python-errno", "-Users-david-code-gitlore",
     "2026-07-15", "p='hooks/hooks.json'", "[Errno 30]", "short", 40, 4000),
    # git's busy-device refusal: the EBUSY half of the message alternation
    ("fire-readonly-path-git-busy", "-Users-david-code-gitlore", "2026-07-23",
     "git worktree remove /Users/david/code/gitlore/.eval-tmp/head-tree",
     "Device or resource busy", "short", 40, 4000),
    # a checkout that finished, then a config write refused: the command's
    # merge shape with no git partial-checkout error (Item 8.0 slice 5)
    ("fire-readonly-path-git-config-busy", "-Users-david-code-micro",
     "2026-07-09",
     "git checkout -q display-golden-tests && git branch -f softwrapcolumn2",
     "could not write config file", "short", 40, 4000),
    # git's partial-checkout error for a new directory, from the live
    # reproduction in docs/references/readonly-path.md (Item 8.0 slice 5)
    ("fire-readonly-path-git-mkdir", "-Users-david-code-sandbox-lies",
     "2026-09-27", "git -C /tmp/sl8c-wt checkout feat2 2>&1",
     "cannot create directory at", "short", 40, 4000),
    # a checkout that exited 0 with HEAD moved after only an unlink failure on
    # the settings file, then an ff-only merge the stranded copy blocked
    # (plans/2026-10-31-brief-sandboxed-checkout-moves-head.md)
    ("fire-readonly-path-checkout-moved", "-Users-david-code-handoff",
     "2026-10-31", "git checkout main && git merge --ff-only dev",
     "unable to unlink old", "short", 40, 4000),
    # the memory index line naming the message mid-line
    ("quiet-readonly-path-index-line", "-Users-david-code-gitlore",
     "2026-08-13", 'grep -n "claude-plugin-dev" memory/ddaanet/MEMORY.md',
     "inter-device move failed", "short", 60, 4000),
]


def iter_calls(project):
    """Yield (day, command, output) for every Bash call in one project."""
    root = PROJECTS / project
    if not root.is_dir():
        return
    for path in sorted(root.rglob("*.jsonl")):
        cmds = {}
        for line in path.open(encoding="utf-8", errors="replace"):
            try:
                e = json.loads(line)
            except Exception:
                continue
            if not isinstance(e, dict):
                continue
            msg = e.get("message")
            if not isinstance(msg, dict):
                continue
            content = msg.get("content")
            if not isinstance(content, list):
                continue
            ts = e.get("timestamp")
            day = ts[:10] if isinstance(ts, str) else ""
            for b in content:
                if not isinstance(b, dict):
                    continue
                if b.get("type") == "tool_use" and b.get("name") == "Bash":
                    inp = b.get("input")
                    c = inp.get("command") if isinstance(inp, dict) else None
                    if isinstance(c, str) and isinstance(b.get("id"), str):
                        cmds[b.get("id")] = c
                elif b.get("type") == "tool_result":
                    tid = b.get("tool_use_id")
                    cmd = cmds.get(tid) if isinstance(tid, str) else None
                    if cmd is None:
                        continue
                    t = b.get("content")
                    if isinstance(t, list):
                        t = "\n".join(
                            x.get("text") if isinstance(x.get("text"), str) else ""
                            for x in t if isinstance(x, dict))
                    if isinstance(t, str):
                        yield day, cmd, t


def pick(project, day, cmd_sub, out_sub, negate_out, prefer, lo, hi):
    best = None
    for d, cmd, out in iter_calls(project):
        if day and d != day:
            continue
        if cmd_sub not in cmd:
            continue
        if not lo <= len(out) <= hi:
            continue
        if out_sub is not None and out_sub not in out:
            continue
        if negate_out and any(x in out for x in negate_out):
            continue
        if best is None or (
            len(out) < len(best[2]) if prefer == "short"
            else len(out) > len(best[2])
        ):
            best = (d, cmd, out)
    return best


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    wanted = set(sys.argv[1:])
    unknown = wanted - {entry[0] for entry in SPEC}
    if unknown:
        print("NOT IN SPEC: " + ", ".join(sorted(unknown)), file=sys.stderr)
        return 1
    missing = []
    for name, project, day, cmd_sub, out_sub, prefer, lo, hi in SPEC:
        if wanted and name not in wanted:
            continue
        # the "clean" fixtures must be free of every symptom
        negate = None
        if name.startswith("quiet-clean-"):
            negate = ["Unable to create", "could not lock config file",
                      "crw-rw-rw-", "?? .bash", "?? .claude/",
                      "can only add regular files"]
        hit = pick(project, day, cmd_sub, out_sub, negate, prefer, lo, hi)
        if hit is None:
            missing.append(name)
            continue
        d, cmd, out = hit
        path = OUT / (name + ".txt")
        path.write_text(out, encoding="utf-8")
        print(f"{name:<32} {len(out):>7}B  {project.lstrip('-')} {d}")
    if missing:
        print("\nNOT FOUND: " + ", ".join(missing), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
