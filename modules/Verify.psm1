# Verify.psm1 — detect -> install -> verify per component (Windows).
# NOTE: no sibling imports (nesting rule). Entry scripts import everything.
function Test-ForgeVersion($Name, $ToolArgs) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) { Write-Host '  detected: no'; return $null }
  $out = Invoke-ForgeTool $cmd.Source $ToolArgs
  if (-not $out) { Write-Host ("  detected: yes ({0} runs but reports nothing)" -f $Name); return $null }
  Write-Host '  detected: yes'
  Write-Host ("  version: {0}" -f $out)
  return $out
}
function Install-ForgeGit {
  $v = Test-ForgeVersion 'git' @('--version')
  if ($v) { return $true }
  Install-ForgeWinget 'Git.Git' 'Git'
  $v = Test-ForgeVersion 'git' @('--version')
  if (-not $v) { throw "Git install reported success but 'git --version' still fails." }
  Write-Host '  installed: yes'
  return $true
}
function Install-ForgeNode {
  $v = Test-ForgeVersion 'node' @('--version')
  $n = Test-ForgeVersion 'npm' @('--version')
  if ($v -and $n) { return $true }
  Install-ForgeWinget 'OpenJS.NodeJS' 'Node.js'
  $v = Test-ForgeVersion 'node' @('--version')
  $n = Test-ForgeVersion 'npm' @('--version')
  if (-not ($v -and $n)) { throw "Node.js install reported success but 'node --version' still fails." }
  Write-Host '  installed: yes'
  return $true
}
function Install-ForgeOpenCodeApp {
  $v = Test-ForgeVersion 'opencode' @('--version')
  if ($v) {
    if ($v -match 'v?2\.') { return $true }
    Write-Host ("  detected: yes BUT version looks like V1 ({0}), need V2" -f $v)
  }
  Install-ForgeNode
  Write-Host '  installing... (npm @opencode/cli, official package)'
  & npm install -g '@opencode/cli' 2>&1 | Out-Null
  Update-ForgePath
  $v = Test-ForgeVersion 'opencode' @('--version')
  if (-not $v) { throw "OpenCode install failed: 'opencode --version' still fails. See https://opencode.ai, install manually, then re-run." }
  if ($v -notmatch 'v?2\.') { Write-Host ("  WARN: version {0} does not look like V2, continuing anyway" -f $v) }
  Write-Host '  installed: yes (npm)'
  return $true
}
function Install-ForgeOllamaApp {
  $v = Test-ForgeVersion 'ollama' @('--version')
  if ($v) {
    if (Test-ForgeOllamaService) { Write-Host '  service: running'; return $true }
    Write-Host '  service: starting...'
    Start-ForgeOllamaService
    return $true
  }
  Install-ForgeWinget 'Ollama.Ollama' 'Ollama'
  $v = Test-ForgeVersion 'ollama' @('--version')
  if (-not $v) { throw "Ollama install reported success but 'ollama --version' still fails." }
  Write-Host '  installed: yes'
  Start-ForgeOllamaService
  return $true
}
function Test-ForgeOllamaService {
  $ollama = (Get-Command 'ollama' -ErrorAction SilentlyContinue).Source
  if (-not $ollama) { return $false }
  $out = Invoke-ForgeTool $ollama @('list') 30000
  return ($out -match '^NAME\s')
}
function Start-ForgeOllamaService {
  if (Test-ForgeOllamaService) { Write-Host '  service: running'; return $true }
  Write-Host '  service: starting...'
  try { Start-Process (Get-Command 'ollama').Source -ArgumentList 'serve' -WindowStyle Hidden -ErrorAction Stop } catch { }
  for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 2
    if (Test-ForgeOllamaService) { Write-Host '  service: running'; return $true }
  }
  throw "Ollama installed but the service does not answer ('ollama list' fails). Start Ollama manually, then re-run."
}
function Install-ForgeUvApp {
  $v = Test-ForgeVersion 'uv' @('--version')
  if ($v) { return $true }
  try {
    Install-ForgeWinget 'astral-sh.uv' 'uv'
  } catch {
    Write-Host ("  winget failed ({0}), trying official Astral installer..." -f $_.Exception.Message)
  }
  $v = Test-ForgeVersion 'uv' @('--version')
  if ($v) { Write-Host '  installed: yes'; return $true }
  Write-Host '  installing... (official Astral installer: https://astral.sh/uv/install.ps1)'
  try {
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" 2>&1 | Out-Null
  } catch { }
  Update-ForgePath
  $v = Test-ForgeVersion 'uv' @('--version')
  if (-not $v) { throw "uv install reported success but 'uv --version' still fails. Install from https://docs.astral.sh/uv/, then re-run." }
  Write-Host '  installed: yes'
  return $true
}
function Install-ForgePython {
  $v = Test-ForgeVersion 'python' @('--version')
  if (-not $v) { $v = Test-ForgeVersion 'python3' @('--version') }
  if ($v) { return $true }
  try {
    Install-ForgeWinget 'Python.Python.3.12' 'Python 3.12'
  } catch {
    throw "Python3 missing and winget install failed. Install Python 3.10+ from https://www.python.org then re-run."
  }
  $v = Test-ForgeVersion 'python' @('--version')
  if (-not $v) { $v = Test-ForgeVersion 'python3' @('--version') }
  if (-not $v) { throw "Python install reported success but 'python --version' still fails." }
  Write-Host '  installed: yes'
  return $true
}
function Install-ForgeTsx {
  $v = Test-ForgeVersion 'tsx' @('--version')
  if ($v) { return $true }
  Install-ForgeNode
  Write-Host '  installing... (npm tsx)'
  & npm install -g 'tsx' 2>&1 | Out-Null
  Update-ForgePath
  $v = Test-ForgeVersion 'tsx' @('--version')
  if (-not $v) { throw "tsx install failed: 'tsx --version' still fails." }
  Write-Host '  installed: yes'
  return $true
}
function Install-ForgeMemoryApp {
  $cmd = Get-Command 'openviking-server' -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Host '  detected: no'
    Write-Host '  installing... (uv tool install openviking)'
    Install-ForgeUvApp
    & uv tool install openviking 2>&1 | Out-Null
    Update-ForgePath
    $cmd = Get-Command 'openviking-server' -ErrorAction SilentlyContinue
    if (-not $cmd) { throw "'openviking-server' still missing after 'uv tool install openviking'." }
    Write-Host '  installed: yes'
  } else { Write-Host '  detected: yes (openviking-server)' }
  return $true
}
function Test-ForgeModelPresent($Model) {
  $list = Get-ForgeOllamaModels
  if (-not $list) { return $false }
  return ((($list -join "`n") -match [regex]::Escape($Model)) -as [bool])
}
function Install-ForgeModels($Embedding, $Memory, $NoModels) {
  foreach ($m in @($Embedding, $Memory)) {
    if (Test-ForgeModelPresent $m) { Write-Host ("  model present: {0}" -f $m); continue }
    if ($NoModels) { Write-Host ("  model skipped (--NoModels): {0}" -f $m); continue }
    Write-Host ("  pulling {0} (large download)..." -f $m)
    Install-ForgeOllamaModel $m
    if (-not (Test-ForgeModelPresent $m)) { throw ("'ollama pull {0}' reported success but model is not in 'ollama list'." -f $m) }
    Write-Host ("  model downloaded + listed: {0}" -f $m)
  }
  return $true
}
function Test-ForgeModels($Embedding, $Memory, $NoModels) {
  $fail = $false
  foreach ($m in @($Embedding, $Memory)) {
    if (Test-ForgeModelPresent $m) { Write-Host ("  model listed: {0}" -f $m) }
    elseif ($NoModels) { Write-Host ("  model skipped (--NoModels): {0}" -f $m) }
    else { Write-Host ("  model missing: {0}" -f $m); $fail = $true }
  }
  if ($fail) { return $false }
  if ($NoModels) { return $true }
  Write-Host ("  inference smoke test ({0})..." -f $Memory)
  $ollama = (Get-Command 'ollama').Source
  $out = Invoke-ForgeTool $ollama @('run', $Memory, 'Reply with exactly: OK') 240000
  if ($out) { Write-Host ("  inference: ok ({0})" -f $out.Substring(0, [Math]::Min(80, $out.Length))); return $true }
  Write-Host '  inference: no usable response'
  return $false
}
function Test-ForgeConfigFiles($Root, $Components) {
  $dir = Get-ForgeOpenCodeConfigDir
  $cfg = Join-Path $dir 'opencode.jsonc'
  if (-not (Test-Path $cfg)) { Write-Host '  opencode.jsonc: missing'; return $false }
  try {
    $text = Get-Content $cfg -Raw
    $text = [regex]::Replace($text, '(?m)^\s*//.*\r?$', '')
    $text | ConvertFrom-Json | Out-Null
    Write-Host '  opencode.jsonc: valid JSON'
  } catch { Write-Host '  opencode.jsonc: INVALID'; return $false }
  $fail = $false
  $want = @()
  if ($Components -contains 'commands') { $want += 'commands\discuss.md', 'commands\plan.md' }
  if ($Components -contains 'projectThinking') { $want += 'skills\project-thinking\SKILL.md' }
  foreach ($rel in $want) {
    $f = Join-Path $dir $rel
    if (-not (Test-Path $f)) { Write-Host ("  referenced file missing: {0}" -f $f); $fail = $true }
  }
  if (-not $fail) { Write-Host '  referenced files: present' }
  return (-not $fail)
}
Export-ModuleMember -Function Test-ForgeVersion, Test-ForgeModelPresent, Install-ForgeGit, Install-ForgeNode, Install-ForgePython, Install-ForgeOpenCodeApp, Install-ForgeOllamaApp, Test-ForgeOllamaService, Start-ForgeOllamaService, Install-ForgeUvApp, Install-ForgeTsx, Install-ForgeMemoryApp, Install-ForgeModels, Test-ForgeModels, Test-ForgeConfigFiles
