$ErrorActionPreference = "Stop"
$archive = Join-Path $env:RUNNER_TEMP "libduckdb-windows-amd64.zip"
$extractDir = Join-Path $env:RUNNER_TEMP "libduckdb-windows-amd64"
Invoke-WebRequest `
  -Uri "https://github.com/duckdb/duckdb/releases/download/$env:DUCKDB_VERSION/libduckdb-windows-amd64.zip" `
  -OutFile $archive
if (Test-Path $extractDir) {
  Remove-Item -Recurse -Force $extractDir
}
Expand-Archive -Path $archive -DestinationPath $extractDir
$duckdbDll = Get-ChildItem -Path $extractDir -Filter "duckdb.dll" -File -Recurse | Select-Object -First 1
if ($null -eq $duckdbDll) {
  throw "duckdb.dll was not found in the DuckDB $env:DUCKDB_VERSION archive"
}
$backendBin = Join-Path $env:GITHUB_WORKSPACE "$env:SOURCE_DIR\backend\bin"
$runtimeLibs = Join-Path $env:GITHUB_WORKSPACE "$env:SOURCE_DIR\backend\runtime\libs"
New-Item -ItemType Directory -Force -Path $backendBin, $runtimeLibs | Out-Null
Copy-Item -Force $duckdbDll.FullName (Join-Path $backendBin "libduckdb.dll")
Copy-Item -Force $duckdbDll.FullName (Join-Path $runtimeLibs "libduckdb.dll")
Add-Content -Path $env:GITHUB_ENV -Value "LIBDUCKDB_DIR=$runtimeLibs"
Write-Host "staged $($duckdbDll.FullName)"
