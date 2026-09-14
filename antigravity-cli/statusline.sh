#!/bin/bash
set -euo pipefail

# ─── Locale: force C numeric (prevents comma-as-decimal on European locales) ─
export LC_NUMERIC=C

# ─── ANSI Helpers (Standard 16-color palette only) ───────────────────────────
R="\033[0m"         # Reset
B="\033[1m"         # Bold
D="\033[2m"         # Dim
I="\033[3m"         # Italic

# Foreground accents (Standard 16 colors)
FG_BLACK="\033[30m"
FG_RED="\033[31m"
FG_GREEN="\033[32m"
FG_YELLOW="\033[33m"
FG_BLUE="\033[34m"
FG_MAGENTA="\033[35m"
FG_CYAN="\033[36m"
FG_WHITE="\033[37m"

FG_GRAY="\033[90m"
FG_BRIGHT_RED="\033[91m"
FG_BRIGHT_GREEN="\033[92m"
FG_BRIGHT_YELLOW="\033[93m"
FG_BRIGHT_BLUE="\033[94m"
FG_BRIGHT_MAGENTA="\033[95m"
FG_BRIGHT_CYAN="\033[96m"
FG_BRIGHT_WHITE="\033[97m"

# Number Highlight Color
NUM_COLOR="${FG_BRIGHT_WHITE}${B}"

# ─── Helper: Format Token Counts (e.g. 88.2k, 1.2M) ──────────────────────────
format_tokens() {
  local num=${1%.*}
  num=${num:-0}
  if [ "$num" -ge 1000000 ]; then
    echo "$((num / 1000000)).$(( (num % 1000000) / 100000 ))M"
  elif [ "$num" -ge 1000 ]; then
    echo "$((num / 1000)).$(( (num % 1000) / 100 ))k"
  else
    echo "$num"
  fi
}

# ─── Helper: Format Duration (e.g. 5h, 4h 30m, 45m, 4d) ─────────────────────
format_duration() {
  local secs=${1%.*}
  secs=${secs:-0}
  if [ "$secs" -le 0 ]; then
    echo ""
  elif [ "$secs" -ge 86400 ]; then
    local d=$((secs / 86400))
    local h=$(( (secs % 86400) / 3600 ))
    if [ "$h" -gt 0 ]; then
      echo "${d}d ${h}h"
    else
      echo "${d}d"
    fi
  elif [ "$secs" -ge 3600 ]; then
    local h=$((secs / 3600))
    local m=$(( (secs % 3600) / 60 ))
    if [ "$m" -gt 0 ]; then
      echo "${h}h ${m}m"
    else
      echo "${h}h"
    fi
  else
    local m=$((secs / 60))
    echo "${m}m"
  fi
}

