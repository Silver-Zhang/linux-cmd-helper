#!/usr/bin/env bash
# copilot-cmd-context.sh — shared context helper functions for cmd/cmdx
# Provides context assembly functions with different verbosity levels.

# 确保跨平台公共函数（resolve_path 等）可用，即使本库在
# copilot-cmd-platform.sh 之前被 source 也能正常工作。
if ! command -v resolve_path >/dev/null 2>&1; then
  # shellcheck disable=SC1090
  [ -f "$HOME/.local/lib/copilot-cmd-platform.sh" ] && source "$HOME/.local/lib/copilot-cmd-platform.sh"
fi

# Env defaults for tail lines
CMD_LAST_RUN_TAIL="${CMD_LAST_RUN_TAIL:-200}"
CMD_LAST_RECORD_TAIL="${CMD_LAST_RECORD_TAIL:-300}"

# Base cache directory
_CTX_BASE="$HOME/.cache/copilot-cmd"

# --- append_policy_summary ---
# Short policy summary (replaces the long 10-rule block in default mode)
append_policy_summary() {
  cat <<'EOF'
你是 Linux 终端命令行助手。默认给只读检查命令；不要默认 sudo；不要访问其他用户目录；高风险操作必须提示风险；cmd 不执行命令；cmdx 只能在用户确认后执行命令。
EOF
}

# --- append_minimal_context ---
# Minimal context: pwd, user/host, backend, session note
append_minimal_context() {
  local backend="${1:-deepseek}"
  local model="${2:-}"

  echo "## Environment"
  echo '```text'
  echo "pwd:  $(pwd)"
  echo "user: $(whoami)"
  echo "host: $(hostname)"
  echo "backend: $backend"
  if [ -n "$model" ]; then
    echo "model: $model"
  fi
  echo '```'
}

# --- append_compact_context ---
# Compact context: pwd, user, host, git branch/status, df -h ., last-run/last-record meta (no output.log)
append_compact_context() {
  echo "## Environment"
  echo '```text'
  echo "pwd:   $(pwd)"
  echo "user:  $(whoami)"
  echo "host:  $(hostname)"
  echo "shell: ${SHELL:-unknown}"
  echo '```'
  echo

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "## Git Status"
    echo '```text'
    git status --short --branch 2>/dev/null || true
    echo '```'
    echo
  fi

  echo "## Disk"
  echo '```text'
  df -h . 2>/dev/null || true
  echo '```'
  echo

  # last-run meta only
  if [ -L "$_CTX_BASE/last-run" ] || [ -d "$_CTX_BASE/last-run" ]; then
    local run_dir
    run_dir="$(resolve_path "$_CTX_BASE/last-run" 2>/dev/null || true)"
    if [ -n "$run_dir" ] && [ -d "$run_dir" ]; then
      echo "## Latest cmd-run"
      echo "path: $run_dir"
      if [ -f "$run_dir/meta.txt" ]; then
        echo '```text'
        cat "$run_dir/meta.txt" 2>/dev/null || true
        echo '```'
      fi
      echo
    fi
  fi

  # last-record meta only
  if [ -L "$_CTX_BASE/last-record" ] || [ -d "$_CTX_BASE/last-record" ]; then
    local rec_dir
    rec_dir="$(resolve_path "$_CTX_BASE/last-record" 2>/dev/null || true)"
    if [ -n "$rec_dir" ] && [ -d "$rec_dir" ]; then
      echo "## Latest cmd-record"
      echo "path: $rec_dir"
      if [ -f "$rec_dir/meta.txt" ]; then
        echo '```text'
        cat "$rec_dir/meta.txt" 2>/dev/null || true
        echo '```'
      fi
      echo
    fi
  fi
}

# --- append_last_run_tail ---
# Appends last-run meta + output.log tail
append_last_run_tail() {
  if [ -L "$_CTX_BASE/last-run" ] || [ -d "$_CTX_BASE/last-run" ]; then
    local run_dir
    run_dir="$(resolve_path "$_CTX_BASE/last-run" 2>/dev/null || true)"
    if [ -n "$run_dir" ] && [ -d "$run_dir" ]; then
      echo "## Latest cmd-run"
      echo "path: $run_dir"
      echo
      if [ -f "$run_dir/meta.txt" ]; then
        echo "### meta.txt"
        echo '```text'
        cat "$run_dir/meta.txt" 2>/dev/null || true
        echo '```'
        echo
      fi
      if [ -f "$run_dir/output.log" ]; then
        echo "### output.log (tail ${CMD_LAST_RUN_TAIL} lines)"
        echo '```text'
        tail -n "$CMD_LAST_RUN_TAIL" "$run_dir/output.log" 2>/dev/null || true
        echo '```'
        echo
      fi
    else
      echo "## Latest cmd-run"
      echo "last-run: none (symlink target missing)"
      echo
    fi
  else
    echo "## Latest cmd-run"
    echo "last-run: none"
    echo
  fi
}

# --- append_last_record_tail ---
# Appends last-record meta + output.log tail
append_last_record_tail() {
  if [ -L "$_CTX_BASE/last-record" ] || [ -d "$_CTX_BASE/last-record" ]; then
    local rec_dir
    rec_dir="$(resolve_path "$_CTX_BASE/last-record" 2>/dev/null || true)"
    if [ -n "$rec_dir" ] && [ -d "$rec_dir" ]; then
      echo "## Latest cmd-record"
      echo "path: $rec_dir"
      echo
      if [ -f "$rec_dir/meta.txt" ]; then
        echo "### meta.txt"
        echo '```text'
        cat "$rec_dir/meta.txt" 2>/dev/null || true
        echo '```'
        echo
      fi
      if [ -f "$rec_dir/output.log" ]; then
        echo "### output.log (tail ${CMD_LAST_RECORD_TAIL} lines)"
        echo '```text'
        tail -n "$CMD_LAST_RECORD_TAIL" "$rec_dir/output.log" 2>/dev/null || true
        echo '```'
        echo
      fi
    else
      echo "## Latest cmd-record"
      echo "last-record: none (symlink target missing)"
      echo
    fi
  else
    echo "## Latest cmd-record"
    echo "last-record: none"
    echo
  fi
}

# --- append_model_info ---
# Appends model backend info block
append_model_info() {
  local backend="${1:-deepseek}"
  local model="${2:-}"
  local copilot_model="${3:-}"

  echo "## Model backend"
  echo '```text'
  echo "backend: $backend"
  if [ "$backend" = "deepseek" ]; then
    echo "model: ${copilot_model:-unknown}"
  else
    if [ -n "$model" ]; then
      echo "model: ${model} (--model)"
    else
      local native_model_file="$HOME/.config/copilot-cmd/current-native-model"
      if [ -f "$native_model_file" ] && [ -s "$native_model_file" ]; then
        echo "model: $(cat "$native_model_file")"
        echo "note: display label recorded by cmd-model; actual model is controlled by Copilot CLI /model"
      else
        echo "model: GitHub Copilot CLI current/default model"
      fi
    fi
  fi
  echo '```'
}
