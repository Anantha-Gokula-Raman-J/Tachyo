# Android smoke test on the local emulator.
#   -Wipe     wipe emulator data and cold boot first (asks nothing; destroys emulator state)
#   -Avd      AVD name (default Medium_Phone)
#   -Reboot   also verify the status-bar meter restarts after reboot
# Steps: (wipe/boot) -> build APK -> install -> launch -> enable meter -> grant notifications
#        -> check foreground service + status-bar screenshot -> (reboot check)
param([switch]$Wipe, [string]$Avd = 'Medium_Phone', [switch]$Reboot, [string]$OutDir = "$env:TEMP\tachyo_android")
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$pkg = 'app.tachyo'
New-Item -ItemType Directory -Force $OutDir | Out-Null

function Wait-Boot {
  & $adb wait-for-device
  for ($i = 0; $i -lt 120; $i++) { if ((& $adb shell getprop sys.boot_completed 2>$null) -eq '1') { return }; Start-Sleep 2 }
  throw 'emulator did not boot'
}
function Save-Screen($name) {
  & $adb shell screencap -p /sdcard/t.png; & $adb pull /sdcard/t.png (Join-Path $OutDir "$name.png") | Out-Null
  "screenshot: $(Join-Path $OutDir "$name.png")"
}
function Get-UiNodes {
  & $adb shell uiautomator dump /sdcard/ui.xml | Out-Null
  & $adb shell cat /sdcard/ui.xml
}
function Test-ServiceRunning { (& $adb shell "dumpsys activity services $pkg | grep -c isForeground=true") -eq '1' }

if ($Wipe) {
  Start-Process (Join-Path $sdk 'emulator\emulator.exe') -ArgumentList @('-avd', $Avd, '-wipe-data', '-no-snapshot-load', '-no-boot-anim')
  Start-Sleep 5
}
Wait-Boot

Push-Location $root
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'apk build failed' }
Pop-Location
& $adb install -r (Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk')
& $adb shell monkey -p $pkg -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep 5
Save-Screen 'live'

if (-not (Test-ServiceRunning)) {
  # The meter switch is the last checkable node on the Live page.
  $xml = Get-UiNodes
  $m = [regex]::Matches($xml, 'checkable="true"[^>]*?bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"') | Select-Object -Last 1
  if (-not $m) { throw 'meter switch not found' }
  & $adb shell input tap (([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2) (([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2)
  Start-Sleep 2
  $xml = Get-UiNodes
  $allow = [regex]::Match($xml, 'text="Allow"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
  if ($allow.Success) {
    & $adb shell input tap (([int]$allow.Groups[1].Value + [int]$allow.Groups[3].Value) / 2) (([int]$allow.Groups[2].Value + [int]$allow.Groups[4].Value) / 2)
    Start-Sleep 3
  }
}
if (-not (Test-ServiceRunning)) { throw 'FAIL: meter service not running' }
Write-Output 'PASS: meter foreground service running'
& $adb shell input keyevent KEYCODE_HOME
Start-Sleep 3
Save-Screen 'statusbar'

if ($Reboot) {
  & $adb reboot
  Wait-Boot
  $ok = $false
  for ($i = 0; $i -lt 30 -and -not $ok; $i++) { Start-Sleep 4; $ok = Test-ServiceRunning }
  if (-not $ok) { throw 'FAIL: meter did not restart after reboot' }
  Write-Output 'PASS: meter restarted after reboot'
}
Write-Output 'ANDROID SMOKE OK'
