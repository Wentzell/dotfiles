#!/bin/bash
# Update tmux window marker for Codex CLI session state.
# Sets a per-window @codex user option rendered as a colored square.
#
# Caches pane ID and last state in /tmp to minimize overhead when
# called frequently (e.g., PreToolUse on every tool call).

command -v tmux >/dev/null 2>&1 || exit 0

new="${1:-clear}"
cache="/tmp/.codex-tmux-$PPID"

# Read cache: first field = last state, second = pane ID
if [ -f "$cache" ]; then
    IFS=$'\t' read -r old pane < "$cache"
    [ "$old" = "$new" ] && exit 0
else
    # First call — resolve pane
    pane="$TMUX_PANE"
    if [ -z "$pane" ]; then
        pid=$$
        while [ "$pid" -gt 1 ] 2>/dev/null; do
            pane=$(tr '\0' '\n' < /proc/$pid/environ 2>/dev/null \
                   | sed -n 's/^TMUX_PANE=//p')
            [ -n "$pane" ] && break
            pid=$(awk '{print $4}' /proc/$pid/stat 2>/dev/null) || break
        done
    fi
fi
[ -z "$pane" ] && exit 0

case "$new" in
    clear) tmux set-option -wqu -t "$pane" @codex 2>/dev/null
           rm -f "$cache" ;;
    *)     printf '%s\t%s' "$new" "$pane" > "$cache"
           tmux set-option -wq  -t "$pane" @codex "$new" 2>/dev/null ;;
esac
