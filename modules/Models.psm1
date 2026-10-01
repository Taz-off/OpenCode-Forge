# Models.psm1 — tier + model plan driven by hardware/model-rules.json.
function Get-ForgeModelPlan($Hardware, $RulesPath) {
  $rules = Get-Content $RulesPath -Raw | ConvertFrom-Json
  $tier = 'low'
  foreach ($t in $rules.tiers) {
    if ($Hardware.RamGb -le $t.when.ramGbMax -and $Hardware.VramGb -le $t.when.vramGbMax) { $tier = $t.tier; break }
    $tier = $t.tier
  }
  $rule = $rules.tiers | Where-Object { $_.tier -eq $tier } | Select-Object -First 1
  return [pscustomobject]@{
    Tier = $tier
    Embedding = $rules.embeddingModel
    Memory = $rule.memoryModel
    Code = $rule.codeModel
    CodeOptional = [bool]$rule.codeModelOptional
  }
}
Export-ModuleMember -Function Get-ForgeModelPlan
