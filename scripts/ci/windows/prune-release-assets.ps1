$ErrorActionPreference = "Stop"
$version = $env:RELEASE_VERSION
$tag = $env:RELEASE_TAG
$releaseJson = gh release view $tag --json assets 2>$null
if ($LASTEXITCODE -ne 0 -or !$releaseJson) {
  Write-Host "release $tag does not exist yet; nothing to prune"
  exit 0
}
$assets = ($releaseJson | ConvertFrom-Json).assets
foreach ($asset in $assets) {
  $name = $asset.name
  $isWindowsAsset = $name -match '^AI[.\s]Data[.\s]Studio_.*_x64'
  $isCurrentVersion = $name.Contains("_${version}_")
  if ($isWindowsAsset -and !$isCurrentVersion) {
    Write-Host "deleting stale Windows release asset: $name"
    gh release delete-asset $tag $name -y
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}
