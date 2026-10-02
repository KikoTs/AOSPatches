# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (c) 2026 Kiril Tsanov (KikoTs)
param(
    [string]$OutputDirectory = "$PSScriptRoot/../../build/loader-output",
    [string]$BuildDirectory = "$PSScriptRoot/../../build/loader"
)
$ErrorActionPreference = 'Stop'
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$build = [IO.Path]::GetFullPath($BuildDirectory)
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vs) { throw 'Visual Studio C++ x86/x64 build tools are required.' }
New-Item -ItemType Directory -Path $build, $OutputDirectory -Force | Out-Null
$bootstrap = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'bootstrap.py'))
$header = 'static const char kBootstrap[] = R"AOSBOOT(' + $bootstrap + ')AOSBOOT";'
[IO.File]::WriteAllText((Join-Path $build 'generated_bootstrap.h'), $header, [Text.UTF8Encoding]::new($false))
$devcmd = Join-Path $vs 'Common7/Tools/VsDevCmd.bat'
$buildCmd = Join-Path $build 'compile.cmd'
$content = @"
@echo off
rem VsDevCmd can print harmless lookup noise on stderr; failures still set errorlevel.
call "$devcmd" -no_logo -arch=x86 -host_arch=x64 2>nul
if errorlevel 1 exit /b %errorlevel%
cd /d "$build"
cl /nologo /Brepro /LD /MT /O2 /W4 /WX /EHsc /std:c++17 /I"$build" /I"$PSScriptRoot" "$PSScriptRoot/loader.cpp" /link /DEF:"$PSScriptRoot/winmm.def" /OUT:"$OutputDirectory/winmm.dll" /IMPLIB:"$build/winmm.lib" /DYNAMICBASE /NXCOMPAT /MACHINE:X86 /Brepro
exit /b %errorlevel%
"@
[IO.File]::WriteAllText($buildCmd, $content, [Text.ASCIIEncoding]::new())
& $buildCmd
if ($LASTEXITCODE -ne 0) { throw 'Loader compilation failed.' }
