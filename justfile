import 'plugin-dev/release.just'
import 'plugin-dev/gates.just'

# Lines the precommit hash folds in, each a command whose output is hashed.
# Tool versions first: no lockfile pins them. rumdl is pinned by uv.lock, which
# is an input. Then two inputs the hashed file list cannot carry:
# - the tracked set, by name: the hash lists tracked and untracked files alike,
#   while check-line-limits, check-links and tests/docs.bats walk tracked files
#   only, so without it a pass taken before `git add` of a new file stays
#   cached after it. Those checks keep to tracked files, against
#   plugin-dev/manual/gates.md's advice: walking untracked ones would let an
#   unrelated draft block a commit it is not part of;
# - the memory file tests/matchers.bats sweeps, inside the memory gitlink the
#   hash sees by name only ("absent" while the tier is not mounted).
export PLUGIN_DEV_GATE_TOOLS := "bats --version\nshellcheck --version\njq --version\npython3 --version\ngit --version\nbash --version\n" + "set -o pipefail; git ls-files -z | cksum\n" + "f=memory/ddaanet/sandbox-effects.md; if [ -f \"$f\" ]; then git hash-object -- \"$f\"; else echo absent; fi"

# Each check runs through `report`, which records its name; a clean run ends
# with the list of checks that passed, and a failing one stops at that check
# with the check's own output. The gate skips itself, printing "cached", while
# no input it reads has changed (sentinel-guard; plugin-dev/manual/gates.md).
[doc('Checks that run before every commit.')]
precommit: check-refs task-files
    #!{{ plugin_dev_gate_prolog }}
    # gate_dirs: every tracked top-level directory except the memory gitlink,
    # which the hash sees by name only: the one memory file a check reads
    # (tests/matchers.bats) is folded in by PLUGIN_DEV_GATE_TOOLS instead, and
    # docs.bats skips gitlinks. tests/docs.bats sweeps
    # every tracked file, so plans/, inbox/ and .gitlore/ are inputs; the root
    # files are listed by name below, and a new one needs adding.
    gate_dirs=(.claude .claude-plugin .gitlore bin docs hooks inbox lib manual
        plans plugin-dev scripts skills tests)
    sentinel-guard precommit "${gate_dirs[@]}" .envrc .gitignore .gitmodules \
        .rumdl.toml LICENSE dist.include pyproject.toml uv.lock ':(glob)*.md' \
        ':(exclude)TASK.md' ':(exclude)TODO.md'
    passed=""
    report() {
        local name="$1"
        shift
        "$@"
        passed="${passed:+$passed, }$name"
    }
    # lint_paths: tracked and untracked-unignored files under gate_dirs with
    # one of the extensions given, plus every file under bin/, whose shipped
    # scripts are extensionless bash, so a new file is linted before its first
    # commit (wider than scripts/lib/tracked.sh's tracked-only list) and never
    # outside what the hash covers. NUL-delimited through a file so names with
    # whitespace survive and a git failure stops the gate.
    list=$(mktemp "${TMPDIR:-/tmp}/sandbox-lies-precommit.XXXXXX")
    trap 'rm -f "$list"' EXIT
    lint_paths() {
        local f ext
        git ls-files -z --cached --others --exclude-standard -- \
            "${gate_dirs[@]}" >"$list"
        files=()
        while IFS= read -r -d '' f; do
            for ext in "$@"; do
                case "$f" in bin/* | *."$ext") files+=("$f"); break ;; esac
            done
        done <"$list"
    }
    each_bash_n() {
        local f
        for f in "$@"; do bash -n "$f"; done
    }
    report plugin.json jq empty .claude-plugin/plugin.json
    report hooks.json jq empty hooks/hooks.json
    lint_paths sh bash bats
    report shellcheck shellcheck "${files[@]}"
    lint_paths sh
    report 'bash -n' each_bash_n "${files[@]}"
    report rumdl rumdl fmt --check -q --no-cache
    report 'line limits' scripts/check-line-limits.sh
    report links scripts/check-links.sh
    # tests/corpus-eval.bats and tests/extract-fixtures.bats run the two Python
    # tools, but a syntax error would surface there as scattered case
    # failures. A compile() over each source names it first and, unlike
    # py_compile, writes no bytecode.
    report 'python compile' python3 -c \
        'import sys; [compile(open(f, encoding="utf-8").read(), f, "exec") for f in sys.argv[1:]]' \
        tests/extract-fixtures.py tests/corpus-eval.py
    report tests just test
    printf 'precommit passed: %s\n' "$passed"
    record-sentinel

# The checks that read TASK.md and TODO.md, which the cached main gate does not
# (uncached check-refs reads them too): the detector matchers, the line cap and
# the link check. Never cached, and a dependency of precommit, so editing either
# file reruns this and leaves the cached main gate standing (the main gate's
# hash excludes both). The matchers walk the files
# `git ls-files` reports, as the scripts do, and skip one gone from the work
# tree. lib/matchers.sh exits 1 when quiet, 0 with verdict names when firing
# and above 1 when bash itself failed; the file reaches it on fd 3, opened
# apart, because a failed redirection inside the command substitution would
# exit 1 and read as quiet.
[doc('Detector matchers, line cap and link check over TASK.md and TODO.md.')]
task-files:
    #!/usr/bin/env bash
    set -euo pipefail
    passed=""
    report() {
        local name="$1"
        shift
        "$@"
        passed="${passed:+$passed, }$name"
    }
    matchers() {
        local tracked file status verdicts bad=0
        tracked=$(git ls-files -- TASK.md TODO.md)
        while IFS= read -r file; do
            { [ -n "$file" ] && [ -f "$file" ]; } || continue
            if ! exec 3<"$file"; then
                printf 'task-files: cannot read %s\n' "$file" >&2
                bad=1
                continue
            fi
            status=0
            verdicts=$(bash lib/matchers.sh <&3) || status=$?
            exec 3<&-
            if [ "$status" -gt 1 ]; then
                printf 'task-files: matchers exited %s on %s\n' \
                    "$status" "$file" >&2
                bad=1
            elif [ -n "$verdicts" ]; then
                printf 'task-files: %s fires a detector: %s\n' \
                    "$file" "${verdicts//$'\n'/, }" >&2
                bad=1
            fi
        done <<<"$tracked"
        return "$bad"
    }
    report matchers matchers
    report 'line limits' scripts/check-line-limits.sh --task-files
    report links scripts/check-links.sh --task-files
    printf 'task-files passed: %s\n' "$passed"

# Hard-wrap the markdown in scope (.rumdl.toml) at 80 columns.
format-docs:
    rumdl fmt -q --no-cache

# The bats suites, failures only (the full TAP log path is kept on a failure).
# In parallel where GNU parallel is what `parallel` runs, since bats -j without
# it runs no test and exits non-zero.
test:
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(parallel --version 2>/dev/null) || version=
    case "$version" in
        'GNU parallel'*) set -- -j "$(( $(getconf _NPROCESSORS_ONLN) * 2 ))" ;;
    esac
    plugin-dev/run-bats.sh "$@" tests/

# The bats suites under /bin/bash: Apple's 3.2.57 on a Mac, where `env bash`
# usually finds Homebrew's.
test-system-bash:
    scripts/run-bats-under.sh /bin/bash tests/

# Checks that run before a release. Add slow or paid checks here.
prerelease: precommit
