# syntax-check.ps1 — parse all PowerShell files + validate JSON files.
$Root = Split-Path $PSScriptRoot
$err = 0
foreach ($f in Get-ChildItem $Root -Recurse -Include @('*.ps1', '*.psm1') | Where-Object { $_.FullName -notmatch '\\.git\\' }) {
  $tokens = $null; $errors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
  if ($errors.Count -gt 0) { Write-Host ("SYNTAX FAIL: {0}" -f $f.FullName); $errors | ForEach-Object { Write-Host $_.Message }; $err++ }
  else { Write-Host ("OK: {0}" -f $f.Name) }
}
foreach ($f in Get-ChildItem $Root -Recurse -Include @('*.json') | Where-Object { $_.FullName -notmatch '\\.git\\' }) {
  try { Get-Content $f.FullName -Raw | ConvertFrom-Json | Out-Null; Write-Host ("JSON OK: {0}" -f $f.Name) }
  catch { Write-Host ("JSON FAIL: {0}" -f $f.FullName); $err++ }
}
if ($err -gt 0) { Write-Error "$err file(s) invalid."; exit 1 }
Write-Host 'syntax-check: all files valid.'
