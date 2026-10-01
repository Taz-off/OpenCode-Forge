# probe.ps1 — read-only functional test (no install, no download).
$Root = 'C:/Users/Laszl/OneDrive/projet laszlo/opencode/projects/OpenCode-Forge'
Import-Module "$Root/modules/Hardware.psm1" -Force
Import-Module "$Root/modules/Software.psm1" -Force
Import-Module "$Root/modules/Models.psm1" -Force
$hw = Get-ForgeHardware
$hw | Format-List | Out-String | Write-Host
$sw = Get-ForgeSoftware
$sw | Format-List | Out-String | Write-Host
$plan = Get-ForgeModelPlan $hw "$Root/hardware/model-rules.json"
$plan | Format-List | Out-String | Write-Host
