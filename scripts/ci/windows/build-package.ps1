$ErrorActionPreference = "Stop"

npm --prefix desktop run build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$bundleRoot = "desktop\src-tauri\target\x86_64-pc-windows-msvc\release\bundle"
if (Test-Path $bundleRoot) {
  Remove-Item -Recurse -Force $bundleRoot
}
$inlineConfig = '{"bundle":{"icon":["icons/32x32.png","icons/128x128.png","icons/128x128@2x.png","icons/icon.icns","icons/icon.ico"]}}'
$buildArgs = @("tauri", "build", "--target", "x86_64-pc-windows-msvc", "--config", $inlineConfig)
if (!$env:TAURI_BUILD_CONFIG) {
  $buildArgs += "--no-sign"
}
if ($env:TAURI_BUILD_CONFIG) {
  $buildArgs += @("--config", $env:TAURI_BUILD_CONFIG)
}
cargo @buildArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
