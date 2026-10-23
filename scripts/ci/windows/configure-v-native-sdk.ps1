$ErrorActionPreference = "Stop"
$vRoot = Join-Path $env:RUNNER_TEMP "vlang"
$sdk = $env:VCPKG_INSTALLED_DIR
if (!(Test-Path "$sdk/include/openssl/ssl.h")) { throw "Selected OpenSSL SDK is incomplete" }
# V's legacy Program Files guesses are tokenized before MSVC argument quoting.
# Bind include/library discovery to the SDK actually installed by this build.
$modules = @("net/openssl/openssl.c.v", "crypto/ecdsa/ecdsa_d_use_openssl.c.v", "x/crypto/mldsa/mldsa.c.v", "x/crypto/slhdsa/slhdsa.c.v")
foreach ($module in $modules) {
  $path = Join-Path "$vRoot/vlib" $module
  $lines = Get-Content $path
  $legacy = @($lines | Where-Object { $_ -match '^#flag windows -[IL]C:/Program Files/OpenSSL(-Win64)?/' })
  if ($legacy.Count -ne 4) { throw "Unexpected OpenSSL flags in pinned V module: $module" }
  $lines | Where-Object { $_ -notmatch '^#flag windows -[IL]C:/Program Files/OpenSSL(-Win64)?/' } | Set-Content -Encoding utf8 $path
}
$env:INCLUDE = "$sdk/include;$env:INCLUDE"
$env:LIB = "$sdk/lib;$env:LIB"
Add-Content $env:GITHUB_ENV "INCLUDE=$env:INCLUDE"
Add-Content $env:GITHUB_ENV "LIB=$env:LIB"
$smoke = Join-Path $env:RUNNER_TEMP "v-openssl-smoke.exe"
& "$vRoot/v.exe" -new-compiler -cc msvc -d use_openssl -o $smoke "$env:GITHUB_WORKSPACE/scripts/ci/windows/smoke-toolchain.v"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $smoke
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
