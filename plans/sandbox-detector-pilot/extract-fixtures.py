#!/usr/bin/env python3
"""Cut layer-2 fixtures out of the transcript corpus.

Layer 1 replayed candidate matchers over ~/.claude/projects and classified the
hits; this pulls the *recorded output* of a curated subset back out, verbatim,
as one file per case. The ordering matters: hand-writing these first would
encode what the output was expected to look like rather than what it is.

Each SPEC entry names a project, a day, a substring of the Bash command, and a
substring the recorded output must contain -- enough to identify one call
uniquely without pinning a session id.

Usage: python3 plans/sandbox-detector-pilot/extract-fixtures.py
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
            msg = e.get("message")
            if not isinstance(msg, dict):
                continue
            content = msg.get("content")
            if not isinstance(content, list):
                continue
            day = e.get("timestamp", "")[:10]
            for b in content:
                if not isinstance(b, dict):
                    continue
                if b.get("type") == "tool_use" and b.get("name") == "Bash":
                    c = (b.get("input") or {}).get("command")
                    if isinstance(c, str):
                        cmds[b.get("id")] = c
                elif b.get("type") == "tool_result":
                    cmd = cmds.get(b.get("tool_use_id"))
                    if cmd is None:
                        continue
                    t = b.get("content")
                    if isinstance(t, list):
                        t = "\n".join(x.get("text", "") for x in t
                                      if isinstance(x, dict))
                    if isinstance(t, str):
                        yield day, cmd, t


def pick(project, day, cmd_sub, out_sub, negate_out, prefer, lo, hi):
    projects = [project] if project else [
        d.name for d in sorted(PROJECTS.iterdir()) if d.is_dir()
    ]
    best = None
    for proj in projects:
        for d, cmd, out in iter_calls(proj):
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
    missing = []
    for name, project, day, cmd_sub, out_sub, prefer, lo, hi in SPEC:
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
        print(f"{name:<32} {len(out):>7}B  {(project or '*').lstrip('-')} {d}")
    if missing:
        print("\nNOT FOUND: " + ", ".join(missing), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
