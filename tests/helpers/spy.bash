#!/usr/bin/env bash
# PATH-shadowing recorders for NFR-4's "writes nothing". Each stub appends its
# name and arguments to a log, then execs the real tool, so a test can assert
# the tool was never called at all — whichever directory the call would have
# written to, and whether or not the call succeeded.
#
# Usage: make_spy <dir> <log> <tool>...   then   PATH="<dir>:$PATH" run …
#        and assert [ ! -e <log> ]

make_spy() {
  local dir="$1" log="$2" tool real
  shift 2
  mkdir -p "$dir"
  for tool in "$@"; do
    real=$(command -v "$tool") || { echo "make_spy: no real $tool on PATH" >&2; return 1; }
    # unquoted EOF: $tool, $log and $real expand now; \$ forms stay for run time
    cat > "$dir/$tool" <<STUB
#!/bin/sh
printf '%s %s\n' "$tool" "\$*" >>"$log"
exec "$real" "\$@"
STUB
    chmod 755 "$dir/$tool"
  done
}
