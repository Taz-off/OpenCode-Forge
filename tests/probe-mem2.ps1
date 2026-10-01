# probe-mem2.ps1 — full install.ps1 import set, then memory step only.
$Root = 'C:/Users/Laszl/OneDrive/projet laszlo/opencode/projects/OpenCode-Forge'
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
Write-Host ("UV-WHICH: " + (Get-Command uv -ErrorAction SilentlyContinue).Source)
$r = Install-ForgeMemoryApp
Write-Host "MEM-RESULT: $r"
Write-Host ("OVS-NOW: " + (Get-Command openviking-server -ErrorAction SilentlyContinue).Source)
