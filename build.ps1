# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (c) 2026 Kiril Tsanov (KikoTs)
# Build the runtime files into dist/, then package the release assets into out/.
[CmdletBinding()]
param(
    [string]$SteamSdk = $env:STEAMWORKS_SDK,
    [string]$Version = 'dev',
    [switch]$FixesOnly
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath($PSScriptRoot)
if (-not $FixesOnly) {
    if (-not $SteamSdk) { throw 'Pass -SteamSdk C:\path\steamworks_sdk, set STEAMWORKS_SDK, or use -FixesOnly.' }
    $SteamSdk = [IO.Path]::GetFullPath($SteamSdk)
    foreach ($file in @('public/steam/steam_api.h', 'redistributable_bin/win64/steam_api64.lib', 'redistributable_bin/win64/steam_api64.dll')) {
        if (-not (Test-Path -LiteralPath (Join-Path $SteamSdk $file))) { throw "Missing Steamworks SDK file: $file" }
    }
}
$scratch = Join-Path $root ('build/package-' + [Guid]::NewGuid().ToString('N'))
$stage = Join-Path $scratch 'runtime'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
& (Join-Path $root 'src/retail/build.ps1') -OutputDirectory $stage -BuildDirectory (Join-Path $scratch 'loader')
$scripts = @('aosfix_runtime.py', 'aos_mousefix.py', 'aos_equipmentfix.py', 'aos_uifix.py', 'aos_movementfix.py')
if (-not $FixesOnly) {
    $scripts += @('aos_networkfix.py', 'aos_steam_bridge.py')
    & (Join-Path $root 'src/relay/build.ps1') -SteamSdk $SteamSdk -OutputDirectory (Join-Path $stage 'relay') -BuildDirectory (Join-Path $scratch 'relay')
}
foreach ($name in $scripts) {
    Copy-Item -LiteralPath (Join-Path $root "src/retail/$name") -Destination (Join-Path $stage $name)
}
# Name the exact source revision in the shipped notices.
$revision = $null
try { $revision = (& git -C $root rev-parse HEAD 2>$null) } catch { $revision = $null }
if (-not $revision) { $revision = $env:GITHUB_SHA }
if (-not $revision) { $revision = 'main' }
# Keep the runtime ZIP self-contained for licensing without extra install files.
# These inert UTF-8 comments include the full license, permissions and notices.
$runtime = Join-Path $stage 'aosfix_runtime.py'
$contents = "# -*- coding: utf-8 -*-`n" + [IO.File]::ReadAllText($runtime)
$contents += "`n# BEGIN AOSPATCHES DISTRIBUTION NOTICES`n# AOSPatches version: $Version`n"
$contents += "# Corresponding source: https://github.com/KikoTs/AOSPatches/tree/$revision`n"
foreach ($name in @('LICENSE', 'LICENSING.md', 'THIRD_PARTY_NOTICES.md', 'licenses/LICENSE-Revival.txt')) {
    $contents += "# --- $name ---`n"
    foreach ($line in ([IO.File]::ReadAllText((Join-Path $root $name)) -split '\r?\n')) {
        $contents += if ($line.Length) { "# $line`n" } else { "#`n" }
    }
}
$contents += "# END AOSPATCHES DISTRIBUTION NOTICES`n"
[IO.File]::WriteAllText($runtime, $contents, (New-Object Text.UTF8Encoding $false))
# Compile products stay in build/. Replace only this repository's own dist/.
$dist = Join-Path $root 'dist'
if (Test-Path -LiteralPath $dist) {
    $item = Get-Item -LiteralPath $dist -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
        (Resolve-Path -LiteralPath $dist).Path -ne [IO.Path]::GetFullPath($dist) -or
        [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($dist)) -ne $root) {
        throw 'Refusing to replace an unexpected dist path.'
    }
    Remove-Item -LiteralPath $dist -Recurse -Force
}
Move-Item -LiteralPath $stage -Destination $dist
& (Join-Path $root 'package.ps1') -Version $Version
Write-Output 'Ready: dist/ holds the drag-and-drop runtime files; out/ holds the release assets.'
