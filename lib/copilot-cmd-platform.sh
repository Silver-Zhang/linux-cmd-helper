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

# --- cmd_redact_stream ---
# Redact common credentials before text enters a context snapshot or model prompt.
# This intentionally handles common shell/config forms; it is not a secret scanner.
cmd_redact_stream() {
  sed -E \
    -e 's#(https?://)[^/@[:space:]]+@#\1<redacted>@#g' \
    -e 's#([?&](api[_-]?key|access[_-]?token|token|password|passwd|secret)=)[^&#[:space:]]+#\1<redacted>#gi' \
    -e 's#((api[_-]?key|access[_-]?token|token|password|passwd|secret)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted>#gi' \
    -e 's#(Bearer[[:space:]]+)[^[:space:]]+#\1<redacted>#gi' \
    -e 's#-----BEGIN [A-Z ]*PRIVATE KEY-----#<redacted-private-key>#g'
}

# --- cmd_redact_file_tail <file> <lines> ---
cmd_redact_file_tail() {
  local file="${1:-}" lines="${2:-50}"
  [ -f "$file" ] || return 1
  case "$lines" in
    ''|*[!0-9]*) lines=50 ;;
  esac
  tail -n "$lines" "$file" 2>/dev/null | cmd_redact_stream
}


# 仅当目标严格位于允许的根目录之内时，才用 `rm -rf` 删除。
# 拒绝删除根目录本身、根目录之外的路径，以及无法解析的路径。
# 如果目标本身是符号链接，只删除链接，不跟随链接删除其目标。
# 用法：safe_rm_rf_path <允许的根目录> <目标>
safe_rm_rf_path() {
  local root="${1:-}" target="${2:-}"
  [ -n "$root" ] && [ -n "$target" ] || return 1

  local rroot parent name rparent lexical_target resolved_target
  rroot="$(resolve_path "$root")" || return 1
  [ -d "$rroot" ] || return 1

  # Resolve only the parent.  Resolving the target itself would follow a
  # symlink and could make rm -rf delete the link's target instead of the link.
  parent="$(dirname -- "$target")"
  name="$(basename -- "$target")"
  rparent="$(resolve_path "$parent")" || return 1
  lexical_target="$rparent/$name"

  case "$lexical_target" in
    "$rroot"/?*)
      ;;
    *)
      echo "safe_rm_rf_path：拒绝删除 '$lexical_target'（不在 '$rroot' 之内）" >&2
      return 1
      ;;
  esac
  if [ "$rparent" != "$rroot" ]; then
    echo "safe_rm_rf_path：拒绝删除非直接子项 '$target'" >&2
    return 1
  fi

  if [ -L "$target" ]; then
    rm -f -- "$target"
    return $?
  fi

  [ -e "$target" ] || {
    echo "safe_rm_rf_path：目标不存在 '$target'" >&2
    return 1
  }

  resolved_target="$(resolve_path "$target")" || return 1
  case "$resolved_target" in
    "$rroot"/?*) rm -rf -- "$target" ;;
    *)
      echo "safe_rm_rf_path：拒绝删除 '$resolved_target'（不在 '$rroot' 之内）" >&2
      return 1
      ;;
  esac
}
