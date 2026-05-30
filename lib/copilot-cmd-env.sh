#!/usr/bin/env bash

CONFIG="$HOME/.config/copilot-deepseek/env"

if [ ! -f "$CONFIG" ]; then
  echo "Missing config: $CONFIG" >&2
  echo "Please create it and add:" >&2
  echo "  export COPILOT_PROVIDER_API_KEY='your DeepSeek API key'" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG"

if [ -z "${COPILOT_PROVIDER_API_KEY:-}" ]; then
  echo "COPILOT_PROVIDER_API_KEY is empty in $CONFIG" >&2
  exit 1
fi

export COPILOT_PROVIDER_TYPE='anthropic'
export COPILOT_PROVIDER_BASE_URL='https://api.deepseek.com/anthropic'
export COPILOT_PROVIDER_MAX_PROMPT_TOKENS='840000'
export COPILOT_PROVIDER_MAX_OUTPUT_TOKENS='128000'

# cmd 助手默认使用 DeepSeek Flash
export COPILOT_MODEL="${COPILOT_MODEL:-deepseek-v4-flash}"

# cmd 专用 Copilot session 空间，不污染默认 ~/.copilot
export COPILOT_HOME="$HOME/.copilot-cmd"
mkdir -p "$COPILOT_HOME" "$HOME/.cache/copilot-cmd"
