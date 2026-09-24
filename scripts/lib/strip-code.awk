# Blank fenced code blocks and inline code spans before check-links.sh's
# `](target)` extraction, so a broken target written as code is not
# reported. POSIX awk only: no gensub, no 3-arg match, no \s (BSD/macOS
# awk is the one-true-awk) — see shell-scripting:shell-gotchas.
#
# Fence: a line whose content after leading whitespace starts with 3+ of
# the same character (backtick or tilde), optionally followed by an info
# string, opens a fenced block; a later line consisting solely of 3+ of
# that same character (leading/trailing whitespace ignored) closes it.
# Both the opening and closing lines, and every line between, are dropped
# rather than printed — none of the three can hold a link this script
# should see. A backtick fence is not closed by a `~~~` line or vice
# versa (CommonMark): that line is fence content, dropped like any other.
# A backtick opener's info string holds no backtick (CommonMark), so a
# line starting with a code span such as ```` ``` ```` opens nothing. A
# trailing `\r` counts as whitespace: in a CRLF file no closer would match
# otherwise, and the first fence would swallow the rest of the file. A
# fence left open at the end of the file runs to the end, as in
# CommonMark.
#
# Span: a single-backtick pair on one line is blanked to a space; text on
# the same line outside the span is left in place.
#
# Residuals of this line-at-a-time approximation. Loud — the link inside
# is reported: a closing marker shorter than the opener (a ```` fence
# closed by ```); a double-backtick span (``code``); a span crossing a
# line break; and a 4-space indented code block, which is not a fence at
# all. Silent — a link is skipped: a fence inside a list item or block
# quote that the container's end would close in CommonMark swallows the
# rest of the file, and so does a lone fence marker line inside an
# indented code block, since any indentation opens a fence here (a list
# item's fence may sit 4+ columns in); and a backslash-escaped backtick
# (\`) still opens a span.

BEGIN { in_fence = 0; fence_char = "" }

{
    line = $0
    trimmed = line
    sub(/^[ \t]+/, "", trimmed)

    if (in_fence) {
        if (fence_char == "`") {
            closes = (trimmed ~ /^```+[ \t\r]*$/)
        } else {
            closes = (trimmed ~ /^~~~+[ \t\r]*$/)
        }
        if (closes) {
            in_fence = 0
            fence_char = ""
        }
        next
    }

    if (trimmed ~ /^```+[^`]*$/) {
        in_fence = 1
        fence_char = "`"
        next
    }
    if (trimmed ~ /^~~~+/) {
        in_fence = 1
        fence_char = "~"
        next
    }

    gsub(/`[^`]*`/, " ", line)
    print line
}
