# Item 5.4 slice 1 RED

Test added to `tests/probes-readonly-members.bats` (after the repository-root newline case, 12 cases total, file 266 lines):

- `a resolved refused path holding a newline gives nopath, not path=` (case 6)

Setup: refusal text from `readonly_path_text fire-readonly-path-cp-tmp "'a'"`, command `cat build.out`, both cwds created with `mkdir` (blank twin `<tmp>/r readfile=x`, newline dir `<tmp>/r⏎readfile=x`).

- Blank half (passes, as the SUT should): output equals `writable`, `path=<tmp>/r readfile=x/a`, `readfile=build.out`.
- Newline half (red): `[ "$output" = $'nopath\nreadfile=build.out' ]` fails. Bats: `not ok 6 ... (in test file tests/probes-readonly-members.bats, line 153) ... failed`. It fails on the assertion, not on an error.

Actual forged output for the newline half (`cat -A`, `<tmp>` for the tmpdir):

```
writable$
path=<tmp>/r$
readfile=x/a$
readfile=build.out$
```

The newline splits `path=` and forges a `readfile=x/a` line.

Full-file run (foreground): 12 cases, cases 1-5 and 7-12 ok, only case 6 not ok.

No lib/ edit, no mutation needed (SUT exists, test reds on the defect). Nothing committed.
