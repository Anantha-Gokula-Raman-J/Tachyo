# Prints the specs to read for a feature before touching source.
# Usage: harness/context.ps1 -Feature NSM-ANDROID   (IDs: specs/INDEX.md "Feature IDs")
param([Parameter(Mandatory = $true)][string]$Feature, [switch]$Full)
$root = Split-Path -Parent $PSScriptRoot
$map = @{
  'NSM-CORE'     = @('specs/core/common/README.md', 'specs/core/models.md', 'specs/core/format.md', 'specs/core/sampler.md')
  'NSM-USAGE'    = @('specs/data/common/README.md', 'specs/data/usage.md', 'specs/state/meter-controller.md')
  'NSM-SETTINGS' = @('specs/data/settings.md', 'specs/ui/pages.md')
  'NSM-ANDROID'  = @('specs/platform/common/README.md', 'specs/platform/channel.md', 'specs/platform/meter-platform.md', 'specs/platform/android-native.md')
  'NSM-WINDOWS'  = @('specs/platform/common/README.md', 'specs/platform/channel.md', 'specs/platform/meter-platform.md', 'specs/platform/windows-native.md')
  'NSM-UI'       = @('specs/ui/common/README.md', 'specs/ui/design-system.md', 'specs/ui/pages.md')
  'NSM-BRAND'    = @('specs/ui/branding.md')
  'NSM-SPEEDTEST' = @('specs/speedtest/common/README.md', 'specs/speedtest/engine.md', 'specs/speedtest/controller.md', 'specs/ui/pages.md')
}
$key = $Feature.ToUpperInvariant()
if (-not $map.ContainsKey($key)) { throw "Unknown feature '$Feature'. Known: $($map.Keys -join ', ')" }
Write-Output "Read in order (architecture -> specs -> only then the source ranges they name):"
Write-Output "  ARCHITECTURE.md"
foreach ($s in $map[$key]) {
  Write-Output "  $s"
  if ($Full) { Write-Output '----'; Get-Content (Join-Path $root $s); Write-Output '----' }
}
