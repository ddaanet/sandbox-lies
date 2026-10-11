import 'plugin-dev/release.just'

# Each check runs through `report`, which records its name; a clean run ends
# with the list of checks that passed, and a failing one stops at that check
# with the check's own output.
[doc('Checks that run before every commit.')]
precommit:
    #!/usr/bin/env bash
    set -euo pipefail
    passed=""
    report() {
        local name="$1"
        shift
        "$@"
        passed="${passed:+$passed, }$name"
    }
    # lint_paths: tracked and untracked-unignored paths matching the
    # pathspecs, so a new file is linted before its first commit (wider than
    # scripts/lib/tracked.sh's tracked-only list), NUL-delimited through a
    # file so names with whitespace survive and a git failure stops the gate.
    list=$(mktemp "${TMPDIR:-/tmp}/sandbox-lies-precommit.XXXXXX")
    trap 'rm -f "$list"' EXIT
    lint_paths() {
        git ls-files -z --cached --others --exclude-standard -- "$@" >"$list"
        files=()
        while IFS= read -r -d '' f; do files+=("$f"); done <"$list"
    }
    each_bash_n() {
        local f
        for f in "$@"; do bash -n "$f"; done
    }
    report plugin.json jq empty .claude-plugin/plugin.json
    report hooks.json jq empty hooks/hooks.json
    lint_paths '*.sh' '*.bash' '*.bats'
    report shellcheck shellcheck "${files[@]}"
    lint_paths '*.sh'
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

# Hard-wrap the markdown in scope (.rumdl.toml) at 80 columns.
format-docs:
    rumdl fmt -q --no-cache

# The bats suites, failures only (full TAP log path on the last line).
test:
    scripts/run-bats.sh tests/

# Checks that run before a release. Add slow or paid checks here.
prerelease: precommit
