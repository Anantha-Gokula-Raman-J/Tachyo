# Drives the running Tachyo Windows build for smoke tests: click at a point
# relative to the Tachyo window, then save a screenshot of the window.
#   tool/win_drive.ps1 -Shot live
#   tool/win_drive.ps1 -ClickX 452 -ClickY 915 -Shot settings
# Coordinates are physical pixels relative to the window's top-left corner.
param([int]$ClickX = -1, [int]$ClickY = -1, [string]$Shot = '', [string]$OutDir = "$env:TEMP\tachyo_shots", [switch]$Close)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('TachyoWin' -as [type])) {
  Add-Type @"
using System; using System.Runtime.InteropServices;
public class TachyoWin {
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(int f, int x, int y, int d, int e);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr FindWindow(string c, string t);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  public struct RECT { public int L, T, R, B; }
  public static void Click(int x, int y) { SetCursorPos(x, y); mouse_event(2,0,0,0,0); System.Threading.Thread.Sleep(60); mouse_event(4,0,0,0,0); }
}
"@
}
[TachyoWin]::SetProcessDPIAware() | Out-Null
$hwnd = [TachyoWin]::FindWindow('FLUTTER_RUNNER_WIN32_WINDOW', 'Tachyo')
if ($hwnd -eq [IntPtr]::Zero) { throw 'Tachyo window not found' }

function Get-TachyoRect { $r = New-Object TachyoWin+RECT; [TachyoWin]::GetWindowRect($hwnd, [ref]$r) | Out-Null; $r }

if ($Close) { [TachyoWin]::PostMessage($hwnd, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null; Start-Sleep 1 }
if ($ClickX -ge 0) {
  $r = Get-TachyoRect
  if (($r.R - $r.L) -le $ClickX -or ($r.B - $r.T) -le $ClickY) { throw "Click ($ClickX,$ClickY) is outside the window" }
  [TachyoWin]::SetForegroundWindow($hwnd) | Out-Null
  Start-Sleep -Milliseconds 300
  [TachyoWin]::Click($r.L + $ClickX, $r.T + $ClickY)
  Start-Sleep -Milliseconds 1500
}
$r = Get-TachyoRect
"visible=$([TachyoWin]::IsWindowVisible($hwnd)) rect=$($r.L),$($r.T) size=$($r.R - $r.L)x$($r.B - $r.T)"
if ($Shot -and [TachyoWin]::IsWindowVisible($hwnd)) {
  New-Item -ItemType Directory -Force $OutDir | Out-Null
  $w = $r.R - $r.L; $h = $r.B - $r.T
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
  $path = Join-Path $OutDir "$Shot.png"
  $bmp.Save($path); $g.Dispose(); $bmp.Dispose()
  "shot=$path"
}
