$ErrorActionPreference = "Stop"

if (Get-Command dumpbin -ErrorAction SilentlyContinue) {
  dumpbin /DEPENDENTS "backend\bin\vtable-sidecar.exe"
  Get-ChildItem -Path "backend\runtime\libs", "backend\runtime\plugins" -Filter "*.dll" -File | Sort-Object FullName | ForEach-Object {
    Write-Host "DEPENDENTS $($_.Name)"
    dumpbin /DEPENDENTS $_.FullName
  }
} else {
  Write-Warning "dumpbin not found; skipping dependency inspection"
}
