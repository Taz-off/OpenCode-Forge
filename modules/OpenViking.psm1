# OpenViking.psm1 — single-instance launcher, never two servers.
function Test-ForgeOpenViking {
  try {
    $r = Invoke-RestMethod -Uri 'http://127.0.0.1:1933/health' -TimeoutSec 5 -ErrorAction Stop
    return $true
  } catch { return $false }
}
function Start-ForgeOpenViking($ConfigPath) {
  if (Test-ForgeOpenViking) { Write-Host 'OpenViking already running.'; return $true }
  $cmd = Get-Command 'openviking-server' -ErrorAction SilentlyContinue
  if (-not $cmd) { Write-Warning 'openviking-server not found. OpenCode will start with a warning.'; return $false }
  Start-Process -FilePath $cmd.Source -ArgumentList @('--config', $ConfigPath) -WindowStyle Hidden
  for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    if (Test-ForgeOpenViking) { return $true }
  }
  Write-Warning 'OpenViking did not answer /health in time. Continuing with a warning.'
  return $false
}
Export-ModuleMember -Function Test-ForgeOpenViking, Start-ForgeOpenViking
