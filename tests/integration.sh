#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  printf 'ok - %s\n' "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf 'not ok - %s\n' "$1" >&2
  [ "$#" -gt 1 ] && printf '%s\n' "$2" >&2
}

assert_file_contains() {
  local name="$1" file="$2" pattern="$3"
  if grep -Fq "$pattern" "$file"; then pass "$name"; else fail "$name" "missing '$pattern' in $file"; fi
}

stage_home() {
  TEST_HOME="$TMP_ROOT/home-$RANDOM"
  mkdir -p "$TEST_HOME/.local/lib" "$TEST_HOME/.local/bin" \
    "$TEST_HOME/.config/copilot-deepseek" "$TEST_HOME/.config/copilot-cmd" \
    "$TEST_HOME/.cache/copilot-cmd"
  cp "$ROOT"/lib/*.sh "$TEST_HOME/.local/lib/"
  cp "$ROOT"/bin/* "$TEST_HOME/.local/bin/"
}

run_home() {
  HOME="$TEST_HOME" PATH="$TMP_ROOT/fakebin:$TEST_HOME/.local/bin:$PATH" "$@"
}

mkdir -p "$TMP_ROOT/fakebin"

# Every fake Copilot invocation records that it was reached and returns a
# harmless answer. Tests never contact a provider or use a real API key.
cat > "$TMP_ROOT/fakebin/copilot" <<'FAKE_COPILOT'
#!/usr/bin/env bash
printf '%s\n' "fake-copilot-called" >> "${FAKE_COPILOT_LOG:?}"
printf '%s\n' "native-test-answer"
FAKE_COPILOT
chmod +x "$TMP_ROOT/fakebin/copilot"

cat > "$TMP_ROOT/fakebin/crontab" <<'FAKE_CRONTAB'
#!/usr/bin/env bash
state="${FAKE_CRONTAB_STATE:?}"
if [ "${FAKE_CRONTAB_FAIL:-0}" = "1" ] && [ "${1:-}" = "-l" ]; then
  echo "crontab: permission denied" >&2
  exit 1
fi
case "${1:-}" in
  -l)
    if [ -f "$state" ]; then
      cat "$state"
      exit 0
    fi
    echo "no crontab for integration-test" >&2
    exit 1
    ;;
  -r)
    if [ "${FAKE_CRONTAB_REMOVE_FAIL:-0}" = "1" ]; then
      echo "crontab: remove failed" >&2
      exit 1
    fi
    rm -f "$state"
    ;;
  -|"")
    cat > "$state"
    ;;
  *)
    echo "unsupported fake crontab invocation: $*" >&2
    exit 1
    ;;
esac
FAKE_CRONTAB
chmod +x "$TMP_ROOT/fakebin/crontab"

# 1. Native-only paths work without a DeepSeek config or key.
stage_home
export FAKE_COPILOT_LOG="$TEST_HOME/copilot.log"
printf '# no DeepSeek key\n' > "$TEST_HOME/.config/copilot-deepseek/env"
for spec in 'cmd --help' 'cmd --copilot test' 'cmdx --help' \
  'cmdx --copilot test' 'cmd-new --copilot test' 'cmd-chat --copilot' \
  'cmd-resume --copilot'; do
  set -- $spec
  command_name="$1"
  shift
  if run_home bash "$TEST_HOME/.local/bin/$command_name" "$@" >/dev/null 2>&1; then
    pass "native-only $spec"
  else
    fail "native-only $spec"
  fi
done
mkdir -p "$TEST_HOME/repo"
git -C "$TEST_HOME/repo" init -q
if (cd "$TEST_HOME/repo" && run_home bash "$TEST_HOME/.local/bin/cmd-git" --copilot status >/dev/null 2>&1); then
  pass 'native-only cmd-git --copilot'
else
  fail 'native-only cmd-git --copilot'
fi

# 2. DeepSeek still fails clearly when the selected backend lacks a key.
stage_home
printf '# empty\n' > "$TEST_HOME/.config/copilot-deepseek/env"
if run_home bash "$TEST_HOME/.local/bin/cmd" --deepseek test >/tmp/cmd-helper-test.out 2>&1; then
  fail 'DeepSeek missing key fails'
else
  assert_file_contains 'DeepSeek missing key message' /tmp/cmd-helper-test.out 'COPILOT_PROVIDER_API_KEY is empty'
fi
rm -f /tmp/cmd-helper-test.out

# 3. Safe deletion only removes direct children and never follows symlinks.
source "$ROOT/lib/copilot-cmd-platform.sh"
SAFE_ROOT="$TMP_ROOT/safe-root"
mkdir -p "$SAFE_ROOT/child/nested" "$TMP_ROOT/outside"
printf x > "$SAFE_ROOT/child/file"
printf secret > "$TMP_ROOT/outside/secret"
ln -s "$TMP_ROOT/outside" "$SAFE_ROOT/link-out"
if safe_rm_rf_path "$SAFE_ROOT" "$SAFE_ROOT/child" && [ ! -e "$SAFE_ROOT/child" ]; then
  pass 'safe deletion allows direct child'
else
  fail 'safe deletion allows direct child'
fi
if safe_rm_rf_path "$SAFE_ROOT" "$SAFE_ROOT/child/nested" 2>/dev/null; then
  fail 'safe deletion rejects nested child'
else
  pass 'safe deletion rejects nested child'
fi
if safe_rm_rf_path "$SAFE_ROOT" "$SAFE_ROOT" 2>/dev/null; then
  fail 'safe deletion rejects root itself'
else
  pass 'safe deletion rejects root itself'
fi
if safe_rm_rf_path "$SAFE_ROOT" "$TMP_ROOT/outside" 2>/dev/null; then
  fail 'safe deletion rejects outside path'
else
  pass 'safe deletion rejects outside path'
fi
if safe_rm_rf_path "$SAFE_ROOT" "$SAFE_ROOT/link-out" \
    && [ ! -e "$SAFE_ROOT/link-out" ] && [ -f "$TMP_ROOT/outside/secret" ]; then
  pass 'safe deletion does not follow symlink'
else
  fail 'safe deletion does not follow symlink'
fi

# 4. Context snapshots are unique and common credentials are redacted.
stage_home
printf 'export TOKEN=secret-token\nhttps://user:pass@example.com/x?api_key=url-secret\n' > "$TEST_HOME/history"
mkdir -p "$TEST_HOME/.cache/copilot-cmd/contexts"
HOME="$TEST_HOME" HISTFILE="$TEST_HOME/history" bash "$ROOT/bin/cmd-context" > "$TMP_ROOT/context-a" &
HOME="$TEST_HOME" HISTFILE="$TEST_HOME/history" bash "$ROOT/bin/cmd-context" > "$TMP_ROOT/context-b" &
wait
context_count=0
for context_dir in "$TEST_HOME/.cache/copilot-cmd/contexts"/*; do
  [ -d "$context_dir" ] && context_count=$((context_count + 1))
done
if [ "$context_count" -eq 2 ]; then
  pass 'context concurrent snapshots are unique'
else
  fail 'context concurrent snapshots are unique'
fi
if ! grep -R -Eq 'secret-token|user:pass|url-secret' "$TEST_HOME/.cache/copilot-cmd/contexts"; then
  pass 'context redacts common credentials'
else
  fail 'context redacts common credentials'
fi

# 5. cmd-question keeps machine-readable stdout clean and diagnoses broken links.
stage_home
mkdir -p "$TEST_HOME/.cache/copilot-cmd/question-target"
printf 'question body\n' > "$TEST_HOME/.cache/copilot-cmd/question-target/question.txt"
ln -s "$TEST_HOME/.cache/copilot-cmd/question-target" "$TEST_HOME/.cache/copilot-cmd/last-question"
run_home bash "$TEST_HOME/.local/bin/cmd-question" > "$TMP_ROOT/question.out" 2> "$TMP_ROOT/question.err"
if [ "$(cat "$TMP_ROOT/question.out")" = 'question body' ] && grep -Fq '[cmd-question]' "$TMP_ROOT/question.err"; then
  pass 'cmd-question stdout/stderr contract'
else
  fail 'cmd-question stdout/stderr contract'
fi

# 6. Model list loading no longer depends on Bash 4 mapfile.
stage_home
printf '#!/usr/bin/env bash\nprintf "copilot-exited\\n"\n' > "$TEST_HOME/.local/bin/copilot"
chmod +x "$TEST_HOME/.local/bin/copilot"
printf 'Auto\n# comment\nCustom Model\n' > "$TEST_HOME/.config/copilot-cmd/copilot-models"
printf '0\n' | run_home bash "$TEST_HOME/.local/bin/cmd-model" > "$TMP_ROOT/model.out" 2>&1
if grep -Fq '1) Auto' "$TMP_ROOT/model.out" && grep -Fq '2) Custom Model' "$TMP_ROOT/model.out"; then
  pass 'cmd-model indexed array loading'
else
  fail 'cmd-model indexed array loading'
fi

# 7. The sender falls back only for a clearly missing session, not auth errors.
stage_home
printf '#!/usr/bin/env bash\ncase "$1" in --continue) echo "No session to continue" >&2; exit 2;; *) echo fallback-ok;; esac\n' > "$TEST_HOME/.local/bin/copilot"
chmod +x "$TEST_HOME/.local/bin/copilot"
printf '' > "$TMP_ROOT/prompt"
if HOME="$TEST_HOME" PATH="$TEST_HOME/.local/bin:$TMP_ROOT/fakebin:$PATH" \
    bash "$TEST_HOME/.local/bin/copilot-cmd-send" --prompt-file "$TMP_ROOT/prompt" -- > "$TMP_ROOT/send.out" 2> "$TMP_ROOT/send.err" \
    && grep -Fq fallback-ok "$TMP_ROOT/send.out"; then
  pass 'sender missing-session fallback'
else
  fail 'sender missing-session fallback'
fi
printf '#!/usr/bin/env bash\necho "Authentication failed" >&2\nexit 9\n' > "$TEST_HOME/.local/bin/copilot"
chmod +x "$TEST_HOME/.local/bin/copilot"
if HOME="$TEST_HOME" PATH="$TEST_HOME/.local/bin:$TMP_ROOT/fakebin:$PATH" \
    bash "$TEST_HOME/.local/bin/copilot-cmd-send" --prompt-file "$TMP_ROOT/prompt" -- > "$TMP_ROOT/send.out" 2> "$TMP_ROOT/send.err"; then
  fail 'sender does not retry auth failure'
else
  if grep -Fq 'Authentication failed' "$TMP_ROOT/send.err"; then
    pass 'sender does not retry auth failure'
  else
    fail 'sender does not retry auth failure' 'auth error was not preserved'
  fi
fi

# 8. Installer preserves user config and installs all managed artifacts.
INSTALL_HOME="$TMP_ROOT/install-home"
mkdir -p "$INSTALL_HOME/.config/copilot-deepseek" "$INSTALL_HOME/.config/copilot-cmd"
printf 'export COPILOT_PROVIDER_API_KEY=not-a-real-test-key\n' > "$INSTALL_HOME/.config/copilot-deepseek/env"
printf 'User Model\n' > "$INSTALL_HOME/.config/copilot-cmd/copilot-models"
HOME="$INSTALL_HOME" PATH="$TMP_ROOT/fakebin:$PATH" bash "$ROOT/install.sh" </dev/null >/dev/null 2>&1
if [ -x "$INSTALL_HOME/.local/bin/cmd-version" ] && [ -f "$INSTALL_HOME/.local/lib/copilot-cmd-trash.sh" ] \
  && grep -Fq 'not-a-real-test-key' "$INSTALL_HOME/.config/copilot-deepseek/env" \
  && grep -Fq 'User Model' "$INSTALL_HOME/.config/copilot-cmd/copilot-models"; then
  pass 'installer artifacts and user config preservation'
else
  fail 'installer artifacts and user config preservation'
fi

# 9. Cron read/remove failures never report success or modify the old table.
stage_home
export FAKE_CRONTAB_STATE="$TEST_HOME/crontab"
printf '0 1 * * * backup.sh\n# BEGIN COPILOT-CMD-TRASH-AUTO\n30 3 * * * prune\n# END COPILOT-CMD-TRASH-AUTO\n' > "$FAKE_CRONTAB_STATE"
old_crontab="$(cat "$FAKE_CRONTAB_STATE")"
if FAKE_CRONTAB_STATE="$FAKE_CRONTAB_STATE" FAKE_CRONTAB_FAIL=1 run_home bash "$TEST_HOME/.local/bin/cmd-trash-auto-off" >/dev/null 2>&1; then
  fail 'cron read failure returns nonzero'
else
  if [ "$old_crontab" = "$(cat "$FAKE_CRONTAB_STATE")" ]; then pass 'cron read failure preserves table'; else fail 'cron read failure preserves table'; fi
fi
printf '# BEGIN COPILOT-CMD-TRASH-AUTO\n30 3 * * * prune\n# END COPILOT-CMD-TRASH-AUTO\n' > "$FAKE_CRONTAB_STATE"
if FAKE_CRONTAB_STATE="$FAKE_CRONTAB_STATE" FAKE_CRONTAB_REMOVE_FAIL=1 run_home bash "$TEST_HOME/.local/bin/cmd-trash-auto-off" >/dev/null 2>&1; then
  fail 'cron remove failure returns nonzero'
else
  pass 'cron remove failure returns nonzero'
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
