#!/usr/bin/env python3
"""Layer 2 corpus replay: measure the shipped shell matchers (lib/matchers.sh)
against the full local transcript corpus, running the real shell code as the
arbiter on every candidate.

Two-phase, because invoking matchers.sh once per Bash tool result (~21,000 of
them) is ~21,000 process spawns and blows the 10-minute cap:

  extract   - walk ~/.claude/projects, reconstruct Bash tool_use/tool_result
              pairs (same pairing as
              plans/2026-09-02-sandbox-detector-replay.py), apply an
              over-broad substring prefilter, write survivors to
              individual files under a scratch dir plus a JSONL manifest
              carrying each call's dangerouslyDisableSandbox flag.
  aggregate - given the verdicts a shell loop produced by running matchers.sh
              over each survivor file, join back to the manifest and print
              per-verdict hit counts, how many of them ran with the flag set,
              top projects, and each hit's transcript line.

Usage:
  python3 tests/corpus-eval.py extract --outdir DIR
  # then, in bash (detect prints one verdict per line; aggregate reads one
  # line per file, its verdicts blank-separated, so tr joins them):
  #   for f in DIR/survivors/*; do
  #     v=$(bash lib/matchers.sh <"$f" | tr '\n' ' ')
  #     [ -n "$v" ] && printf '%s\t%s\n' "$(basename "$f")" "$v" >>DIR/verdicts.tsv
  #   done
  python3 tests/corpus-eval.py aggregate --outdir DIR
"""

import argparse
import collections
import json
import re
from pathlib import Path

PROJECTS = Path.home() / ".claude" / "projects"

MASKED = [
    ".bash_profile", ".bashrc", ".gitconfig", ".idea", ".mcp.json", ".profile",
    ".ripgreprc", ".vscode", ".zprofile", ".zshrc",
    ".claude/agents", ".claude/commands", ".claude/hooks", ".claude/launch.json",
    ".claude/loop.md", ".claude/output-styles", ".claude/routines",
    ".claude/scheduled_tasks.json", ".claude/skills", ".claude/workflows",
    ".git/config.lock", ".git/config.worktree",
]

# Deliberately over-broad: strictly broader than any matcher in matchers.sh,
# and than the candidate detectors' discriminators in
# docs/references/detectors.md and readonly-path.md, so nothing a matcher
# would catch is dropped before it sees it. The candidates' strings follow the shipped ones.
PREFILTER_SUBSTRINGS = [
    "File exists",
    "could not lock config file",
    "can only add regular files",
    "crw-",
    "Read-only file system",
    "Device or resource busy",
    "Permission denied",
    "No such file or directory",
    "No conversation found",
    "no active session",
    "apply-seccomp",
] + MASKED


def result_is_error(entry, block):
    if block.get("is_error"):
        return True
    tur = entry.get("toolUseResult")
    if isinstance(tur, dict):
        code = tur.get("exitCode", tur.get("exit_code"))
        if isinstance(code, int) and code != 0:
            return True
        if tur.get("is_error") or tur.get("isError"):
            return True
    c = block.get("content")
    if isinstance(c, str):
        m = re.match(r"Exit code (\d+)", c)
        if m and m.group(1) != "0":
            return True
    return False


def result_text(entry, block):
    parts = []
    c = block.get("content")
    if isinstance(c, str):
        parts.append(c)
    elif isinstance(c, list):
        for b in c:
            if isinstance(b, dict) and isinstance(b.get("text"), str):
                parts.append(b["text"])
    tur = entry.get("toolUseResult")
    if isinstance(tur, dict):
        for k in ("stdout", "stderr"):
            v = tur.get(k)
            if isinstance(v, str) and v not in parts:
                parts.append(v)
    return "\n".join(parts)


def prefilter_hit(text):
    return any(s in text for s in PREFILTER_SUBSTRINGS)


