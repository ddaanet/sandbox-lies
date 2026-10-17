# Note: `lib/probes.sh` cites a retired memory fact

From: gitlore, 2026-10-16.

`lib/probes.sh` lines 169 and 310 justify their stderr handling as
"no-stderr-suppression exception 1 of 2" and "exception 2 of 2". That memory
fact has been retired from the ddaanet tier, so the citation and its numbering
now point at nothing.

The content lives in the shell-gotchas skill,
`skills/shell-gotchas/references/robustness.md`:

- line 38, "capture and match instead of suppressing". It keeps a redirect only
  where "provoking the error *is* the mechanism", which is the case at line
  169. It also covers the capture-then-match-expected-shapes pattern at
  line 310.
- line 39, "never replace a tool's own message with a guess".

That reference does not number its exceptions. So a citation by name reads
best, such as "shell-gotchas robustness: provoking the error is the
mechanism". Alternatively, keep the inline reason and drop the citation.
