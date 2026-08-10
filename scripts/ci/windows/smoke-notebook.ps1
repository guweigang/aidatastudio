$ErrorActionPreference = "Stop"
function Invoke-SidecarText {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath,

    [AllowEmptyCollection()]
    [string[]]$Arguments = @(),

    [string]$InputText = $null
  )

  Write-Host "sidecar> $ExePath $($Arguments -join ' ')"
  $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $processInfo.FileName = $ExePath
  foreach ($argument in $Arguments) {
    [void]$processInfo.ArgumentList.Add($argument)
  }
  $processInfo.UseShellExecute = $false
  $processInfo.CreateNoWindow = $true
  $processInfo.RedirectStandardOutput = $true
  $processInfo.RedirectStandardError = $true
  if ($null -ne $InputText) {
    $processInfo.RedirectStandardInput = $true
  }
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $processInfo
  if (!$process.Start()) {
    throw "failed to start sidecar command"
  }
  if ($null -ne $InputText) {
    $process.StandardInput.Write($InputText)
    $process.StandardInput.Close()
  }
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  $exitCode = $process.ExitCode
  $text = ($stdout + $stderr).Trim()
  if ($text) {
    Write-Host $text
  }
  if ($exitCode -ne 0) {
    throw "sidecar command failed with exit code $($exitCode): $text"
  }
  return $text
}

$sidecarDir = (Resolve-Path "backend\bin").Path
$sidecar = Join-Path $sidecarDir "vtable-sidecar.exe"
$runtimeRoot = (Resolve-Path "backend\runtime").Path
$runtimeDir = Join-Path $runtimeRoot "libs"
$pluginDir = Join-Path $runtimeRoot "plugins"
$assetDir = Join-Path $runtimeRoot "assets"
$driverAssetDir = Join-Path $runtimeRoot "driver-assets"
$runtimeBinDir = Join-Path $runtimeRoot "bin"
$systemRoot = if ($env:SystemRoot) { $env:SystemRoot } else { "C:\Windows" }
$env:PATH = @(
  $sidecarDir,
  $runtimeDir,
  $pluginDir,
  $runtimeBinDir,
  (Join-Path $systemRoot "System32"),
  $systemRoot
) -join [System.IO.Path]::PathSeparator
$env:VJSX_ASSET_ROOT = $assetDir
$env:VTABLE_BUILTIN_DRIVER_ASSET_DIR = $driverAssetDir
$env:MARIADB_PLUGIN_DIR = $pluginDir
$env:VTABLE_NOTEBOOK_DEBUG = "1"
Write-Host "VJSX_ASSET_ROOT=$env:VJSX_ASSET_ROOT"
$vjsxBin = Join-Path $runtimeBinDir "vjsx.exe"
if (!(Test-Path $vjsxBin)) {
  throw "vjsx runtime binary not found at $vjsxBin"
}
Invoke-SidecarText -ExePath $vjsxBin -Arguments @("check-runtime", "--runtime", "node") | Out-Null
$dbPath = Join-Path $env:RUNNER_TEMP "aidatastudio-notebook-smoke.sqlite"
if (Test-Path $dbPath) {
  Remove-Item -Force $dbPath
}
Invoke-SidecarText -ExePath $sidecar -Arguments @("initialize-database-file", "--engine", "SQLITE", "--db-path", $dbPath) | Out-Null
$brokerReadyFile = Join-Path $env:RUNNER_TEMP ("aidatastudio-runtime-broker-{0}.txt" -f ([Guid]::NewGuid().ToString("N")))
$brokerToken = [Guid]::NewGuid().ToString("N")
$brokerScript = Join-Path $PSScriptRoot "runtime-broker.ps1"
$brokerInfo = [System.Diagnostics.ProcessStartInfo]::new()
$brokerInfo.FileName = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
foreach ($argument in @(
  "-NoProfile",
  "-File", $brokerScript,
  "-Sidecar", $sidecar,
  "-ReadyFile", $brokerReadyFile,
  "-Token", $brokerToken
)) {
  [void]$brokerInfo.ArgumentList.Add($argument)
}
$brokerInfo.UseShellExecute = $false
$brokerInfo.CreateNoWindow = $true
$brokerInfo.RedirectStandardOutput = $true
$brokerInfo.RedirectStandardError = $true
$broker = [System.Diagnostics.Process]::new()
$broker.StartInfo = $brokerInfo
if (!$broker.Start()) {
  throw "failed to start database runtime broker"
}

