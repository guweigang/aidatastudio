$ErrorActionPreference = "Stop"

$tauriCliVersion = "2.11.4"
$templateSha256 = "20f4ecc730defb71f1342eaeaec4021df13be3d843abba0effe88ea5835fa079"
$customTemplateSha256 = "e26b49c7fcba7bb53eaab8b72d81f4f24db95b839afcc41c7a98cf2f04829446"
$templateUrl = "https://raw.githubusercontent.com/tauri-apps/tauri/tauri-cli-v$tauriCliVersion/crates/tauri-bundler/src/bundle/windows/nsis/installer.nsi"
$templatePath = Join-Path $env:RUNNER_TEMP "tauri-installer-$tauriCliVersion-preserve-app-data.nsi"

$downloadPath = "$templatePath.download"
Invoke-WebRequest -Uri $templateUrl -OutFile $downloadPath
$actualSha256 = (Get-FileHash -Algorithm SHA256 -Path $downloadPath).Hash.ToLowerInvariant()
if ($actualSha256 -ne $templateSha256) {
  throw "Unexpected Tauri NSIS template SHA-256: expected $templateSha256, got $actualSha256"
}

$source = [IO.File]::ReadAllText($downloadPath)
$defaultLine = '      ${IfThen} $UpdateMode = 1 ${|} StrCpy $R1 "$R1 /UPDATE" ${|} ; append /UPDATE'
$preservingLines = @(
  "      ; An uninstall launched by this installer is an upgrade/reinstall transition."
  "      ; Always use /UPDATE so the old uninstaller cannot remove user app data."
  '      StrCpy $R1 "$R1 /UPDATE"'
) -join "`n"

$matches = ([regex]::Matches($source, [regex]::Escape($defaultLine))).Count
if ($matches -ne 1) {
  throw "Expected exactly one Tauri upgrade-uninstall line, found $matches"
}

$customized = $source.Replace($defaultLine, $preservingLines)
[IO.File]::WriteAllText($templatePath, $customized, [Text.UTF8Encoding]::new($false))
$actualCustomSha256 = (Get-FileHash -Algorithm SHA256 -Path $templatePath).Hash.ToLowerInvariant()
if ($actualCustomSha256 -ne $customTemplateSha256) {
  throw "Unexpected customized NSIS template SHA-256: expected $customTemplateSha256, got $actualCustomSha256"
}
Remove-Item -Force $downloadPath

"VTABLE_NSIS_TEMPLATE=$templatePath" >> $env:GITHUB_ENV
Write-Host "Prepared audited NSIS template: $templatePath"
