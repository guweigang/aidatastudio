param(
  [Parameter(Mandatory = $true)]
  [string]$SidecarPath,

  [switch]$RequireMinGWRuntime
)

$ErrorActionPreference = "Stop"

function Resolve-FullPath([string]$InputPath) {
  return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $InputPath))
}

function Assert-AnyFile {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Directories,

    [Parameter(Mandatory = $true)]
    [string[]]$Patterns,

    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  foreach ($directory in $Directories) {
    if (!(Test-Path $directory)) {
      continue
    }

    foreach ($pattern in $Patterns) {
      $match = Get-ChildItem -Path $directory -Filter $pattern -File -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($null -ne $match) {
        Write-Host "ok: $Label -> $($match.FullName)"
        return
      }
    }
  }

  $patternList = $Patterns -join ", "
  $directoryList = $Directories -join ", "
  throw "missing $Label runtime DLL. expected one of [$patternList] in [$directoryList]"
}

function Invoke-SidecarJson {
  param(
    [Parameter(Mandatory = $true)]
    [string]$ExePath,

    [AllowEmptyCollection()]
    [string[]]$Arguments = @(),

    [Parameter(Mandatory = $true)]
    [string]$PathValue
  )

  $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $processInfo.FileName = $ExePath
  foreach ($argument in $Arguments) {
    [void]$processInfo.ArgumentList.Add($argument)
  }
  $processInfo.UseShellExecute = $false
  $processInfo.CreateNoWindow = $true
  $processInfo.RedirectStandardOutput = $true
  $processInfo.RedirectStandardError = $true
  $processInfo.Environment["PATH"] = $PathValue

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $processInfo
  if (!$process.Start()) {
    throw "failed to start sidecar command"
  }
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  $exitCode = $process.ExitCode

  $text = ($stdout + $stderr).Trim()
  if ($exitCode -ne 0) {
    throw "sidecar command failed with exit code $($exitCode): $text"
  }

  try {
    return $text | ConvertFrom-Json
  } catch {
    throw "sidecar command did not return JSON: $text"
  }
}

$sidecar = Resolve-FullPath $SidecarPath
if (!(Test-Path $sidecar)) {
  throw "sidecar not found: $sidecar"
}

$sidecarDir = Split-Path -Parent $sidecar
$runtimeDir = Join-Path $sidecarDir "runtime\libs"
$runtimeSearchDirs = @($sidecarDir, $runtimeDir)

Write-Host "doctor: $sidecar"
Assert-AnyFile -Directories $runtimeSearchDirs -Patterns @("libssl-*.dll") -Label "OpenSSL ssl"
Assert-AnyFile -Directories $runtimeSearchDirs -Patterns @("libcrypto-*.dll") -Label "OpenSSL crypto"
Assert-AnyFile -Directories $runtimeSearchDirs -Patterns @("libmariadb.dll", "libmysql.dll") -Label "MySQL/MariaDB client"
Assert-AnyFile -Directories $runtimeSearchDirs -Patterns @("libpq.dll") -Label "PostgreSQL client"

if ($RequireMinGWRuntime) {
  Assert-AnyFile -Directories $runtimeSearchDirs -Patterns @("libwinpthread-1.dll") -Label "MinGW pthread"
  Assert-AnyFile -Directories $runtimeSearchDirs -Patterns @("libgcc_s_*.dll") -Label "MinGW gcc runtime"
  Assert-AnyFile -Directories $runtimeSearchDirs -Patterns @("libstdc++-6.dll") -Label "MinGW C++ runtime"
}

$systemRoot = $env:SystemRoot
if (!$systemRoot) {
  $systemRoot = "C:\Windows"
}

$packageOnlyPath = @(
  $sidecarDir,
  $runtimeDir,
  (Join-Path $systemRoot "System32"),
  $systemRoot
) -join [System.IO.Path]::PathSeparator

$probe = Invoke-SidecarJson -ExePath $sidecar -Arguments @() -PathValue $packageOnlyPath
if ($probe.ok -ne $false -or $probe.error -ne "missing command") {
  throw "unexpected sidecar no-arg probe response: $($probe | ConvertTo-Json -Compress)"
}
Write-Host "ok: sidecar starts with package-local runtime path"

$tempDb = Join-Path ([System.IO.Path]::GetTempPath()) ("aidatastudio-runtime-doctor-{0}.sqlite" -f ([Guid]::NewGuid().ToString("N")))
try {
  $sqliteProbe = Invoke-SidecarJson -ExePath $sidecar -Arguments @("init-sqlite", "--db", $tempDb) -PathValue $packageOnlyPath
  if ($sqliteProbe.ok -ne $true) {
    throw "sqlite probe failed: $($sqliteProbe | ConvertTo-Json -Compress)"
  }
  if (!(Test-Path $tempDb)) {
    throw "sqlite probe did not create $tempDb"
  }
  Write-Host "ok: sqlite init works with package-local runtime path"
} finally {
  if (Test-Path $tempDb) {
    Remove-Item -Force $tempDb
  }
}

Write-Host "runtime doctor passed"
