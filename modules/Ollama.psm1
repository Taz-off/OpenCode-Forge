# Ollama.psm1 — check + pull models (caller must confirm before download).
function Test-ForgeOllama {
  return [bool](Get-Command 'ollama' -ErrorAction SilentlyContinue)
}
function Get-ForgeOllamaModels {
  try { return (ollama list 2>$null) } catch { return $null }
}
function Install-ForgeOllamaModel($Model) {
  Write-Host "Pulling Ollama model: $Model (large download, already confirmed)"
  ollama pull $Model
}
Export-ModuleMember -Function Test-ForgeOllama, Get-ForgeOllamaModels, Install-ForgeOllamaModel
