#!/usr/bin/env bash
set -euo pipefail

# Runs the bats suites under a chosen bash — by default /bin/bash, which on a
# Mac is Apple's 3.2.57 while `env bash` usually finds Homebrew's 5.x first.
# bats, its libexec helpers and every script under test start with
# `#!/usr/bin/env bash`, and the tests call `bash` by name, so a `bash` link
# first on PATH moves all of them at once.
#
# Usage: run-bats-under.sh [<bash>] [<bats-args...>]   (default: /bin/bash tests/)

bash_bin=/bin/bash
case "${1:-}" in
    */bash*) bash_bin=$1; shift ;;
esac
[ "$#" -gt 0 ] || set -- tests/
[ -x "$bash_bin" ] || { echo "run-bats-under: no executable bash at $bash_bin" >&2; exit 2; }

# Xs last: BSD mktemp randomises only a trailing run of them.
shim="$(mktemp -d "${TMPDIR:-/tmp}/sandbox-lies-bash.XXXXXX")"
trap 'rm -rf "$shim"' EXIT
ln -s "$bash_bin" "$shim/bash"
PATH="$shim:$PATH"
export PATH

# Proves the link is what `env bash` now resolves to, so a run reported as
# 3.2 really was one.
# shellcheck disable=SC2016 # expands in the child bash, not here
version=$(env bash -c 'printf %s "$BASH_VERSION"')
echo "bats under $bash_bin (bash $version)"

# Not exec: the EXIT trap removes the shim once the run is over.
"$(dirname "$0")/run-bats.sh" "$@"
