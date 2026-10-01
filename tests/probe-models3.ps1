# probe-models3.ps1 — inline functions, no modules.
function Get-M { return (ollama list 2>$null) }
function Pull-M($Model) {
  Write-Host "Pulling $Model"
  ollama pull $Model
  Write-Host "pull-done exit=$LASTEXITCODE"
}
Write-Host ("WHICH: " + (Get-Command ollama).Source)
$m = 'nomic-embed-text'
$l1 = Get-M
Write-Host ("BEFORE: [$l1]")
Pull-M $m
$l2 = Get-M
Write-Host ("AFTER: [$l2]")
