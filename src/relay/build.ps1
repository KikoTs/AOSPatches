# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (c) 2026 Kiril Tsanov (KikoTs)
param(
    [Parameter(Mandatory=$true)][string]$SteamSdk,
    [string]$OutputDirectory = "$PSScriptRoot/../../build/relay-output",
    [string]$BuildDirectory = "$PSScriptRoot/../../build/relay",
    [switch]$TestLoopback
)
$ErrorActionPreference = 'Stop'
$SteamSdk = [IO.Path]::GetFullPath($SteamSdk)
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$build = [IO.Path]::GetFullPath($BuildDirectory)
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Visual Studio C++ x86/x64 build tools are required.' }
foreach ($file in @('public/steam/steam_api.h', 'redistributable_bin/win64/steam_api64.lib', 'redistributable_bin/win64/steam_api64.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $SteamSdk $file))) { throw "Missing Steamworks SDK file: $file" }
}
New-Item -ItemType Directory -Path $build, $OutputDirectory -Force | Out-Null
$devcmd = Join-Path $vs 'Common7/Tools/VsDevCmd.bat'
$testDefine = if ($TestLoopback) { '/DAOS_RELAY_LOOPBACK_TEST' } else { '' }
$executable = if ($TestLoopback) { 'aos-retail-relay-test.exe' } else { 'aos-retail-relay.exe' }
$content = @"
@echo off
call "$devcmd" -no_logo -arch=x64 -host_arch=x64
if errorlevel 1 exit /b %errorlevel%
cd /d "$build"
cl /nologo /MT /O2 /W4 /WX /EHsc /std:c++17 /D_CRT_SECURE_NO_WARNINGS /DWIN32_LEAN_AND_MEAN /DNOMINMAX $testDefine /I"$SteamSdk/public" "$PSScriptRoot/retail_relay.cpp" /link "$SteamSdk/redistributable_bin/win64/steam_api64.lib" ws2_32.lib /OUT:"$OutputDirectory/$executable" /DYNAMICBASE /NXCOMPAT
exit /b %errorlevel%
"@
$script = Join-Path $build 'compile.cmd'
[IO.File]::WriteAllText($script, $content, [Text.ASCIIEncoding]::new())
& $script
if ($LASTEXITCODE -ne 0) { throw 'Retail relay compilation failed.' }
Copy-Item -LiteralPath (Join-Path $SteamSdk 'redistributable_bin/win64/steam_api64.dll') -Destination $OutputDirectory -Force
