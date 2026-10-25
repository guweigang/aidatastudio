param(
  [Parameter(Mandatory)][string]$InstalledRoot,
  [Parameter(Mandatory)][string]$EvidenceRoot,
  [Parameter(Mandatory)][string]$WorkingDirectory
)
$ErrorActionPreference = "Stop"
$binaries = @(Get-ChildItem $InstalledRoot -File -Filter "*.exe" | Where-Object { $_.Name -notmatch 'uninstall' })
if ($binaries.Count -ne 1) { throw "Expected one installed application executable under $InstalledRoot" }
$exe = $binaries[0].FullName
$oldStore = $env:VTABLE_APP_DATA_DIR
$oldWorkspaces = $env:VTABLE_USER_WORKSPACE_ROOT
$process = $null
try {
  $env:VTABLE_APP_DATA_DIR = Join-Path $EvidenceRoot "installed-gui-app"
  $env:VTABLE_USER_WORKSPACE_ROOT = Join-Path $EvidenceRoot "installed-gui-workspaces"
  $stdout = Join-Path $EvidenceRoot "installed-app-stdout.log"
  $stderr = Join-Path $EvidenceRoot "installed-app-stderr.log"
  $process = Start-Process -FilePath $exe -WorkingDirectory $WorkingDirectory -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  $deadline = (Get-Date).AddSeconds(45)
  $ready = $false
  while ((Get-Date) -lt $deadline) {
    $process.Refresh()
    if ($process.HasExited) {
      throw "Installed application exited during startup with code $($process.ExitCode): $(Get-Content -Raw $stderr -ErrorAction SilentlyContinue)"
    }
    if ($process.MainWindowHandle -ne [IntPtr]::Zero -and $process.Responding -and (Test-Path (Join-Path $env:VTABLE_APP_DATA_DIR "data/app.sqlite"))) {
      $ready = $true
      break
    }
    Start-Sleep -Milliseconds 250
  }
  if (!$ready) { throw "Installed application did not create a responding native window: $(Get-Content -Raw $stderr -ErrorAction SilentlyContinue)" }
  Start-Sleep -Seconds 2
  $process.Refresh()
  if ($process.HasExited -or !$process.Responding) { throw "Installed application became unavailable after startup" }
  [ordered]@{
    status = "passed"
    executable = $exe
    processId = $process.Id
    windowTitle = $process.MainWindowTitle
    nativeWindowCreated = $true
    responding = $true
    isolatedDataDirectory = $env:VTABLE_APP_DATA_DIR
    appDatabaseCreated = $true
    workingDirectory = $WorkingDirectory
    path = $env:PATH
  } | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $EvidenceRoot "installed-app-startup.json")
  Write-Host "Installed application cold startup passed: $exe"
} finally {
  if ($null -ne $process -and !$process.HasExited) {
    $process.Kill($true)
    if (!$process.WaitForExit(10000)) { throw "Isolated installed application did not stop" }
  }
  [Environment]::SetEnvironmentVariable("VTABLE_APP_DATA_DIR", $oldStore, "Process")
  [Environment]::SetEnvironmentVariable("VTABLE_USER_WORKSPACE_ROOT", $oldWorkspaces, "Process")
}
