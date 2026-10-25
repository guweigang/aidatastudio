function Set-VNativeOpenSslPaths {
  param([Parameter(Mandatory)][string]$VRoot, [Parameter(Mandatory)][string]$SdkRoot)
  if (!(Test-Path (Join-Path $SdkRoot "include/openssl/ssl.h") -PathType Leaf)) {
    throw "Selected OpenSSL SDK is incomplete"
  }
  # These are the OpenSSL-backed modules in the shared, pinned upstream V.
  # ML-DSA is pure V; SLH-DSA quotes its Program Files paths.
  $modules = @("net/openssl/openssl.c.v", "crypto/ecdsa/ecdsa_d_use_openssl.c.v", "x/crypto/slhdsa/slhdsa.c.v")
  $pattern = '^#flag windows -[IL]"?C:/Program Files/OpenSSL(-Win64)?/'
  $updates = @()
  foreach ($module in $modules) {
    $path = Join-Path (Join-Path $VRoot "vlib") $module
    if (!(Test-Path $path -PathType Leaf)) { throw "Pinned V OpenSSL module missing: $module" }
    $lines = @(Get-Content $path)
    $legacy = @($lines | Where-Object { $_ -match $pattern })
    if ($legacy.Count -ne 4) { throw "Unexpected OpenSSL flags in pinned V module: $module" }
    $updates += @{ Path = $path; Lines = @($lines | Where-Object { $_ -notmatch $pattern }) }
  }
  # Validate the entire pinned layout before changing any module.
  foreach ($update in $updates) {
    $update.Lines | Set-Content -Encoding utf8 $update.Path
  }
}
