# repair.ps1 — real repair: verify, fix only broken components, retest.
$Root = Split-Path $PSScriptRoot
& (Join-Path $PSScriptRoot 'install.ps1') -Repair
