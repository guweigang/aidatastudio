$ErrorActionPreference = "Stop"
$entries = @(
  Get-ChildItem "HKCU:/Software/Microsoft/Windows/CurrentVersion/Uninstall", "HKLM:/Software/Microsoft/Windows/CurrentVersion/Uninstall" -ErrorAction SilentlyContinue |
    ForEach-Object { Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName -eq "AI Data Studio" }
)
if ($entries.Count -ne 1) { throw "Expected exactly one installed AI Data Studio" }
$installed = $entries[0].InstallLocation
if (!$installed) { throw "Installed application location missing from uninstall entry" }
$runtime = Join-Path $installed "backend/runtime/attachment-ocr"
$source = Join-Path $env:GITHUB_WORKSPACE "source"
$staged = Join-Path $source "backend/runtime/attachment-ocr"
$evidence = Join-Path $env:RUNNER_TEMP "attachment-ocr-evidence"
if ((Get-FileHash "$runtime/manifest.json").Hash -ne (Get-FileHash "$staged/manifest.json").Hash) {
  throw "Installed OCR manifest differs from staged resources"
}
$manifest = Get-Content -Raw "$runtime/manifest.json" | ConvertFrom-Json
if ($manifest.platform -ne "windows-x86_64") { throw "Installed OCR target mismatch" }
foreach ($entry in $manifest.files.PSObject.Properties) {
  $file = Join-Path $runtime $entry.Name
  if ((Get-FileHash -Algorithm SHA256 $file).Hash.ToLowerInvariant() -ne $entry.Value) { throw "Installed OCR resource digest mismatch: $file" }
}
$dumpbin = (Get-Command dumpbin -ErrorAction Stop).Source
$dependencies = @()
foreach ($file in Get-ChildItem "$runtime/bin" -File | Where-Object { $_.Extension -in @(".dll", ".exe") }) {
  $output = & $dumpbin /DEPENDENTS $file.FullName
  if ($LASTEXITCODE -ne 0) { throw "Dependency inspection failed: $($file.Name)" }
  foreach ($line in $output) {
    if ($line -match '^\s+([a-zA-Z0-9_.+-]+\.dll)\s*$') {
      $dll = $Matches[1]
      if ($dll -notmatch '^(api-ms-win-|ext-ms-win-)' -and !(Test-Path "$runtime/bin/$dll") -and !(Test-Path "$env:WINDIR/System32/$dll")) {
        throw "OCR dependency is not packaged or supplied by Windows: $($file.Name) -> $dll"
      }
      $dependencies += [ordered]@{ binary = $file.Name; dependency = $dll }
    }
  }
}
# Remove build SDK paths before executing the installed worker and normalization probe.
$python = (Get-Command python -ErrorAction Stop).Source
$env:PATH = "$env:WINDIR/System32;$env:WINDIR"
$env:PYTHONUTF8 = "1"
& $python "$source/desktop/scripts/test-attachment-ocr.py" --runtime "$runtime" --normalizer "$source/desktop/native/attachment-ocr/target/release/attachment-normalization-probe.exe" --output "$evidence/installed-acceptance.json"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
[ordered]@{ status = "passed"; installedRoot = $installed; platform = $manifest.platform; resourceCount = @($manifest.files.PSObject.Properties).Count; sdkPathsRemoved = $true; dependencies = $dependencies } |
  ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 "$evidence/installed-distribution.json"
