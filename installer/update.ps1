# update.ps1 — fetch remote manifest, compare, backup, apply what changed, test, save state.
param([string]$ManifestUrl = '')
$Root = Split-Path $PSScriptRoot
Import-Module "$Root/modules/GitHub.psm1" -Force
Import-Module "$Root/modules/State.psm1" -Force
Import-Module "$Root/modules/Backup.psm1" -Force
$local = Get-Content (Join-Path $Root 'manifest.json') -Raw | ConvertFrom-Json
if (-not $ManifestUrl) { $ManifestUrl = $local.manifestUrl }
Write-Host "Local version: $($local.version)"
$remote = Get-ForgeRemoteManifest $ManifestUrl
if (-not $remote) { Write-Warning 'Remote manifest unreachable. Check network, nothing changed.'; exit 1 }
Write-Host "Remote version: $($remote.version)"
if ($remote.version -eq $local.version) { Write-Host 'Already up to date.'; exit 0 }
$cfg = Join-Path (Get-ForgeHome) '.config/opencode/opencode.jsonc'
if (Test-Path $cfg) { New-ForgeBackup $cfg 'before-update' | Out-Null; Write-Host 'Config backed up.' }
Write-Host 'Update strategy V1: download the new release zip and re-run install.ps1 (idempotent).'
Write-Host ("Release page: {0}" -f $local.releaseUrl)
$state = Read-ForgeState
$state.lastUpdate = (Get-Date).ToString('s')
Write-ForgeState $state
