# e2e-sandbox.ps1 — full pipeline test with MOCKS (no real installs, no downloads).
# Isolated USERPROFILE + fake bin dir + fake :1933 health server.
# Steps run in child processes (like real usage). Fast: mocked pulls answer instantly.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tests/e2e-sandbox.ps1
$ErrorActionPreference = 'Stop'
$ForgeRoot = Split-Path $PSScriptRoot
$fail = 0
function Step($Name, [scriptblock]$Body) {
  Write-Host "`n=== E2E: $Name ==="
  try { & $Body; Write-Host "PASS: $Name" }
  catch { Write-Host ("FAIL: {0} : {1}" -f $Name, $_.Exception.Message); $script:fail++ }
}
function Assert($Cond, $Msg) { if (-not $Cond) { throw $Msg } }

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ('forge-e2e-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
$mockbin = Join-Path $sandbox 'mockbin'
New-Item -ItemType Directory -Force -Path $mockbin | Out-Null
Copy-Item (Join-Path $ForgeRoot 'tests/mock-bin/*') $mockbin -Force
$env:USERPROFILE = $sandbox
$env:HOME = $sandbox
$env:MOCKBIN = $mockbin
$env:MOCK_MODELS = Join-Path $sandbox 'ollama-models.txt'
$env:PATH = "$mockbin;" + $env:PATH
Write-Host "Sandbox: $sandbox"

function Start-Health {
  $p = Start-Process python -ArgumentList "`"$ForgeRoot/tests/mock-health.py`" 1933" -PassThru -WindowStyle Hidden
  for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1
    try { if ((Invoke-WebRequest -Uri 'http://127.0.0.1:1933/health' -TimeoutSec 2 -UseBasicParsing).StatusCode -eq 200) { return $p } } catch { }
  }
  throw 'fake health server did not start'
}
function Run-Child($File, $ArgList, $LogName) {
  $log = Join-Path $sandbox "$LogName.log"
  $prevErr = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & powershell -NoProfile -ExecutionPolicy Bypass -File $File @ArgList > $log 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prevErr
  Get-Content $log | Select-Object -Last 4 | ForEach-Object { Write-Host "  | $_" }
  return @{ Code = $code; Log = (Get-Content $log -Raw) }
}

# V1 opencode pre-installed -> installer must upgrade via npm mock
"@echo off`necho opencode v1.18.33" | Set-Content (Join-Path $mockbin 'opencode.cmd') -Encoding Ascii

$health = Start-Health
try {
  Step 'full install (mock tools, V1 upgrade, mocked pulls)' {
    $r = Run-Child "$ForgeRoot/installer/install.ps1" @('-Profile', 'minimal', '-Yes') 'install-1'
    Assert ($r.Code -eq 0) ('exit code: ' + $r.Code)
    Assert ($r.Log -match 'Result: SUCCESS') 'no SUCCESS table'
    Assert ($r.Log -match 'installed: yes \(npm\)') 'opencode V1 was not upgraded via npm'
    Assert (Test-Path "$sandbox/.opencode-forge/state.json") 'state.json missing'
    Assert (Test-Path "$sandbox/.config/opencode/opencode.jsonc") 'opencode.jsonc missing'
    Assert ($r.Log -match 'inference: ok') 'no inference smoke test'
  }
  Step 'idempotence (2nd run, no re-pull, same config)' {
    $h1 = (Get-FileHash "$sandbox/.config/opencode/opencode.jsonc").Hash
    $m1 = if (Test-Path $env:MOCK_MODELS) { (Get-Content $env:MOCK_MODELS | Measure-Object -Line).Lines } else { 0 }
    $r = Run-Child "$ForgeRoot/installer/install.ps1" @('-Profile', 'minimal', '-Yes') 'install-2'
    Assert ($r.Code -eq 0) '2nd run failed'
    Assert ($r.Log -match 'Result: SUCCESS') 'no SUCCESS on 2nd run'
    Assert ((Get-FileHash "$sandbox/.config/opencode/opencode.jsonc").Hash -eq $h1) 'config rewritten on 2nd run'
    $m2 = if (Test-Path $env:MOCK_MODELS) { (Get-Content $env:MOCK_MODELS | Measure-Object -Line).Lines } else { 0 }
    Assert ($m2 -eq $m1) 'models re-pulled on 2nd run'
  }
  Step 'doctor sees install' {
    $r = Run-Child "$ForgeRoot/installer/doctor.ps1" @() 'doctor'
    Assert ($r.Log -match 'Config file\s+PASS') 'doctor misses config'
    Assert ($r.Log -match 'OpenCode\s+PASS') 'doctor misses opencode'
  }
  Step 'refresh-path dedup (no PATH duplication)' {
    $origUser = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    try {
      Import-Module "$ForgeRoot/modules/Winget.psm1" -Force
      New-Item -ItemType Directory -Force -Path (Join-Path $sandbox '.local/bin') | Out-Null
      Update-ForgePath | Out-Null
      Update-ForgePath | Out-Null
      $want = (Join-Path $sandbox '.local/bin')
      $n = ($env:PATH -split ';' | Where-Object { $_ -eq $want }).Count
      Assert ($n -eq 1) "PATH has $n copies of sandbox bin"
    } finally {
      [System.Environment]::SetEnvironmentVariable('PATH', $origUser, 'User')
    }
  }
  Step 'failed install stops with FAILURE (unknown profile)' {
    $r = Run-Child "$ForgeRoot/installer/install.ps1" @('-Profile', 'doesnotexist123', '-Yes') 'install-fail'
    Assert ($r.Code -ne 0) 'should have failed'
  }
} finally {
  try { Stop-Process -Id $health.Id -Force -ErrorAction SilentlyContinue } catch { }
}

Write-Host "`nSandbox kept at: $sandbox"
if ($fail -gt 0) { Write-Error "$fail E2E step(s) failed."; exit 1 }
Write-Host 'E2E: all steps passed.'
