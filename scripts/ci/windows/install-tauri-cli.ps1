$ErrorActionPreference = "Stop"
$root = Join-Path $env:RUNNER_TEMP "tauri-cli-bin"
New-Item -ItemType Directory -Force -Path $root | Out-Null
npm install --prefix $root --no-audit --no-fund --no-package-lock "@tauri-apps/cli@$env:TAURI_CLI_VERSION"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$env:VTABLE_TAURI_NODE = (Get-Command node -ErrorAction Stop).Source
$env:VTABLE_TAURI_JS = Join-Path $root "node_modules/@tauri-apps/cli/tauri.js"
if (!(Test-Path $env:VTABLE_TAURI_JS)) { throw "Official Tauri CLI entrypoint missing" }
# A small native cargo-subcommand adapter preserves argv (notably JSON config)
# without cmd.exe parsing and delegates to the official prebuilt CLI.
$shim = Join-Path $root "cargo-tauri.exe"
rustc --edition 2021 "$env:GITHUB_WORKSPACE/scripts/ci/windows/tauri-cli-shim.rs" -o $shim
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$env:PATH = "$root;$env:PATH"
Add-Content $env:GITHUB_PATH $root
$actual = (cargo tauri --version).Trim()
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($actual -ne "tauri-cli $env:TAURI_CLI_VERSION") { throw "Unexpected Tauri CLI: $actual" }
Write-Host $actual
