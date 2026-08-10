$ErrorActionPreference = "Stop"
if (!$env:TAURI_SIGNING_PRIVATE_KEY) {
  throw "TAURI_SIGNING_PRIVATE_KEY secret is required to publish updater artifacts"
}
$pubkey = if ($env:TAURI_UPDATER_PUBLIC_KEY_SECRET) { $env:TAURI_UPDATER_PUBLIC_KEY_SECRET } else { $env:TAURI_UPDATER_PUBLIC_KEY_VAR }
if (!$pubkey) {
  throw "TAURI_UPDATER_PUBLIC_KEY repository variable or secret is required"
}
$config = [ordered]@{
  bundle = [ordered]@{ createUpdaterArtifacts = $true }
  plugins = [ordered]@{
    updater = [ordered]@{
      pubkey = $pubkey
      endpoints = @($env:TAURI_UPDATER_ENDPOINT)
      windows = [ordered]@{ installMode = "passive" }
    }
  }
}
$configPath = Join-Path $env:RUNNER_TEMP "tauri-updater.conf.json"
$config | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -Path $configPath
Add-Content -Path $env:GITHUB_ENV -Value "TAURI_BUILD_CONFIG=$configPath"
