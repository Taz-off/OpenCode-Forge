# OpenCode.psm1 — config install, ONE source (opencode.jsonc), backup first, idempotent.
# NOTE: never Import-Module sibling modules here (it would nest them and hide
# their commands from the caller). Entry scripts import everything they need.
function Get-ForgeOpenCodeConfigDir {
  return (Join-Path (Get-ForgeHome) '.config/opencode')
}
function Install-ForgeOpenCodeConfig($TemplatePath, $MemoryModel) {
  $dir = Get-ForgeOpenCodeConfigDir
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $dest = Join-Path $dir 'opencode.jsonc'
  $legacy = Join-Path $dir 'opencode.json'
  if (Test-Path $dest) { New-ForgeBackup $dest 'opencode-jsonc' | Out-Null }
  if (Test-Path $legacy) {
    $disabled = "$legacy.disabled-$(Get-Date -Format 'yyyyMMdd')"
    Move-Item $legacy $disabled -Force
    Write-Host "Legacy opencode.json moved to: $disabled (single source: opencode.jsonc)"
  }
  $text = Get-Content $TemplatePath -Raw
  $uvx = 'uvx'
  try {
    $u = Get-Command 'uvx' -ErrorAction SilentlyContinue
    if ($u) { $uvx = $u.Source }
    else {
      $local = Join-Path (Get-ForgeHome) '.local/bin/uvx.exe'
      if (Test-Path $local) { $uvx = $local }
    }
  } catch { }
  $tsx = 'tsx.cmd'
  try { $t = Get-Command 'tsx.cmd' -ErrorAction SilentlyContinue; if ($t) { $tsx = $t.Source } } catch { }
  $text = $text.Replace('__UVX__', ($uvx -replace '\\', '\\')).Replace('__TSX__', ($tsx -replace '\\', '\\'))
  $text | Set-Content $dest -Encoding UTF8
  # dcp.jsonc
  $dcpDest = Join-Path $dir 'dcp.jsonc'
  $dcpTpl = Join-Path (Split-Path $TemplatePath) 'dcp.jsonc'
  if ((Test-Path $dcpTpl) -and (-not (Test-Path $dcpDest))) { Copy-Item $dcpTpl $dcpDest -Force }
  # openviking ov.conf
  $ovDir = Join-Path (Get-ForgeHome) '.openviking'
  if (-not (Test-Path $ovDir)) { New-Item -ItemType Directory -Force -Path $ovDir | Out-Null }
  $ovDest = Join-Path $ovDir 'ov.conf'
  $ovTpl = Join-Path (Split-Path $TemplatePath) 'openviking/ov.conf.json'
  if (Test-Path $ovTpl) {
    if (Test-Path $ovDest) { New-ForgeBackup $ovDest 'ov-conf' | Out-Null }
    $ov = (Get-Content $ovTpl -Raw).Replace('__HOME__', (Get-ForgeHome).Replace('\', '/')).Replace('__MEMORY_MODEL__', $MemoryModel)
    $ov | Set-Content $ovDest -Encoding UTF8
  }
  # commands
  $cmdDir = Join-Path $dir 'commands'
  if (-not (Test-Path $cmdDir)) { New-Item -ItemType Directory -Force -Path $cmdDir | Out-Null }
  $cmdSrc = Join-Path (Split-Path (Split-Path $TemplatePath)) 'commands'
  if (Test-Path $cmdSrc) { Copy-Item (Join-Path $cmdSrc '*.md') $cmdDir -Force }
  return $dest
}
Export-ModuleMember -Function Get-ForgeOpenCodeConfigDir, Install-ForgeOpenCodeConfig
