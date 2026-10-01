# Backup.psm1 — timestamped backups, excludes heavy dirs, never destructive.
# NOTE: never Import-Module siblings (nesting hides commands). Caller imports State first.
function New-ForgeBackup($Path, $Label = 'pre-change') {
  if (-not (Test-Path $Path)) { return $null }
  $root = Join-Path (Get-ForgeHome) '.opencode-forge/backups'
  if (-not (Test-Path $root)) { New-Item -ItemType Directory -Force -Path $root | Out-Null }
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $dest = Join-Path $root "$stamp-$Label"
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  $leaf = Split-Path $Path -Leaf
  $target = Join-Path $dest $leaf
  if (Test-Path $Path -PathType Container) {
    Copy-Item $Path $target -Recurse -Force -Exclude @('node_modules', 'data', 'vectordb', '*.log')
  } else {
    Copy-Item $Path $target -Force
  }
  return $target
}
Export-ModuleMember -Function New-ForgeBackup