def cmd_extract(args):
    outdir = Path(args.outdir)
    survdir = outdir / "survivors"
    survdir.mkdir(parents=True, exist_ok=True)
    manifest_path = outdir / "manifest.jsonl"
    denom_path = outdir / "denominators.json"

    files = sorted(PROJECTS.rglob("*.jsonl"))
    projects = set(p.relative_to(PROJECTS).parts[0] for p in files)

    bash_uses = bash_results = survivors = 0
    bad = 0
    counter = 0

    with open(manifest_path, "w", encoding="utf-8") as manifest:
        for path in files:
            project = path.relative_to(PROJECTS).parts[0]
            bash_cmds = {}
            # tool_use_id -> the call's dangerouslyDisableSandbox, joined onto
            # its result: a candidate's flag policy gates on it (FR-5).
            bash_flags = {}
            try:
                fh = path.open(encoding="utf-8", errors="replace")
            except OSError:
                continue
            with fh:
                for lineno, line in enumerate(fh, 1):
                    try:
                        e = json.loads(line)
                    except Exception:
                        bad += 1
                        continue
                    msg = e.get("message")
                    if not isinstance(msg, dict):
                        continue
                    content = msg.get("content")
                    if not isinstance(content, list):
                        continue
                    ts = e.get("timestamp", "")
                    sess = e.get("sessionId") or e.get("session_id") or ""
                    for b in content:
                        if not isinstance(b, dict):
                            continue
                        if b.get("type") == "tool_use" and b.get("name") == "Bash":
                            inp = b.get("input") or {}
                            cmd = inp.get("command")
                            if not isinstance(cmd, str):
                                continue
                            bash_uses += 1
                            bash_cmds[b.get("id")] = cmd
                            bash_flags[b.get("id")] = (
                                inp.get("dangerouslyDisableSandbox") is True)
                        elif b.get("type") == "tool_result":
                            tid = b.get("tool_use_id")
                            if tid not in bash_cmds:
                                continue
                            bash_results += 1
                            text = result_text(e, b)
                            if not text or not prefilter_hit(text):
                                continue
                            survivors += 1
                            counter += 1
                            fname = f"{counter:06d}.txt"
                            (survdir / fname).write_text(text, encoding="utf-8")
                            err = result_is_error(e, b)
                            manifest.write(json.dumps({
                                "file": fname,
                                "project": project,
                                "session": sess,
                                "ts": ts,
                                "err": err,
                                "flag": bash_flags.get(tid, False),
                                "command": bash_cmds[tid][:800],
                                "path": str(path.relative_to(PROJECTS)),
                                "line": lineno,
                            }) + "\n")

    denom = {
        "jsonl_files": len(files),
        "projects_total": len(projects),
        "bash_tool_use": bash_uses,
        "bash_tool_result": bash_results,
        "prefilter_survivors": survivors,
        "unparsable_lines": bad,
    }
    denom_path.write_text(json.dumps(denom, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(denom, indent=2))
    print(f"\nsurvivors written to {survdir}")
    print(f"manifest written to {manifest_path}")


def cmd_aggregate(args):
    outdir = Path(args.outdir)
    manifest_path = outdir / "manifest.jsonl"
    verdicts_path = outdir / "verdicts.tsv"

    manifest = {}
    with open(manifest_path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            rec = json.loads(line)
            manifest[rec["file"]] = rec

    verdicts = collections.defaultdict(list)  # verdict -> [file, ...]
    file_verdicts = collections.defaultdict(list)  # file -> [verdict, ...]
    with open(verdicts_path, encoding="utf-8") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line:
                continue
            fname, vs = line.split("\t", 1)
            for v in vs.split():
                verdicts[v].append(fname)
                file_verdicts[fname].append(v)

    print(f"survivor files in manifest: {len(manifest)}")
    print(f"survivor files with a verdict line: {len(file_verdicts)}")
    print()

    # A manifest written before the flag join has no "flag": read it as
    # unset, as the hook reads an absent flag.
    print(f"{'verdict':<20} {'hits':>5} {'flag':>5}   top projects")
    for v in sorted(verdicts):
        fnames = verdicts[v]
        flagged = sum(1 for f in fnames if manifest[f].get("flag"))
        per_project = collections.Counter(manifest[f]["project"] for f in fnames)
        top = per_project.most_common(3)
        top_s = ", ".join(f"{p.lstrip('-')}:{n}" for p, n in top)
        print(f"{v:<20} {len(fnames):>5} {flagged:>5}   {top_s}")

    print()
    print("Full per-hit detail (verdict, flag, project, ts, command, file, "
          "transcript:line):")
    for v in sorted(verdicts):
        print(f"\n=== {v} ===")
        for f in verdicts[v]:
            rec = manifest[f]
            flag = "flag" if rec.get("flag") else "-"
            print(f"  {flag:<4}  {rec['project']}  {rec['ts']}  "
                  f"{rec['command'][:120]!r}  -> {f}  "
                  f"{rec['path']}:{rec.get('line', '?')}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    ex = sub.add_parser("extract")
    ex.add_argument("--outdir", required=True)
    ex.set_defaults(func=cmd_extract)

    ag = sub.add_parser("aggregate")
    ag.add_argument("--outdir", required=True)
    ag.set_defaults(func=cmd_aggregate)

    args = ap.parse_args()
    args.func(args)
