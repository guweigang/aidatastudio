$ErrorActionPreference = "Stop"
$build = Join-Path $env:RUNNER_TEMP "attachment-ocr-build"
$evidence = Join-Path $env:RUNNER_TEMP "attachment-ocr-evidence"
New-Item -ItemType Directory -Force -Path $build, $evidence | Out-Null
python desktop/scripts/fetch-attachment-pdfium.py --target win-x64 --output "$build/pdfium"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
python desktop/scripts/fetch-attachment-ocr-models.py --output "$build/tessdata"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
cargo build --release --locked --features acceptance-probe --manifest-path desktop/native/attachment-ocr/Cargo.toml
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
$crt = Get-ChildItem -Path $env:VCToolsRedistDir -Directory -Recurse | Where-Object {
  $_.FullName -match "[\\/]x64[\\/]Microsoft\.VC[0-9]+\.CRT$"
} | Select-Object -First 1
if ($null -eq $crt) { throw "MSVC x64 runtime directory not found" }
python desktop/scripts/prepare-attachment-ocr.py --prefix "$env:VCPKG_INSTALLED_DIR" --pdfium "$build/pdfium" --worker desktop/native/attachment-ocr/target/release/vtable-attachment-ocr.exe --tessdata "$build/tessdata" --msvc-redist "$($crt.FullName)" --output backend/runtime/attachment-ocr
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Copy-Item backend/runtime/attachment-ocr/manifest.json "$evidence/manifest.json"
python desktop/scripts/test-attachment-ocr.py --runtime backend/runtime/attachment-ocr --normalizer desktop/native/attachment-ocr/target/release/attachment-normalization-probe.exe --output "$evidence/native-acceptance.json"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
