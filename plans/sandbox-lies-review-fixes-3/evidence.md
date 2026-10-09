# Evidence — sandbox-lies-review-fixes-3

The probes `outline.md` rests on.

Each probe below ran on this box (Linux). Bash 3.2 means a 3.2.0 built from
the GNU tarball (gnu89, glibc malloc, `-O1`). It is indicative only: Apple's
3.2.57 is unverified, and so is everything about macOS. To rebuild it, take
`bash-3.2.tar.gz` from ftp.gnu.org and configure with `--without-bash-malloc`.
Before `make`, `touch` `y.tab.c` and `y.tab.h` (the 3.2.57 tarball's `y.tab.c`
is stale against its `parse.y` and fails to link without bison). Pass this as
both `CC` and `CC_FOR_BUILD`, demoting gcc 14's errors:
`gcc -O1 -std=gnu89 -w -fcommon
-Wno-error=implicit-function-declaration -Wno-error=int-conversion
-Wno-error=incompatible-pointer-types -Wno-error=implicit-int
-Wno-error=return-mismatch`.

- **`printf %q` forms.** Bytes 1 to 255 were run through it, between two
  letters, on both versions under `C` and `C.UTF-8`. Each byte gives one of
  two forms:
  - backslash form: a backslash before each shell-special printable byte;
  - `$'…'` form: whenever a byte is not printable. Its escapes are `\a \b \E
    \f \n \r \t \v`, three-digit octal `\NNN`, and `\\` and `\'`.

  The two versions agree byte for byte on single bytes. They diverge in two
  ways:
  - bash 5.2 escapes a leading `~` and bash 3.2 does not;
  - under `C.UTF-8`, bash 5.2 prints a valid multibyte character raw (`café`),
    where bash 3.2 and any `C` locale print `$'caf\303\251'`.
- **The locale pin works.** `LC_ALL=C printf %q …`, as a prefix on the
  builtin, gives the `$'…'` form for non-ASCII under a UTF-8 session on both
  versions. So the wire form does not depend on the hook's locale. The
  extractors already pin `LC_ALL=C` for byte safety.
- **Assignment eval decodes wrongly on 3.2.** bash 3.2's `%q` leaves `~` bare.
  `eval "x=$q"` then tilde-expands after a `:`: `/a:~root/b c` decoded to
  `/a:/root/b c`. A word-context eval and `read` without `-r` both decode it
  right. `printf %b` decodes `\NNN`, `\E` and `\\` on both versions, but not
  `\'`.
- **Tokenizer cost** (`_readonly_tokenize`, 16384 characters):

  | input | bash 5.2.37 | bash 3.2.0 |
  | --- | --- | --- |
  | one word | 4.2 s | 38.7 s |
  | 1600 short words | 1.3 s | 2.5 s |

  The gap between the rows is the `word="$word$ch"` copy. On 3.2 a single word
  past about 8 KB alone exceeds the hook's 10 s timeout, and the annotation is
  then lost with no signal.
- **`nopath` hits.** From `plans/sandbox-lies/reports/item-8-1-dogfood-numbers.md`:
  11 of 195 `readonly-path` hits, in five shapes:
  - tee's refusal of a `/tmp` file;
  - sed's temporary file in a relative directory;
  - git's refusal to write `.git/config`, busy rather than read-only;
  - a removal warning on `.bash_profile`;
  - `cp` with an empty operand.

  Every extractable path there is writable outside the sandbox, so `writable`
  would give the same act `nopath` gives: re-run the whole call unsandboxed.
  None names `.claude/settings.json`. The empty operand holds no path at all.
