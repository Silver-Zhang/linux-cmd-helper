#!/usr/bin/env bash
# copilot-cmd-ui.sh — Lightweight terminal UI helpers for cmd / cmdx.
# Source this file; do not execute directly.
# All visual output goes to stderr so stdout stays clean for piping.

# ─── Environment detection ────────────────────────────────────────────────────

# Returns 0 if stdout is a TTY (interactive terminal).
ui_is_tty() {
  [ -t 1 ]
}

# Returns 0 if color output is enabled.
ui_color_enabled() {
  [ -z "${CMD_PLAIN:-}" ] && [ -z "${NO_COLOR:-}" ] && ui_is_tty
}

# Returns 0 if spinner is enabled.
ui_spinner_enabled() {
  [ -z "${CMD_PLAIN:-}" ] && [ -z "${CMD_NO_SPINNER:-}" ] && ui_is_tty
}

# Returns 0 if box drawing / decorations are enabled.
ui_fancy_enabled() {
  [ -z "${CMD_PLAIN:-}" ] && ui_is_tty
}

# ─── Color codes (set only when color is enabled) ─────────────────────────────

_ui_init_colors() {
  if ui_color_enabled; then
    _C_RESET=$'\033[0m'
    _C_BOLD=$'\033[1m'
    _C_DIM=$'\033[2m'
    _C_RED=$'\033[31m'
    _C_GREEN=$'\033[32m'
    _C_YELLOW=$'\033[33m'
    _C_CYAN=$'\033[36m'
    _C_MAGENTA=$'\033[35m'
    _C_BOLD_CYAN=$'\033[1;36m'
    _C_BOLD_GREEN=$'\033[1;32m'
    _C_BOLD_YELLOW=$'\033[1;33m'
    _C_BOLD_MAGENTA=$'\033[1;35m'
  else
    _C_RESET=''
    _C_BOLD=''
    _C_DIM=''
    _C_RED=''
    _C_GREEN=''
    _C_YELLOW=''
    _C_CYAN=''
    _C_MAGENTA=''
    _C_BOLD_CYAN=''
    _C_BOLD_GREEN=''
    _C_BOLD_YELLOW=''
    _C_BOLD_MAGENTA=''
  fi
}

# Initialize colors on source
_ui_init_colors

# ─── Box drawing primitives ───────────────────────────────────────────────────

# Width for box drawing (excluding box chars)
_UI_WIDTH=52

# Print a section box: ui_section "title"
# Outputs a top-border, expects content via ui_section_line, then ui_section_end.
ui_section() {
  local title="$1"
  if ui_fancy_enabled; then
    printf '%s╭─ %s ─%s╮%s\n' "${_C_BOLD_CYAN}" "$title" "$(printf '%0.s─' $(seq 1 $(( _UI_WIDTH - ${#title} - 4 )) ))" "${_C_RESET}" >&2
  else
    printf '[%s]\n' "$title" >&2
  fi
}

ui_section_kv() {
  local key="$1" value="$2"
  if ui_fancy_enabled; then
    printf '%s│%s %-8s: %s%s\n' "${_C_DIM}" "${_C_RESET}" "$key" "$value" "" >&2
  else
    printf '[%s] %s: %s\n' "${_UI_CURRENT_SECTION:-info}" "$key" "$value" >&2
  fi
}

ui_section_line() {
  local line="$1"
  if ui_fancy_enabled; then
    printf '%s│%s %s\n' "${_C_DIM}" "${_C_RESET}" "$line" >&2
  else
    printf '%s\n' "$line" >&2
  fi
}

ui_section_end() {
  if ui_fancy_enabled; then
    printf '%s╰%s╯%s\n' "${_C_DIM}" "$(printf '%0.s─' $(seq 1 $(( _UI_WIDTH )) ))" "${_C_RESET}" >&2
  fi
}

# ─── Convenience wrappers ─────────────────────────────────────────────────────

ui_hr() {
  if ui_fancy_enabled; then
    printf '%s━%s%s\n' "${_C_DIM}" "$(printf '%0.s━' $(seq 1 $(( _UI_WIDTH )) ))" "${_C_RESET}" >&2
  else
    printf '%s\n' "---" >&2
  fi
}

ui_info() {
  local key="$1" value="$2"
  printf '%s[%s]%s %s\n' "${_C_DIM}" "$key" "${_C_RESET}" "$value" >&2
}

ui_warn() {
  printf '%s[warn]%s %s\n' "${_C_BOLD_YELLOW}" "${_C_RESET}" "$1" >&2
}

ui_error() {
  printf '%s[error]%s %s\n' "${_C_RED}" "${_C_RESET}" "$1" >&2
}

ui_success() {
  printf '%s[ok]%s %s\n' "${_C_GREEN}" "${_C_RESET}" "$1" >&2
}

# ─── Model info box ──────────────────────────────────────────────────────────

# ui_model_info <tool_name> <backend> <model_display> <context_mode> [extra_kv...]
ui_model_info() {
  local tool_name="$1" backend_display="$2" model_display="$3" ctx_mode="$4"
  shift 4

  _UI_CURRENT_SECTION="$tool_name"
  printf '\n' >&2
  ui_section "$tool_name"
  ui_section_kv "backend" "$backend_display"
  ui_section_kv "model" "$model_display"
  ui_section_kv "context" "$ctx_mode"
  # Extra key-value pairs
  while [ "$#" -ge 2 ]; do
    ui_section_kv "$1" "$2"
    shift 2
  done
  ui_section_end
  printf '\n' >&2
}

