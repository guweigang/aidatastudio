$ErrorActionPreference = "Stop"
$quickjsSource = Join-Path $env:GITHUB_WORKSPACE $env:QUICKJS_DIR
$quickjsBuild = Join-Path $env:RUNNER_TEMP "quickjs-ng-build"
if (Test-Path $quickjsBuild) {
  Remove-Item -Recurse -Force $quickjsBuild
}
cmake -S $quickjsSource -B $quickjsBuild -G Ninja -DCMAKE_BUILD_TYPE=Release -DQJS_BUILD_LIBC=ON -DBUILD_SHARED_LIBS=OFF
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
cmake --build $quickjsBuild --target qjs_exe
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$qjsLib = Get-ChildItem -Path $quickjsBuild -Filter qjs.lib -File -Recurse |
  Select-Object -First 1
$qjsExe = Get-ChildItem -Path $quickjsBuild -Filter qjs.exe -File -Recurse |
  Select-Object -First 1
if ($null -eq $qjsLib) { throw "qjs.lib not found under $quickjsBuild" }
if ($null -eq $qjsExe) { throw "qjs.exe not found under $quickjsBuild" }
$smokeOutput = (& $qjsExe.FullName -e "print(1 + 1)" | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($smokeOutput -ne "2") { throw "quickjs-ng smoke expected 2, got: $smokeOutput" }
Add-Content -Path $env:GITHUB_ENV -Value "VJS_QUICKJS_LIB_PATH=$($qjsLib.FullName)"
Write-Host "VJS_QUICKJS_LIB_PATH=$($qjsLib.FullName)"
Write-Host "quickjs-ng smoke: $smokeOutput"
