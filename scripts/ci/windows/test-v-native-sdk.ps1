param([string]$PinnedVRoot)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "bind-v-native-sdk.ps1")
$root = Join-Path ([IO.Path]::GetTempPath()) ("ads native SDK fixture " + [guid]::NewGuid())
$modules = @("net/openssl/openssl.c.v", "crypto/ecdsa/ecdsa_d_use_openssl.c.v", "x/crypto/slhdsa/slhdsa.c.v")
$pattern = '^#flag windows -[IL]"?C:/Program Files/OpenSSL(-Win64)?/'
function Assert-True($Condition, [string]$Message) { if (!$Condition) { throw $Message } }
function New-Fixture([string]$Name, [string]$Style) {
  $fixture = Join-Path $root $Name
  $v = Join-Path $fixture "V checkout with spaces"
  $sdk = Join-Path $fixture "SDK with spaces"
  New-Item -ItemType Directory -Force (Join-Path $sdk "include/openssl") | Out-Null
  Set-Content (Join-Path $sdk "include/openssl/ssl.h") "synthetic SDK header"
  foreach ($module in $modules) {
    $path = Join-Path (Join-Path $v "vlib") $module
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    if ($Style -eq "pinned") {
      Copy-Item (Join-Path (Join-Path $PinnedVRoot "vlib") $module) $path
    } else {
      $quote = if ($Style -eq "quoted" -or ($Style -eq "mixed" -and $module.StartsWith("x/"))) { '"' } else { '' }
      @("// Unicode fixture: 青松", "module fixture", "#flag linux -I/opt/ssl/include", "#flag windows -l libcrypto", "#include <openssl/ssl.h>", "#flag windows -I${quote}C:/Program Files/OpenSSL-Win64/include${quote}", "#flag windows -L${quote}C:/Program Files/OpenSSL-Win64/lib/VC/x64/MD${quote}", "#flag windows -I${quote}C:/Program Files/OpenSSL/include${quote}", "#flag windows -L${quote}C:/Program Files/OpenSSL/lib/VC/x64/MD${quote}") | Set-Content -Encoding utf8 $path
    }
  }
  # No obsolete mldsa.c.v exists: the pinned module is implemented in pure V.
  $pure = Join-Path $v "vlib/x/crypto/mldsa/mldsa.v"
  New-Item -ItemType Directory -Force (Split-Path $pure) | Out-Null
  Set-Content $pure "module mldsa"
  return @{ V = $v; Sdk = $sdk; Pure = $pure }
}
function Snapshot($Fixture) {
  $result = @{}
  foreach ($module in $modules) {
    $path = Join-Path (Join-Path $Fixture.V "vlib") $module
    if (Test-Path $path) { $result[$module] = (Get-FileHash $path).Hash }
  }
  return $result
}
function Assert-RejectedWithoutMutation($Fixture) {
  $before = Snapshot $Fixture
  $rejected = $false
  try { Set-VNativeOpenSslPaths -VRoot $Fixture.V -SdkRoot $Fixture.Sdk } catch { $rejected = $true }
  Assert-True $rejected "invalid pinned SDK layout must be rejected"
  $after = Snapshot $Fixture
  Assert-True ($before.Count -eq $after.Count) "rejected layout changed the module set"
  foreach ($module in $before.Keys) {
    Assert-True ($before[$module] -eq $after[$module]) "rejected layout modified an earlier module"
  }
}
try {
  $styles = @("unquoted", "quoted", "mixed")
  if ($PinnedVRoot) { $styles += "pinned" }
  foreach ($style in $styles) {
    $fixture = New-Fixture $style $style
    $expected = @{}
    foreach ($module in $modules) {
      $path = Join-Path (Join-Path $fixture.V "vlib") $module
      $expected[$module] = @((Get-Content $path) | Where-Object { $_ -notmatch $pattern })
    }
    $pureHash = (Get-FileHash $fixture.Pure).Hash
    Set-VNativeOpenSslPaths -VRoot $fixture.V -SdkRoot $fixture.Sdk
    foreach ($module in $modules) {
      $actual = @(Get-Content (Join-Path (Join-Path $fixture.V "vlib") $module))
      Assert-True (($actual | ConvertTo-Json -Compress) -eq ($expected[$module] | ConvertTo-Json -Compress)) "binding removed unrelated source lines: $module"
      Assert-True (@($actual | Where-Object { $_ -match 'Program Files/OpenSSL' }).Count -eq 0) "legacy Windows path remains"
    }
    Assert-True ((Get-FileHash $fixture.Pure).Hash -eq $pureHash) "pure V module changed"
  }
  $missing = New-Fixture "missing" "mixed"
  Remove-Item (Join-Path (Join-Path $missing.V "vlib") $modules[-1])
  Assert-RejectedWithoutMutation $missing
  $unexpected = New-Fixture "unexpected" "mixed"
  Add-Content (Join-Path (Join-Path $unexpected.V "vlib") $modules[-1]) '#flag windows -IC:/Program Files/OpenSSL/extra'
  Assert-RejectedWithoutMutation $unexpected
  $badSdk = New-Fixture "incomplete SDK" "mixed"
  Remove-Item (Join-Path $badSdk.Sdk "include/openssl/ssl.h")
  Assert-RejectedWithoutMutation $badSdk
  [ordered]@{ status = "passed"; styles = $styles; invalidLayoutsRejectedWithoutMutation = 3; pureVModulePreserved = $true } | ConvertTo-Json -Compress
} finally { if (Test-Path $root) { Remove-Item -Recurse -Force $root } }
