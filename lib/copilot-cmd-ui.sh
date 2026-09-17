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
    # 格式串以 `-` 开头时必须加 `--`，否则 bash 的 printf 会把它当成选项并报
    # "printf: --: 无效的选项"。这里只在非 TTY / CMD_PLAIN 下才会走到，容易被忽略。
    printf -- '--- proposed commands ---\n' >&2
    nl -ba "$file" >&2
    printf -- '--- end commands ---\n' >&2
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
    # 同上：格式串以 `-` 开头，必须加 `--`
    printf -- '--- Round %d/%d ---\n' "$round" "$max" >&2
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

# ─── 退出清理钩子 ─────────────────────────────────────────────────────────────

_UI_EXIT_HOOKS=""

# 依次执行 spinner 收尾和调用方注册的清理命令。
_ui_run_exit_hooks() {
  # 先停 spinner：它会恢复被隐藏的光标
  ui_spinner_stop
  if [ -n "$_UI_EXIT_HOOKS" ]; then
    # shellcheck disable=SC2294
    eval "$_UI_EXIT_HOOKS"
  fi
  return 0
}

# ui_on_exit <命令>
# 注册脚本退出时要执行的清理命令，可以多次调用（先注册的先执行）。
#
# 请用它代替直接写 `trap '...' EXIT`，原因有两个：
#
#   1. 直接写 `trap ... EXIT` 会覆盖掉本库的清理，导致脚本异常退出时后台 spinner
#      不被回收、终端光标停留在隐藏状态（\033[?25l 之后没有 \033[?25h）。
#
#   2. 本库刻意**只捕获 EXIT，不捕获 INT/TERM**。捕获 INT/TERM 会让 SIGINT/SIGTERM
#      （含 Ctrl-C）被吞掉，脚本不会中断——用户就没法中止一个卡住的模型调用。
#      不捕获时 bash 会因信号退出，而 EXIT trap 依然会执行，清理不会丢。
ui_on_exit() {
  local cmd="${1:-}"
  [ -n "$cmd" ] || return 1

  if [ -n "$_UI_EXIT_HOOKS" ]; then
    # 用换行分隔，这样调用方可以注册多行命令
    _UI_EXIT_HOOKS="${_UI_EXIT_HOOKS}
${cmd}"
  else
    _UI_EXIT_HOOKS="$cmd"
  fi
  trap '_ui_run_exit_hooks' EXIT
}

# ─── 模型返回内容的呈现 ───────────────────────────────────────────────────────

# ui_model_reply <输出文件> <退出码> [成功时的区块标题]
#
# 成功时按原有格式把内容打到 stdout（保持可管道）；
# 失败时把 CLI 的原始输出打到 stderr 并明确报错——失败时 $file 里通常就是
# 认证失败、模型名不可用之类的错误信息，不打印出来用户只会看到一个退出码。
ui_model_reply() {
  local file="$1" rc="$2" title="${3:-answer}"

  printf '\n' >&2

  if [ ! -s "$file" ]; then
    ui_error "模型调用没有产生任何输出（退出码 ${rc}）。"
    printf '\n' >&2
    return 0
  fi

  if [ "$rc" -eq 0 ]; then
    _UI_CURRENT_SECTION="$title"
    ui_section "$title"
    cat "$file"
    ui_section_end
  else
    _UI_CURRENT_SECTION="model call failed"
    ui_section "model call failed (exit ${rc})"
    cat "$file" >&2
    ui_section_end
    printf '\n' >&2
    ui_error "模型调用失败（退出码 ${rc}）。上面是 CLI 的原始输出，常见原因见 README 第 24 节。"
  fi

  printf '\n' >&2
}