try {
  $brokerEndpoint = ""
  for ($attempt = 0; $attempt -lt 100; $attempt++) {
    if (Test-Path $brokerReadyFile) {
      $brokerEndpoint = (Get-Content -Raw $brokerReadyFile).Trim()
      if ($brokerEndpoint) {
        break
      }
    }
    if ($broker.HasExited) {
      $brokerOutput = $broker.StandardOutput.ReadToEnd()
      $brokerError = $broker.StandardError.ReadToEnd()
      throw "database runtime broker exited early with code $($broker.ExitCode): $brokerOutput $brokerError"
    }
    Start-Sleep -Milliseconds 100
  }
  if (!$brokerEndpoint) {
    throw "timed out waiting for database runtime broker"
  }
  $env:VTABLE_DATABASE_RUNTIME_ENDPOINT = $brokerEndpoint
  $env:VTABLE_DATABASE_RUNTIME_TOKEN = $brokerToken
  $env:VTABLE_DATABASE_RUNTIME_OWNER = "ci:notebook-smoke"

  $requests = @(
    '{"op":"inspect_state"}',
    '{"op":"run_cell","cellId":"sql-smoke","resultVarName":"sql_result","language":"sql","code":"select 42 as runtime_probe","last_results":{"source_kind":"workspace-query","source_sql":"","columns":[],"preview_rows":[],"total_rows":0,"page_size":0,"page_offset":0},"schema":{"active_table":"","tables":{},"selected_row":{}}}',
    '{"op":"run_cell","cellId":"js-smoke","resultVarName":"result","language":"javascript","code":"1 + 1","last_results":{"source_kind":"workspace-query","source_sql":"","columns":[],"preview_rows":[],"total_rows":0,"page_size":0,"page_offset":0},"schema":{"active_table":"","tables":{},"selected_row":{}}}',
    '{"op":"shutdown"}'
  ) -join [Environment]::NewLine
  $text = Invoke-SidecarText -ExePath $sidecar -Arguments @("notebook-kernel-daemon", "--engine", "SQLITE", "--db", $dbPath) -InputText $requests
  $lines = @($text -split "`r?`n" | Where-Object {
    $line = $_.Trim()
    $line -and !$line.StartsWith("[notebook]")
  })
  if ($lines.Count -lt 4) {
    throw "notebook daemon smoke returned too few responses: $text"
  }
  $inspect = $lines[0] | ConvertFrom-Json
  $sqlResult = $lines[1] | ConvertFrom-Json
  $jsResult = $lines[2] | ConvertFrom-Json
  $shutdown = $lines[3] | ConvertFrom-Json
  if ($inspect.ok -ne $true) {
    throw "notebook inspect failed: $($lines[0])"
  }
  if ($sqlResult.ok -ne $true -or $sqlResult.kind -ne "table" -or $sqlResult.row_count -ne 1) {
    throw "notebook SQL/runtime broker smoke failed: $($lines[1])"
  }
  if ($jsResult.ok -ne $true -or $jsResult.kind -eq "error" -or $jsResult.text -ne "2") {
    throw "notebook JavaScript smoke failed: $($lines[2])"
  }
  if ($shutdown.ok -ne $true) {
    throw "notebook shutdown failed: $($lines[3])"
  }
} finally {
  Remove-Item Env:VTABLE_DATABASE_RUNTIME_ENDPOINT -ErrorAction SilentlyContinue
  Remove-Item Env:VTABLE_DATABASE_RUNTIME_TOKEN -ErrorAction SilentlyContinue
  Remove-Item Env:VTABLE_DATABASE_RUNTIME_OWNER -ErrorAction SilentlyContinue
  if (!$broker.HasExited) {
    $broker.Kill($true)
    $broker.WaitForExit()
  }
  $brokerOutput = $broker.StandardOutput.ReadToEnd()
  $brokerError = $broker.StandardError.ReadToEnd()
  if ($brokerOutput) {
    Write-Host $brokerOutput.Trim()
  }
  if ($brokerError) {
    Write-Host $brokerError.Trim()
  }
  $broker.Dispose()
  if (Test-Path $brokerReadyFile) {
    Remove-Item -Force $brokerReadyFile
  }
  if (Test-Path $dbPath) {
    Remove-Item -Force $dbPath
  }
}
