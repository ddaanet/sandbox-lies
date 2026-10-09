# Item 0 — bash 3.2.0 build

Binary: `/tmp/claude/bash32/bash` (source tree: `/tmp/claude/bash32/src/bash-3.2`).

Ran, per the recipe in `evidence.md`:

1. `curl -fsSL https://ftp.gnu.org/gnu/bash/bash-3.2.tar.gz` (first host; allowed
   through the sandbox proxy, no mirror needed), extracted under
   `/tmp/claude/bash32/src`.
2. `CC` and `CC_FOR_BUILD` set to the gcc flag set from `evidence.md`
   (`-O1 -std=gnu89 -w -fcommon` plus the five `-Wno-error=` demotions);
   `./configure --without-bash-malloc` (rc 0).
3. `touch y.tab.c y.tab.h`, then `make` with the same CC/CC_FOR_BUILD, no `-j`
   (rc 0).
4. Copied `bash` to `/tmp/claude/bash32/bash`.

Verification output:

    GNU bash, version 3.2.0(1)-release (x86_64-unknown-linux-gnu)
    a\ b
    $'x\ny'
    $'caf\303\251'

No tracked repo files touched; nothing committed.
