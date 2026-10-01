# secret-scan.ps1 — fail if a real secret is tracked. Generic examples allowed.
$Root = Split-Path $PSScriptRoot
$patterns = @('Bearer eyJ', 'C:\\Users\\laszlo', 'C:/Users/laszlo', '100\.100\.119\.122', 'api_key\s*=\s*[''"][^*]', 'password\s*=\s*[''"][^*]')
$bad = @()
foreach ($f in Get-ChildItem $Root -Recurse -File -Include @('*.json', '*.jsonc', '*.md', '*.ps1', '*.psm1', '*.example') | Where-Object { $_.FullName -notmatch '\\.git\\' -and $_.Name -ne 'secret-scan.ps1' }) {
  $text = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
  foreach ($p in $patterns) {
    if ($text -match $p) {
      # Allow documented placeholders and masked values
      $lines = (Get-Content $f.FullName) | Where-Object { $_ -match $p -and $_ -notmatch 'MASQUE|<OWNER>|local-no-key-needed|HOMEASSISTANT_TOKEN=$|example|__HOME__' }
      if ($lines) { $bad += ("{0}: {1}" -f $f.FullName, $p) }
    }
  }
}
# Never allow a real .env with values
foreach ($f in Get-ChildItem $Root -Recurse -File -Filter '.env' | Where-Object { $_.FullName -notmatch '\\.git\\' }) { $bad += $f.FullName }
if ($bad.Count -gt 0) { Write-Error ("Secrets suspected:`n" + ($bad -join "`n")); exit 1 }
Write-Host 'secret-scan: OK (no real secrets found)'
