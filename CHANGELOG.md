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
- Add `cmd-git`, a Git-aware assistant for repository status analysis and command suggestions.
- Add lightweight terminal UI helpers (`lib/copilot-cmd-ui.sh`) for clearer command output.
- Add spinner while waiting for model responses.
- Add `CMD_PLAIN` and `CMD_NO_SPINNER` environment variables.
- Add `cmdx --loop` for multi-round user-approved command execution.
- Add `cmd-new` to start a new cmd session: injects current terminal context and last-record, sends the task description as the first message (non-interactive), and disables `shell`/`write` tools for safety. Subsequent `cmd`/`cmdx`/`cmd-chat` continue this session.
- Add `cmd-resume` to open the cmd session picker (`copilot --resume`) and restore a previous task without deleting any session.
- Add `cmd-question` to print the most recently submitted `cmd`/`cmdx` question.
- `cmd-new` and `cmd-resume` support backend/model flags (`-m flash|pro`, `--copilot`) consistent with `cmd`/`cmdx`/`cmd-chat`.

### Changed
- Improve separation between model info, question preview, AI response, command approval, and execution output.
- `cmdx --loop` now displays clear round headers for each iteration.
- Update the default DeepSeek Flash model to `deepseek-flash` (upstream renamed it from
  `deepseek-v4-flash`; the old name still resolves but is now an alias). `deepseek-v4-pro` is unchanged.
- DeepSeek model names are no longer hardcoded in each script. They are defined once in
  `lib/copilot-cmd-env.sh` as `CMD_DEEPSEEK_FLASH_MODEL` / `CMD_DEEPSEEK_PRO_MODEL`, and every
  `bin/` script now references those variables. Users can override them from
  `~/.config/copilot-deepseek/env` without touching the repository.

### Fixed
- `uninstall.sh` now removes `cmd-new`, `cmd-resume`, and all installed `lib/copilot-cmd-*.sh` helpers (previously only `copilot-cmd-env.sh` was removed).
- Fix trash entries being deleted immediately instead of after the retention period.
  `cmd-clean` moves entries into the trash with `mv`, which preserves the directory's original
  mtime, while `cmd-trash-prune` deletes by `-mtime`. An entry whose mtime was already older than
  the retention window was therefore removed by the next prune run (usually the daily cron job)
  rather than being kept for N days. `cmd-clean` now resets the timestamp on move, so the
  retention period counts from the moment the entry enters the trash.
- Fix `cmd-trash-auto-off` deleting unrelated crontab entries. It removed the marker block with
  `sed "/BEGIN/,/END/d"`; when the crontab held a `BEGIN` without a matching `END`, the address
  range extended to the end of the file and every entry after the marker was removed. The same
  code path could also wipe the entire crontab when `crontab -l` failed, because a read error was
  indistinguishable from an empty table.
- `cmd-trash-auto-on` had the same two problems and is fixed the same way.
- Add `lib/copilot-cmd-trash.sh`: shared crontab helpers that read the crontab safely (only
  "no crontab for <user>" is treated as empty), validate that the marker pair is complete and
  correctly ordered before any modification, and remove the block with an exact-line `awk`
  match instead of a `sed` address range.
- `cmd-trash-auto-status` now reports a half-present marker block instead of silently reporting
  the feature as enabled, and reads the crontab once instead of three times.
- `cmd-trash-auto-on` now writes the absolute path reported by `command -v cmd-trash-prune`
  rather than hardcoding `~/.local/bin`, and refuses to install a cron entry that could not run.
- `cmd`, `cmdx` and `cmd-git` no longer exit silently when the model call fails. Because the call
  site ran under `set -e`, a non-zero return exited the script before the response file was
  printed: the user saw only an exit code while the CLI's error message sat unread in a temp file.
  The failure is now captured, the CLI output is printed to stderr, and the CLI's exit code is
  returned. `cmdx --loop` reports which round failed before stopping.
- The terminal cursor is no longer left hidden after a failed or interrupted model call.
  `lib/copilot-cmd-ui.sh` installed its cleanup with `trap ... EXIT INT TERM`, but every script
  then replaced the EXIT trap with its own, so the spinner was never stopped on abnormal exit and
  the `\033[?25l` that hides the cursor had no matching `\033[?25h`.
- `Ctrl+C` and `SIGTERM` now actually interrupt `cmd` / `cmdx` / `cmd-git`. Because the UI library
  trapped `INT` and `TERM`, those signals were swallowed and a hung model call could not be
  aborted. The library now traps `EXIT` only — bash still runs the EXIT trap when the shell dies
  from an untrapped signal, so cleanup is preserved — and exposes `ui_on_exit`, which callers use
  to register cleanup instead of overwriting the trap.
- Fix `printf: --: invalid option` on the non-TTY / `CMD_PLAIN` output path. The format strings in
  `ui_cmd_block` and `ui_round_header` begin with `---`, which bash's `printf` parses as options.
  This made `cmdx "..." | tee log` and `cmdx --loop` print an error instead of the command block.

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
