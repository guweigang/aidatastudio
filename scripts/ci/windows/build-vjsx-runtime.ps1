$ErrorActionPreference = "Stop"
$runtimeBinDir = "backend\runtime\bin"
New-Item -ItemType Directory -Force -Path $runtimeBinDir | Out-Null
$runtimeBinDir = (Resolve-Path $runtimeBinDir).Path
$vjsxOut = Join-Path $runtimeBinDir "vjsx.exe"
$vjsxBuildScript = Join-Path $env:GITHUB_WORKSPACE "$env:VJSX_DIR\scripts\build-vjsx.ps1"
if (!(Test-Path $vjsxBuildScript)) {
  throw "vjsx build script not found at $vjsxBuildScript"
}
$sdkLibDir = Join-Path $env:VCPKG_INSTALLED_DIR "lib"
$sdkIncludeDir = Join-Path $env:VCPKG_INSTALLED_DIR "include"
$env:LIB = "$sdkLibDir;$env:LIB"
$env:INCLUDE = "$sdkIncludeDir;$env:INCLUDE"
& $vjsxBuildScript -Out $vjsxOut -QuickjsPath $env:VJS_QUICKJS_PATH -QuickjsLibPath $env:VJS_QUICKJS_LIB_PATH
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (!(Test-Path $vjsxOut)) {
  throw "vjsx runtime binary was not produced at $vjsxOut"
}
Write-Host "prepared $((Resolve-Path $vjsxOut).Path)"
