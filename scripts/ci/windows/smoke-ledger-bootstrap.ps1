$ErrorActionPreference = "Stop"
$sidecar = (Resolve-Path "backend/bin/vtable-sidecar.exe").Path
$probeRoot = Join-Path $env:RUNNER_TEMP ("ads-ledger-bootstrap-" + [Guid]::NewGuid().ToString("N"))
$names = @("VTABLE_APP_DATA_DIR", "VTABLE_USER_WORKSPACE_ROOT", "VTABLE_APP_STATE_RUNTIME_REQUIRED")
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
try {
  $env:VTABLE_APP_DATA_DIR = Join-Path $probeRoot "app"
  $env:VTABLE_USER_WORKSPACE_ROOT = Join-Path $probeRoot "workspaces"
  Remove-Item Env:VTABLE_APP_STATE_RUNTIME_REQUIRED -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force $env:VTABLE_APP_DATA_DIR | Out-Null
  # Exercise the same maintenance commands as application setup, including FTS5.
  # Repeat on the same store to cover an already initialized installation.
  foreach ($pass in 1..2) {
    foreach ($arguments in @(
      ,@("migrate-agent-run-ledgers", "--startup")
      ,@("migrate-proposal-submission-coverage")
    )) {
      $output = & $sidecar @arguments
      if ($LASTEXITCODE -ne 0) { throw "ledger bootstrap command failed: $($arguments -join ' ')" }
      $result = ($output -join "`n") | ConvertFrom-Json
      if ($result.ok -ne $true) { throw "ledger bootstrap failed: $($output -join ' ')" }
      Write-Host "ledger bootstrap pass $pass succeeded: $($arguments -join ' ')"
    }
  }
} finally {
  foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
  if (Test-Path $probeRoot) { Remove-Item -Recurse -Force $probeRoot }
}
