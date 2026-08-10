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
Invoke-SidecarText -ExePath $sidecar -Arguments @("init-sqlite", "--db", $dbPath) | Out-Null
$requests = @(
  '{"op":"inspect_state"}',
  '{"op":"run_cell","cellId":"smoke","resultVarName":"result","language":"javascript","code":"1 + 1","last_results":{"source_kind":"workspace-query","source_sql":"","columns":[],"preview_rows":[],"total_rows":0,"page_size":0,"page_offset":0},"schema":{"active_table":"","tables":{},"selected_row":{}}}',
  '{"op":"shutdown"}'
) -join [Environment]::NewLine
$text = Invoke-SidecarText -ExePath $sidecar -Arguments @("notebook-kernel-daemon", "--engine", "SQLITE", "--db", $dbPath) -InputText $requests
$lines = @($text -split "`r?`n" | Where-Object {
  $line = $_.Trim()
  $line -and !$line.StartsWith("[notebook]")
})
if ($lines.Count -eq 1) {
  $single = $lines[0] | ConvertFrom-Json
  if ($single.ok -eq $false -and ($single.error -like "*unknown command*notebook-kernel-daemon*")) {
    Write-Warning "notebook-kernel-daemon is not available in this source ref; skipping daemon smoke"
    return
  }
}
if ($lines.Count -lt 3) {
  throw "notebook daemon smoke returned too few responses: $text"
}
$inspect = $lines[0] | ConvertFrom-Json
$result = $lines[1] | ConvertFrom-Json
$shutdown = $lines[2] | ConvertFrom-Json
if ($inspect.ok -ne $true) {
  throw "notebook inspect failed: $($lines[0])"
}
if ($result.ok -ne $true -or $result.kind -eq "error" -or $result.text -ne "2") {
  throw "notebook run failed: $($lines[1])"
}
if ($shutdown.ok -ne $true) {
  throw "notebook shutdown failed: $($lines[2])"
}
