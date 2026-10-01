# MCP.psm1 — optional servers enabled only on explicit profile choice.
function Get-ForgeMcpStatus {
  try {
    $out = (opencode mcp list 2>&1) -join "`n"
    return $out
  } catch { return 'opencode mcp list unavailable' }
}
Export-ModuleMember -Function Get-ForgeMcpStatus
