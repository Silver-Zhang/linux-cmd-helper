#!/usr/bin/env bash
set -euo pipefail

if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ]; then
  echo "错误：HOME 为空或为 /，为避免误删系统文件，拒绝卸载。" >&2
  exit 1
fi
case "$HOME" in
  /*) ;;
  *)
    echo "错误：HOME 必须是绝对路径，为避免误删文件，拒绝卸载。" >&2
    exit 1
    ;;
esac
HOME_REAL="$(cd -- "$HOME" 2>/dev/null && pwd -P)" || {
  echo "错误：无法解析 HOME，为避免误删文件，拒绝卸载。" >&2
  exit 1
}
if [ "$HOME_REAL" = "/" ] || [ -z "$HOME_REAL" ]; then
  echo "错误：HOME 解析为根目录，为避免误删系统文件，拒绝卸载。" >&2
  exit 1
fi

echo "== cmd-helper 卸载器 =="
echo

BIN_LIST="
cmd
cmdx
cmd-chat
cmd-git
cmd-new
cmd-resume
cmd-context
cmd-run
cmd-record
cmd-suggest
cmd-clean
cmd-trash-list
cmd-trash-empty
cmd-trash-prune
cmd-trash-auto-on
cmd-trash-auto-off
cmd-trash-auto-status
cmd-model
cmd-model-set
cmd-model-current
cmd-question
cmd-version
copilot-cmd-send
"

for f in $BIN_LIST; do
  if [ -f "$HOME/.local/bin/$f" ]; then
    rm -f "$HOME/.local/bin/$f"
    echo "已删除: ~/.local/bin/$f"
  fi
done

LIB_LIST="
copilot-cmd-platform.sh
copilot-cmd-env.sh
copilot-cmd-context.sh
copilot-cmd-ui.sh
copilot-cmd-trash.sh
VERSION
"

for f in $LIB_LIST; do
  if [ -f "$HOME/.local/lib/$f" ]; then
    rm -f "$HOME/.local/lib/$f"
    echo "已删除: ~/.local/lib/$f"
  fi
done

echo
echo "脚本已删除。"
echo
if ! read -r -p "是否删除用户配置和缓存？这包括 API key 模板/配置、session、日志。输入 YES I UNDERSTAND 删除：" ans; then
  ans=""
fi

if [ "$ans" = "YES I UNDERSTAND" ]; then
  rm -rf "$HOME/.config/copilot-deepseek"
  rm -rf "$HOME/.config/copilot-cmd"
  rm -rf "$HOME/.cache/copilot-cmd"
  rm -rf "$HOME/.copilot-cmd"
  rm -rf "$HOME/.copilot-cmd-trash"
  rm -rf "$HOME/.cache/copilot-cmd-trash"
  echo "已删除配置/缓存/session 目录。"
else
  echo "已保留配置/缓存/session 目录。"
fi

echo
echo "注意：PATH 配置行不会被自动删除。"
echo "如果想清理，请手动检查以下文件中是否有这一行："
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo "  ~/.profile  ~/.bashrc  ~/.bash_profile  ~/.zprofile  ~/.zshrc"
echo
echo "卸载完成。"
