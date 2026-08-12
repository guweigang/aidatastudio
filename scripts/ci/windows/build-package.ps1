$ErrorActionPreference = "Stop"

npm --prefix desktop run build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$bundleRoot = "desktop\src-tauri\target\x86_64-pc-windows-msvc\release\bundle"
if (Test-Path $bundleRoot) {
  Remove-Item -Recurse -Force $bundleRoot
}
if (!$env:VTABLE_NSIS_TEMPLATE) {
  throw "VTABLE_NSIS_TEMPLATE is not set; refusing to build with Tauri's data-destructive default upgrade flow"
}
$inlineConfig = @{
  bundle = @{
    icon = @("icons/32x32.png", "icons/128x128.png", "icons/128x128@2x.png", "icons/icon.icns", "icons/icon.ico")
    targets = @("nsis")
    windows = @{
      nsis = @{
        template = $env:VTABLE_NSIS_TEMPLATE
      }
    }
  }
} | ConvertTo-Json -Compress -Depth 6
$buildArgs = @("tauri", "build", "--target", "x86_64-pc-windows-msvc", "--bundles", "nsis", "--config", $inlineConfig)
if (!$env:TAURI_BUILD_CONFIG) {
  $buildArgs += "--no-sign"
}
if ($env:TAURI_BUILD_CONFIG) {
  $buildArgs += @("--config", $env:TAURI_BUILD_CONFIG)
}
cargo @buildArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
