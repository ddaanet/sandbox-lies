# readonly-path: the `readfile=` residuals

What the `readfile=` operand rule of the `readonly-path` probe gets wrong, each
shown by what the probe prints. The rule itself is in
[readonly-path.md](readonly-path.md#readonly-path); its conventions apply here
unchanged.

- Other options' separate arguments (`-n 5`, `-d ,`) read as operands. A
  log-named one is the candidate (`sort -T t.log in.txt` gives `t.log`); under
  `grep`, `sed` or `awk` one takes the pattern role, so the pattern is taken as
  input (`grep -m 5 x.log y.out` gives `x.log`); under `uniq` one counts as an
  operand, so `uniq -f 1 in.log` reads as a writer and gives no line.
- Clustered short (`-ne`, `-nf`) and long (`--regexp=`, `--expression=`,
  `--file=`) forms of the `-e`/`-f` family are not recognised. Glued, the
  pattern role stays open and takes the input (`grep -nepat x.log` and
  `grep --regexp=pat x.log` give no line); a separate clustered form after an
  earlier `-e` leaves its argument as input (`grep -e a -ve x.log y.out` gives
  `x.log`).
- sed's `w` command and the `s///w` flag write a file but are not counted as
  writers: `sed 's/a/b/w out.log' in.log` gives `in.log`.
- A descriptor duplication such as `2>&1` standing in the pattern slot or an
  `-e`/`-f` argument slot is taken as that operand, so the word after it is read
  as input: `grep 2>&1 x.log y.out` gives `x.log`, and
  `grep -e 2>&1 pat.log x.log` gives `pat.log`.
- `--` is honoured only in `uniq`'s operand count. A file named `-x.log` after
  it is never a candidate (`cat -- -x.log` gives no line), and a pattern opening
  with `-` after it is passed over as an option, so `grep -- -x.log y.out` gives
  no line.
- A `<` anywhere in a word reads as an input redirection, quoted or not:
  `grep '<div' y.out` gives no line, and `cat 'a<x.log'` gives `x.log`. A
  here-string's word is a candidate too: `grep pat <<<x.log` gives `x.log`.
- In `uniq`, a lone `-` glued to a redirection is skipped as an option:
  `uniq -<in.log out.log` writes `out.log` and gives `in.log`.
- The glob and expansion skip tests the word with its quotes already removed, so
  a quoted literal naming a real file is skipped too: `grep -l pat '*.log'`
  gives no line, the safe side.
- A backtick substitution is not parsed, so it is not skipped:
  ``cat `echo a`.log`` gives the backtick word as `readfile=`, the same
  misdirection the skip withholds for a glob.
