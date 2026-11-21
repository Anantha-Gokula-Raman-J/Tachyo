# Tachyo window checks through UI Automation (no compiled helpers, so it also
# works where Add-Type compilation is blocked).
#   tool/win_check.ps1                 -> report main + floating windows
#   tool/win_check.ps1 -CloseMain      -> close the main window (WM_CLOSE) first
#   tool/win_check.ps1 -Shot file.png  -> also save a 2x crop around the floating meter
param([switch]$CloseMain, [string]$Shot = '')
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing
$root = [System.Windows.Automation.AutomationElement]::RootElement
function Find-Win([string]$cls) {
  $c = New-Object System.Windows.Automation.PropertyCondition ([System.Windows.Automation.AutomationElement]::ClassNameProperty), $cls
  $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $c)
}
$main = Find-Win 'FLUTTER_RUNNER_WIN32_WINDOW'
if ($CloseMain -and $main) {
  $main.GetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern).Close(); Start-Sleep 2
  $main = Find-Win 'FLUTTER_RUNNER_WIN32_WINDOW'
}
$fl = Find-Win 'TachyoFloatingMeter'
"processes=$(@(Get-Process tachyo -EA SilentlyContinue).Count) mainWindowShown=$([bool]$main)"
if (-not $fl) { 'floating=not shown'; return }
$r = $fl.Current.BoundingRectangle
"floating shown size=$([int]$r.Width)x$([int]$r.Height) at=$([int]$r.X),$([int]$r.Y)"
if ($Shot) {
  $pad = 50
  $w = [int]$r.Width + 2 * $pad; $h = [int]$r.Height + 2 * $pad
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen([int]$r.X - $pad, [int]$r.Y - $pad, 0, 0, $bmp.Size); $g.Dispose()
  $big = New-Object System.Drawing.Bitmap ($w * 2), ($h * 2)
  $g2 = [System.Drawing.Graphics]::FromImage($big)
  $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g2.DrawImage($bmp, 0, 0, $w * 2, $h * 2); $g2.Dispose()
  $big.Save($Shot); $bmp.Dispose(); $big.Dispose(); "shot=$Shot"
}
