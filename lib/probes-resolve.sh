#!/usr/bin/env bash
# Node names cited here (lock-detectors.md) are files of the plugin
# repository's docs/references/, which the plugin does not ship.
# lib/probes-resolve.sh — _probe_resolve_path, the relative lock path
# resolution shared by probe_git_lock and probe_config_lock. Sourced by
# lib/probes.sh, so no other caller needs a source line of its own for it.
#
# set -u as in lib/probes.sh; bats does not set it, so setting it here keeps
# an unset variable an error when a caller sources this file directly.
set -u

# Resolves <path> against a base directory: an absolute or empty <path>
# prints unchanged. An empty one is not joined either, because joined it
# would name the base itself, a directory the holder check would then read
# as held by whatever sits in it. A relative <path> is joined onto the
# nearest directory at or above the base holding a `.git` directory, else
# onto the base unchanged. Git prints a relative lock path only from a
# `.git` directory's top-level; from a linked worktree or a submodule, whose
# `.git` is a file, it prints the path absolute, so a `.git` file is walked
# past. The base is <cwd-arg> (the probe's own $2), or the probe's own
# working directory when <cwd-arg> is missing or empty — never `/`; a
# relative base is taken from that working directory too, so each step
# drops one component of an absolute path and the walk ends at `/`, one
# `[ -d ]` per ancestor and no process. Lexical, not canonical. Residuals: a
# base reached through a symlink walks the link's parents, not the target's,
# where git would find the top-level; a base inside a gitdir (bare, or
# `.git` itself), where git prints paths relative to that gitdir, resolves
# against an enclosing worktree when one exists.
_probe_resolve_path() {
    local base dir
    case "$1" in
        /* | '')
            printf '%s\n' "$1"
            return
            ;;
    esac
    dir="${2:-$PWD}"
    case "$dir" in
        /*) ;;
        *) dir="$PWD/$dir" ;;
    esac
    base="$dir"
    while :; do
        if [ -d "$dir/.git" ]; then
            base="$dir"
            break
        fi
        [ "$dir" = / ] && break
        dir="${dir%/*}"
        [ -n "$dir" ] || dir=/
    done
    printf '%s/%s\n' "${base%/}" "$1"
}
