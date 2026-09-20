#!/usr/bin/env bash
# copilot-cmd-trash.sh —— 回收站定时清理（crontab）相关的公共函数。
#
# 由 cmd-trash-auto-on / cmd-trash-auto-off / cmd-trash-auto-status 三个脚本
# source 引入。本库只定义常量和函数，不产生任何副作用。

# crontab 中标记块的起止行，三个脚本必须保持一致。
CMD_TRASH_MARK_BEGIN="# BEGIN COPILOT-CMD-TRASH-AUTO"
CMD_TRASH_MARK_END="# END COPILOT-CMD-TRASH-AUTO"

# cmd_trash_crontab_read 会把当前 crontab 的完整内容写入这个全局变量。
CMD_TRASH_CRONTAB=""

# --- cmd_trash_crontab_read ---
# 安全读取当前用户的 crontab 到 $CMD_TRASH_CRONTAB。
#
# "no crontab for <user>" 属于正常情况（用户本来就没有 crontab），按空表处理；
# 其他任何读取失败都必须让调用方中止——否则会把「读取失败」误当成「空表」，
# 从而用一份空内容覆盖掉用户已有的 crontab。
cmd_trash_crontab_read() {
  local out=""
  if ! out="$(crontab -l 2>&1)"; then
    if printf '%s\n' "$out" | grep -Eq '^(crontab: )?no crontab for [^[:space:]]+$'; then
      out=""
    else
      echo "错误：读取 crontab 失败。为避免覆盖你已有的 crontab，本次不做任何修改。" >&2
      echo "  crontab 返回：$out" >&2
      return 1
    fi
  fi
  CMD_TRASH_CRONTAB="$out"
  return 0
}

# --- cmd_trash_mark_state ---
# 判断标记块状态，输出以下三者之一：
#   both   —— BEGIN 和 END 都存在，且 BEGIN 在前，块完整
#   none   —— 两个都不存在，即从未开启过
#   broken —— 只存在其中一个，或顺序颠倒（crontab 被手工改过 / 上次写入中断）
#
# 之所以要单独区分 broken，是因为 sed 的 "/BEGIN/,/END/d" 地址范围在缺少 END 时
# 会一直延伸到文件末尾，把标记之后用户自己的定时任务一并删掉。
cmd_trash_mark_state() {
  printf '%s\n' "$CMD_TRASH_CRONTAB" | awk -v b="$CMD_TRASH_MARK_BEGIN" -v e="$CMD_TRASH_MARK_END" '
    $0 == b { begins++ ; if (first_begin == 0) first_begin = NR }
    $0 == e { ends++   ; if (first_end == 0) first_end = NR }
    END {
      if (begins == 0 && ends == 0) print "none"
      else if (begins == 1 && ends == 1 && first_begin < first_end) print "both"
      else print "broken"
    }
  '
}

# --- cmd_trash_crontab_strip ---
# 输出「移除标记块之后」的 crontab 内容。
#
# 用 awk 精确匹配整行，而不是 sed 的地址范围，理由见 cmd_trash_mark_state。
# 调用前应先用 cmd_trash_mark_state 确认状态不是 broken。
cmd_trash_crontab_strip() {
  # crontab 本来就不存在时不要输出一个空行，否则写回的 crontab 会以此开头。
  [ -n "$CMD_TRASH_CRONTAB" ] || return 0

  printf '%s\n' "$CMD_TRASH_CRONTAB" | awk -v b="$CMD_TRASH_MARK_BEGIN" -v e="$CMD_TRASH_MARK_END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip   { print }
  '
}

# --- cmd_trash_crontab_block ---
# 输出标记块本身（含 BEGIN 和 END 两行）。
cmd_trash_crontab_block() {
  printf '%s\n' "$CMD_TRASH_CRONTAB" | awk -v b="$CMD_TRASH_MARK_BEGIN" -v e="$CMD_TRASH_MARK_END" '
    $0 == b { inblock = 1 }
    inblock { print }
    $0 == e { inblock = 0 }
  '
}

# --- cmd_trash_crontab_is_empty <内容> ---
# 内容只含空行时返回 0（视为空），否则返回 1。
cmd_trash_crontab_is_empty() {
  if printf '%s\n' "${1:-}" | grep -qv '^[[:space:]]*$'; then
    return 1
  fi
  return 0
}
