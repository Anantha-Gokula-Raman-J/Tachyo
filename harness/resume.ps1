# Prints where the project stands: checkpoint, specs, toolchain, devices.
# Usage: powershell -ExecutionPolicy Bypass -File harness/resume.ps1
$root = Split-Path -Parent $PSScriptRoot
Write-Output "== Tachyo - Net Speed Meter =="
Write-Output "Root: $root"
Write-Output ""
Write-Output "== RESUME.md (checkpoint) =="
Get-Content (Join-Path $root 'RESUME.md') -TotalCount 40
Write-Output ""
Write-Output "== Specs =="
Get-ChildItem (Join-Path $root 'specs') -Recurse -Filter *.md | ForEach-Object {
  $lines = (Get-Content $_.FullName | Measure-Object -Line).Lines
  $flag = if ($lines -gt 600) { '  <-- OVER 600 LINES' } else { '' }
  '{0,-45} {1,4} lines{2}' -f $_.FullName.Substring($root.Length + 1), $lines, $flag
}
Write-Output ""
Write-Output "== Toolchain =="
flutter --version 2>$null | Select-Object -First 1
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (Test-Path $adb) { & $adb devices } else { Write-Output 'adb not found' }
Write-Output ""
Write-Output "Next: harness/context.ps1 -Feature <ID>  (IDs in specs/INDEX.md)"
