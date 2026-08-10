#!/bin/sh

set -eu
mkdir -p "${RUNNER_TEMP}/tauri-cli-bin"
cat > "${RUNNER_TEMP}/tauri-cli-bin/cargo-tauri" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "tauri" ]; then
  shift
fi
exec npm exec --yes --package @tauri-apps/cli@^2 -- tauri "$@"
EOF
chmod +x "${RUNNER_TEMP}/tauri-cli-bin/cargo-tauri"
echo "${RUNNER_TEMP}/tauri-cli-bin" >> "${GITHUB_PATH}"
PATH="${RUNNER_TEMP}/tauri-cli-bin:${PATH}" cargo tauri --version
