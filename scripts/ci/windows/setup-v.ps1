$ErrorActionPreference = "Stop"

$toolchainPath = Join-Path $env:GITHUB_WORKSPACE "scripts\ci\v-toolchain.env"
if (!(Test-Path $toolchainPath -PathType Leaf)) {
  throw "V toolchain config not found at $toolchainPath"
}
$toolchain = @{}
foreach ($line in Get-Content $toolchainPath) {
  $trimmed = $line.Trim()
  if (!$trimmed -or $trimmed.StartsWith("#")) { continue }
  $separatorIndex = $trimmed.IndexOf("=")
  if ($separatorIndex -le 0) {
    throw "invalid V toolchain config line: $line"
  }
  $key = $trimmed.Substring(0, $separatorIndex).Trim()
  $value = $trimmed.Substring($separatorIndex + 1).Trim()
  if (!$key -or !$value) {
    throw "invalid V toolchain config line: $line"
  }
  $toolchain[$key] = $value
}
foreach ($required in @("V_REPO", "V_BRANCH", "V_COMMIT")) {
  if (!$toolchain[$required]) {
    throw "missing $required in $toolchainPath"
  }
}
$vRepo = $toolchain["V_REPO"]
$vBranch = $toolchain["V_BRANCH"]
$vCommit = $toolchain["V_COMMIT"]

$installRoot = Join-Path $env:RUNNER_TEMP "vlang"
if (Test-Path $installRoot) {
  Remove-Item -Recurse -Force $installRoot
}
git clone --branch $vBranch --single-branch --depth 1 $vRepo $installRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git -C $installRoot checkout --detach $vCommit
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$actualCommit = (git -C $installRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($actualCommit -ne $vCommit) {
  throw "unexpected V commit: $actualCommit; expected $vCommit"
}
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
$verifiedCommit = (git -C $installRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($verifiedCommit -ne $vCommit) {
  throw "V checkout changed during build: $verifiedCommit; expected $vCommit"
}
Write-Host "V commit: $verifiedCommit"
git -C $installRoot log -1 --oneline
