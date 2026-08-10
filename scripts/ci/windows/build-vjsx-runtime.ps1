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

$assetDir = (Resolve-Path "backend\cmd\vtable_sidecar\sql_parser_assets").Path
$umdDir = Join-Path $assetDir "umd"
$parsers = @(
  @{ Source = "mysql.umd.js"; Output = "mysql-parser.qbc" },
  @{ Source = "postgresql.umd.js"; Output = "postgresql-parser.qbc" },
  @{ Source = "sqlite.umd.js"; Output = "sqlite-parser.qbc" }
)
foreach ($parser in $parsers) {
  $source = Join-Path $umdDir $parser.Source
  $output = Join-Path $assetDir $parser.Output
  if (!(Test-Path $source)) { throw "SQL parser UMD not found at $source" }
  & $vjsxOut compile --entry-only --runtime node $source -o $output
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  if (!(Test-Path $output)) { throw "SQL parser bytecode was not produced at $output" }
  Write-Host "compiled $output"
}
Write-Host "prepared $((Resolve-Path $vjsxOut).Path)"
