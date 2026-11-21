# Builds platform icons from the PNG masters rendered by tool/render_icon_test.dart.
# Uses only Windows' built-in System.Drawing (no third-party tools).
#   flutter test tool/render_icon_test.dart
#   powershell -ExecutionPolicy Bypass -File tool/make_icons.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$master = Join-Path $root 'assets\icon\tachyo_icon.png'
$fg = Join-Path $root 'assets\icon\tachyo_foreground.png'

function Resize-Png([string]$src, [string]$dst, [int]$size) {
  $img = [System.Drawing.Image]::FromFile($src)
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($img, 0, 0, $size, $size)
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  $bmp.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose(); $img.Dispose()
}

# Android legacy launcher icons + adaptive foreground.
$res = Join-Path $root 'android\app\src\main\res'
$densities = @{ 'mdpi' = 1; 'hdpi' = 1.5; 'xhdpi' = 2; 'xxhdpi' = 3; 'xxxhdpi' = 4 }
foreach ($d in $densities.Keys) {
  $s = $densities[$d]
  Resize-Png $master (Join-Path $res "mipmap-$d\ic_launcher.png") ([int](48 * $s))
  Resize-Png $fg (Join-Path $res "mipmap-$d\ic_launcher_foreground.png") ([int](108 * $s))
}
$any = Join-Path $res 'mipmap-anydpi-v26'
New-Item -ItemType Directory -Force $any | Out-Null
@'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'@ | Set-Content -Encoding utf8 (Join-Path $any 'ic_launcher.xml')
$values = Join-Path $res 'values'
@'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1B1B1B</color>
</resources>
'@ | Set-Content -Encoding utf8 (Join-Path $values 'ic_launcher_background.xml')

# Windows .ico with PNG-compressed entries (Vista+ format).
$sizes = 16, 20, 24, 32, 40, 48, 64, 128, 256
$tmp = Join-Path $env:TEMP 'tachyo_ico'
New-Item -ItemType Directory -Force $tmp | Out-Null
$pngs = foreach ($s in $sizes) { $p = Join-Path $tmp "$s.png"; Resize-Png $master $p $s; ,[System.IO.File]::ReadAllBytes($p) }
$ico = Join-Path $root 'windows\runner\resources\app_icon.ico'
$ms = New-Object System.IO.MemoryStream
$w = New-Object System.IO.BinaryWriter $ms
$w.Write([UInt16]0); $w.Write([UInt16]1); $w.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $s = $sizes[$i]; $len = $pngs[$i].Length
  $b = if ($s -ge 256) { 0 } else { $s }
  $w.Write([byte]$b); $w.Write([byte]$b); $w.Write([byte]0); $w.Write([byte]0)
  $w.Write([UInt16]1); $w.Write([UInt16]32); $w.Write([UInt32]$len); $w.Write([UInt32]$offset)
  $offset += $len
}
foreach ($p in $pngs) { $w.Write($p) }
[System.IO.File]::WriteAllBytes($ico, $ms.ToArray())
$w.Dispose()
Remove-Item -Recurse -Force $tmp
Write-Output "Icons written: Android mipmaps, adaptive icon, $ico"
