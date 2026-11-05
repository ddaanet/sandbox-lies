## Current task

Making `just precommit` cheaper. Byte caps, the frontmatter check and the split into `gate-docs` and `gate-code` are in, and a prose edit now pays about 49 s against 173 s before. `gate-docs` no longer lints shell, and `tests/gate-coverage.bats` builds its scratch tree once and copies it per case. That commit has had its medium review, and its fixes are in. Next: `TODO.md`; the release review still owes `dev` against `main`.
