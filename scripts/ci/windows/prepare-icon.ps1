$ErrorActionPreference = "Stop"

$iconDir = "desktop\src-tauri\icons"
$icoPath = Join-Path $iconDir "icon.ico"
if (!(Test-Path $icoPath)) {
  $sourceIcon = Join-Path $iconDir "128x128@2x.png"
  if (!(Test-Path $sourceIcon)) {
    $sourceIcon = Join-Path $iconDir "128x128.png"
  }
  if (!(Test-Path $sourceIcon)) {
    throw "Tauri Windows icon source not found under $iconDir"
  }
  magick $sourceIcon -define icon:auto-resize=256,128,64,48,32,16 $icoPath
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
if (!(Test-Path $icoPath)) {
  throw "Tauri Windows icon was not prepared at $icoPath"
}
Write-Host "prepared $icoPath"
