# GitHub.psm1 — fetch latest stable release manifest, network-safe.
function Get-ForgeLatestRelease($Owner, $Repo) {
  $url = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
  try {
    $r = Invoke-RestMethod -Uri $url -TimeoutSec 20 -ErrorAction Stop
    return [pscustomobject]@{ Tag = $r.tag_name; Url = $r.zipball_url; Name = $r.name }
  } catch {
    return $null
  }
}
function Get-ForgeRemoteManifest($ManifestUrl) {
  try {
    $m = Invoke-RestMethod -Uri $ManifestUrl -TimeoutSec 20 -ErrorAction Stop
    return $m
  } catch { return $null }
}
Export-ModuleMember -Function Get-ForgeLatestRelease, Get-ForgeRemoteManifest
