#!/bin/bash
# Update tmux window marker for an agent CLI session state.
# Sets the per-window @<agent> tmux user option, rendered as a colored dot
# by the status format in .tmux.conf. The agent name is inferred from the
# grandparent directory of $0 (e.g. .claude/hooks/tmux-status.sh → "claude"),
# so .codex/hooks/tmux-status.sh can be a symlink to this file.
#
# Invoked frequently (PreToolUse fires on every tool call), so this stays
# cheap: resolve the pane once via $TMUX_PANE (or walk /proc parents as a
# fallback), then issue a single tmux set-option.

command -v tmux >/dev/null 2>&1 || exit 0

agent=$(basename "$(dirname "$(dirname "$0")")")
agent="${agent#.}"
new="${1:-clear}"
[ -z "$agent" ] && exit 0

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

case "$new" in
    clear) tmux set-option -wqu -t "$pane" "@$agent" 2>/dev/null ;;
    *)     tmux set-option -wq  -t "$pane" "@$agent" "$new" 2>/dev/null ;;
esac
