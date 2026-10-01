# repair.ps1 — re-apply templates + skills, verify with doctor.
$Root = Split-Path $PSScriptRoot
& (Join-Path $PSScriptRoot 'configure.ps1')
& (Join-Path $PSScriptRoot 'doctor.ps1')
