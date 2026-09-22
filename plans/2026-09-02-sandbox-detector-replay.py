#!/usr/bin/env python3
"""Layer 1 of the sandbox-detector pilot: replay candidate matchers over the
local transcript corpus.

Walks every JSONL under ~/.claude/projects, reconstructs each Bash tool_use ->
tool_result pair, and runs the candidate matchers for the three piloted
detectors over the real history:

  A  .git/index.lock          PostToolUse, matches the error string
  B  phantom dotfiles         PostToolUse, matches output content
  C  sandboxed `claude -p`    PreToolUse,  matches the command

Prints a hit count per matcher and writes every hit (command + the matching
excerpt) to a JSONL sample file for hand classification.

Usage: python3 plans/2026-09-02-sandbox-detector-replay.py [--out FILE] [--sample N]
"""

import argparse
import collections
import json
import re
import sys
from pathlib import Path

PROJECTS = Path.home() / ".claude" / "projects"

# ---------------------------------------------------------------- detector A

# the exact git string, generalised over which lockfile
A_LOCK = re.compile(r"[Uu]nable to create '([^']*\.lock)': File exists")
# `git config` / `git branch -d` shape, same cause
A_CONFIG_LOCK = re.compile(r"could not lock config file ([^\n:]+): File exists")
# the naive net, for comparison: any mention of a lockfile path
A_NAIVE = re.compile(r"\.git/[\w.-]*\.lock")
# the string as git actually emits it: a diagnostic at the head of a line,
# not the same words quoted inside prose or backticks
A_STRICT = re.compile(
    r"(?:^|\n)(?:fatal|error): Unable to create '[^']*\.lock': File exists", re.M
)
# git's follow-on sentence, which a prose quotation almost never carries
A_FOLLOWON = re.compile(
    r"Another git process seems to be running in this repository"
)

# ---------------------------------------------------------------- detector B

# the 22 measured mask paths (2026-08-15, gitlore project root)
MASKED = [
    ".bash_profile", ".bashrc", ".gitconfig", ".idea", ".mcp.json", ".profile",
    ".ripgreprc", ".vscode", ".zprofile", ".zshrc",
    ".claude/agents", ".claude/commands", ".claude/hooks", ".claude/launch.json",
    ".claude/loop.md", ".claude/output-styles", ".claude/routines",
    ".claude/scheduled_tasks.json", ".claude/skills", ".claude/workflows",
    ".git/config.lock", ".git/config.worktree",
]
MASKED_SET = set(MASKED)
# a masked name as a standalone path token
B_TOKEN = re.compile(
    r"(?<![\w./-])(" + "|".join(re.escape(m) for m in MASKED) + r")/?(?![\w.-])"
)
# git refusing a char device / non-regular file
B_GITADD = re.compile(
    r"can only add regular files, symbolic links or git-directories"
)
# a char-device stat in an `ls -l` listing
B_CHARDEV = re.compile(r"^\s*c[rwx-]{9}[.+@]?\s", re.M)
# a porcelain/long-format untracked line naming a masked path
B_UNTRACKED = re.compile(
    r"^(?:\?\?\s+|\s*(?:new file:|\s{4,}))(" +
    "|".join(re.escape(m) for m in MASKED) + r")/?\s*$",
    re.M,
)

# ---------------------------------------------------------------- detector C

# segment splitter mirroring excludedCommands' cut points (top level only)
C_SPLIT = re.compile(r"&&|\|\||\||;|&|\n")
# a `claude` invocation in print mode
C_CLAUDE_P = re.compile(r"(?<![\w./-])claude\b(?=[^\n]*?(?<![\w-])(-p|--print)(?![\w-]))")
# any `claude` invocation at all
C_CLAUDE = re.compile(r"(?<![\w./-])claude\b")
# nesting the exclusion never descends into
C_NEST = re.compile(r"\$\(|\(\s|`|sh\s+-c|bash\s+-c|\bif\b")
# recipes and scripts known to run claude internally
C_RECIPE = re.compile(r"(?<![\w-])just\s+(evals|release|prerelease|precommit)(?![\w-])")
# wrapper commands the matcher unwraps before comparing
C_WRAPPERS = {"timeout", "time", "nice", "stdbuf", "nohup", "command", "builtin",
              "noglob", "env", "xargs"}