# ─── Parse JSON from stdin (Single jq pass for performance) ──────────────────
# Extract all fields in one pass to prevent spawning jq multiple times.
{
  read -r STATE; STATE="${STATE%$'\r'}"
  read -r USED_PCT; USED_PCT="${USED_PCT%$'\r'}"
  read -r IN_TOKENS; IN_TOKENS="${IN_TOKENS%$'\r'}"
  read -r OUT_TOKENS; OUT_TOKENS="${OUT_TOKENS%$'\r'}"
  read -r QUOTA_FRAC; QUOTA_FRAC="${QUOTA_FRAC%$'\r'}"
  read -r RESET_SECS; RESET_SECS="${RESET_SECS%$'\r'}"
  read -r VCS_BRANCH; VCS_BRANCH="${VCS_BRANCH%$'\r'}"
  read -r VCS_DIRTY; VCS_DIRTY="${VCS_DIRTY%$'\r'}"
  read -r SANDBOX; SANDBOX="${SANDBOX%$'\r'}"
  read -r ARTIFACTS; ARTIFACTS="${ARTIFACTS%$'\r'}"
  read -r SUBAGENTS; SUBAGENTS="${SUBAGENTS%$'\r'}"
  read -r BG_TASKS; BG_TASKS="${BG_TASKS%$'\r'}"
  read -r MODEL; MODEL="${MODEL%$'\r'}"
  read -r COLS; COLS="${COLS%$'\r'}"
} <<< "$(
  jq -r '
    (.agent_state // "idle"),
    (.context_window.used_percentage // 0),
    (.context_window.total_input_tokens // 0),
    (.context_window.total_output_tokens // 0),
    (if .quota and (.quota | length > 0) then
      ([.quota | to_entries[] | .value] | sort_by(.reset_in_seconds // 999999999) | first | (.remaining_fraction // "")|tostring)
    else "" end),
    (if .quota and (.quota | length > 0) then
      ([.quota | to_entries[] | .value] | sort_by(.reset_in_seconds // 999999999) | first | (.reset_in_seconds // 0)|tostring)
    else "0" end),
    (.vcs.branch // ""),
    (.vcs.dirty // false),
    (.sandbox.enabled // false),
    (.artifact_count // 0),
    (if .subagents | type == "array" then (.subagents | length) else 0 end),
    (.task_count // 0),
    (.model.display_name // ""),
    (.terminal_width // 80)
  ' 2>/dev/null || printf "idle\n0\n0\n0\n\n0\n\nfalse\nfalse\n0\n0\n0\n\n80\n"
)"

# ─── Computed Values ─────────────────────────────────────────────────────────
PCT_FMT=$(printf "%.1f" "$USED_PCT")
PCT_INT=${USED_PCT%.*}; PCT_INT=${PCT_INT:-0}

# ─── State Indicator (No background colors) ──────────────────────────────────
case "$STATE" in
  idle)     S="${FG_BRIGHT_GREEN}${B}● READY${R}" ;;
  thinking) S="${FG_BRIGHT_YELLOW}${B}◆ THINKING${R}" ;;
  working)  S="${FG_BRIGHT_CYAN}${B}⚙ WORKING${R}" ;;
  tool_use) S="${FG_BRIGHT_MAGENTA}${B}🔧 TOOL${R}" ;;
  *)        S="${FG_WHITE}${B}⏳ $(echo "$STATE" | tr '[:lower:]' '[:upper:]')${R}" ;;
esac

# ─── VCS Branch ──────────────────────────────────────────────────────────────
V=""
if [ -n "$VCS_BRANCH" ]; then
  if [ "$VCS_DIRTY" = "true" ]; then
    V="${FG_GRAY} ╱ ${FG_BRIGHT_RED}${VCS_BRANCH}${FG_BRIGHT_YELLOW}*${R}"
  else
    V="${FG_GRAY} ╱ ${FG_BRIGHT_BLUE}${VCS_BRANCH}${R}"
  fi
fi

# ─── Model ───────────────────────────────────────────────────────────────────
M=""
if [ -n "$MODEL" ]; then
  M="${FG_GRAY} ╱ ${FG_BRIGHT_MAGENTA}${I}${MODEL}${R}"
fi

# ─── Sandbox Badge ───────────────────────────────────────────────────────────
if [ "$SANDBOX" = "true" ]; then
  SB="${FG_GRAY}sandbox ${FG_BRIGHT_GREEN}${B}ON${R}"
else
  SB="${FG_GRAY}sandbox off${R}"
fi

# ─── Context Bar (15 segments, fine-grain Unicode) ────────────────────────────
BAR_LEN=15
FILLED=$((PCT_INT * BAR_LEN / 100))
REMAINDER=$(( (PCT_INT * BAR_LEN) % 100 ))

# Pick color based on percentage
if [ "$PCT_INT" -ge 90 ]; then
  BAR_COLOR="$FG_BRIGHT_RED"
elif [ "$PCT_INT" -ge 60 ]; then
  BAR_COLOR="$FG_BRIGHT_YELLOW"
else
  BAR_COLOR="$FG_BRIGHT_WHITE"
fi

# Build bar with partial-fill last block
BAR=""
for ((i = 0; i < BAR_LEN; i++)); do
  if [ "$i" -lt "$FILLED" ]; then
    BAR="${BAR}█"
  elif [ "$i" -eq "$FILLED" ]; then
    if [ "$REMAINDER" -ge 75 ]; then
      BAR="${BAR}▓"
    elif [ "$REMAINDER" -ge 50 ]; then
      BAR="${BAR}▒"
    elif [ "$REMAINDER" -ge 25 ]; then
      BAR="${BAR}░"
    else
      BAR="${BAR}·"
    fi
  else
    BAR="${BAR}·"
  fi
done

# ─── Separators ──────────────────────────────────────────────────────────────
DOT="${FG_GRAY} · ${R}"

# ─── Stats & Google AI Usage ─────────────────────────────────────────────────
CTX="${FG_GRAY}ctx ${BAR_COLOR}${BAR} ${NUM_COLOR}${PCT_FMT}%${R}"

# Token usage badge (in ▲ / out ▼)
IN_FMT=$(format_tokens "$IN_TOKENS")
OUT_FMT=$(format_tokens "$OUT_TOKENS")
TOK_FMT="${FG_GRAY}tokens ${NUM_COLOR}${IN_FMT}${FG_GRAY}▲ ${NUM_COLOR}${OUT_FMT}${FG_GRAY}▼${R}"

# Quota remaining badge (with period reset countdown)
QUOTA_FMT=""
if [ -n "$QUOTA_FRAC" ] && [ "$QUOTA_FRAC" != "null" ]; then
  QUOTA_INT=$(awk "BEGIN {printf \"%.0f\", $QUOTA_FRAC * 100}" 2>/dev/null || echo "")
  if [ -n "$QUOTA_INT" ]; then
    if [ "$QUOTA_INT" -le 20 ]; then
      Q_COLOR="$FG_BRIGHT_RED"
    elif [ "$QUOTA_INT" -le 50 ]; then
      Q_COLOR="$FG_BRIGHT_YELLOW"
    else
      Q_COLOR="$FG_BRIGHT_GREEN"
    fi
    DUR_STR=$(format_duration "$RESET_SECS")
    if [ -n "$DUR_STR" ]; then
      QUOTA_FMT="${DOT}${FG_GRAY}quota ${Q_COLOR}${B}${QUOTA_INT}%${R} ${FG_GRAY}(${DUR_STR} left)${R}"
    else
      QUOTA_FMT="${DOT}${FG_GRAY}quota ${Q_COLOR}${B}${QUOTA_INT}%${R}"
    fi
  fi
fi

ART_FMT="${FG_GRAY}artifacts ${NUM_COLOR}${ARTIFACTS}${R}"
SUB_FMT="${FG_GRAY}subagents ${NUM_COLOR}${SUBAGENTS}${R}"
BG_FMT="${FG_GRAY}tasks ${NUM_COLOR}${BG_TASKS}${R}"

# ─── Output ──────────────────────────────────────────────────────────────────
LINE1="${S}${M}${V}"
LINE2=" ${CTX}${DOT}${TOK_FMT}${QUOTA_FMT}${DOT}${ART_FMT}${DOT}${SUB_FMT}${DOT}${BG_FMT}${DOT}${SB}"

if [ "$COLS" -ge 140 ]; then
  # Wide: single line
  echo -e "${LINE1}${FG_GRAY}  │  ${R}${LINE2}"
elif [ "$COLS" -ge 80 ]; then
  # Medium: two-line layout with border
  echo -e "${FG_GRAY}╭─${R} ${LINE1}"
  echo -e "${FG_GRAY}╰─${R}${LINE2}"
else
  # Narrow: compact two-line, minimal chrome
  echo -e "${S}${M}"
  echo -e "${CTX}${DOT}${TOK_FMT}"
fi
