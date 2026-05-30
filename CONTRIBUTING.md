# Contributing

Contributions are welcome.

## Development Principles

This project is a Linux terminal AI assistant wrapper. Please follow these principles:

1. Do not introduce shell execution without explicit user approval.
2. Do not hardcode user-specific paths, API keys, tokens, hostnames, or server names.
3. Keep scripts readable and maintainable.
4. Prefer safe defaults: read-only checks before write operations.
5. Preserve the separation between:
   - user configuration
   - runtime cache
   - chat sessions
   - public install package
6. Do not store real user prompts, terminal logs, API keys, or Copilot sessions in this repository.
7. Avoid destructive defaults. Commands such as sudo, rm -rf, chmod -R, chown -R, dd, mkfs, firewall changes, Docker deletion, shutdown, reboot, and service restart must require explicit user confirmation.

## Testing

Before submitting changes, run:

    bash -n install.sh
    bash -n uninstall.sh
    find ./bin ./lib -type f -print0 | xargs -0 -I{} bash -n {}

Recommended manual tests:

    cmd "only answer OK"
    cmd -m pro "only answer OK"
    cmdx "check whether current directory is a Git repository; propose read-only commands if needed"
    cmd-suggest
    cmd-clean sessions

## Pull Requests

Please include:

- What changed
- Why it changed
- How it was tested
- Any security impact
- Any compatibility impact for existing users

## Security

Do not commit credentials or runtime data. See SECURITY.md for details.
