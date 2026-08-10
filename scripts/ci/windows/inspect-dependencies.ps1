$ErrorActionPreference = "Stop"

if (Get-Command dumpbin -ErrorAction SilentlyContinue) {
  dumpbin /DEPENDENTS "backend\bin\vtable-sidecar.exe"
  Get-ChildItem -Path "backend\bin" -Filter "*.dll" -File | Sort-Object Name | ForEach-Object {
    Write-Host "DEPENDENTS $($_.Name)"
    dumpbin /DEPENDENTS $_.FullName
  }
} else {
  Write-Warning "dumpbin not found; skipping dependency inspection"
}
