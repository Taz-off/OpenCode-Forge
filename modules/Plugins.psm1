# Plugins.psm1 — plugins live in opencode.jsonc template; ensure step is idempotent check.
function Get-ForgePlugins($ConfigPath) {
  $text = Get-Content $ConfigPath -Raw
  $out = @()
  foreach ($p in @('opencode-dcp', 'plannotator', 'openviking', 'superpowers')) {
    $out += [pscustomobject]@{ Plugin = $p; Present = ($text -match $p) }
  }
  return $out
}
Export-ModuleMember -Function Get-ForgePlugins