def top_level_segments(cmd):
    """Split like excludedCommands does: cut at the shell operators, never
    descend into nesting. Approximate (no tree-sitter), which is the point --
    the replay measures the approximation."""
    return [s.strip() for s in C_SPLIT.split(cmd) if s.strip()]


def command_word(seg):
    """Strip leading VAR=value assignments and wrapper commands."""
    toks = seg.split()
    i = 0
    while i < len(toks):
        t = toks[i]
        if re.match(r"^[A-Za-z_][\w]*=", t):
            i += 1
            continue
        if t in C_WRAPPERS:
            i += 1
            continue
        break
    return toks[i] if i < len(toks) else ""


def excerpt(text, m, pad=140):
    a = max(0, m.start() - pad)
    b = min(len(text), m.end() + pad)
    return text[a:b].replace("\n", "\\n")


def match_result(text, err, reader):
    """Run the PostToolUse matchers over one Bash tool_result. Yields
    (matcher, excerpt) pairs."""
    m = A_LOCK.search(text)
    if m:
        yield "A1_lockfile", excerpt(text, m)
        if err and not reader:
            yield "A1g_lockfile_gated", excerpt(text, m)
    m = A_STRICT.search(text)
    if m:
        yield "A1s_anchored", excerpt(text, m)
    if A_LOCK.search(text) and A_FOLLOWON.search(text):
        yield "A1f_followon", excerpt(text, A_LOCK.search(text))
    if m and A_FOLLOWON.search(text):
        yield "A1sf_anchored_followon", excerpt(text, m)
    m = A_CONFIG_LOCK.search(text)
    if m:
        yield "A2_configlock", excerpt(text, m)
        if err and not reader:
            yield "A2g_configlock_gated", excerpt(text, m)
    m = A_NAIVE.search(text)
    if m:
        yield "A3_naive_lockpath", excerpt(text, m)

    m = B_GITADD.search(text)
    if m:
        yield "B1_gitadd_refused", excerpt(text, m)
        if err and not reader:
            yield "B1g_gitadd_gated", excerpt(text, m)
    m = B_CHARDEV.search(text)
    if m:
        yield "B2_chardev_listing", excerpt(text, m)

    untracked = {mm.group(1) for mm in B_UNTRACKED.finditer(text)}
    if len(untracked) >= 2:
        yield "B3_untracked_masked_2", ",".join(sorted(untracked))
        if not reader:
            yield "B3g_untracked_masked_2_nr", ",".join(sorted(untracked))
    if len(untracked) >= 5:
        yield "B3_untracked_masked_5", ",".join(sorted(untracked))

    anywhere = {mm.group(1) for mm in B_TOKEN.finditer(text)}
    if len(anywhere) >= 2:
        yield "B4_naive_anywhere_2", ",".join(sorted(anywhere))
    if len(anywhere) >= 5:
        yield "B4_naive_anywhere_5", ",".join(sorted(anywhere))


def claude_p_segments(cmd):
    """Faithful to excludedCommands: compare only the command word of each
    top-level segment, never the rest of the line and never a heredoc body."""
    out = []
    for seg in top_level_segments(cmd):
        if command_word(seg) != "claude":
            continue
        toks = seg.split()
        if any(t in ("-p", "--print") for t in toks):
            out.append(seg)
    return out


