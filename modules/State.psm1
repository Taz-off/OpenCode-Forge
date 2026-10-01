# State.psm1 — local state in ~/.opencode-forge, no secrets ever.
function Get-ForgeHome {
  if ($env:USERPROFILE -and (Test-Path $env:USERPROFILE)) { return $env:USERPROFILE }
  return $HOME
}
function Get-ForgeStateDir {
  $root = Join-Path (Get-ForgeHome) '.opencode-forge'
  foreach ($d in @($root, (Join-Path $root 'logs'), (Join-Path $root 'backups'))) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
  }
  return $root
}
function Read-ForgeState {
  $p = Join-Path (Get-ForgeStateDir) 'state.json'
  if (Test-Path $p) { return (Get-Content $p -Raw | ConvertFrom-Json) }
  return [pscustomobject]@{ version = $null; channel = 'stable'; profile = $null; components = @(); models = @{}; lastUpdate = $null }
}
function Write-ForgeState($State) {
  $p = Join-Path (Get-ForgeStateDir) 'state.json'
  ($State | ConvertTo-Json -Depth 6) | Set-Content $p -Encoding UTF8
}
Export-ModuleMember -Function Get-ForgeHome, Get-ForgeStateDir, Read-ForgeState, Write-ForgeState
