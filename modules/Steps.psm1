# Steps.psm1 — numbered step framework. A step passes ONLY if its verification passes.
$script:ForgeStepNames = @()
$script:ForgeStepStatus = @()
$script:ForgeStepI = 0
$script:ForgeStepN = 0
$script:ForgeStepFail = 0
function Set-ForgeStepTotal($N) {
  $script:ForgeStepN = $N; $script:ForgeStepI = 0
  $script:ForgeStepNames = @(); $script:ForgeStepStatus = @(); $script:ForgeStepFail = 0
}
function Invoke-ForgeStep($Name, [scriptblock]$Body) {
  $script:ForgeStepI++
  Write-Host ''
  Write-Host ("[{0}/{1}] {2}" -f $script:ForgeStepI, $script:ForgeStepN, $Name)
  try {
    $ok = & $Body
    if ($ok -eq $false) { throw 'verification returned false' }
  } catch {
    Write-Host ("  test: FAIL -- {0}" -f $_.Exception.Message)
    $script:ForgeStepNames += $Name; $script:ForgeStepStatus += 'FAIL'; $script:ForgeStepFail = 1
    return $false
  }
  Write-Host '  test: PASS'
  $script:ForgeStepNames += $Name; $script:ForgeStepStatus += 'PASS'
  return $true
}
function Skip-ForgeStep($Name) {
  $script:ForgeStepI++
  Write-Host ''
  Write-Host ("[{0}/{1}] {2}" -f $script:ForgeStepI, $script:ForgeStepN, $Name)
  Write-Host '  skipped (not in profile scope)'
  $script:ForgeStepNames += $Name; $script:ForgeStepStatus += 'SKIP'
}
function Show-ForgeSummary {
  Write-Host ''
  Write-Host '================================'
  Write-Host 'OpenCode Forge Installation'
  Write-Host '================================'
  for ($i = 0; $i -lt $script:ForgeStepNames.Count; $i++) {
    Write-Host ("{0,-16} {1}" -f $script:ForgeStepNames[$i], $script:ForgeStepStatus[$i])
  }
  Write-Host ''
  if ($script:ForgeStepFail -eq 0) { Write-Host 'Result: SUCCESS'; return $true }
  Write-Host 'Result: FAILURE (see FAIL rows above)'
  return $false
}
function Stop-ForgeStep($Message) {
  if ($script:ForgeStepN -gt 0) { Show-ForgeSummary | Out-Null }
  throw $Message
}
Export-ModuleMember -Function Set-ForgeStepTotal, Invoke-ForgeStep, Skip-ForgeStep, Show-ForgeSummary, Stop-ForgeStep