def match_command(cmd):
    """Run the PreToolUse matchers over one Bash command. Yields
    (matcher, excerpt) pairs."""
    for seg in claude_p_segments(cmd):
        yield "C4_claude_p_commandword", seg[:300]
    if not C_CLAUDE.search(cmd):
        if C_RECIPE.search(cmd):
            yield "C2_recipe_runs_claude", cmd[:300]
        return

    segs = top_level_segments(cmd)
    # would `claude:*` cover every claude invocation in this call?
    covered = all(
        command_word(s) == "claude" or not C_CLAUDE.search(s) for s in segs
    )
    nested = bool(C_NEST.search(cmd))

    if C_CLAUDE_P.search(cmd):
        if not covered or nested:
            yield "C1_claude_p_uncovered", cmd[:300]
        else:
            yield "C1b_claude_p_covered", cmd[:300]
    else:
        yield "C3_claude_other", cmd[:300]

    if C_RECIPE.search(cmd):
        yield "C2_recipe_runs_claude", cmd[:300]


# a command whose whole job is to read a file: its output quoting an error
# string is documentation, not a symptom
READER = re.compile(
    r"^(cat|sed|head|tail|bat|less|awk|grep|rg|wc|jq|python3?|diff|git\s+show|"
    r"git\s+log|git\s+diff)(?![\w-])"
)


def is_reader(cmd):
    """True when every top-level segment is a file reader."""
    segs = top_level_segments(cmd)
    return bool(segs) and all(READER.match(command_word(s) + " " + s) or
                              READER.match(s) for s in segs)


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="plans/2026-09-02-sandbox-detector-hits.jsonl")
    ap.add_argument("--sample", type=int, default=0,
                    help="cap stored hits per matcher (0 = unlimited)")
    args = ap.parse_args()

    files = sorted(PROJECTS.rglob("*.jsonl"))
    hits = collections.Counter()
    per_project = collections.defaultdict(collections.Counter)
    bash_uses = bash_results = 0
    bad = 0
    stored = collections.Counter()
    out = open(args.out, "w", encoding="utf-8")

    for path in files:
        project = path.relative_to(PROJECTS).parts[0]
        # tool_use_id -> command, for Bash calls only
        bash_cmds = {}
        try:
            fh = path.open(encoding="utf-8", errors="replace")
        except OSError:
            continue
        with fh:
            for line in fh:
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
                        cmd = (b.get("input") or {}).get("command")
                        if not isinstance(cmd, str):
                            continue
                        bash_uses += 1
                        bash_cmds[b.get("id")] = cmd
                        for matcher, ex in match_command(cmd):
                            hits[matcher] += 1
                            per_project[matcher][project] += 1
                            if not args.sample or stored[matcher] < args.sample:
                                stored[matcher] += 1
                                out.write(json.dumps({
                                    "matcher": matcher, "project": project,
                                    "ts": ts, "session": sess,
                                    "command": cmd[:400], "excerpt": ex,
                                }) + "\n")
                    elif b.get("type") == "tool_result":
                        tid = b.get("tool_use_id")
                        if tid not in bash_cmds:
                            continue
                        bash_results += 1
                        text = result_text(e, b)
                        if not text:
                            continue
                        err = result_is_error(e, b)
                        reader = is_reader(bash_cmds[tid])
                        for matcher, ex in match_result(text, err, reader):
                            hits[matcher] += 1
                            per_project[matcher][project] += 1
                            if not args.sample or stored[matcher] < args.sample:
                                stored[matcher] += 1
                                out.write(json.dumps({
                                    "matcher": matcher, "project": project,
                                    "ts": ts, "session": sess, "err": err,
                                    "reader": reader,
                                    "command": bash_cmds[tid][:400],
                                    "excerpt": ex,
                                }) + "\n")
    out.close()

    print(f"files            {len(files)}")
    print(f"projects         {len(set(p.relative_to(PROJECTS).parts[0] for p in files))}")
    print(f"Bash tool_use    {bash_uses}")
    print(f"Bash tool_result {bash_results}")
    print(f"unparsable lines {bad}")
    print()
    width = max((len(k) for k in hits), default=10)
    for matcher in sorted(hits):
        top = per_project[matcher].most_common(3)
        top_s = ", ".join(f"{p.lstrip('-')}:{n}" for p, n in top)
        print(f"{matcher:<{width}}  {hits[matcher]:>6}   {top_s}")
    print(f"\nhits written to {args.out}")


if __name__ == "__main__":
    main()
