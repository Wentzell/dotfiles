#!/bin/bash
# Update tmux window marker for Codex CLI session state.
# Sets a per-window @codex user option rendered as a colored square.
#
# Caches the last state per pane in /tmp. We still apply the tmux option
# every time so stale cache files cannot leave the visible marker wrong.

command -v tmux >/dev/null 2>&1 || exit 0

new="${1:-clear}"

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
[ -z "$pane" ] && exit 0

cache="/tmp/.codex-tmux-${pane#%}"

case "$new" in
    clear) tmux set-option -wqu -t "$pane" @codex 2>/dev/null
           rm -f "$cache" ;;
    *)     printf '%s\n' "$new" > "$cache"
           tmux set-option -wq  -t "$pane" @codex "$new" 2>/dev/null ;;
esac
