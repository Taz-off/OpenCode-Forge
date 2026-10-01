# Hardware.psm1 — real detection, PS 5.1 + 7 compatible.
function Get-ForgeHardware {
  $cpu = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Name
  $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
  $ramGb = 0
  if ($cs -and $cs.TotalPhysicalMemory) { $ramGb = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1) }
  $gpus = @()
  $vramGb = 0
  try {
    $vc = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
    foreach ($v in $vc) {
      if (-not $v.Name) { continue }
      $gpus += $v.Name
      if ($v.AdapterRAM -and $v.AdapterRAM -gt 0 -and $v.AdapterRAM -lt 128GB) {
        $gb = [math]::Round($v.AdapterRAM / 1GB, 1)
        if ($gb -gt $vramGb) { $vramGb = $gb }
      }
    }
  } catch { }
  $disk = Get-PSDrive C -ErrorAction SilentlyContinue
  $freeGb = 0
  if ($disk -and $disk.Free) { $freeGb = [math]::Round($disk.Free / 1GB, 1) }
  $arch = $env:PROCESSOR_ARCHITECTURE
  return [pscustomobject]@{
    CPU = $cpu; RamGb = $ramGb; GPUs = $gpus; VramGb = $vramGb
    Arch = $arch; DiskFreeGb = $freeGb
  }
}
Export-ModuleMember -Function Get-ForgeHardware
