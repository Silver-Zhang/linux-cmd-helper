#!/usr/bin/env bash
set -euo pipefail

echo "== cmd-helper uninstaller =="
echo

BIN_LIST="
cmd
cmdx
cmd-chat
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
copilot-cmd-send
"

for f in $BIN_LIST; do
  if [ -f "$HOME/.local/bin/$f" ]; then
    rm -f "$HOME/.local/bin/$f"
    echo "Removed: ~/.local/bin/$f"
  fi
done

if [ -f "$HOME/.local/lib/copilot-cmd-env.sh" ]; then
  rm -f "$HOME/.local/lib/copilot-cmd-env.sh"
  echo "Removed: ~/.local/lib/copilot-cmd-env.sh"
fi

echo
echo "Scripts removed."
echo
read -r -p "Remove user config and cache? This includes API key template/config, sessions, logs. Type yes to remove: " ans

if [ "$ans" = "yes" ]; then
  rm -rf "$HOME/.config/copilot-deepseek"
  rm -rf "$HOME/.config/copilot-cmd"
  rm -rf "$HOME/.cache/copilot-cmd"
  rm -rf "$HOME/.copilot-cmd"
  rm -rf "$HOME/.copilot-cmd-trash"
  rm -rf "$HOME/.cache/copilot-cmd-trash"
  echo "Removed config/cache/session directories."
else
  echo "Kept config/cache/session directories."
fi

echo "Uninstall completed."
