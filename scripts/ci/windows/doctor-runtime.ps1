$ErrorActionPreference = "Stop"

$sourceDoctorScript = ".\desktop\scripts\doctor-runtime-libs.ps1"
if (!(Test-Path $sourceDoctorScript)) {
  throw "source doctor script not found at $sourceDoctorScript"
}
$doctorScript = Resolve-Path $sourceDoctorScript
$doctorArgs = @()
if ($env:VTABLE_WINDOWS_SIDECAR_V_FLAGS -match "-cc\s+gcc") {
  $doctorArgs += "-RequireMinGWRuntime"
}
& $doctorScript.Path -SidecarPath "backend\bin\vtable-sidecar.exe" @doctorArgs
