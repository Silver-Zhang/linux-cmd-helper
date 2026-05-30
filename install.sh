#!/usr/bin/env bash
set -euo pipefail

PKG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "== cmd-helper installer =="
echo "Package: $PKG_DIR"
echo "User:    $(whoami)"
echo "Home:    $HOME"
echo

# 1. 创建用户本地目录
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.local/lib"
mkdir -p "$HOME/.config/copilot-deepseek"
mkdir -p "$HOME/.config/copilot-cmd"
mkdir -p "$HOME/.cache/copilot-cmd"
mkdir -p "$HOME/.copilot-cmd"

# 2. 安装 bin 脚本
if [ ! -d "$PKG_DIR/bin" ]; then
  echo "ERROR: missing package bin directory: $PKG_DIR/bin" >&2
  exit 1
fi

cp -a "$PKG_DIR/bin/"* "$HOME/.local/bin/"
chmod 700 "$HOME/.local/bin"/cmd* 2>/dev/null || true
chmod 700 "$HOME/.local/bin"/copilot-* 2>/dev/null || true

# 3. 安装 lib
if [ ! -d "$PKG_DIR/lib" ]; then
  echo "ERROR: missing package lib directory: $PKG_DIR/lib" >&2
  exit 1
fi

cp -a "$PKG_DIR/lib/"* "$HOME/.local/lib/"
chmod 700 "$HOME/.local/lib"/*.sh 2>/dev/null || true

# 4. 安装 Copilot native 模型显示列表
if [ -f "$PKG_DIR/config/copilot-models" ]; then
  if [ ! -f "$HOME/.config/copilot-cmd/copilot-models" ]; then
    cp -a "$PKG_DIR/config/copilot-models" "$HOME/.config/copilot-cmd/copilot-models"
    chmod 600 "$HOME/.config/copilot-cmd/copilot-models"
  else
    echo "Keep existing: ~/.config/copilot-cmd/copilot-models"
  fi
fi

# 5. 配置 DeepSeek API Key
DS_ENV="$HOME/.config/copilot-deepseek/env"

if [ -f "$DS_ENV" ] && grep -q "COPILOT_PROVIDER_API_KEY" "$DS_ENV"; then
  echo "Keep existing DeepSeek config: $DS_ENV"
else
  echo
  echo "DeepSeek API Key is required for default cmd/cmdx/cmd-chat DeepSeek backend."
  echo "It will be saved only in your private file:"
  echo "  $DS_ENV"
  echo
  read -r -s -p "Input DeepSeek API Key, or press Enter to skip: " DS_KEY
  echo

  if [ -n "$DS_KEY" ]; then
    cat > "$DS_ENV" <<KEYEOF
export COPILOT_PROVIDER_API_KEY='$DS_KEY'
KEYEOF
    chmod 600 "$DS_ENV"
    echo "Saved DeepSeek key to: $DS_ENV"
  else
    cat > "$DS_ENV" <<'KEYEOF'
# Fill your DeepSeek API Key here:
# export COPILOT_PROVIDER_API_KEY='sk-...'
KEYEOF
    chmod 600 "$DS_ENV"
    echo "Created template: $DS_ENV"
    echo "You need to edit it before using DeepSeek backend:"
    echo "  nano $DS_ENV"
  fi
fi

chmod 700 "$HOME/.config/copilot-deepseek"
chmod 700 "$HOME/.config/copilot-cmd"

# 6. PATH 配置：只写 ~/.profile，不写 ~/.bashrc
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.profile" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
  echo "Added ~/.local/bin to PATH in ~/.profile"
else
  echo "PATH already configured in ~/.profile"
fi

# 当前 shell 临时提示
export PATH="$HOME/.local/bin:$PATH"

# 7. 检查 Copilot CLI 是否存在
echo
if command -v copilot >/dev/null 2>&1; then
  echo "Found copilot: $(command -v copilot)"
  copilot --version || true
else
  echo "WARNING: copilot command not found."
  echo
  echo "cmd-helper depends on GitHub Copilot CLI."
  echo "If Node/npm is available, you can install it with:"
  echo "  npm install -g @github/copilot"
  echo
  echo "If npm is not available, install Node.js with nvm first."
fi

# 8. 语法检查
echo
echo "Checking installed scripts..."
for f in "$HOME/.local/bin"/cmd* "$HOME/.local/bin"/copilot-*; do
  [ -f "$f" ] || continue
  bash -n "$f" || {
    echo "ERROR: syntax check failed: $f" >&2
    exit 1
  }
done

echo
echo "Installation completed."
echo
echo "If cmd is not found in current shell, run:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo
echo "Basic tests:"
echo "  cmd \"只回答 OK\""
echo "  cmd -m pro \"只回答 OK\""
echo "  cmdx \"请判断当前目录是否是 Git 仓库，必要时提出只读命令\""
echo
echo "For GitHub Copilot native backend:"
echo "  cmd-model"
echo "  /login"
echo "  /model"
echo "  /exit"
echo
echo "Then:"
echo "  cmd --copilot \"只回答 OK\""
