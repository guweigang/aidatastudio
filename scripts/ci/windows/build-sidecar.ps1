$ErrorActionPreference = "Stop"
$moduleRoot = Join-Path $env:RUNNER_TEMP "vtable-vmodules-windows"
$buildOutputDir = Join-Path $env:RUNNER_TEMP "vtable-sidecar-build-windows"
$outputDir = "backend\bin"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$outputDir = Resolve-Path $outputDir
$sidecar = Join-Path $outputDir "vtable-sidecar.exe"
if (Test-Path $buildOutputDir) {
  Remove-Item -Recurse -Force $buildOutputDir
}
New-Item -ItemType Directory -Force -Path $buildOutputDir | Out-Null
$builtSidecar = Join-Path $buildOutputDir "vtable-sidecar.exe"
Get-ChildItem -Path $outputDir -Filter "vtable-sidecar*" -File -ErrorAction SilentlyContinue | Remove-Item -Force
if (Test-Path $moduleRoot) {
  Remove-Item -Recurse -Force $moduleRoot
}
New-Item -ItemType Directory -Force -Path $moduleRoot | Out-Null
Copy-Item -Recurse -Force $env:VTABLE_VJSX_PATH (Join-Path $moduleRoot "vjsx")
Copy-Item -Recurse -Force (Join-Path $env:VTABLE_VJSX_PATH "runtimejs") (Join-Path $moduleRoot "runtimejs")
$vduckdbModuleRoot = Join-Path $moduleRoot "rodabt"
New-Item -ItemType Directory -Force -Path $vduckdbModuleRoot | Out-Null
Copy-Item -Recurse -Force (Join-Path $env:GITHUB_WORKSPACE $env:VDUCKDB_DIR) (Join-Path $vduckdbModuleRoot "vduckdb")
Copy-Item -Recurse -Force (Join-Path $env:GITHUB_WORKSPACE $env:VCLICKHOUSE_DIR) (Join-Path $moduleRoot "vclickhouse")
$env:VMODULES = $moduleRoot
$flags = $env:VTABLE_SIDECAR_V_FLAGS -split '\s+' | Where-Object { $_ }
$mysqlImportLib = Get-ChildItem -Path (Join-Path $env:MYSQL_ROOT "lib") -Include libmariadb.lib, mysqlclient.lib, libmysql.lib, mysql.lib -File -Recurse | Select-Object -First 1
$pgImportLib = Get-ChildItem -Path (Join-Path $env:POSTGRES_ROOT "lib") -Include libpq.lib, pq.lib -File -Recurse | Select-Object -First 1
if ($null -eq $mysqlImportLib) { throw "MariaDB/MySQL import library not found under $env:MYSQL_ROOT" }
if ($null -eq $pgImportLib) { throw "PostgreSQL libpq import library not found under $env:POSTGRES_ROOT" }
$flags += @("-showcc")
& v @flags -o $builtSidecar "backend\cmd\vtable_sidecar"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (!(Test-Path $builtSidecar)) { throw "sidecar build did not produce $builtSidecar" }
Copy-Item -Force $builtSidecar $sidecar
Get-ChildItem -Path $outputDir -Filter "vtable-sidecar*.exe" | Sort-Object Name | ForEach-Object {
  Write-Host "prepared $($_.FullName)"
}
