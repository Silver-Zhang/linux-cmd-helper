#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# cmd-helper 跨平台安装器（Linux + macOS）
#
# 只安装到当前用户的家目录，绝不写入 /usr/local/bin、/opt/homebrew/bin
# 等系统目录；也绝不自动安装 Node/npm/Copilot CLI——只做检测和提示。
# ============================================================

PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------
# 0. 识别操作系统
# ------------------------------------------------------------
case "$(uname -s)" in
  Linux)  OS_TYPE="linux" ;;
  Darwin) OS_TYPE="macos" ;;
  *)
    echo "错误：不支持的操作系统：$(uname -s)" >&2
    echo "cmd-helper 仅支持 Linux 和 macOS。" >&2
    exit 1
    ;;
esac

echo "== cmd-helper 安装器 =="
echo "安装包目录: $PKG_DIR"
echo "操作系统:   $OS_TYPE ($(uname -s))"
echo "用户:       $(whoami)"
echo "家目录:     $HOME"
echo "Shell:      ${SHELL:-未知}"
echo

PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'

# ------------------------------------------------------------
# 公共函数
# ------------------------------------------------------------

# detect_shell_name：尽力得到用户 shell 的名字（zsh/bash/...）。
detect_shell_name() {
  if [ -n "${SHELL:-}" ]; then
    basename -- "$SHELL"
  else
    echo ""
  fi
}

# ensure_path_line <文件>：幂等地把 PATH_LINE 追加到 <文件>。
ensure_path_line() {
  local file="$1"
  if [ ! -e "$file" ]; then
    : > "$file"
  fi
  if grep -Fqs "$PATH_LINE" "$file"; then
    echo "PATH 已在该文件中配置过: $file"
  else
    printf '%s\n' "$PATH_LINE" >> "$file"
    echo "已把 ~/.local/bin 加入 PATH: $file"
  fi
}

# configure_path：按当前系统/shell 把 PATH 写入正确的启动文件。
configure_path() {
  local shell_name
  shell_name="$(detect_shell_name)"

  if [ "$OS_TYPE" = "macos" ]; then
    case "$shell_name" in
      zsh)
        ensure_path_line "$HOME/.zprofile"
        ensure_path_line "$HOME/.zshrc"
        ;;
      bash)
        ensure_path_line "$HOME/.bash_profile"
        ensure_path_line "$HOME/.bashrc"
        ;;
      *)
        echo "无法判断 shell，默认写入 zsh 启动文件。"
        ensure_path_line "$HOME/.zprofile"
        ;;
    esac
  else
    # Linux：~/.profile 是登录时配置 PATH 的标准位置。
    ensure_path_line "$HOME/.profile"
    if [ "$shell_name" = "bash" ]; then
      echo "提示：对于非登录 bash shell，你也可以把下面这行加入 ~/.bashrc："
      echo "  $PATH_LINE"
    fi
  fi
}

# ------------------------------------------------------------
# 1. 创建用户本地目录
# ------------------------------------------------------------
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/lib"
mkdir -p "$HOME/.config/copilot-deepseek"
mkdir -p "$HOME/.config/copilot-cmd"
mkdir -p "$HOME/.cache/copilot-cmd"
mkdir -p "$HOME/.copilot-cmd"

# ------------------------------------------------------------
# 2. 安装 bin 脚本
# ------------------------------------------------------------
if [ ! -d "$PKG_DIR/bin" ]; then
  echo "错误：缺少安装包 bin 目录：$PKG_DIR/bin" >&2
  exit 1
fi

cp -a "$PKG_DIR/bin/"* "$HOME/.local/bin/"
chmod 700 "$HOME/.local/bin"/cmd* 2>/dev/null || true
chmod 700 "$HOME/.local/bin"/copilot-* 2>/dev/null || true

# ------------------------------------------------------------
# 3. 安装 lib（包含跨平台公共函数库）
# ------------------------------------------------------------
if [ ! -d "$PKG_DIR/lib" ]; then
  echo "错误：缺少安装包 lib 目录：$PKG_DIR/lib" >&2
  exit 1
fi

