# bisect.ps1 — find which step unloads Read-ForgeState.
$Root = 'C:/Users/Laszl/OneDrive/projet laszlo/opencode/projects/OpenCode-Forge'
Import-Module "$Root/modules/Hardware.psm1" -Force
Import-Module "$Root/modules/Software.psm1" -Force
Import-Module "$Root/modules/Models.psm1" -Force
Import-Module "$Root/modules/State.psm1" -Force
Import-Module "$Root/modules/Backup.psm1" -Force
Write-Host ("after State+Backup import: " + [bool](Get-Command Read-ForgeState -ErrorAction SilentlyContinue) + ' / ' + [bool](Get-Command New-ForgeBackup -ErrorAction SilentlyContinue))
Import-Module "$Root/modules/OpenCode.psm1" -Force
Write-Host ("after OpenCode import: " + [bool](Get-Command Read-ForgeState -ErrorAction SilentlyContinue))
Import-Module "$Root/modules/Skills.psm1" -Force
Write-Host ("after Skills import: " + [bool](Get-Command Read-ForgeState -ErrorAction SilentlyContinue))
Import-Module "$Root/modules/Ollama.psm1" -Force
Import-Module "$Root/modules/OpenViking.psm1" -Force
Write-Host ("after all imports: " + [bool](Get-Command Read-ForgeState -ErrorAction SilentlyContinue))
if (-not (Get-Command Read-ForgeState -ErrorAction SilentlyContinue)) { throw 'REGRESSION: Read-ForgeState hidden (module nesting). Modules must not Import-Module siblings.' }
if (-not (Get-Command New-ForgeBackup -ErrorAction SilentlyContinue)) { throw 'REGRESSION: New-ForgeBackup hidden (module nesting).' }
if (-not (Get-Command Get-ForgeHome -ErrorAction SilentlyContinue)) { throw 'REGRESSION: Get-ForgeHome hidden (module nesting).' }
Get-Module | Where-Object { $_.Name -match '^(State|Backup|OpenCode|Skills)$' } | Format-Table Name,Path
