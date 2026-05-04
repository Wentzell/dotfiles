#!/bin/bash

SHOW_EFFORT_DEFAULT=         # set e.g. "xhigh" to hide effort when it matches
SHOW_CTX_LABEL=1            # 0 → just "13%" instead of "ctx 13%"
SHOW_CTX_BAR=1              # 0 → hide visual bar, show percent only
CTX_BAR_WIDTH=10            # cells in the bar (10 → each cell = 10%)
SHOW_7D_TIME=0              # 0 → "7d 19% (Sun)" instead of "7d 19% (Sun 4:44pm)"
SEP=' │ '                   # try '·' or '|' for tighter / plain look

bar() {
  local pct=${1%.*} width=$2 filled empty i out=
  (( pct < 0 )) && pct=0
  (( pct > 100 )) && pct=100
  filled=$(( (pct * width + 50) / 100 ))
  empty=$((width - filled))
  for ((i=0; i<filled; i++)); do out+='█'; done
  for ((i=0; i<empty; i++)); do out+='░'; done
  printf '%s' "$out"
}

input=$(cat)

model=$(jq -r '.model.display_name' <<<"$input")
effort=$(jq -r '.effort.level // empty' <<<"$input")
dir=$(jq -r '.workspace.current_dir // empty' <<<"$input")
used_tokens=$(jq -r '(.context_window.current_usage // {}) | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)' <<<"$input")
window=${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-$(jq -r '.context_window.context_window_size // 0' <<<"$input")}
lim5h=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
lim7d=$(jq -r '.rate_limits.seven_day.used_percentage // empty' <<<"$input")
rst5h=$(jq -r '.rate_limits.five_hour.resets_at // empty' <<<"$input")
rst7d=$(jq -r '.rate_limits.seven_day.resets_at // empty' <<<"$input")

model=${model#Claude }
[[ "$model" =~ ^(.*)\ \((.+)\ context\)$ ]] && model="${BASH_REMATCH[1]} (${BASH_REMATCH[2]})"

# ctx % against the auto-compact threshold if set, else the model's full window
# (+ window/2 rounds to nearest instead of truncating)
pct=
(( used_tokens > 0 && window > 0 )) && pct=$(( (used_tokens * 100 + window/2) / window ))

repo=${dir:-$PWD}
cwd=$(basename "$repo")
branch=$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null \
         || git -C "$repo" rev-parse --short HEAD 2>/dev/null)
[ -n "$branch" ] && [ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ] && branch="$branch*"

now=$(date '+%-I:%M%P')
[ -n "$rst5h" ] && rst5h_fmt=$(date -d "@$rst5h" '+%-I:%M%P')
if [ -n "$rst7d" ]; then
  if [ "$SHOW_7D_TIME" = 1 ]; then
    rst7d_fmt=$(date -d "@$rst7d" '+%a %-I:%M%P')
  else
    rst7d_fmt=$(date -d "@$rst7d" '+%a')
  fi
fi

head="$model"
[ -n "$effort" ] && [ "$effort" != "$SHOW_EFFORT_DEFAULT" ] && head="$head · $effort"

left="$cwd"
[ -n "$branch" ] && left="$left@$branch"
left="$left$SEP$head"
if [ -n "$pct" ]; then
  ctx_seg=$(printf '%.0f%%' "$pct")
  [ "$SHOW_CTX_BAR" = 1 ] && ctx_seg="[$(bar "$pct" "$CTX_BAR_WIDTH")] $ctx_seg"
  [ "$SHOW_CTX_LABEL" = 1 ] && ctx_seg="ctx $ctx_seg"
  left="$left$SEP$ctx_seg"
fi

right=
[ -n "$lim5h" ] && right=${right:+$right$SEP}$(printf '5h %.0f%% (%s)' "$lim5h" "$rst5h_fmt")
[ -n "$lim7d" ] && right=${right:+$right$SEP}$(printf '7d %.0f%% (%s)' "$lim7d" "$rst7d_fmt")
right=${right:+$right$SEP}$now

cols=${COLUMNS:-$(tput cols 2>/dev/null)}
cols=${cols:-120}
pad=$(( cols - ${#left} - ${#right} - 4 ))
(( pad < 2 )) && pad=2

printf '%s%*s%s' "$left" "$pad" '' "$right"
