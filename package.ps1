# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (c) 2026 Kiril Tsanov (KikoTs)
# Repackage an already-built dist/ without including source, docs or intermediates.
$ErrorActionPreference = 'Stop'
$dist = Join-Path $PSScriptRoot 'dist'
$files = @('winmm.dll', 'aosfix_runtime.py', 'aos_mousefix.py', 'aos_equipmentfix.py', 'aos_uifix.py', 'aos_movementfix.py')
$optional = @('aos_networkfix.py', 'aos_steam_bridge.py', 'relay/aos-retail-relay.exe', 'relay/steam_api64.dll')
if ($optional | Where-Object { Test-Path -LiteralPath (Join-Path $dist $_) }) { $files += $optional }
foreach ($name in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $dist $name) -PathType Leaf)) { throw "Missing runtime file: $name. Run build.ps1 first." }
}
$actual = @(Get-ChildItem -LiteralPath $dist -File -Recurse -Force | ForEach-Object { $_.FullName.Substring($dist.Length + 1).Replace('\', '/') })
if (Compare-Object ($files | Sort-Object) ($actual | Sort-Object)) { throw 'dist/ contains unexpected files; rebuild before packaging.' }
if (-not ([IO.File]::ReadAllText((Join-Path $dist 'aosfix_runtime.py')).Contains('# BEGIN AOSPATCHES DISTRIBUTION NOTICES'))) {
    throw 'Distribution notices are missing; run build.ps1 before packaging.'
}
$build = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$candidate = Join-Path $build ('package-' + [Guid]::NewGuid().ToString('N') + '.zip')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($candidate, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($name in $files) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $dist $name), $name) | Out-Null
    }
} finally { $archive.Dispose() }
Move-Item -LiteralPath $candidate -Destination (Join-Path $PSScriptRoot 'AOSPatches.zip') -Force
Write-Output "Packaged $($files.Count) runtime files into AOSPatches.zip"
