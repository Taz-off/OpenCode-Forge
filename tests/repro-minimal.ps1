# repro-minimal.ps1 — fresh sandbox, minimal install, full error visible.
$ErrorActionPreference = 'Continue'
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ('forge-repro-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
$env:USERPROFILE = $sandbox
$env:HOME = $sandbox
Write-Host "Sandbox: $sandbox"
$Root = 'C:/Users/Laszl/OneDrive/projet laszlo/opencode/projects/OpenCode-Forge'
& "$Root/installer/install.ps1" -Profile minimal -Yes -NoModels
Write-Host ("EXIT: " + $LASTEXITCODE)
Get-ChildItem $sandbox -Recurse -ErrorAction SilentlyContinue | Select-Object -First 10 FullName
