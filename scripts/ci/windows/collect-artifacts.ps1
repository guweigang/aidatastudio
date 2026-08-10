$ErrorActionPreference = "Stop"

$dist = Join-Path $env:GITHUB_WORKSPACE "dist\windows"
if (Test-Path $dist) {
  Remove-Item -Recurse -Force $dist
}
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$tauriConfig = Get-Content -Raw -Path "source\desktop\src-tauri\tauri.conf.json" | ConvertFrom-Json
$version = $tauriConfig.version
$bundleRoot = Join-Path $env:GITHUB_WORKSPACE "source\desktop\src-tauri\target\x86_64-pc-windows-msvc\release\bundle"
if (!(Test-Path $bundleRoot)) {
  throw "Windows bundle output not found: $bundleRoot"
}
function Get-ReleaseAssetName([string]$Name) {
  return $Name -replace '\s+', '.'
}
Get-ChildItem -Path $bundleRoot -File -Recurse | Where-Object {
  $_.Extension -in @(".msi", ".exe", ".zip", ".sig") -and $_.Name.Contains("_${version}_")
} | ForEach-Object {
  Copy-Item -Force $_.FullName (Join-Path $dist (Get-ReleaseAssetName $_.Name))
}
$artifact = Get-ChildItem -Path $dist -File | Where-Object {
  $_.Extension -in @(".msi", ".exe", ".zip")
} | Sort-Object Name | Select-Object -First 1
if ($null -eq $artifact) {
  throw "Windows package artifact not found under $dist"
}
$updaterArtifact = Get-ChildItem -Path $dist -File | Where-Object {
  $_.Extension -in @(".zip", ".exe", ".msi") -and (Test-Path "$($_.FullName).sig")
} | Sort-Object @{ Expression = {
  if ($_.Extension -eq ".zip") { 0 } elseif ($_.Extension -eq ".exe") { 1 } else { 2 }
}}, Name | Select-Object -First 1
if ($env:TAURI_BUILD_CONFIG -and $null -eq $updaterArtifact) {
  Write-Host "Windows dist contents:"
  Get-ChildItem -Path $dist -File | Sort-Object Name | ForEach-Object { Write-Host $_.FullName }
  throw "Windows updater artifact/signature not found under $dist"
}
$metadata = [ordered]@{
  source_ref = $env:SOURCE_REF
  platform = "windows"
  arch = "x64"
  target = "x86_64-pc-windows-msvc"
  version = $version
  artifact = $artifact.Name
  created_at = (Get-Date).ToUniversalTime().ToString("o")
}
if ($null -ne $updaterArtifact) {
  $metadata.updaterArtifact = $updaterArtifact.Name
  $metadata.updaterSignature = "$($updaterArtifact.Name).sig"
}
$metadata | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $dist "release.json")
"version=$version" >> $env:GITHUB_OUTPUT
"tag=v$version" >> $env:GITHUB_OUTPUT
Get-ChildItem -Path $dist -File | Sort-Object Name | ForEach-Object { Write-Host $_.FullName }
