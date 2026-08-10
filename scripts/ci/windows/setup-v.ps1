$ErrorActionPreference = "Stop"

$installRoot = Join-Path $env:RUNNER_TEMP "vlang"
if (Test-Path $installRoot) {
  Remove-Item -Recurse -Force $installRoot
}
git clone --depth 1 https://github.com/vlang/v.git $installRoot
$makev = Join-Path $installRoot "makev.bat"
$makevContent = Get-Content -Raw $makev
if ($makevContent -notmatch "-lbcrypt") {
  $makevContent = $makevContent -replace "-ladvapi32 -lws2_32", "-ladvapi32 -lbcrypt -lws2_32"
  Set-Content -NoNewline -Path $makev -Value $makevContent
}
Push-Location $installRoot
cmd /c makev.bat -msvc
$vBuildExitCode = $LASTEXITCODE
Pop-Location
if ($vBuildExitCode -ne 0) { exit $vBuildExitCode }
$sqliteSource = Join-Path $installRoot "thirdparty\sqlite\sqlite3.cpp"
if (!(Test-Path $sqliteSource)) {
  Push-Location $installRoot
  & (Join-Path $installRoot "v.exe") run "vlib\db\sqlite\install_thirdparty_sqlite.vsh"
  $sqliteInstallExitCode = $LASTEXITCODE
  Pop-Location
  if ($sqliteInstallExitCode -ne 0) { exit $sqliteInstallExitCode }
  $sqliteCSource = Join-Path $installRoot "thirdparty\sqlite\sqlite3.c"
  if (Test-Path $sqliteCSource) {
    Copy-Item -Force $sqliteCSource $sqliteSource
  } elseif (!(Test-Path $sqliteSource)) {
    throw "V thirdparty sqlite source not found at $sqliteSource"
  }
}
Add-Content -Path $env:GITHUB_PATH -Value $installRoot
& (Join-Path $installRoot "v.exe") version
git -C $installRoot log -1 --oneline
