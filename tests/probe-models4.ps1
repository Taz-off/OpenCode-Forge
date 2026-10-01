# probe-models4.ps1 — module loaded, then DIRECT ollama calls.
$Root = 'C:/Users/Laszl/OneDrive/projet laszlo/opencode/projects/OpenCode-Forge'
Import-Module "$Root/modules/Ollama.psm1" -Force
Write-Host "DIRECT pull:"
ollama pull direct-test-model
Write-Host "direct-done exit=$LASTEXITCODE"
Write-Host "VIA-FUNCTION pull:"
Install-ForgeOllamaModel via-fn-model
Write-Host "fn-done exit=$LASTEXITCODE"
