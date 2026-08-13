#!/bin/sh

set -eu
mkdir -p "${RUNNER_TEMP}/tauri-cli-bin"
cat > "${RUNNER_TEMP}/tauri-cli-bin/cargo-tauri" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "tauri" ]; then
  shift
fi
exec npm exec --yes --package "@tauri-apps/cli@${TAURI_CLI_VERSION:?}" -- tauri "$@"
EOF
chmod +x "${RUNNER_TEMP}/tauri-cli-bin/cargo-tauri"
echo "${RUNNER_TEMP}/tauri-cli-bin" >> "${GITHUB_PATH}"
actual="$(PATH="${RUNNER_TEMP}/tauri-cli-bin:${PATH}" cargo tauri --version)"
expected="tauri-cli ${TAURI_CLI_VERSION}"
if [ "$actual" != "$expected" ]; then
  echo "unexpected Tauri CLI version: $actual; expected $expected" >&2
  exit 1
fi
printf '%s\n' "$actual"
