# Skills.psm1 — copy skill folders idempotently (project-thinking full, others as stubs).
function Install-ForgeSkills($SkillsSrc, $SkillNames) {
  Import-Module "$PSScriptRoot/State.psm1" -Force
  $dest = Join-Path (Get-ForgeHome) '.config/opencode/skills'
  if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }
  foreach ($s in $SkillNames) {
    $src = Join-Path $SkillsSrc $s
    $target = Join-Path $dest $s
    if (Test-Path $src) {
      if (-not (Test-Path $target)) { New-Item -ItemType Directory -Force -Path $target | Out-Null }
      Copy-Item (Join-Path $src '*') $target -Recurse -Force
    } else {
      if (-not (Test-Path $target)) { New-Item -ItemType Directory -Force -Path $target | Out-Null }
      if (-not (Test-Path (Join-Path $target 'SKILL.md'))) {
        "# $s`n`nStub installed by OpenCode Forge. See skills/README.md." | Set-Content (Join-Path $target 'SKILL.md') -Encoding UTF8
      }
    }
  }
}
Export-ModuleMember -Function Install-ForgeSkills
