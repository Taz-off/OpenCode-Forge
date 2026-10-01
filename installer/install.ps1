# install.ps1 — interactive installer. Idempotent. No big download without confirmation.
param([string]$Profile = '', [switch]$Yes, [switch]$NoModels, [switch]$Check, [switch]$Repair, [switch]$DryRun, [switch]$Help)
$Root = Split-Path $PSScriptRoot
if ($Help) {
  Write-Host 'Usage: .\install.ps1 [-Profile NAME] [-Yes] [-NoModels] [-Check] [-Repair] [-DryRun] [-Help]'
  Write-Host '  NAME = minimal|recommended|minecraft|gamedev|complete|custom'
  Write-Host '  -Check verifies only and changes nothing (same as doctor.ps1).'
  Write-Host '  -Repair verifies, fixes only broken components, retests.'
  Write-Host '  -DryRun shows what would be done, changes nothing.'
  Write-Host '  -Yes skips confirmation prompt (plan is still displayed).'
  exit 0
}
Import-Module "$Root/modules/Hardware.psm1" -Force
Import-Module "$Root/modules/Software.psm1" -Force
Import-Module "$Root/modules/Models.psm1" -Force
Import-Module "$Root/modules/State.psm1" -Force
Import-Module "$Root/modules/Backup.psm1" -Force
Import-Module "$Root/modules/OpenCode.psm1" -Force
Import-Module "$Root/modules/Skills.psm1" -Force
Import-Module "$Root/modules/Ollama.psm1" -Force
Import-Module "$Root/modules/OpenViking.psm1" -Force
Import-Module "$Root/modules/Steps.psm1" -Force
Import-Module "$Root/modules/Winget.psm1" -Force
Import-Module "$Root/modules/Verify.psm1" -Force

if ($Check) { & (Join-Path $PSScriptRoot 'doctor.ps1'); exit $LASTEXITCODE }

if ($DryRun) {
  Write-Host '=== OpenCode Forge — dry-run (changes nothing) ==='
  $hwDry = Get-ForgeHardware
  $planDry = Get-ForgeModelPlan $hwDry (Join-Path $Root 'hardware/model-rules.json')
  $hwDry | Format-List | Out-String | Write-Host
  Write-Host ("Tier: {0} (memory {1}, embedding {2})" -f $planDry.Tier, $planDry.Memory, $planDry.Embedding)
  Write-Host '[dry-run] would verify Git, Python, Node, OpenCode, Ollama, uv, tsx'
  Write-Host '[dry-run] would write + validate config'
  Write-Host '[dry-run] would install skills, pull + inference-test models, healthcheck memory'
  Write-Host '[dry-run] would backup existing configs to ~/.opencode-forge/backups/'
  exit 0
}

if ($Repair) {
  Set-ForgeStepTotal 6
  $repaired = $false
  if (-not (Test-ForgeVersion 'git' @('--version'))) { Write-Host 'Git broken/missing -> reinstalling'; if (Invoke-ForgeStep 'Git' { Install-ForgeGit }) { $repaired = $true } }
  if (-not ((Test-ForgeVersion 'python' @('--version')) -or (Test-ForgeVersion 'python3' @('--version')))) { Write-Host 'Python broken/missing -> reinstalling'; if (Invoke-ForgeStep 'Python' { Install-ForgePython }) { $repaired = $true } }
  if (-not (Test-ForgeVersion 'opencode' @('--version'))) { Write-Host 'OpenCode broken/missing -> reinstalling'; if (Invoke-ForgeStep 'OpenCode' { Install-ForgeOpenCodeApp }) { $repaired = $true } }
  if (-not (Test-ForgeOllamaService)) { Write-Host 'Ollama broken/missing -> reinstalling'; if (Invoke-ForgeStep 'Ollama' { Install-ForgeOllamaApp }) { $repaired = $true } }
  if (-not (Test-ForgeVersion 'uv' @('--version'))) { Write-Host 'uv broken/missing -> reinstalling'; if (Invoke-ForgeStep 'uv' { Install-ForgeUvApp }) { $repaired = $true } }
  if (-not (Test-ForgeConfigFiles $Root $null)) {
    Write-Host 'Config invalid/missing -> rewriting from templates'
    $hwRepair = Get-ForgeHardware
    $planRepair = Get-ForgeModelPlan $hwRepair (Join-Path $Root 'hardware/model-rules.json')
    if (Invoke-ForgeStep 'Config' { Install-ForgeOpenCodeConfig (Join-Path $Root 'templates/opencode.jsonc') $planRepair.Memory; Test-ForgeConfigFiles $Root $null }) { $repaired = $true }
  }
  if (-not (Test-ForgeOpenViking)) {
    Write-Host 'Memory server down -> restarting'
    $ovc = Join-Path (Get-ForgeHome) '.openviking\ov.conf'
    if (Invoke-ForgeStep 'Memory' { Start-ForgeOpenViking $ovc }) { $repaired = $true }
  }
  if (-not $repaired) { Write-Host 'Nothing broken. All good.' }
  $ok = Show-ForgeSummary
  if ($ok) { exit 0 } else { exit 1 }
}