cp -a "$PKG_DIR/lib/"* "$HOME/.local/lib/"
chmod 700 "$HOME/.local/lib"/*.sh 2>/dev/null || true

# ------------------------------------------------------------
# 4. 安装 Copilot native 模型显示列表（不覆盖已有）
# ------------------------------------------------------------
if [ -f "$PKG_DIR/config/copilot-models" ]; then
  if [ ! -f "$HOME/.config/copilot-cmd/copilot-models" ]; then
    cp -a "$PKG_DIR/config/copilot-models" "$HOME/.config/copilot-cmd/copilot-models"
    echo "已安装: ~/.config/copilot-cmd/copilot-models"
  else
    echo "保留已有: ~/.config/copilot-cmd/copilot-models"
  fi
fi

# ------------------------------------------------------------
# 5. 配置 DeepSeek API Key（可选）
# ------------------------------------------------------------
DS_ENV="$HOME/.config/copilot-deepseek/env"

if [ -f "$DS_ENV" ] && grep -q "COPILOT_PROVIDER_API_KEY" "$DS_ENV"; then
  echo "保留已有 DeepSeek 配置: $DS_ENV"
else
  echo
  echo "DeepSeek API Key 用于默认的 cmd/cmdx/cmd-chat DeepSeek 后端。"
  echo "它是可选的：你也可以跳过，改用 GitHub Copilot native 后端。"
  echo "如果填写，只会保存在你的私有文件中："
  echo "  $DS_ENV"
  echo
  DS_KEY=""
  if [ -t 0 ]; then
    read -r -s -p "请输入 DeepSeek API Key，或直接回车跳过：" DS_KEY || DS_KEY=""
    echo
  else
    echo "（非交互式安装：跳过 key 输入；如需可稍后编辑 $DS_ENV）"
  fi

  if [ -n "$DS_KEY" ]; then
    cat > "$DS_ENV" <<KEYEOF
export COPILOT_PROVIDER_API_KEY='$DS_KEY'
KEYEOF
    echo "已保存 DeepSeek key 到: $DS_ENV"
  else
    cat > "$DS_ENV" <<'KEYEOF'
# 在此填入你的 DeepSeek API Key 以使用 DeepSeek 后端：
# export COPILOT_PROVIDER_API_KEY='sk-...'
KEYEOF
    echo "已创建模板: $DS_ENV"
    echo "使用 DeepSeek 后端前请先编辑它，例如："
    echo "  \${EDITOR:-nano} $DS_ENV"
    echo "（如果只用 GitHub Copilot native 后端，则无需填写。）"
  fi
fi

# ------------------------------------------------------------
# 6. 收紧私有配置目录/文件权限
# ------------------------------------------------------------
chmod 700 "$HOME/.config/copilot-deepseek" 2>/dev/null || true
chmod 700 "$HOME/.config/copilot-cmd" 2>/dev/null || true
[ -f "$DS_ENV" ] && chmod 600 "$DS_ENV" 2>/dev/null || true
[ -f "$HOME/.config/copilot-cmd/copilot-models" ] && chmod 600 "$HOME/.config/copilot-cmd/copilot-models" 2>/dev/null || true

# ------------------------------------------------------------
# 7. 配置 PATH（跨平台，幂等）
# ------------------------------------------------------------
echo
configure_path

# 让工具在当前 shell 立即可用。
export PATH="$HOME/.local/bin:$PATH"

# ------------------------------------------------------------
# 8. 依赖检测（只检测和提示，绝不自动安装）
# ------------------------------------------------------------
echo
echo "== 依赖检测 =="

for dep in bash git; do
  if command -v "$dep" >/dev/null 2>&1; then
    echo "  正常:   $dep -> $(command -v "$dep")"
  else
    echo "  警告:   未找到 $dep"
  fi
done

for dep in node npm; do
  if command -v "$dep" >/dev/null 2>&1; then
    echo "  正常:   $dep -> $(command -v "$dep")"
  else
    echo "  缺失:   $dep（安装 GitHub Copilot CLI 需要它）"
  fi
done

echo
if command -v copilot >/dev/null 2>&1; then
  echo "已找到 copilot: $(command -v copilot)"
  copilot --version 2>/dev/null || true
else
  echo "警告：未找到 copilot 命令。"
  echo "cmd-helper 依赖 GitHub Copilot CLI。"
  if command -v npm >/dev/null 2>&1; then
    echo "可用以下命令安装："
    echo "  npm install -g @github/copilot"
  elif [ "$OS_TYPE" = "macos" ]; then
    if command -v brew >/dev/null 2>&1; then
      echo "请先安装 Node，再安装 Copilot CLI："
      echo "  brew install node"
      echo "  npm install -g @github/copilot"
    else
      echo "请通过 Homebrew 或 nvm 安装 Node.js，再安装 Copilot CLI："
      echo "  brew install node        # 如果你使用 Homebrew"
      echo "  npm install -g @github/copilot"
    fi
  else
    echo "请通过系统包管理器或 nvm 安装 Node.js/npm，然后执行："
    echo "  npm install -g @github/copilot"
  fi
fi

# script（cmd-record 使用）
echo
if command -v script >/dev/null 2>&1; then
  echo "  正常: script  -> $(command -v script)（cmd-record 使用）"
else
  echo "  提示: 未找到 'script'，cmd-record 将不可用。"
  if [ "$OS_TYPE" = "linux" ]; then
    echo "        Linux 上它通常来自 util-linux。"
  else
    echo "        macOS 上它通常由系统自带。"
  fi
fi

# crontab（cmd-trash-auto-* 使用）
if command -v crontab >/dev/null 2>&1; then
  echo "  正常: crontab -> $(command -v crontab)（cmd-trash-auto-* 使用）"
else
  echo "  提示: 未找到 'crontab'，定时清理回收站功能不可用。"
  echo "        你仍可手动清理：cmd-trash-prune [天数] [范围]"
fi

# ------------------------------------------------------------
# 9. 检查已安装脚本的语法
# ------------------------------------------------------------
echo
echo "正在检查已安装的脚本……"
for f in "$HOME/.local/bin"/cmd* "$HOME/.local/bin"/copilot-*; do
  [ -f "$f" ] || continue
  bash -n "$f" || {
    echo "错误：语法检查失败：$f" >&2
    exit 1
  }
done

# ------------------------------------------------------------
# 10. 结束提示
# ------------------------------------------------------------
echo
echo "安装完成。"
echo
echo "要在当前 shell 里立即使用 cmd，执行："
echo "  $PATH_LINE"
echo
if [ "$OS_TYPE" = "macos" ]; then
  echo "对于 macOS 新终端（zsh）：重新打开终端，或执行："
  echo "  source ~/.zshrc"
else
  echo "对于 Linux 新会话：重新登录 SSH，或执行："
  echo "  source ~/.profile"
fi
echo
echo "基本测试："
echo "  cmd --help"
echo "  cmd-context"
echo "  cmd-run echo OK"
echo "  cmd-git status        # 在 Git 仓库内"
echo
echo "使用 GitHub Copilot native 后端："
echo "  cmd-model"
echo "  /login"
echo "  /model"
echo "  /exit"
echo
echo "然后："
echo "  cmd --copilot \"只回答 OK\""
