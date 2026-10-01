# e2e-sandbox.ps1 — full pipeline test with an isolated USERPROFILE.
# Each step runs in a FRESH powershell process, exactly like real usage
# (one script = one process). Nothing real is touched: config/state/backups
# all land in a temp sandbox inherited via environment.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests/e2e-sandbox.ps1 [-Source <forge-tree-dir>]
param([string]$Source = '')
$ErrorActionPreference = 'Stop'
if (-not $Source) { $Source = Split-Path $PSScriptRoot }
$fail = 0
function Step($Name, [scriptblock]$Body) {
  Write-Host "`n=== E2E: $Name ==="
  try { & $Body; Write-Host "PASS: $Name" }
  catch { Write-Host ("FAIL: {0} : {1}" -f $Name, $_.Exception.Message); $script:fail++ }
}
function Assert($Cond, $Msg) { if (-not $Cond) { throw $Msg } }
function Run-Child($File, $ArgList, $LogName) {
  $log = Join-Path $script:sandbox "$LogName.log"
  & powershell -NoProfile -ExecutionPolicy Bypass -File $File @ArgList > $log 2>&1
  $code = $LASTEXITCODE
  Get-Content $log | Select-Object -Last 5 | ForEach-Object { Write-Host "  | $_" }
  return @{ Code = $code; Log = (Get-Content $log -Raw) }
}

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ('forge-e2e-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
$env:USERPROFILE = $sandbox
$env:HOME = $sandbox
Write-Host "Sandbox: $sandbox"

Step 'module commands stay visible (no nesting)' {
  $r = Run-Child "$Source/tests/bisect.ps1" @() 'bisect'
  Assert ($r.Code -eq 0) ('bisect failed: ' + $r.Log)
}
Step 'install minimal (2nd run = idempotence)' {
  $r = Run-Child "$Source/installer/install.ps1" @('-Profile', 'minimal', '-Yes', '-NoModels') 'install-min-1'
  Assert ($r.Code -eq 0) ('install #1 failed: ' + $r.Log)
  $r = Run-Child "$Source/installer/install.ps1" @('-Profile', 'minimal', '-Yes', '-NoModels') 'install-min-2'
  Assert ($r.Code -eq 0) ('install #2 (idempotence) failed: ' + $r.Log)
  Assert (Test-Path "$sandbox/.opencode-forge/state.json") 'state.json missing'
  Assert (Test-Path "$sandbox/.config/opencode/opencode.jsonc") 'opencode.jsonc missing'
  Assert (-not (Test-Path "$sandbox/.config/opencode/opencode.json")) 'legacy opencode.json should not exist'
  $st = Get-Content "$sandbox/.opencode-forge/state.json" -Raw | ConvertFrom-Json
  Assert ($st.profile -eq 'minimal') 'profile not saved'
}
Step 'doctor reports installed config' {
  $r = Run-Child "$Source/installer/doctor.ps1" @() 'doctor'
  Assert ($r.Log -match 'Config file\s+OK') 'doctor does not see the installed config'
}
Step 'configure is idempotent' {
  $r = Run-Child "$Source/installer/configure.ps1" @() 'configure'
  Assert ($r.Code -eq 0) ('configure failed: ' + $r.Log)
  Assert ((Get-Content "$sandbox/.config/opencode/opencode.jsonc" -Raw).Length -gt 0) 'config empty after configure'
}
Step 'rollback restores backup' {
  $r = Run-Child "$Source/installer/rollback.ps1" @() 'rollback'
  Assert ($r.Code -eq 0) ('rollback failed: ' + $r.Log)
  Assert (Test-Path "$sandbox/.config/opencode/opencode.jsonc") 'config missing after rollback'
}
Step 'update (offline-safe)' {
  $r = Run-Child "$Source/installer/update.ps1" @() 'update'
  Assert ($r.Code -eq 0) ('update failed: ' + $r.Log)
}
Step 'no secrets in sandbox state' {
  $text = Get-Content "$sandbox/.opencode-forge/state.json" -Raw
  $pat = 'Bearer ' + 'eyJ'
  Assert ($text -notmatch $pat) 'secret leaked into state'
}
Step 'recommended profile installs skills+commands' {
  $r = Run-Child "$Source/installer/install.ps1" @('-Profile', 'recommended', '-Yes', '-NoModels') 'install-rec'
  Assert ($r.Code -eq 0) ('recommended install failed: ' + $r.Log)
  Assert (Test-Path "$sandbox/.config/opencode/skills/project-thinking/SKILL.md") 'project-thinking missing'
  Assert (Test-Path "$sandbox/.config/opencode/commands/discuss.md") 'commands missing'
}

Write-Host "`nSandbox kept at: $sandbox"
if ($fail -gt 0) { Write-Error "$fail E2E step(s) failed."; exit 1 }
Write-Host 'E2E: all steps passed.'
