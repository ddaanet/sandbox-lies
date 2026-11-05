## Current task

Making `just precommit` cheaper. Byte caps, the frontmatter check and the split into `gate-docs` and `gate-code` are committed. Measured: a prose-only edit about 49 s; `gate-code` forced on a quiet machine 204 s, of which the new `tests/gate-coverage.bats` is about 45 s alone. The old single gate was only estimated at about 170 s, so a code commit may be no cheaper. Next: triage the medium review of the split, which also covers the byte-cap review's fix commit, then report the code gate's cost to my human partner.
