#!/usr/bin/env bash
# PATH-shadowing stand-ins for tools whose BSD/macOS build is stricter than the
# GNU one. Each stub refuses the GNU-only invocation the way the Mac would break
# on it, and execs the real tool for anything both platforms accept — so a
# Linux run fails on the GNU-ism instead of the next Mac user.
#
# Usage: make_bsd_stubs <dir> <tool>...   then   PATH="<dir>:$PATH" run …

make_bsd_stubs() {
  local dir="$1" tool real
  shift
  mkdir -p "$dir"
  for tool in "$@"; do
    real=$(command -v "$tool") || { echo "make_bsd_stubs: no real $tool on PATH" >&2; return 1; }
    case "$tool" in
      sed)    _bsd_stub_sed "$dir/sed" "$real" ;;
      mktemp) _bsd_stub_mktemp "$dir/mktemp" "$real" ;;
      grep)   _bsd_stub_grep "$dir/grep" "$real" ;;
      stat)   _bsd_stub_stat "$dir/stat" "$real" ;;
      wc)     _bsd_stub_wc "$dir/wc" "$real" ;;
      paste)  _bsd_stub_paste "$dir/paste" "$real" ;;
      *)      echo "make_bsd_stubs: no stub for $tool" >&2; return 1 ;;
    esac
    chmod 755 "$dir/$tool"
  done
}

# BSD sed takes -i's backup extension as a SEPARATE argument and GNU sed takes
# it ATTACHED, so there is no spelling of -i both accept (`-i ''` is the script
# to GNU; `-i 's/x/y/'` makes `s/x/y/` the extension to BSD). The stub rejects
# every -i, and every long option — BSD sed has none.
_bsd_stub_sed() {
  # unquoted EOF: $2 (the real sed) expands now; \$ forms stay for run time
  cat > "$1" <<STUB
#!/bin/sh
for a in "\$@"; do
  case "\$a" in
    -i*) echo "sed: -i takes its extension as the next argument on BSD, attached on GNU — write to a temp file and mv instead" >&2; exit 1 ;;
    --*) echo "sed: illegal option -- -" >&2; exit 1 ;;
    -*) ;;
    *) break ;;
  esac
done
exec "$2" "\$@"
STUB
}

# BSD grep's ERE has no `\b`/`\<`/`\>` word boundaries (its spelling is
# `[[:<:]]`/`[[:>:]]`), and no -P or -z. GNU grep accepts them all, so a pattern
# using one lints and passes on Linux and silently matches nothing on a Mac.
_bsd_stub_grep() {
  cat > "$1" <<STUB
#!/bin/sh
for a in "\$@"; do
  case "\$a" in
    -P|-z|-*P*|-*z*) case "\$a" in --*) ;; *) echo "grep: invalid option -- \$a" >&2; exit 2 ;; esac ;;
    *'\\b'*|*'\\<'*|*'\\>'*) echo "grep: GNU word boundary in pattern: \$a (BSD spells it [[:<:]] / [[:>:]])" >&2; exit 2 ;;
  esac
done
exec "$2" "\$@"
STUB
}

# BSD mktemp randomises only TRAILING X's (Apple Libc find_temp_path: no
# minimum-X check, then open/mkdir with O_EXCL on whatever is left). A template
# like `name.XXXXXX.log` is therefore used literally: the first call creates
# it, the second fails with EEXIST. The stub reproduces exactly that; a
# template ending in X goes to the real tool.
_bsd_stub_mktemp() {
  cat > "$1" <<STUB
#!/bin/sh
dir=0; tmpl=
for a in "\$@"; do
  case "\$a" in -d) dir=1 ;; -*) ;; *) tmpl=\$a ;; esac
done
case "\$tmpl" in
  ''|*X) exec "$2" "\$@" ;;
esac
if [ "\$dir" -eq 1 ]; then
  mkdir "\$tmpl" 2>/dev/null || { echo "mktemp: mkdtemp failed on \$tmpl: File exists" >&2; exit 1; }
else
  (set -C; : > "\$tmpl") 2>/dev/null || { echo "mktemp: mkstemp failed on \$tmpl: File exists" >&2; exit 1; }
fi
printf '%s\n' "\$tmpl"
STUB
}

