## Remaining

- `dev` carries the reviewed `partial=1` anchoring and the macOS / bash 3.2 fixes, which `main` lacks; `main` follows `dev` once `dev` has been through review (`/code-review`, `/codex:review`, `/simplify`, not limited to those), with no request to my human partner.
- Check whether the release toolkit rewrites the `sandbox-lies` marketplace entry back to a `github` source on the next release of this plugin.
- A lint for a shell `$name` immediately followed by a non-ASCII byte (`$p’`), which bash on macOS reads as part of the name. Same lint family: a temporary `LC_ALL=…` in front of a builtin (`printf`, `read`), which bash 3.2 ignores, and an empty `printf -v x '%b' ""`, which keeps the previous buffer under 3.2.
- Make a bash 3.2.57 binary a durable test tool so `scripts/run-bats-under.sh` can gate on it on Linux; the build recipe is in the `bash32-macos-traps` memory, and `tmp/bash-3.2.57` is a session artefact.
- Run `/gitlore:index-audit` before the next memory index line: `memory/MEMORY.md` is about 50 bytes under the loader's 24.4KB cutoff.