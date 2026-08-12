$ErrorActionPreference = "Stop"

$bundleRoot = Join-Path $env:GITHUB_WORKSPACE "source\desktop\src-tauri\target\x86_64-pc-windows-msvc\release\bundle\nsis"
$installer = Get-ChildItem -Path $bundleRoot -File -Filter "*.exe" | Where-Object {
  $_.Name -match "setup"
} | Sort-Object Name | Select-Object -First 1
if ($null -eq $installer) {
  throw "NSIS installer not found under $bundleRoot"
}

function Invoke-Installer([string]$Path) {
  $process = Start-Process -FilePath $Path -ArgumentList @("/P", "/NS") -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    throw "Installer exited with code $($process.ExitCode): $Path"
  }
}

function Get-UninstallEntry {
  $roots = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
  )
  foreach ($root in $roots) {
    if (!(Test-Path $root)) { continue }
    foreach ($key in Get-ChildItem -Path $root) {
      $entry = Get-ItemProperty -Path $key.PSPath
      if ($entry.DisplayName -eq "AI Data Studio") {
        return $entry
      }
    }
  }
  throw "AI Data Studio uninstall registry entry was not created"
}

Write-Host "Installing baseline package: $($installer.FullName)"
Invoke-Installer $installer.FullName
$entry = Get-UninstallEntry

$appDataDir = Join-Path $env:APPDATA "com.vtable.desktop"
$databasePath = Join-Path $appDataDir "data\app.sqlite"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $databasePath) | Out-Null
$sentinel = [Text.Encoding]::UTF8.GetBytes("aidatastudio-upgrade-persistence-$([guid]::NewGuid())")
[IO.File]::WriteAllBytes($databasePath, $sentinel)
$beforeHash = (Get-FileHash -Algorithm SHA256 -Path $databasePath).Hash

# Make the installed package look older so the same artifact exercises Tauri's
# upgrade branch, including invocation of the existing uninstaller.
Set-ItemProperty -Path $entry.PSPath -Name DisplayVersion -Value "0.0.0"
Write-Host "Reinstalling as an upgrade with app.sqlite hash $beforeHash"
Invoke-Installer $installer.FullName

if (!(Test-Path $databasePath)) {
  throw "Upgrade removed app.sqlite: $databasePath"
}
$afterHash = (Get-FileHash -Algorithm SHA256 -Path $databasePath).Hash
if ($afterHash -ne $beforeHash) {
  throw "Upgrade changed app.sqlite: before=$beforeHash after=$afterHash"
}

Write-Host "NSIS upgrade preserved app.sqlite ($afterHash)"
