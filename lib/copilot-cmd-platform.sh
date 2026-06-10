#!/usr/bin/env bash
# copilot-cmd-platform.sh —— cmd-helper 的跨平台公共函数库。
#
# 由需要在 Linux 和 macOS 上行为一致的 bin/* 脚本 source 引入。
# 必须保持 POSIX-bash 友好，且不得硬依赖 GNU coreutils，
# 因为 macOS 默认自带的是 BSD 版用户态工具。

# 防止重复 source（函数重复定义代价很小，这里只是保持整洁，
# 避免多个库互相引入时反复执行）。
if [ -n "${_COPILOT_CMD_PLATFORM_LOADED:-}" ]; then
  return 0 2>/dev/null || true
fi
_COPILOT_CMD_PLATFORM_LOADED=1

# --- cmd_detect_os ---
# 输出：linux | macos | unsupported
cmd_detect_os() {
  case "$(uname -s)" in
    Linux) echo "linux" ;;
    Darwin) echo "macos" ;;
    *) echo "unsupported" ;;
  esac
}

cmd_is_macos() { [ "$(uname -s)" = "Darwin" ]; }
cmd_is_linux() { [ "$(uname -s)" = "Linux" ]; }

# --- resolve_path ---
# 返回参数路径的绝对路径（并解析符号链接），效果等价于 GNU `readlink -f`，
# 但兼容 macOS/BSD（这些系统的 readlink 不支持 -f）。
#
# 解析顺序（取第一个非空结果）：
#   1. readlink -f             （Linux，或 macOS 上装了 GNU coreutils）
#   2. perl Cwd::abs_path       （macOS 默认自带 perl）
#   3. python3 os.path.realpath （仅当存在 python3 时）
#   4. 纯 shell 的 cd + pwd -P
#   5. 原样输出输入（兜底）
resolve_path() {
  local target="${1:-}"
  [ -n "$target" ] || return 1
  local out=""

  # 1) GNU readlink -f（较新的 macOS readlink 也支持）。
  out="$(readlink -f -- "$target" 2>/dev/null)" || out=""
  if [ -n "$out" ]; then printf '%s\n' "$out"; return 0; fi

  # 2) perl（macOS 默认自带；路径不存在时 abs_path 返回 undef）。
  if command -v perl >/dev/null 2>&1; then
    out="$(perl -e 'use Cwd "abs_path"; my $p = abs_path($ARGV[0]); print $p if defined $p;' "$target" 2>/dev/null)" || out=""
    if [ -n "$out" ]; then printf '%s\n' "$out"; return 0; fi
  fi

  # 3) python3 兜底（仅当存在时）。
  if command -v python3 >/dev/null 2>&1; then
    out="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$target" 2>/dev/null)" || out=""
    if [ -n "$out" ]; then printf '%s\n' "$out"; return 0; fi
  fi

  # 4) 纯 shell 兜底：用 cd + pwd -P 解析目录。
  if [ -d "$target" ]; then
    out="$(cd -- "$target" 2>/dev/null && pwd -P)" || out=""
    if [ -n "$out" ]; then printf '%s\n' "$out"; return 0; fi
  fi
  local dir base
  dir="$(dirname -- "$target")"
  base="$(basename -- "$target")"
  if [ -d "$dir" ]; then
    out="$(cd -- "$dir" 2>/dev/null && pwd -P)" || out=""
    if [ -n "$out" ]; then printf '%s/%s\n' "$out" "$base"; return 0; fi
  fi

  # 5) 兜底：原样输出输入路径。
  printf '%s\n' "$target"
  return 0
}

# --- cmd_require_command ---
# 必需命令缺失时，给出清晰提示并返回 1（失败）。
cmd_require_command() {
  local name="${1:-}"
  [ -n "$name" ] || return 1
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "错误：未找到必需命令：$name" >&2
    return 1
  fi
  return 0
}

# --- cmd_warn_missing_command ---
# 可选命令缺失时，仅给出警告并返回 1，不让脚本失败。
# 用法：cmd_warn_missing_command <命令名> ["补充说明"]
cmd_warn_missing_command() {
  local name="${1:-}"
  local msg="${2:-}"
  [ -n "$name" ] || return 1
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "警告：未找到可选命令：$name" >&2
    [ -n "$msg" ] && echo "  $msg" >&2
    return 1
  fi
  return 0
}

# --- safe_rm_rf_path ---
# 仅当目标严格位于允许的根目录之内时，才用 `rm -rf` 删除。
# 拒绝删除根目录本身，以及根目录之外的任何路径。
# 用法：safe_rm_rf_path <允许的根目录> <目标>
safe_rm_rf_path() {
  local root="${1:-}" target="${2:-}"
  [ -n "$root" ] && [ -n "$target" ] || return 1
  local rroot rtarget
  rroot="$(resolve_path "$root")"
  rtarget="$(resolve_path "$target")"
  case "$rtarget" in
    "$rroot"/?*) rm -rf -- "$rtarget" ;;
    *)
      echo "safe_rm_rf_path：拒绝删除 '$rtarget'（不在 '$rroot' 之内）" >&2
      return 1
      ;;
  esac
}
