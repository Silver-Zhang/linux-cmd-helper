# Security Policy

## Secrets

Do not commit API keys, GitHub tokens, DeepSeek keys, Anthropic tokens, OpenAI keys, SSH private keys, or any other credentials.

User-specific secrets should be stored only in the user's private configuration file:

    ~/.config/copilot-deepseek/env

This file is intentionally not part of this repository.

A typical local configuration file may look like:

    export COPILOT_PROVIDER_API_KEY='your DeepSeek API key'

Never commit a real key.

## Local Runtime Data

This tool may store local runtime data under:

    ~/.copilot-cmd
    ~/.cache/copilot-cmd
    ~/.copilot-cmd-trash
    ~/.cache/copilot-cmd-trash

These directories may contain prompts, command outputs, terminal logs, model responses, approved command execution records, and session metadata.

Do not upload these directories to public repositories.

## Public Deployment

When deploying this tool to a shared server directory, the public package must not contain:

- DeepSeek API keys
- GitHub tokens
- Anthropic tokens
- OpenAI API keys
- SSH private keys
- Personal shell history
- Runtime logs
- User-specific cache directories
- User-specific Copilot sessions

The public package should contain only scripts, documentation, and template configuration files.

## Approved Command Execution

The `cmdx` command may execute shell commands only after explicit user approval.

Users should carefully review every command before confirming execution.

Potentially destructive commands, including but not limited to `sudo`, `rm -rf`, `mkfs`, `dd`, `chmod -R`, `chown -R`, firewall modifications, Docker deletion, shutdown, reboot, and service stop/restart operations, require additional caution.

## Reporting Security Issues

If you find a security issue, please do not publish exploit details publicly before maintainers have had time to respond.

Report the issue privately to the maintainers or open a security advisory if the repository supports private vulnerability reporting.
