# Item 0 — bash 3.2.0 rebuild

Binary: `/tmp/claude/bash32/bash`. Tarball: `/tmp/claude/bash32/src/bash-3.2.tar.gz`;
tree: `/tmp/claude/bash32/src/dl/bash-3.2`. Logs: `/tmp/claude/bash32/{configure,make}.log`.

Steps run (recipe from `evidence.md`):

1. `curl` of `https://ftp.gnu.org/gnu/bash/bash-3.2.tar.gz`, extracted into the
   new empty `src/dl`.
2. `CC` and `CC_FOR_BUILD` set to the gcc flag set from `evidence.md`;
   `./configure --without-bash-malloc` (rc 0).
3. `touch y.tab.c y.tab.h`, then `make` with no `-j` (rc 0).
4. Copied `bash` to `/tmp/claude/bash32/bash`; recreated
   `/tmp/claude/wait-report.sh`.

Verification:

    GNU bash, version 3.2.0(1)-release (x86_64-unknown-linux-gnu)
    a\ b
    $'caf\303\251'

No tracked repo file touched; nothing committed.
