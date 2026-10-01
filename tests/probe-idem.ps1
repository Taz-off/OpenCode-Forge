# probe-idem.ps1 — double install, byte diff of config.
$ForgeRoot = 'C:/Users/Laszl/OneDrive/projet laszlo/opencode/projects/OpenCode-Forge'
& powershell -NoProfile -ExecutionPolicy Bypass -File "$ForgeRoot/installer/install.ps1" -Profile minimal -Yes > "$env:TEMP/idem1.log" 2>&1
Copy-Item "$env:USERPROFILE/.config/opencode/opencode.jsonc" "$env:TEMP/jsonc1.txt"
& powershell -NoProfile -ExecutionPolicy Bypass -File "$ForgeRoot/installer/install.ps1" -Profile minimal -Yes > "$env:TEMP/idem2.log" 2>&1
Copy-Item "$env:USERPROFILE/.config/opencode/opencode.jsonc" "$env:TEMP/jsonc2.txt"
fc.exe /b "$env:TEMP/jsonc1.txt" "$env:TEMP/jsonc2.txt" | Select-Object -First 6
