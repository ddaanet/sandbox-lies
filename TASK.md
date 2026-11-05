## Current task

Making `just precommit` cheaper. Byte caps, the frontmatter check and the split into `gate-docs` and `gate-code` are committed. Measured: a prose-only edit about 49 s, `gate-code` 195 s, the pre-split gate 173 s. Next: triage the medium review of the fix commit for the split's review, then my human partner's call on trimming `tests/gate-coverage.bats`, in `TODO.md`.
