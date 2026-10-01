# probe-mem.ps1 — run real Install-ForgeMemoryApp in mock env, visible output.
$Root = 'C:/Users/Laszl/OneDrive/projet laszlo/opencode/projects/OpenCode-Forge'
Import-Module "$Root/modules/Software.psm1" -Force
Import-Module "$Root/modules/Winget.psm1" -Force
Import-Module "$Root/modules/Verify.psm1" -Force
Write-Host ("UV-WHICH: " + (Get-Command uv -ErrorAction SilentlyContinue).Source)
Write-Host ("MOCKBIN: " + $env:MOCKBIN)
& uv tool install openviking
Write-Host "direct-uv-done"
Get-ChildItem $env:MOCKBIN | Format-Table Name
$r = Install-ForgeMemoryApp
Write-Host "MEM-RESULT: $r"
