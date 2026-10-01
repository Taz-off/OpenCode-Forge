# bootstrap.ps1 — single-command entry point (run from GitHub release).
# Usage (after the 0.1.0 release exists):
#   irm https://github.com/Taz-off/OpenCode-Forge/releases/latest/download/bootstrap.ps1 | iex
param([string]$Owner = 'Taz-off', [string]$Repo = 'OpenCode-Forge')
$ErrorActionPreference = 'Stop'
$api = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
try {
  $rel = Invoke-RestMethod -Uri $api -TimeoutSec 30
  $zip = ($rel.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1).browser_download_url
  if (-not $zip) { $zip = $rel.zipball_url }
  Write-Host ("OpenCode Forge {0} - downloading..." -f $rel.tag_name)
} catch {
  Write-Warning 'No stable release found (or network blocked). Falling back to main branch zip.'
  $zip = "https://github.com/$Owner/$Repo/archive/refs/heads/main.zip"
}
$tmp = Join-Path $env:TEMP ("opencode-forge-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$file = Join-Path $tmp 'forge.zip'
Invoke-WebRequest -Uri $zip -OutFile $file -TimeoutSec 120
Expand-Archive $file -DestinationPath (Join-Path $tmp 'src') -Force
$installer = Get-ChildItem (Join-Path $tmp 'src') -Recurse -Filter 'install.ps1' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'installer' } | Select-Object -First 1
if (-not $installer) { Write-Error 'installer/install.ps1 not found in archive.'; exit 1 }
Write-Host ("Running: {0}" -f $installer.FullName)
& $installer.FullName
