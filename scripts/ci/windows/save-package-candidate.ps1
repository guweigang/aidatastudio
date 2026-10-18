$ErrorActionPreference = "Stop"
$source = Join-Path $env:GITHUB_WORKSPACE "source"
$target = Join-Path $env:GITHUB_WORKSPACE "dist/windows-candidate"
New-Item -ItemType Directory -Force -Path $target | Out-Null
$packages = @(Get-ChildItem "$source/desktop/src-tauri/target/x86_64-pc-windows-msvc/release/bundle/nsis" -Filter "*setup.exe" -File)
if ($packages.Count -ne 1) { throw "Expected one Windows installation candidate" }
Copy-Item $packages[0].FullName $target
Copy-Item "$source/desktop/native/attachment-ocr/target/release/attachment-normalization-probe.exe" $target
Copy-Item "$env:RUNNER_TEMP/attachment-ocr-evidence/native-acceptance.json" $target
Copy-Item "$source/backend/runtime/attachment-ocr/manifest.json" $target
$sourceCommit = (git -C $source rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
[ordered]@{ sourceCommit = $sourceCommit; ciCommit = $env:GITHUB_SHA; installer = $packages[0].Name; installerSha256 = (Get-FileHash -Algorithm SHA256 $packages[0].FullName).Hash.ToLowerInvariant() } |
  ConvertTo-Json | Set-Content -Encoding utf8 "$target/candidate.json"
