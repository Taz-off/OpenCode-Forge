# rollback.ps1 — restore the newest backup of opencode.jsonc / ov.conf.
Import-Module "$PSScriptRoot/../modules/State.psm1" -Force
$bRoot = Join-Path (Get-ForgeHome) '.opencode-forge/backups'
if (-not (Test-Path $bRoot)) { Write-Error 'No backups found.'; exit 1 }
$latest = Get-ChildItem $bRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
if (-not $latest) { Write-Error 'No backups found.'; exit 1 }
Write-Host "Restoring from: $($latest.FullName)"
foreach ($f in Get-ChildItem $latest.FullName -Recurse -File) {
  if ($f.Name -eq 'opencode.jsonc') { Copy-Item $f.FullName (Join-Path (Get-ForgeHome) '.config/opencode/opencode.jsonc') -Force; Write-Host 'opencode.jsonc restored.' }
  if ($f.Name -eq 'ov.conf') { Copy-Item $f.FullName (Join-Path (Get-ForgeHome) '.openviking/ov.conf') -Force; Write-Host 'ov.conf restored.' }
}
Write-Host 'Rollback done. Run doctor.ps1 to verify.'
