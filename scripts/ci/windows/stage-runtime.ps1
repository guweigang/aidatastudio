$ErrorActionPreference = "Stop"

$sidecarDir = Resolve-Path "backend\bin"
$runtimeRoot = "backend\runtime"
New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null
$runtimeRoot = (Resolve-Path $runtimeRoot).Path
$runtimeDir = Join-Path $runtimeRoot "libs"
$pluginDir = Join-Path $runtimeRoot "plugins"
$assetDir = Join-Path $runtimeRoot "assets"
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
New-Item -ItemType Directory -Force -Path $pluginDir | Out-Null
New-Item -ItemType Directory -Force -Path $assetDir | Out-Null
function Copy-DependencyDll([System.IO.FileInfo]$dll) {
  $sidecarTarget = Join-Path $sidecarDir $dll.Name
  $runtimeTarget = Join-Path $runtimeDir $dll.Name
  Copy-Item -Force $dll.FullName $sidecarTarget
  Copy-Item -Force $dll.FullName $runtimeTarget
}
function Copy-PluginDll([System.IO.FileInfo]$dll) {
  $sidecarTarget = Join-Path $sidecarDir $dll.Name
  $pluginTarget = Join-Path $pluginDir $dll.Name
  Copy-Item -Force $dll.FullName $sidecarTarget
  Copy-Item -Force $dll.FullName $pluginTarget
}

$vcpkgBin = Join-Path $env:VCPKG_INSTALLED_DIR "bin"
if (Test-Path $vcpkgBin) {
  Get-ChildItem -Path $vcpkgBin -Filter "*.dll" -File | ForEach-Object {
    Copy-DependencyDll $_
  }
}

$pluginRoots = @(
  (Join-Path $env:VCPKG_INSTALLED_DIR "plugins\libmariadb"),
  (Join-Path $env:VCPKG_INSTALLED_DIR "plugins"),
  (Join-Path $env:VCPKG_INSTALLED_DIR "lib\mariadb\plugin"),
  (Join-Path $env:VCPKG_INSTALLED_DIR "lib\plugin"),
  (Join-Path $env:VCPKG_INSTALLED_DIR "plugin")
)
foreach ($pluginRoot in $pluginRoots) {
  if (Test-Path $pluginRoot) {
    Get-ChildItem -Path $pluginRoot -Filter "*.dll" -File | ForEach-Object {
      Copy-PluginDll $_
    }
  }
}

if ($env:VCToolsRedistDir -and (Test-Path $env:VCToolsRedistDir)) {
  Get-ChildItem -Path $env:VCToolsRedistDir -Filter "*.dll" -File -Recurse |
    Where-Object { $_.FullName -match "\\x64\\Microsoft\.VC\d+\.CRT\\" } |
    ForEach-Object {
      Copy-DependencyDll $_
    }
}
$typescriptSource = Join-Path $env:GITHUB_WORKSPACE "$env:VJSX_DIR\thirdparty\typescript\lib"
$typescriptTarget = Join-Path $assetDir "thirdparty\typescript\lib"
$webRuntimeSource = Join-Path $env:GITHUB_WORKSPACE "$env:VJSX_DIR\web\js"
$webRuntimeTarget = Join-Path $assetDir "web\js"
if (!(Test-Path (Join-Path $typescriptSource "typescript.js"))) {
  throw "vjsx TypeScript runtime asset not found under $typescriptSource"
}
if (!(Test-Path (Join-Path $webRuntimeSource "util.js"))) {
  throw "vjsx web runtime assets not found under $webRuntimeSource"
}
New-Item -ItemType Directory -Force -Path $typescriptTarget | Out-Null
Copy-Item -Force (Join-Path $typescriptSource "*.js") $typescriptTarget
New-Item -ItemType Directory -Force -Path $webRuntimeTarget | Out-Null
Copy-Item -Recurse -Force (Join-Path $webRuntimeSource "*") $webRuntimeTarget
Get-ChildItem -Path $sidecarDir -File | Sort-Object Name | ForEach-Object { Write-Host "staged $($_.Name)" }
Get-ChildItem -Path $assetDir -File -Recurse | Sort-Object FullName | ForEach-Object {
  Write-Host "staged asset $($_.FullName.Substring($assetDir.Length + 1))"
}
Get-ChildItem -Path (Join-Path $runtimeRoot "bin") -File | Sort-Object Name | ForEach-Object { Write-Host "staged runtime bin $($_.Name)" }
Get-ChildItem -Path $pluginDir -File | Sort-Object Name | ForEach-Object { Write-Host "staged plugin $($_.Name)" }
