$ErrorActionPreference = "Stop"

$targetTriple = "x86_64-pc-windows-msvc"
$parserRoot = Join-Path (Get-Location) "backend\native\sql_parser"
$manifestPath = Join-Path $parserRoot "Cargo.toml"
$builtLibrary = Join-Path $parserRoot "target\$targetTriple\release\vtable_sql_parser.lib"
$linkDirectory = Join-Path $parserRoot "lib"
$linkLibrary = Join-Path $linkDirectory "vtable_sql_parser.lib"

if (!(Test-Path $manifestPath)) {
  throw "Rust SQL parser manifest not found at $manifestPath"
}

& cargo build --locked --manifest-path $manifestPath --release --target $targetTriple
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (!(Test-Path $builtLibrary)) {
  throw "Rust SQL parser static library was not produced at $builtLibrary"
}

New-Item -ItemType Directory -Force -Path $linkDirectory | Out-Null
Copy-Item -Force $builtLibrary $linkLibrary
Write-Host "prepared Rust SQL parser library at $linkLibrary"