$hw = Get-ForgeHardware
$plan = Get-ForgeModelPlan $hw (Join-Path $Root 'hardware/model-rules.json')

Write-Host '=== OpenCode Forge — detection ==='
$hw | Format-List | Out-String | Write-Host
Write-Host ("Suggested tier: {0} (memory {1}, embedding {2})" -f $plan.Tier, $plan.Memory, $plan.Embedding)

if (-not $Profile) {
  Write-Host ''
  Write-Host 'Profiles: MINIMAL / RECOMMENDED / MINECRAFT / GAMEDEV / CUSTOM / COMPLETE'
  $Profile = (Read-Host 'Profile').ToLower()
  if (-not $Profile) { $Profile = 'recommended' }
}
$profFile = Join-Path $Root ("profiles/$Profile.json")
if ($Profile -eq 'custom') {
  Write-Host 'CUSTOM: answer yes/no per component.'
  $want = @('opencode', 'openviking', 'ollama', 'embeddingModel', 'memoryModel', 'dcp', 'plannotator', 'superpowers', 'projectThinking', 'context7', 'commands')
  $chosen = @()
  foreach ($c in $want) { if ((Read-Host "Include $c ? (y/n)") -match '^[Yy]') { $chosen += $c } }
  $components = $chosen
} else {
  if (-not (Test-Path $profFile)) { Write-Error "Unknown profile: $Profile"; exit 1 }
  $components = (Get-Content $profFile -Raw | ConvertFrom-Json).components
}

Write-Host ''
Write-Host '=== Install plan (confirmation required) ==='
Write-Host "Profile: $Profile"
Write-Host ("Components: {0}" -f ($components -join ', '))
Write-Host ("Models: embedding={0} memory={1}" -f $plan.Embedding, $plan.Memory)
if ($plan.Code -and $components -contains 'memoryModel') { Write-Host ("Optional code model: {0} (only with explicit yes)" -f $plan.Code) }
Write-Host 'Existing configs will be backed up to ~/.opencode-forge/backups.'
if (-not $Yes) {
  $ok = Read-Host 'Proceed? (yes/no)'
  if ($ok -ne 'yes') { Write-Host 'Aborted. Nothing changed.'; exit 0 }
}

