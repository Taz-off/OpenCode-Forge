# probe-models2.ps1 — call the REAL Install-ForgeModels in mock env.
$Root = 'C:/Users/Laszl/OneDrive/projet laszlo/opencode/projects/OpenCode-Forge'
Import-Module "$Root/modules/State.psm1" -Force
Import-Module "$Root/modules/Backup.psm1" -Force
Import-Module "$Root/modules/Software.psm1" -Force
Import-Module "$Root/modules/Ollama.psm1" -Force
Import-Module "$Root/modules/Verify.psm1" -Force
Write-Host "WHICH-OLLAMA: $((Get-Command ollama).Source)"
Write-Host "MODELS-FILE: $($env:MOCK_MODELS)"
$r = Install-ForgeModels 'nomic-embed-text' 'qwen3:8b' $false
Write-Host "INSTALL-RESULT: $r"
Write-Host "--- direct list ---"
& ollama list
