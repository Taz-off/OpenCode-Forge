# configure.ps1 — re-run config from templates (backup first, idempotent).
param([string]$MemoryModel = 'qwen3:8b')
$Root = Split-Path $PSScriptRoot
Import-Module "$Root/modules/OpenCode.psm1" -Force
$dest = Install-ForgeOpenCodeConfig (Join-Path $Root 'templates/opencode.jsonc') $MemoryModel
Write-Host "Config refreshed: $dest"
