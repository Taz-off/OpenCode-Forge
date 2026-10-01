# probe-child.ps1 — check env inheritance into child powershell.
$first3 = ($env:PATH -split ';' | Select-Object -First 3) -join '|'
Write-Host "CHILD-PATH-HEAD: $first3"
Write-Host ("CHILD-WINGET: " + (Get-Command winget -ErrorAction SilentlyContinue).Source)
Write-Host ("CHILD-MOCKBIN: " + $env:MOCKBIN)
