@echo off
rem SPDX-License-Identifier: AGPL-3.0-or-later
rem Copyright (c) 2026 Kiril Tsanov (KikoTs)
rem
rem AOSPatches one-click installer for Ace of Spades on Steam (app 224540).
rem Double-click this file. It downloads install.ps1 from the latest AOSPatches
rem release over HTTPS into %TEMP%, runs it with Windows PowerShell and keeps
rem this window open at the end.
rem
rem Any arguments are passed on to install.ps1, for example:
rem   AOSPatches-Installer.cmd -Uninstall
rem   AOSPatches-Installer.cmd -GameDir "D:\Steam\steamapps\common\aceofspades"
rem The AOSPATCHES_GAMEDIR environment variable also selects the game folder.
rem AOSPATCHES_SCRIPT may name a local install.ps1 to run instead (testing).
rem
rem Paths are only ever handed to PowerShell through environment variables, so
rem folders with spaces, apostrophes or non-English letters work.

setlocal EnableExtensions DisableDelayedExpansion
title AOSPatches installer

echo.
echo  AOSPatches installer for Ace of Spades on Steam
echo  ===============================================
echo.

where powershell.exe >nul 2>nul
if errorlevel 1 goto :no_powershell

set "AOSP_URL=https://github.com/KikoTs/AOSPatches/releases/latest/download/install.ps1"
set "AOSP_PS1=%TEMP%\AOSPatches-install-%RANDOM%%RANDOM%.ps1"

if defined AOSPATCHES_SCRIPT goto :use_local

echo  Downloading the installer script...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }; try { Invoke-WebRequest -UseBasicParsing -Uri $env:AOSP_URL -OutFile $env:AOSP_PS1 -UserAgent 'AOSPatches-installer' } catch { Write-Host ('  ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }"
if errorlevel 1 goto :download_failed
goto :run

:use_local
echo  Using the local installer script from AOSPATCHES_SCRIPT.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath $env:AOSPATCHES_SCRIPT -Destination $env:AOSP_PS1 -Force"
if errorlevel 1 goto :download_failed

:run
if not exist "%AOSP_PS1%" goto :download_failed
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%AOSP_PS1%" %*
set "AOSP_RESULT=%ERRORLEVEL%"
del /q "%AOSP_PS1%" >nul 2>nul

echo.
if "%AOSP_RESULT%"=="0" goto :success
if "%AOSP_RESULT%"=="2" goto :cancelled
goto :failed

:success
echo  ------------------------------------------------------------
echo   SUCCESS. All done. Start Ace of Spades from Steam as usual.
echo   Run this file again any time to update or uninstall.
echo  ------------------------------------------------------------
set "AOSP_EXIT=0"
goto :end

:cancelled
echo  ------------------------------------------------------------
echo   Cancelled. Nothing was changed.
echo  ------------------------------------------------------------
set "AOSP_EXIT=2"
goto :end

:failed
echo  ------------------------------------------------------------
echo   FAILED (code %AOSP_RESULT%). See the messages above.
echo   Help: https://github.com/KikoTs/AOSPatches/issues
echo  ------------------------------------------------------------
set "AOSP_EXIT=1"
goto :end

:download_failed
del /q "%AOSP_PS1%" >nul 2>nul
echo.
echo  ------------------------------------------------------------
echo   FAILED: could not download the installer script.
echo   Check your internet connection and try again, or download
echo   AOSPatches.zip by hand from:
echo   https://github.com/KikoTs/AOSPatches/releases/latest
echo  ------------------------------------------------------------
set "AOSP_EXIT=1"
goto :end

:no_powershell
echo  ------------------------------------------------------------
echo   FAILED: Windows PowerShell was not found on this PC.
echo   Download AOSPatches.zip by hand from:
echo   https://github.com/KikoTs/AOSPatches/releases/latest
echo  ------------------------------------------------------------
set "AOSP_EXIT=1"
goto :end

:end
echo.
pause
endlocal & exit /b %AOSP_EXIT%
