# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (c) 2026 Kiril Tsanov (KikoTs)
# Package an already-built dist/ into the release assets in out/:
#   AOSPatches-<version>.zip, AOSPatches.zip (same bytes), install.ps1, SHA256SUMS
# Source, docs and intermediates are never included. Entries use a fixed order
# and timestamp, so the same dist/ always produces the same ZIP bytes.
[CmdletBinding()]
param(
    [string]$Version = 'dev'
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($PSScriptRoot)
$dist = Join-Path $root 'dist'
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
if ($Version -notmatch '^[0-9A-Za-z][0-9A-Za-z.+-]*$') { throw "Invalid version: $Version" }

# Fixed entry time: SOURCE_DATE_EPOCH, else the commit time, else 2026-01-01.
$epoch = $env:SOURCE_DATE_EPOCH
if (-not $epoch) {
    try { $epoch = (& git -C $root log -1 --format=%ct 2>$null) } catch { $epoch = $null }
}
$stamp = if ($epoch) { [DateTimeOffset]::FromUnixTimeSeconds([long]$epoch) } else { New-Object DateTimeOffset 2026, 1, 1, 0, 0, 0, ([TimeSpan]::Zero) }
# DOS timestamps have two-second resolution and no zone; keep it explicit.
$stamp = New-Object DateTimeOffset $stamp.Year, $stamp.Month, $stamp.Day, $stamp.Hour, $stamp.Minute, ($stamp.Second - $stamp.Second % 2), ([TimeSpan]::Zero)

$out = Join-Path $root 'out'
if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Recurse -Force }
New-Item -ItemType Directory -Path $out -Force | Out-Null
$versioned = Join-Path $out "AOSPatches-$Version.zip"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($versioned, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($name in $files) {
        $entry = $archive.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = $stamp
        $target = $entry.Open()
        $source = [IO.File]::OpenRead((Join-Path $dist $name))
        try { $source.CopyTo($target) } finally { $source.Dispose(); $target.Dispose() }
    }
} finally { $archive.Dispose() }

# Verify the archive lists exactly the runtime files with identical bytes.
$check = [IO.Compression.ZipFile]::OpenRead($versioned)
try {
    $names = @($check.Entries | ForEach-Object { $_.FullName })
    if (Compare-Object $files $names -SyncWindow 0) { throw 'ZIP entries do not match dist/.' }
    $sha = [Security.Cryptography.SHA256]::Create()
    foreach ($entry in $check.Entries) {
        $stream = $entry.Open()
        try { $inZip = [BitConverter]::ToString($sha.ComputeHash($stream)) } finally { $stream.Dispose() }
        $onDisk = [BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes((Join-Path $dist $entry.FullName))))
        if ($inZip -ne $onDisk) { throw "ZIP entry differs from dist/: $($entry.FullName)" }
    }
} finally { $check.Dispose() }

Copy-Item -LiteralPath $versioned -Destination (Join-Path $out 'AOSPatches.zip')
Copy-Item -LiteralPath (Join-Path $root 'install.ps1') -Destination (Join-Path $out 'install.ps1')
$sums = foreach ($name in @("AOSPatches-$Version.zip", 'AOSPatches.zip', 'install.ps1')) {
    '{0}  {1}' -f (Get-FileHash -LiteralPath (Join-Path $out $name) -Algorithm SHA256).Hash.ToLowerInvariant(), $name
}
[IO.File]::WriteAllText((Join-Path $out 'SHA256SUMS'), (($sums -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
Write-Output "Packaged $($files.Count) runtime files into out/AOSPatches-$Version.zip"
Get-Content -LiteralPath (Join-Path $out 'SHA256SUMS')
