# Winget.psm1 — install via winget (verified IDs only) + PATH refresh without restart.
function Install-ForgeWinget($Id, $Label) {
  Write-Host "  detected: no"
  Write-Host ("  installing... (winget {0})" -f $Id)
  $winget = (Get-Command 'winget' -ErrorAction SilentlyContinue).Source
  if (-not $winget) { throw 'winget not found. Install App Installer from the Microsoft Store, then re-run.' }
  & $winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
  Update-ForgePath
}
function Update-ForgePath {
  $machine = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine')
  $user = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
  $userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
  $extra = @(
    (Join-Path $userHome '.local\bin'),
    (Join-Path $userHome '.opencode\bin')
  )
  try {
    $npmRoot = (& npm root -g 2>$null | Select-Object -First 1)
    if ($npmRoot) {
      $npmBin = Split-Path $npmRoot -ErrorAction SilentlyContinue
      if ($npmBin -and (Test-Path $npmBin)) { $extra += $npmBin }
    }
  } catch { }
  $parts = @()
  foreach ($p in (($env:PATH + ';' + $machine + ';' + $user + ';' + ($extra -join ';')) -split ';')) {
    $t = $p.Trim()
    if ($t -and ($parts -notcontains $t)) { $parts += $t }
  }
  $env:PATH = $parts -join ';'
  foreach ($d in $extra) {
    if (-not $d) { continue }
    if ((Test-Path $d) -and ($user -notmatch [regex]::Escape($d))) {
      try {
        [System.Environment]::SetEnvironmentVariable('PATH', ($user + ';' + $d), 'User')
        Write-Host ("  path+: {0} (persisted, applies to new terminals)" -f $d)
      } catch { Write-Host ("  path+: {0} (session only)" -f $d) }
    }
  }
}
Export-ModuleMember -Function Install-ForgeWinget, Update-ForgePath
