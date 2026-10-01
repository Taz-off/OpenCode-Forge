# Software.psm1 — detect tools without installing anything.
function Get-ForgeCommandVersion($Name, $Args) {
  try {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }
    $out = & $cmd.Source @Args 2>&1 | Select-Object -First 1
    return "$out".Trim()
  } catch { return $null }
}
function Get-ForgeSoftware {
  return [pscustomobject]@{
    OpenCode = (Get-ForgeCommandVersion 'opencode' @('--version'))
    Node     = (Get-ForgeCommandVersion 'node' @('--version'))
    Npm      = (Get-ForgeCommandVersion 'npm' @('--version'))
    Ollama   = (Get-ForgeCommandVersion 'ollama' @('--version'))
    Uv       = (Get-ForgeCommandVersion 'uv' @('--version'))
    Git      = (Get-ForgeCommandVersion 'git' @('--version'))
    Gh       = (Get-ForgeCommandVersion 'gh' @('--version'))
    Tsx      = [bool](Get-Command 'tsx' -ErrorAction SilentlyContinue)
  }
}
Export-ModuleMember -Function Get-ForgeSoftware, Get-ForgeCommandVersion
