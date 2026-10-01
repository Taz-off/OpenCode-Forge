# probe-install.ps1 — replicate e2e child env exactly, show resolution.
Write-Host ("PATH-HEAD: " + (($env:PATH -split ';' | Select-Object -First 2) -join '|'))
Write-Host ("WINGET: " + (Get-Command winget -ErrorAction SilentlyContinue).Source)
Write-Host ("MOCKBIN-ENV: " + $env:MOCKBIN)
