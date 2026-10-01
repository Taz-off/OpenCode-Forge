# probe-models.ps1 — trace ollama resolution + pull/list in mock env.
$oll = Get-Command ollama -ErrorAction SilentlyContinue
Write-Host ("RESOLVED: " + $oll.Source)
Write-Host "--- list ---"
& ollama list
Write-Host ("list-exit=" + $LASTEXITCODE)
Write-Host "--- pull ---"
& ollama pull qwen3:8b
Write-Host ("pull-exit=" + $LASTEXITCODE)
Write-Host "--- list2 ---"
& ollama list
Write-Host "--- models file ---"
Get-Content $env:MOCK_MODELS -ErrorAction SilentlyContinue
