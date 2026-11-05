import 'plugin-dev/release.just'
import 'plugin-dev/gates.just'

# The directories gate-code owns: everything the hook, the scripts and the
# suites are made of. Every other tracked top-level entry belongs to gate-docs
# (derived at run time, below). tests/helpers/sweep.bash holds the same list for
# the FR-11 sweep, which splits along it; tests/sweep-code.bats pins the two.
code_dirs := "lib hooks scripts bin tests plugin-dev"

# `precommit` holds no sentinel: it runs the uncached checks, then the two gates
# below, each its own recipe (a second sentinel in one body is refused) with its
# own inputs, so a prose-only commit does not pay for shellcheck and the code
# suites, and a code-only commit does not pay for the prose sweep. Each gate
# skips itself, printing "cached", while no input it reads has changed
# (sentinel-guard; plugin-dev/manual/gates.md), and ends with the list of checks
# that passed.
[doc('Checks that run before every commit.')]
precommit: check-refs check-size check-frontmatter task-files gate-docs gate-code
    @printf 'precommit passed: check-refs, check-size, check-frontmatter, task-files, gate-docs, gate-code\n'

# Everything that is not code: the manifest, the wrap check, the link check and
# the FR-11 sweep over the docs side (tests/docs.bats).
#
# Inputs. Every tracked top-level entry that is not a code dir, not a gitlink
# (the memory tier is hashed by name only and docs.bats skips gitlinks) and not
# the root TASK.md or TODO.md (`just task-files` covers those, so editing either
# leaves this pass standing), derived from the index so a new tracked directory
# or root file is hashed with no edit here. Tracked entries only: a bare root
# glob would hash untracked sandbox masks such as a root .bashrc. Plus root
# markdown, tracked or not, as the hash listed it before. Plus the code files
# these checks run, which sit in code dirs: the matchers and the sweep suite
# with the helpers it loads, and the link check with the two files it sources.
# A change to one reruns both gates, since gate-code reads some of them too.
# rumdl is pinned by uv.lock, which is an input, so it has no version line.
#
# The tool lines are set here, before the guard, because the hash reads
# PLUGIN_DEV_GATE_TOOLS when it is taken; tests/gate-coverage.bats proves each
# gate's value reaches its own hash. Beside the versions, the tracked set of the
# docs side by name: the hash lists tracked and untracked files alike, while
# check-links and tests/docs.bats walk tracked files only, so without it a pass
# taken before `git add` of a new file stays cached after it. Those checks keep
# to tracked files, against plugin-dev/manual/gates.md's advice: walking
# untracked ones would let an unrelated draft block a commit it is not part of.
[doc('Docs-side checks: manifest, wrap, links and the docs sweep.')]
gate-docs:
    #!{{ plugin_dev_gate_prolog }}
    code_dirs=({{ code_dirs }})
    index=$(mktemp "${TMPDIR:-/tmp}/sandbox-lies-docs-index.XXXXXX")
    tops=$(mktemp "${TMPDIR:-/tmp}/sandbox-lies-docs-tops.XXXXXX")
    trap 'rm -f "$index" "$tops"' EXIT
    # NUL-delimited through files, so names with whitespace survive and a git
    # failure stops the gate. `-s` prefixes each path with `<mode> <object>
    # <stage>` and a tab; 160000 is a gitlink.
    git ls-files -z -s >"$index"
    while IFS= read -r -d '' meta; do
        path=${meta#*$'\t'}
        [ "${meta%% *}" != 160000 ] || continue
        case "$path" in TASK.md | TODO.md) continue ;; esac
        top=${path%%/*}
        for d in "${code_dirs[@]}"; do [ "$top" != "$d" ] || continue 2; done
        printf '%s\0' "$top"
    done <"$index" | LC_ALL=C sort -zu >"$tops"
    docs_inputs=()
    while IFS= read -r -d '' top; do docs_inputs+=(":(literal)$top"); done <"$tops"
    excludes=()
    for d in "${code_dirs[@]}"; do excludes+=("':(exclude)$d'"); done
    tools=('bats --version' 'jq --version' 'git --version' 'bash --version'
        "set -o pipefail; git ls-files -z -- . ${excludes[*]} | cksum")
    PLUGIN_DEV_GATE_TOOLS=$(printf '%s\n' "${tools[@]}")
    export PLUGIN_DEV_GATE_TOOLS
    sentinel-guard gate-docs "${docs_inputs[@]}" ':(glob)*.md' \
        ':(exclude)TASK.md' ':(exclude)TODO.md' \
        lib/matchers.sh tests/docs.bats tests/helpers/bsd-stubs.bash \
        tests/helpers/git-env.bash tests/helpers/sweep.bash \
        scripts/check-links.sh scripts/lib/tracked.sh scripts/lib/strip-code.awk
    passed=""
    report() {
        local name="$1"
        shift
        "$@"
        passed="${passed:+$passed, }$name"
    }
    report plugin.json jq empty .claude-plugin/plugin.json
    report rumdl rumdl fmt --check -q --no-cache
    report links scripts/check-links.sh
    report docs.bats plugin-dev/run-bats.sh tests/docs.bats
    printf 'gate-docs passed: %s\n' "$passed"
    record-sentinel

# The code: the hook manifest, shellcheck, `bash -n`, the Python compile check
# and every bats suite but tests/docs.bats.
#
# Inputs: the code dirs, plus the three frozen pilot files under plans/ that
# tests/sweep-code.bats and tests/task-files.bats feed to the matchers. The
# audit of what the suites read outside the code dirs (grep over tests/ for
# every root file and non-code directory, by path, by `$ROOT`, by
# `BATS_TEST_DIRNAME` and by `git ls-files`) found the justfile and the plugin-dev
# files that tests/test-recipe.bats and tests/task-files.bats copy, both always
# hashed; memory/ddaanet/sandbox-effects.md, read by tests/matchers.bats, which
# the line below folds in because the memory tier is a gitlink the hash sees by
# name only ("absent" while the tier is not mounted); and those three plans
# files. No suite reads .claude-plugin/plugin.json, dist.include, pyproject.toml
# or .gitignore: the .gitignore decides which untracked files the hash lists,
# and that already moves the hash. tests/task-files-cache.bats copies the whole
# tree and runs the gates on the copy, which does not make everything an input:
# every check it runs over prose is also run by gate-docs or by an uncached
# dependency, so a stale code pass hides nothing there.
#
# Tool versions, the memory file and the tracked set of the code dirs (a pass
# taken before `git add` of a new file there must not stay cached, as in
# gate-docs) go in PLUGIN_DEV_GATE_TOOLS, set before the guard.
[doc('Code checks: hooks.json, shellcheck, bash -n, python compile and the bats suites.')]
gate-code:
    #!{{ plugin_dev_gate_prolog }}
    code_dirs=({{ code_dirs }})
    tools=('bats --version' 'shellcheck --version' 'jq --version'
        'python3 --version' 'git --version' 'bash --version'
        "set -o pipefail; git ls-files -z -- ${code_dirs[*]} | cksum"
        'f=memory/ddaanet/sandbox-effects.md; if [ -f "$f" ]; then git hash-object -- "$f"; else echo absent; fi')
    PLUGIN_DEV_GATE_TOOLS=$(printf '%s\n' "${tools[@]}")
    export PLUGIN_DEV_GATE_TOOLS
    sentinel-guard gate-code "${code_dirs[@]}" \
        plans/2026-09-02-sandbox-detector-replay.py \
        plans/2026-09-02-sandbox-detector-hits.jsonl \
        plans/2026-09-03-sandbox-matcher-corpus-eval.md
    passed=""
    report() {
        local name="$1"
        shift
        "$@"
        passed="${passed:+$passed, }$name"
    }
    # lint_paths: tracked and untracked-unignored files under the code dirs with
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
            "${code_dirs[@]}" >"$list"
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
    report hooks.json jq empty hooks/hooks.json
    lint_paths sh bash bats
    report shellcheck shellcheck "${files[@]}"
    lint_paths sh
    report 'bash -n' each_bash_n "${files[@]}"
    # tests/corpus-eval.bats and tests/extract-fixtures.bats run the two Python
    # tools, but a syntax error would surface there as scattered case
    # failures. A compile() over each source names it first and, unlike
    # py_compile, writes no bytecode.
    report 'python compile' python3 -c \
        'import sys; [compile(open(f, encoding="utf-8").read(), f, "exec") for f in sys.argv[1:]]' \
        tests/extract-fixtures.py tests/corpus-eval.py
    report suites just _bats code
    printf 'gate-code passed: %s\n' "$passed"
    record-sentinel

# The checks that read TASK.md and TODO.md, which the cached gates do not
# (uncached check-refs and check-size read them too): the detector matchers and
# the link check. Never cached, and a dependency of precommit, so editing either
# file reruns this and leaves the cached gates standing (gate-docs's hash
# excludes both and gate-code's never listed them). The matchers walk the files
# `git ls-files` reports, as the scripts do, and skip one gone from the work
# tree. lib/matchers.sh exits 1 when quiet, 0 with verdict names when firing
# and above 1 when bash itself failed; the file reaches it on fd 3, opened
# apart, because a failed redirection inside the command substitution would
# exit 1 and read as quiet.
[doc('Detector matchers and link check over TASK.md and TODO.md.')]
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
    report links scripts/check-links.sh --task-files
    printf 'task-files passed: %s\n' "$passed"

# Hard-wrap the markdown in scope (.rumdl.toml) at 80 columns.
format-docs:
    rumdl fmt -q --no-cache

# The bats suites, failures only (the full TAP log path is kept on a failure).
# Every suite, tests/docs.bats included: the whole suite for a person running it
# by hand. gate-code runs the same minus tests/docs.bats, which gate-docs owns.
[doc('Every bats suite.')]
test: (_bats "all")

# The shared runner behind `test` and gate-code. suite is `all` (the tests/
# directory) or `code` (every tests/*.bats but docs.bats, by glob, so a new
# suite is in). In parallel where GNU parallel is what `parallel` runs, since
# bats -j without it runs no test and exits non-zero.
[private]
_bats suite:
    #!/usr/bin/env bash
    set -euo pipefail
    version=$(parallel --version 2>/dev/null) || version=
    case "$version" in
        'GNU parallel'*) set -- -j "$(( $(getconf _NPROCESSORS_ONLN) * 2 ))" ;;
    esac
    case {{ quote(suite) }} in
        all) set -- "$@" tests/ ;;
        code)
            for f in tests/*.bats; do
                [ "$f" = tests/docs.bats ] || set -- "$@" "$f"
            done
            ;;
        *) echo "_bats: suite must be all or code" >&2; exit 2 ;;
    esac
    plugin-dev/run-bats.sh "$@"

# The bats suites under /bin/bash: Apple's 3.2.57 on a Mac, where `env bash`
# usually finds Homebrew's.
test-system-bash:
    scripts/run-bats-under.sh /bin/bash tests/

# Checks that run before a release. Add slow or paid checks here.
prerelease: precommit