if ($components -contains 'opencode' -or $components -contains 'commands') {
  $needTsx = $components -contains 'minecraftMcp'
  $total = 12
  if ($needTsx) { $total += 2 }
  Set-ForgeStepTotal $total
  if (-not (Invoke-ForgeStep 'Git' { Install-ForgeGit })) { exit 1 }
  if (-not (Invoke-ForgeStep 'Python' { Install-ForgePython })) { exit 1 }
  if ($needTsx) {
    if (-not (Invoke-ForgeStep 'Node' { Install-ForgeNode })) { exit 1 }
    if (-not (Invoke-ForgeStep 'tsx' { Install-ForgeTsx })) { exit 1 }
  }
  if (-not (Invoke-ForgeStep 'OpenCode' { Install-ForgeOpenCodeApp })) { exit 1 }
  if (-not (Invoke-ForgeStep 'Ollama' { Install-ForgeOllamaApp })) { exit 1 }
  if (-not (Invoke-ForgeStep 'uv' { Install-ForgeUvApp })) { exit 1 }
  if (-not (Invoke-ForgeStep 'OpenViking' { Install-ForgeMemoryApp })) { exit 1 }
  if (-not (Invoke-ForgeStep 'Config' {
    $dest = Install-ForgeOpenCodeConfig (Join-Path $Root 'templates/opencode.jsonc') $plan.Memory
    Write-Host ("Config written: {0}" -f $dest)
    Test-ForgeConfigFiles $Root $components
  })) { exit 1 }
} else {
  Set-ForgeStepTotal 11
  if (-not (Invoke-ForgeStep 'Git' { Install-ForgeGit })) { exit 1 }
  if (-not (Invoke-ForgeStep 'Python' { Install-ForgePython })) { exit 1 }
  if (-not (Invoke-ForgeStep 'OpenCode' { Install-ForgeOpenCodeApp })) { exit 1 }
  if (-not (Invoke-ForgeStep 'Ollama' { Install-ForgeOllamaApp })) { exit 1 }
  if (-not (Invoke-ForgeStep 'uv' { Install-ForgeUvApp })) { exit 1 }
  if (-not (Invoke-ForgeStep 'OpenViking' { Install-ForgeMemoryApp })) { exit 1 }
  Skip-ForgeStep 'Config'
}
$skillMap = @{
  projectThinking = @('project-thinking'); minecraftSkills = @('minecraft-paper-dev', 'minecraft-fabric-dev', 'minecraft-neoforge-dev', 'minecraft-resourcepack-datapack-dev', 'minecraft-server-debug')
  blender = @('blender-game-assets'); unity = @('unity-development'); unreal = @('unreal-development')
}
$skills = @()
foreach ($c in $components) { if ($skillMap.ContainsKey($c)) { $skills += $skillMap[$c] } }
if ($skills.Count -gt 0) {
  if (-not (Invoke-ForgeStep 'Skills' {
    Install-ForgeSkills (Join-Path $Root 'skills') $skills
    Write-Host ("Skills: {0}" -f ($skills -join ', '))
    $okSkills = $true
    foreach ($s in $skills) {
      if (-not (Test-Path (Join-Path (Get-ForgeOpenCodeConfigDir) ("skills\{0}\SKILL.md" -f $s)))) { $okSkills = $false }
    }
    $okSkills
  })) { exit 1 }
} else { Skip-ForgeStep 'Skills' }
if (-not $NoModels) {
  if ($components -contains 'ollama' -or $components -contains 'embeddingModel' -or $components -contains 'memoryModel') {
    if (-not (Invoke-ForgeStep 'Models' {
      Install-ForgeModels $plan.Embedding $plan.Memory $false
      Test-ForgeModels $plan.Embedding $plan.Memory $false
    })) { exit 1 }
  } else { Skip-ForgeStep 'Models' }
}
else {
  Write-Host 'Model downloads skipped (-NoModels). Run again without it to pull Ollama models.'
  Skip-ForgeStep 'Models'
}
if ($components -contains 'opencode' -or $components -contains 'commands') {
  if (-not (Invoke-ForgeStep 'Memory' {
    if (Test-ForgeOpenViking) { Write-Host '  server: already running'; Write-Host '  health: ok'; return $true }
    $ovc = Join-Path (Get-ForgeHome) '.openviking\ov.conf'
    Start-ForgeOpenViking $ovc
  })) { exit 1 }
} else { Skip-ForgeStep 'Memory' }
if (-not (Invoke-ForgeStep 'Final' {
  $v = Test-ForgeVersion 'opencode' @('--version')
  return [bool]$v
})) { exit 1 }

$state = Read-ForgeState
$state.version = (Get-Content (Join-Path $Root 'manifest.json') -Raw | ConvertFrom-Json).version
$state.channel = 'stable'
$state.profile = $Profile
$state.components = $components
$state.models = @{ embedding = $plan.Embedding; memory = $plan.Memory; tier = $plan.Tier }
$state.lastUpdate = (Get-Date).ToString('s')
Write-ForgeState $state
Write-Host 'Done. State saved to ~/.opencode-forge/state.json'
if (Show-ForgeSummary) { exit 0 } else { exit 1 }
