# Software.psm1 — detect tools without installing anything.
# Uses System.Diagnostics.Process with a timeout (never PowerShell jobs:
# jobs depend on a real user profile store and hang the installer otherwise).
function Invoke-ForgeTool($Path, $ToolArgs, $TimeoutMs = 30000) {
  try {
    $ext = ([System.IO.Path]::GetExtension($Path)).ToLower()
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($ext -eq '.ps1') {
      $psi.FileName = 'powershell'
      $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -Command "& ''' + $Path + ''' ' + ($ToolArgs -join ' ') + '"'
    } elseif ($ext -eq '.cmd' -or $ext -eq '.bat') {
      $psi.FileName = 'cmd'
      $psi.Arguments = '/c ""' + $Path + '" ' + ($ToolArgs -join ' ') + '"'
    } else {
      $psi.FileName = $Path
      $psi.Arguments = ($ToolArgs -join ' ')
    }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    if (-not $p.WaitForExit($TimeoutMs)) { try { $p.Kill() } catch { }; return $null }
    $out = $p.StandardOutput.ReadToEnd()
    $line = ("$out" -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
    if ($line) { return $line.Trim() }
    return $null
  } catch { return $null }
}
function Get-ForgeCommandVersion($Name, $ToolArgs) {
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) { return $null }
  return (Invoke-ForgeTool $cmd.Source $ToolArgs)
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
Export-ModuleMember -Function Get-ForgeSoftware, Get-ForgeCommandVersion, Invoke-ForgeTool
