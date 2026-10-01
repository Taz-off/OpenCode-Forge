# install.ps1 — interactive installer. Idempotent. No big download without confirmation.
param([string]$Profile = '', [switch]$Yes, [switch]$NoModels, [switch]$Check, [switch]$Help)
$Root = Split-Path $PSScriptRoot
if ($Help) {
  Write-Host 'Usage: .\install.ps1 [-Profile NAME] [-Yes] [-NoModels] [-Check] [-Help]'
  Write-Host '  NAME = minimal|recommended|minecraft|gamedev|complete|custom'
  Write-Host '  -Check verifies only and changes nothing (same as doctor.ps1).'
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

if ($Check) { & (Join-Path $PSScriptRoot 'doctor.ps1'); exit $LASTEXITCODE }

$hw = Get-ForgeHardware
$sw = Get-ForgeSoftware
$plan = Get-ForgeModelPlan $hw (Join-Path $Root 'hardware/model-rules.json')

Write-Host '=== OpenCode Forge — detection ==='
$hw | Format-List | Out-String | Write-Host
Write-Host '--- Software ---'
$sw | Format-List | Out-String | Write-Host
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
  $dest = Install-ForgeOpenCodeConfig (Join-Path $Root 'templates/opencode.jsonc') $plan.Memory
  Write-Host "Config written: $dest"
}
$skillMap = @{
  projectThinking = @('project-thinking'); minecraftSkills = @('minecraft-paper-dev', 'minecraft-fabric-dev', 'minecraft-neoforge-dev', 'minecraft-resourcepack-datapack-dev', 'minecraft-server-debug')
  blender = @('blender-game-assets'); unity = @('unity-development'); unreal = @('unreal-development')
}
$skills = @()
foreach ($c in $components) { if ($skillMap.ContainsKey($c)) { $skills += $skillMap[$c] } }
if ($skills.Count -gt 0) { Install-ForgeSkills (Join-Path $Root 'skills') $skills; Write-Host ("Skills: {0}" -f ($skills -join ', ')) }

if (-not $NoModels) {
if ($components -contains 'ollama' -or $components -contains 'embeddingModel' -or $components -contains 'memoryModel') {
  if (-not (Test-ForgeOllama)) { Write-Warning 'Ollama not found. Install it from https://ollama.com, then re-run.' }
  else {
    $have = Get-ForgeOllamaModels
    foreach ($m in @($plan.Embedding, $plan.Memory)) {
      if ($have -match $m) { Write-Host "Model present: $m" }
      else {
        $a = Read-Host "Download model $m ? (yes/no)"
        if ($a -eq 'yes') { Install-ForgeOllamaModel $m } else { Write-Host "Skipped: $m" }
      }
    }
  }
}
}
else { Write-Host 'Model downloads skipped (-NoModels). Run again without it to pull Ollama models.' }

$state = Read-ForgeState
$state.version = (Get-Content (Join-Path $Root 'manifest.json') -Raw | ConvertFrom-Json).version
$state.channel = 'stable'
$state.profile = $Profile
$state.components = $components
$state.models = @{ embedding = $plan.Embedding; memory = $plan.Memory; tier = $plan.Tier }
$state.lastUpdate = (Get-Date).ToString('s')
Write-ForgeState $state
Write-Host 'Done. State saved to ~/.opencode-forge/state.json'
Write-Host 'Run doctor.ps1 to verify, then start OpenCode.'
