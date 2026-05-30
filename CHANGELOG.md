# Changelog

## v0.2.0

Context injection optimization: default minimal context, on-demand loading.

Features:

- `cmd` and `cmdx` now default to **minimal context** (pwd, user/host, backend, short policy summary).
- New context mode flags:
  - `-c` / `--context`: compact context (git status, disk, last-run/last-record meta).
  - `--last-run`: compact context + last-run output.log tail.
  - `--last-record`: compact context + last-record output.log tail.
  - `--full-context`: full context via cmd-context (directory listing, bash history, etc.).
- Recent Bash History is **no longer sent by default**; only included with `--full-context`.
- Added `lib/copilot-cmd-context.sh` with shared context helper functions.
- Configurable tail line counts via `CMD_LAST_RUN_TAIL` and `CMD_LAST_RECORD_TAIL` environment variables.
- Updated README with context mode documentation.

Security:

- Bash history no longer leaks to model by default.
- No default directory listing sent to model.
- `cmdx` human approval mechanism unchanged.

## Unreleased

### Added
- Add lightweight terminal UI helpers (`lib/copilot-cmd-ui.sh`) for clearer command output.
- Add spinner while waiting for model responses.
- Add `CMD_PLAIN` and `CMD_NO_SPINNER` environment variables.

### Changed
- Improve separation between model info, question preview, AI response, command approval, and execution output.
- `cmdx --loop` now displays clear round headers for each iteration.

### Added
- Add `cmdx --loop` for multi-round user-approved command execution.

- Prepare the project for open-source release.

## v0.1.0

Initial public release.

Features:

- `cmd`: non-invasive AI terminal Q&A.
- `cmdx`: user-approved command execution workflow.
- `cmd-chat`: shared interactive chat session.
- `cmd-context`: terminal context snapshot.
- `cmd-run`: single-command logging.
- `cmd-record`: recorded shell session.
- `cmd-suggest`: context-aware question suggestions.
- Session, cache, trash, and auto-prune management.
- DeepSeek BYOK support.
- GitHub Copilot native model workflow through `cmd-model`.
