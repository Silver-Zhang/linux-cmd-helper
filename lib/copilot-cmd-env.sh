#!/usr/bin/env bash

CONFIG="$HOME/.config/copilot-deepseek/env"

# This library is sourced before commands parse their backend flags.  It must
# not source the DeepSeek config here: native Copilot users may not have one,
# and a user config should never be evaluated on the native path.

cmd_init_runtime() {
  # cmd-specific Copilot state and cache are shared by both backends.
  export COPILOT_HOME="$HOME/.copilot-cmd"
  mkdir -p "$COPILOT_HOME" "$HOME/.cache/copilot-cmd"
}

cmd_require_deepseek_key() {
  if [ ! -f "$CONFIG" ]; then
    echo "Missing config: $CONFIG" >&2
    echo "Please create it and add:" >&2
    echo "  export COPILOT_PROVIDER_API_KEY='your DeepSeek API key'" >&2
    return 1
  fi

  # shellcheck disable=SC1090
  source "$CONFIG"

  if [ -z "${COPILOT_PROVIDER_API_KEY:-}" ]; then
    echo "COPILOT_PROVIDER_API_KEY is empty in $CONFIG" >&2
    return 1
  fi

  export COPILOT_PROVIDER_TYPE='anthropic'
  export COPILOT_PROVIDER_BASE_URL='https://api.deepseek.com/anthropic'
  export COPILOT_PROVIDER_MAX_PROMPT_TOKENS='840000'
  export COPILOT_PROVIDER_MAX_OUTPUT_TOKENS='128000'
  return 0
}

# DeepSeek 上游模型名的唯一来源。
# 上游改名时无需修改任何脚本，在自己的 ~/.config/copilot-deepseek/env 里覆盖即可：
#   export CMD_DEEPSEEK_FLASH_MODEL='deepseek-flash'
CMD_DEEPSEEK_FLASH_MODEL="${CMD_DEEPSEEK_FLASH_MODEL:-deepseek-flash}"
CMD_DEEPSEEK_PRO_MODEL="${CMD_DEEPSEEK_PRO_MODEL:-deepseek-v4-pro}"
export CMD_DEEPSEEK_FLASH_MODEL CMD_DEEPSEEK_PRO_MODEL
