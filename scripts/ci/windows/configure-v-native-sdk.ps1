$ErrorActionPreference = "Stop"
$vRoot = Join-Path $env:RUNNER_TEMP "vlang"
$sdk = $env:VCPKG_INSTALLED_DIR
. (Join-Path $PSScriptRoot "bind-v-native-sdk.ps1")
Set-VNativeOpenSslPaths -VRoot $vRoot -SdkRoot $sdk
$env:INCLUDE = "$sdk/include;$env:INCLUDE"
$env:LIB = "$sdk/lib;$env:LIB"
Add-Content $env:GITHUB_ENV "INCLUDE=$env:INCLUDE"
Add-Content $env:GITHUB_ENV "LIB=$env:LIB"
$smoke = Join-Path $env:RUNNER_TEMP "v-openssl-smoke.exe"
& "$vRoot/v.exe" -new-compiler -cc msvc -d use_openssl -o $smoke "$env:GITHUB_WORKSPACE/scripts/ci/windows/smoke-toolchain.v"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $smoke
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
