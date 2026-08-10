$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path "$env:VCPKG_BINARY_CACHE_DIR" | Out-Null
$env:VCPKG_DEFAULT_BINARY_CACHE = "$env:VCPKG_BINARY_CACHE_DIR"
Add-Content -Path $env:GITHUB_ENV -Value "VCPKG_DEFAULT_BINARY_CACHE=$env:VCPKG_BINARY_CACHE_DIR"
$vcpkgRoot = Join-Path $env:RUNNER_TEMP "vcpkg"
git clone --depth 1 https://github.com/microsoft/vcpkg $vcpkgRoot
& (Join-Path $vcpkgRoot "bootstrap-vcpkg.bat") -disableMetrics
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$triplet = "x64-windows"
& (Join-Path $vcpkgRoot "vcpkg.exe") install openssl:$triplet libmariadb:$triplet libpq:$triplet bdwgc:$triplet
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$sdkRoot = Join-Path $vcpkgRoot "installed\$triplet"
$vRoot = Join-Path $env:RUNNER_TEMP "vlang"
$vMysqlRoot = Join-Path $vRoot "thirdparty\mysql"
$vMysqlInclude = Join-Path $vMysqlRoot "include"
$vMysqlLib = Join-Path $vMysqlRoot "lib"
$vPgRoot = Join-Path $vRoot "thirdparty\pg"
$vPgInclude = Join-Path $vPgRoot "libpq"
$vPgLib = Join-Path $vPgRoot "win64"
New-Item -ItemType Directory -Force -Path $vMysqlInclude, $vMysqlLib, $vPgInclude, $vPgLib | Out-Null
$mysqlHeader = Get-ChildItem -Path $sdkRoot -Filter mysql.h -File -Recurse | Select-Object -First 1
$mysqlImportLib = Get-ChildItem -Path (Join-Path $sdkRoot "lib") -Include libmariadb.lib, mysqlclient.lib, libmysql.lib, mysql.lib -File -Recurse | Select-Object -First 1
$mysqlRuntimeDll = Get-ChildItem -Path $sdkRoot -Include libmariadb.dll, libmysql.dll -File -Recurse | Select-Object -First 1
$pgHeader = Get-ChildItem -Path $sdkRoot -Filter libpq-fe.h -File -Recurse | Select-Object -First 1
$pgConfigHeader = Get-ChildItem -Path $sdkRoot -Filter pg_config.h -File -Recurse | Select-Object -First 1
$pgImportLib = Get-ChildItem -Path (Join-Path $sdkRoot "lib") -Include libpq.lib, pq.lib -File -Recurse | Select-Object -First 1
$pgRuntimeDll = Get-ChildItem -Path $sdkRoot -Include libpq.dll -File -Recurse | Select-Object -First 1
$opensslLibDir = Join-Path $sdkRoot "lib"
$cryptoImportLib = Get-ChildItem -Path $opensslLibDir -Include libcrypto.lib, crypto.lib -File -Recurse | Select-Object -First 1
$sslImportLib = Get-ChildItem -Path $opensslLibDir -Include libssl.lib, ssl.lib -File -Recurse | Select-Object -First 1
if ($null -eq $mysqlHeader) { throw "mysql.h not found under $sdkRoot" }
if ($null -eq $mysqlImportLib) { throw "MariaDB/MySQL import library not found under $sdkRoot" }
if ($null -eq $pgHeader) { throw "libpq-fe.h not found under $sdkRoot" }
if ($null -eq $pgConfigHeader) { throw "pg_config.h not found under $sdkRoot" }
if ($null -eq $pgImportLib) { throw "PostgreSQL libpq import library not found under $sdkRoot" }
if ($null -eq $cryptoImportLib) { throw "OpenSSL crypto import library not found under $sdkRoot" }
if ($null -eq $sslImportLib) { throw "OpenSSL ssl import library not found under $sdkRoot" }
$mysqlCdefs = Join-Path $vRoot "vlib\db\mysql\_cdefs_windows.c.v"
Set-Content -Encoding utf8 -Path $mysqlCdefs -Value @'
module mysql

#flag windows -I@VEXEROOT/thirdparty/mysql/include
#flag windows -L@VEXEROOT/thirdparty/mysql/lib
#flag windows -lmysql

#include <mysql.h> # Please install https://dev.mysql.com/downloads/installer/ , then copy the include, lib, and bin folders to thirdparty/mysql. Make sure thirdparty/mysql/bin and thirdparty/mysql/lib are on PATH, or copy libmysql.dll next to the produced .exe
#include "@VMODROOT/vlib/db/mysql/mysql_compat.h"
'@
Copy-Item -Recurse -Force (Join-Path $mysqlHeader.DirectoryName "*") $vMysqlInclude
Copy-Item -Force $mysqlImportLib.FullName (Join-Path $vMysqlLib "mysql.lib")
Copy-Item -Force $mysqlImportLib.FullName (Join-Path $vMysqlLib "libmysql.lib")
Copy-Item -Force $mysqlImportLib.FullName (Join-Path $vMysqlLib "libmariadb.lib")
if ($null -ne $mysqlRuntimeDll) {
  Copy-Item -Force $mysqlRuntimeDll.FullName (Join-Path $vMysqlLib "libmysql.dll")
}
Copy-Item -Recurse -Force (Join-Path $pgHeader.DirectoryName "*") $vPgInclude
Copy-Item -Force $pgConfigHeader.FullName (Join-Path $vPgInclude "pg_config.h")
Copy-Item -Force $pgImportLib.FullName (Join-Path $vPgLib "libpq.lib")
Copy-Item -Force $pgImportLib.FullName (Join-Path $vPgLib "pq.lib")
if ($null -ne $pgRuntimeDll) {
  Copy-Item -Force $pgRuntimeDll.FullName (Join-Path $vPgLib "libpq.dll")
}
foreach ($alias in @("crypto.lib", "libcrypto.lib")) {
  $aliasPath = Join-Path $opensslLibDir $alias
  if ($cryptoImportLib.FullName -ne $aliasPath) {
    Copy-Item -Force $cryptoImportLib.FullName $aliasPath
  }
}
foreach ($alias in @("ssl.lib", "libssl.lib")) {
  $aliasPath = Join-Path $opensslLibDir $alias
  if ($sslImportLib.FullName -ne $aliasPath) {
    Copy-Item -Force $sslImportLib.FullName $aliasPath
  }
}
Add-Content -Path $env:GITHUB_ENV -Value "OPENSSL_ROOT_DIR=$sdkRoot"
Add-Content -Path $env:GITHUB_ENV -Value "MYSQL_ROOT=$sdkRoot"
Add-Content -Path $env:GITHUB_ENV -Value "POSTGRES_ROOT=$sdkRoot"
Add-Content -Path $env:GITHUB_ENV -Value "VCPKG_INSTALLED_DIR=$sdkRoot"
Add-Content -Path $env:GITHUB_ENV -Value "C_INCLUDE_PATH=$sdkRoot\include;$env:C_INCLUDE_PATH"
Add-Content -Path $env:GITHUB_ENV -Value "LIBRARY_PATH=$sdkRoot\lib;$env:LIBRARY_PATH"
Add-Content -Path $env:GITHUB_ENV -Value "PKG_CONFIG_PATH=$sdkRoot\lib\pkgconfig;$sdkRoot\share\pkgconfig;$env:PKG_CONFIG_PATH"
Add-Content -Path $env:GITHUB_PATH -Value (Join-Path $sdkRoot "bin")
