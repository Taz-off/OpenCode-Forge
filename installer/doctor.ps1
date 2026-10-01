# doctor.ps1 — health checks with short explanation per failure.
$Root = Split-Path $PSScriptRoot
Import-Module "$Root/modules/Software.psm1" -Force
Import-Module "$Root/modules/OpenViking.psm1" -Force
Import-Module "$Root/modules/OpenCode.psm1" -Force
Import-Module "$Root/modules/State.psm1" -Force

function Check($Name, $Ok, $Hint) {
  $s = if ($Ok) { 'OK' } else { 'FAIL' }
  Write-Host ("{0,-18} {1}" -f $Name, $s)
  if (-not $Ok) { Write-Host ("  -> {0}" -f $Hint) }
  return $Ok
}
$sw = Get-ForgeSoftware
$cfg = Join-Path (Get-ForgeOpenCodeConfigDir) 'opencode.jsonc'
$all = $true
$all = (Check 'OpenCode' ([bool]$sw.OpenCode) 'Install from https://opencode.ai') -and $all
$all = (Check 'Git' ([bool]$sw.Git) 'Install Git for Windows, then re-open the terminal.') -and $all
$all = (Check 'GitHub CLI' ([bool]$sw.Gh) 'Optional. Needed only for automated repo/release steps.') -and $all
$all = (Check 'Ollama' ([bool]$sw.Ollama) 'Install from https://ollama.com') -and $all
$all = (Check 'OpenViking' (Test-ForgeOpenViking) 'Start: openviking-server --config $env:USERPROFILE/.openviking/ov.conf') -and $all
$all = (Check 'Port 1933' (Test-ForgeOpenViking) 'Something else uses 1933, or the server is down.') -and $all
$all = (Check 'Config file' (Test-Path $cfg) 'Run installer/install.ps1 first.') -and $all
$all = (Check 'DCP' ((Test-Path $cfg) -and ((Get-Content $cfg -Raw) -match 'opencode-dcp')) 'Re-run install with profile recommended+.') -and $all
$all = (Check 'Context7' ((Test-Path $cfg) -and ((Get-Content $cfg -Raw) -match 'context7')) 'Re-run install with profile recommended+.') -and $all
if ($all) { Write-Host 'All checks passed.' } else { Write-Host 'Fix items above, then re-run doctor.'; exit 1 }
