# Quality gate: analyze, unit/widget tests, spec size check, optional builds.
# Usage: harness/verify.ps1 [-Build]
param([switch]$Build)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
  flutter analyze
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
  flutter test
  if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
  $over = Get-ChildItem specs -Recurse -Filter *.md | Where-Object { (Get-Content $_.FullName | Measure-Object -Line).Lines -gt 600 }
  if ($over) { throw "Specs over 600 lines: $($over.Name -join ', ')" }
  # License policy: pubspec may only depend on the Flutter SDK unless a package is MIT/Apache and listed.
  $deps = Select-String -Path pubspec.yaml -Pattern '^\s{2}[a-z_]+:\s*\^' | ForEach-Object { $_.Line.Trim() } | Where-Object { $_ -notmatch '^sdk:' }
  if ($deps) { Write-Warning "pub packages present - confirm MIT/Apache and list in THIRD_PARTY_LICENSES.md: $deps" }
  if ($Build) {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { throw 'windows build failed' }
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'apk build failed' }
  }
  Write-Output 'VERIFY OK'
} finally { Pop-Location }
