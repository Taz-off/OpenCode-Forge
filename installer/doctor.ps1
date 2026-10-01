# doctor.ps1 — health checks with short explanation per failure. Changes nothing.
# Output: PASS / MISSING / FAIL per component (matches ./install.sh --check).
$Root = Split-Path $PSScriptRoot
Import-Module "$Root/modules/Software.psm1" -Force
Import-Module "$Root/modules/OpenViking.psm1" -Force
Import-Module "$Root/modules/OpenCode.psm1" -Force
Import-Module "$Root/modules/State.psm1" -Force

function Check($Name, $Ok, $Missing, $Hint) {
  if ($Ok) { $s = 'PASS' }
  elseif ($Missing) { $s = 'MISSING' }
  else { $s = 'FAIL' }
  Write-Host ("{0,-18} {1}" -f $Name, $s)
  if ($s -ne 'PASS') { Write-Host ("  -> {0}" -f $Hint) }
  return ($s -eq 'PASS')
}
$sw = Get-ForgeSoftware
$cfg = Join-Path (Get-ForgeOpenCodeConfigDir) 'opencode.jsonc'
$all = $true
$has = { param($n) [bool](Get-Command $n -ErrorAction SilentlyContinue) }
$all = (Check 'OpenCode' ([bool]$sw.OpenCode) (-not (& $has 'opencode')) 'Run installer/install.ps1 (official: npm @opencode/cli / https://opencode.ai)') -and $all
$all = (Check 'Git' ([bool]$sw.Git) (-not (& $has 'git')) 'Install Git for Windows (winget Git.Git), then re-open the terminal.') -and $all
$all = (Check 'Node' ([bool]$sw.Node) (-not (& $has 'node')) 'Run installer/install.ps1 (winget OpenJS.NodeJS).') -and $all
$all = (Check 'Python' ([bool](Get-Command 'python' -ErrorAction SilentlyContinue)) (-not ((Get-Command 'python' -ErrorAction SilentlyContinue) -or (Get-Command 'python3' -ErrorAction SilentlyContinue))) 'Install Python 3.10+ (winget Python.Python.3.12).') -and $all
$all = (Check 'Ollama' ([bool]$sw.Ollama) (-not (& $has 'ollama')) 'Run installer/install.ps1 (winget Ollama.Ollama) or install from https://ollama.com') -and $all
$all = (Check 'uv' ([bool]$sw.Uv) (-not (& $has 'uv')) 'Run installer/install.ps1 (winget astral-sh.uv).') -and $all
$all = (Check 'OpenViking' (Test-ForgeOpenViking) (-not (Get-Command 'openviking-server' -ErrorAction SilentlyContinue)) 'Run installer/install.ps1, or start: openviking-server --config $env:USERPROFILE/.openviking/ov.conf') -and $all
$all = (Check 'Port 1933' (Test-ForgeOpenViking) $false 'Something else uses 1933, or the server is down.') -and $all
$all = (Check 'Config file' (Test-Path $cfg) (-not (Test-Path $cfg)) 'Run installer/install.ps1 first.') -and $all
$all = (Check 'DCP' ((Test-Path $cfg) -and ((Get-Content $cfg -Raw) -match 'opencode-dcp')) $false 'Re-run install with profile recommended+.') -and $all
$all = (Check 'Context7' ((Test-Path $cfg) -and ((Get-Content $cfg -Raw) -match 'context7')) $false 'Re-run install with profile recommended+.') -and $all
if ($all) { Write-Host 'All checks passed.' } else { Write-Host 'Fix items above, then re-run doctor.'; exit 1 }
