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
foreach ($required in @("V_REPO", "V_COMMIT", "VC_REPO", "VC_COMMIT", "TCC_WINDOWS_REPO", "TCC_WINDOWS_COMMIT")) {
  if (!$toolchain[$required]) {
    throw "missing $required in $toolchainPath"
  }
}
$vRepo = $toolchain["V_REPO"]
$vCommit = $toolchain["V_COMMIT"]

$installRoot = Join-Path $env:RUNNER_TEMP "vlang"
if (Test-Path $installRoot) {
  Remove-Item -Recurse -Force $installRoot
}
git init $installRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git -C $installRoot remote add origin $vRepo
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git -C $installRoot fetch --depth 1 origin $vCommit
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git -C $installRoot checkout --detach $vCommit
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$actualCommit = (git -C $installRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($actualCommit -ne $vCommit) {
  throw "unexpected V commit: $actualCommit; expected $vCommit"
}
foreach ($entry in @(
  @{ Path = "vc"; Repo = $toolchain["VC_REPO"]; Commit = $toolchain["VC_COMMIT"] },
  @{ Path = "thirdparty/tcc"; Repo = $toolchain["TCC_WINDOWS_REPO"]; Commit = $toolchain["TCC_WINDOWS_COMMIT"] }
)) {
  $dependency = Join-Path $installRoot $entry.Path
  git init $dependency
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  git -C $dependency remote add origin $entry.Repo
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  git -C $dependency fetch --depth 1 origin $entry.Commit
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  git -C $dependency checkout --detach $entry.Commit
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $actual = (git -C $dependency rev-parse HEAD).Trim()
  if ($actual -ne $entry.Commit) { throw "V bootstrap dependency mismatch: $dependency" }
}
$makev = Join-Path $installRoot "makev.bat"
$makevContent = Get-Content -Raw $makev
if ($makevContent -notmatch "-lbcrypt") {
  $makevContent = $makevContent -replace "-ladvapi32 -lws2_32", "-ladvapi32 -lbcrypt -lws2_32"
  Set-Content -NoNewline -Path $makev -Value $makevContent
}
Push-Location $installRoot
cmd /c makev.bat -msvc --local
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
