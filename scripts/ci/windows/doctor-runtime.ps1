$ErrorActionPreference = "Stop"

$sourceDoctorScript = ".\desktop\scripts\doctor-runtime-libs.ps1"
$ciDoctorScript = Join-Path $env:GITHUB_WORKSPACE "desktop\scripts\doctor-runtime-libs.ps1"
if (Test-Path $sourceDoctorScript) {
  $doctorScript = Resolve-Path $sourceDoctorScript
} elseif (Test-Path $ciDoctorScript) {
  $doctorScript = Resolve-Path $ciDoctorScript
} else {
  throw "doctor-runtime-libs.ps1 not found in source or CI repository"
}
$doctorArgs = @()
if ($env:VTABLE_WINDOWS_SIDECAR_V_FLAGS -match "-cc\s+gcc") {
  $doctorArgs += "-RequireMinGWRuntime"
}
& $doctorScript.Path -SidecarPath "backend\bin\vtable-sidecar.exe" @doctorArgs