# ─── Question preview ─────────────────────────────────────────────────────────

# ui_question_preview <file> [preview_lines]
ui_question_preview() {
  local file="$1"
  local max_lines="${2:-80}"
  local lines
  lines="$(wc -l < "$file" | tr -d ' ')"

  _UI_CURRENT_SECTION="question"
  ui_section "question"
  if [ "$lines" -le "$max_lines" ]; then
    while IFS= read -r line; do
      ui_section_line "$line"
    done < "$file"
  else
    head -n "$max_lines" "$file" | while IFS= read -r line; do
      ui_section_line "$line"
    done
    ui_section_line "... ($lines lines total; truncated)"
  fi
  ui_section_end
  printf '\n' >&2
}

# ─── AI response markers ─────────────────────────────────────────────────────

ui_ai_begin() {
  printf '\n' >&2
  _UI_CURRENT_SECTION="answer"
  ui_section "answer"
}

ui_ai_end() {
  ui_section_end
  printf '\n' >&2
}

# ─── Command block ────────────────────────────────────────────────────────────

# ui_cmd_block <file>
ui_cmd_block() {
  local file="$1"
  printf '\n' >&2
  _UI_CURRENT_SECTION="proposed commands"
  if ui_fancy_enabled; then
    printf '%s╭─ %sproposed commands%s ─%s╮%s\n' "${_C_BOLD_YELLOW}" "${_C_BOLD_YELLOW}" "${_C_BOLD_YELLOW}" "$(printf '%0.s─' $(seq 1 $(( _UI_WIDTH - 21 )) ))" "${_C_RESET}" >&2
    nl -ba "$file" | while IFS= read -r line; do
      printf '%s│%s %s\n' "${_C_BOLD_YELLOW}" "${_C_RESET}" "$line" >&2
    done
    printf '%s╰%s╯%s\n' "${_C_BOLD_YELLOW}" "$(printf '%0.s─' $(seq 1 $(( _UI_WIDTH )) ))" "${_C_RESET}" >&2
  else
    printf '--- proposed commands ---\n' >&2
    nl -ba "$file" >&2
    printf '--- end commands ---\n' >&2
  fi
  printf '\n' >&2
}

# ─── Execution output markers ─────────────────────────────────────────────────

ui_exec_begin() {
  printf '\n' >&2
  _UI_CURRENT_SECTION="execution output"
  ui_section "execution output"
}

ui_exec_end() {
  ui_section_end
  printf '\n' >&2
}

# ─── Round header for loop mode ───────────────────────────────────────────────

# ui_round_header <round> <max_rounds>
ui_round_header() {
  local round="$1" max="$2"
  printf '\n' >&2
  if ui_fancy_enabled; then
    printf '%s━%s%s\n' "${_C_BOLD_MAGENTA}" "$(printf '%0.s━' $(seq 1 $(( _UI_WIDTH )) ))" "${_C_RESET}" >&2
    printf '%sRound %d/%d%s\n' "${_C_BOLD_MAGENTA}" "$round" "$max" "${_C_RESET}" >&2
    printf '%s━%s%s\n' "${_C_BOLD_MAGENTA}" "$(printf '%0.s━' $(seq 1 $(( _UI_WIDTH )) ))" "${_C_RESET}" >&2
  else
    printf '--- Round %d/%d ---\n' "$round" "$max" >&2
  fi
  printf '\n' >&2
}

# ─── Spinner ──────────────────────────────────────────────────────────────────

_UI_SPINNER_PID=""

ui_spinner_start() {
  local msg="${1:-Waiting for model response...}"

  if ! ui_spinner_enabled; then
    # Still print a static message if TTY but spinner disabled
    if ui_is_tty; then
      printf '%s%s%s\n' "${_C_DIM}" "$msg" "${_C_RESET}" >&2
    fi
    return 0
  fi

  # Start spinner in background
  (
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    # Hide cursor
    printf '\033[?25l' >&2
    while true; do
      printf '\r%s%s %s%s' "${_C_CYAN}" "${frames[$i]}" "$msg" "${_C_RESET}" >&2
      i=$(( (i + 1) % ${#frames[@]} ))
      sleep 0.1
    done
  ) &
  _UI_SPINNER_PID=$!
  disown "$_UI_SPINNER_PID" 2>/dev/null || true
}

ui_spinner_stop() {
  if [ -n "${_UI_SPINNER_PID:-}" ]; then
    kill "$_UI_SPINNER_PID" 2>/dev/null || true
    wait "$_UI_SPINNER_PID" 2>/dev/null || true
    _UI_SPINNER_PID=""
  fi
  if ui_spinner_enabled; then
    # Clear line and show cursor
    printf '\r\033[K\033[?25h' >&2
  fi
}

# Trap to clean up spinner on exit
_ui_cleanup() {
  ui_spinner_stop
}
trap '_ui_cleanup' EXIT INT TERM