# BSD stat has no -c (macOS and FreeBSD alike) and no long options; its
# mtime read is -f %m, the same seconds-since-epoch field GNU's -c %Y prints.
# The stub parses the macOS option set with getopts, so a GNU-only option —
# -c, --format, --printf, anywhere in the argument list or bundled — gets
# BSD's "illegal option" line, usage line and exit 1. It serves -f %m
# (attached or not, with or without -L, several operands, no operand meaning
# stdin) from the real `stat -c %Y`: on Linux the real `stat -f` reports
# filesystem info, not file info, so without this the BSD path would be
# untestable here. Everything else BSD accepts — another option or -f
# format, or no -f at all (BSD's default output is not GNU's) — exits 2
# naming itself as not emulated, rather than reaching GNU stat, whose
# -f/-t/-x mean different things. Residual: a missing file's message is GNU's wording, not
# BSD's `stat: <file>: stat: No such file or directory`; the exit status (1)
# matches.
_bsd_stub_stat() {
  # unquoted EOF: $2 (the real stat) expands now; \$ forms stay for run time
  cat > "$1" <<STUB
#!/bin/sh
args=\$* link= fmt= other=
while getopts ':FLlnqrsxf:t:' o; do
  case "\$o" in
    L) link=1 ;;
    f) fmt=\$OPTARG ;;
    :|'?')
      if [ "\$o" = : ]; then
        echo "stat: option requires an argument -- \$OPTARG" >&2
      else
        echo "stat: illegal option -- \$OPTARG" >&2
      fi
      echo "usage: stat [-FLnq] [-f format | -l | -r | -s | -x] [-t timefmt] [file|handle ...]" >&2
      exit 1 ;;
    *) other=\$o ;;
  esac
done
shift \$((OPTIND - 1))
if [ -n "\$other" ] || [ "\$fmt" != %m ]; then
  printf 'make_bsd_stubs stat: only -f %%m is emulated (got: stat %s)\n' "\$args" >&2
  exit 2
fi
[ "\$#" -gt 0 ] || set -- -
if [ -n "\$link" ]; then
  exec "$2" -L -c %Y -- "\$@"
fi
exec "$2" -c %Y -- "\$@"
STUB
}

# BSD wc prints each count as " %7ju" — a space, then the count right-aligned
# in 7 — so `wc -c <file` reads "       7" where GNU prints the bare "7". The
# stub reproduces that for the exact form the probe uses (`-c` alone, stdin)
# by re-printing the real wc's count, and passes a failure of the real wc
# through. Anything else execs the real tool. Residual: that is more lenient
# than BSD for every other form — `wc -c <file-operand>`, `wc -l` — which BSD
# pads too; a probe moving to one of those is not checked by this stub.
_bsd_stub_wc() {
  cat > "$1" <<STUB
#!/bin/sh
if [ "\$#" -eq 1 ] && [ "\$1" = -c ]; then
  n=\$("$2" -c) || exit
  printf ' %7s\n' "\$n"
  exit 0
fi
exec "$2" "\$@"
STUB
}

# BSD paste reads no implicit stdin: with no file operand it prints its usage
# line and exits 1, where GNU paste reads stdin. The stub parses the BSD option
# set (-s, and -d taking a delimiter list, attached or separate) with getopts,
# so `-s`, `-sd:` and `-sd :` with no operand are all refused; an operand,
# including the explicit `-` for stdin, goes to the real tool.
_bsd_stub_paste() {
  # unquoted EOF: $2 (the real paste) expands now; \$ forms stay for run time
  cat > "$1" <<STUB
#!/bin/sh
# true when an operand follows the options; the shift stays inside the function
operands() {
  while getopts ':sd:' o; do
    case "\$o" in
      s|d) ;;
      :)
        echo "paste: option requires an argument -- \$OPTARG" >&2
        echo "usage: paste [-s] [-d delimiters] file ..." >&2
        exit 1 ;;
      '?')
        echo "paste: illegal option -- \$OPTARG" >&2
        echo "usage: paste [-s] [-d delimiters] file ..." >&2
        exit 1 ;;
    esac
  done
  shift \$((OPTIND - 1))
  [ "\$#" -gt 0 ]
}
operands "\$@" || { echo "usage: paste [-s] [-d delimiters] file ..." >&2; exit 1; }
exec "$2" "\$@"
STUB
}
