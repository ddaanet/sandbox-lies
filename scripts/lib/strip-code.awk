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
#
# Span: a single-backtick pair on one line is blanked to a space; text on
# the same line outside the span is left in place.
#
# Residuals, left for a later slice, each of which fails loud — the link
# inside is reported, not silently passed — rather than silently matching:
# a closing marker shorter than the opener (a ```` fence closed by ```);
# a double-backtick span (``code``); a span or a fence that a line break
# would close in CommonMark but this line-at-a-time state machine does
# not, so an unclosed fence swallows the rest of the file; and a 4-space
# indented code block, which is not a fence at all.

BEGIN { in_fence = 0; fence_char = "" }

{
    line = $0
    trimmed = line
    sub(/^[ \t]+/, "", trimmed)

    if (in_fence) {
        if (fence_char == "`") {
            closes = (trimmed ~ /^```+[ \t]*$/)
        } else {
            closes = (trimmed ~ /^~~~+[ \t]*$/)
        }
        if (closes) {
            in_fence = 0
            fence_char = ""
        }
        next
    }

    if (trimmed ~ /^```+/) {
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
