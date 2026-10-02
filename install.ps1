# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (c) 2026 Kiril Tsanov (KikoTs)
<#
.SYNOPSIS
    Installs or removes AOSPatches for the original Steam Ace of Spades
    (app 224540).

.DESCRIPTION
    Finds the Steam game folder, asks once before changing anything, downloads
    the latest release, checks its SHA-256 against the release's checksum file,
    backs up every file it will replace, then copies the new files in.
    -Uninstall puts every replaced file back and deletes the files the install
    added. Run again on a patched game, it offers update or uninstall.

    Easiest: download AOSPatches-Installer.cmd from the latest release and
    double-click it. It downloads and runs this script.

    One-line install (Windows PowerShell 5.1 or newer):
        irm https://github.com/KikoTs/AOSPatches/releases/latest/download/install.ps1 | iex

    With options:
        & ([scriptblock]::Create((irm https://github.com/KikoTs/AOSPatches/releases/latest/download/install.ps1))) -Uninstall

.PARAMETER GameDir
    The Ace of Spades folder (the one containing aos.exe). Found automatically
    from Steam when omitted. The AOSPATCHES_GAMEDIR environment variable is
    used when this is not given.

.PARAMETER Uninstall
    Restore the backup made by the last install and remove what it added.

.PARAMETER Yes
    Do not ask questions; use the default answer for each one.

.PARAMETER PackagePath
    Install from a local ZIP instead of downloading it.

.PARAMETER ChecksumPath
    A SHA256SUMS file to verify -PackagePath against.
#>
[CmdletBinding()]
param(
    [string]$GameDir,
    [switch]$Uninstall,
    [switch]$Yes,
    [string]$PackagePath,
    [string]$ChecksumPath,
    [switch]$PauseAtEnd,
    # Accepted for compatibility with 1.0.0 command lines; fixes are the only product now.
    [ValidateSet('', 'Fixes')]
    [string]$Product = '',
    # Internal: the elevated copy skips the question the user already answered.
    [switch]$Confirmed
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

$AppId = 224540
$PatchesRepo = 'KikoTs/AOSPatches'
$PatchesBase = "https://github.com/$PatchesRepo/releases/latest/download"
$InstallerUrl = "$PatchesBase/install.ps1"
$StateFolder = 'AOSPatches-Backup'
$RetailPkgSha = 'c0d0cdc6f61f4b58172f74faf036c6f323b1cdbe59193f595fcce7d2a524e52c'
$GameProcesses = @('aos', 'aos_debug', 'aos_demo')
$UserAgent = 'AOSPatches-installer'

# ---------------------------------------------------------------------------
# Output and questions

function Write-Step([string]$Text) { Write-Host ''; Write-Host "==> $Text" -ForegroundColor Cyan }
function Write-Info([string]$Text) { Write-Host "    $Text" }
function Write-Good([string]$Text) { Write-Host "    $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "    WARNING: $Text" -ForegroundColor Yellow }

function Read-YesNo([string]$Question, [bool]$Default) {
    if ($Yes) { return $Default }
    $hint = if ($Default) { '[Y/n]' } else { '[y/N]' }
    while ($true) {
        $answer = Read-Host "    $Question $hint"
        if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
        switch -Regex ($answer.Trim()) {
            '^(y|yes)$' { return $true }
            '^(n|no)$' { return $false }
        }
    }
}

function Format-Size([long]$Bytes) {
    if ($Bytes -ge 1GB) { return '{0:N1} GB' -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return '{0:N1} MB' -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return '{0:N0} KB' -f ($Bytes / 1KB) }
    return "$Bytes bytes"
}

# ---------------------------------------------------------------------------
# Finding the game

function Get-SteamRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    $keys = @(
        @{ Path = 'HKCU:\Software\Valve\Steam'; Name = 'SteamPath' },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam'; Name = 'InstallPath' },
        @{ Path = 'HKLM:\SOFTWARE\Valve\Steam'; Name = 'InstallPath' }
    )
    foreach ($key in $keys) {
        try {
            $value = (Get-ItemProperty -LiteralPath $key.Path -Name $key.Name -ErrorAction Stop).($key.Name)
        } catch { continue }
        if ($value) {
            $full = [IO.Path]::GetFullPath(($value -replace '/', '\'))
            if ((Test-Path -LiteralPath $full -PathType Container) -and -not ($roots -contains $full)) { $roots.Add($full) }
        }
    }
    foreach ($guess in @("${env:ProgramFiles(x86)}\Steam", "$env:ProgramFiles\Steam")) {
        if ($guess -and (Test-Path -LiteralPath $guess -PathType Container) -and -not ($roots -contains $guess)) { $roots.Add($guess) }
    }
    return $roots
}

function Get-SteamLibraries([string]$SteamRoot) {
    $libraries = New-Object System.Collections.Generic.List[string]
    $libraries.Add($SteamRoot)
    foreach ($vdf in @("$SteamRoot\steamapps\libraryfolders.vdf", "$SteamRoot\config\libraryfolders.vdf")) {
        if (-not (Test-Path -LiteralPath $vdf -PathType Leaf)) { continue }
        $text = [IO.File]::ReadAllText($vdf, [Text.Encoding]::UTF8)
        # New format: "path" "D:\\Games\\Steam". Old format: "1" "D:\\Games\\Steam".
        foreach ($match in [regex]::Matches($text, '"(?:path|\d+)"\s+"((?:[^"\\]|\\.)*)"')) {
            $path = $match.Groups[1].Value -replace '\\\\', '\'
            if ($path -match '^[A-Za-z]:\\' -and (Test-Path -LiteralPath $path -PathType Container) -and -not ($libraries -contains $path)) {
                $libraries.Add($path)
            }
        }
    }
    return $libraries
}

function Find-GameDir {
    foreach ($root in Get-SteamRoots) {
        foreach ($library in Get-SteamLibraries $root) {
            $manifest = Join-Path $library "steamapps\appmanifest_$AppId.acf"
            if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { continue }
            $installDir = 'aceofspades'
            $match = [regex]::Match([IO.File]::ReadAllText($manifest, [Text.Encoding]::UTF8), '"installdir"\s+"([^"]+)"')
            if ($match.Success) { $installDir = $match.Groups[1].Value }
            $candidate = Join-Path $library "steamapps\common\$installDir"
            if (Test-Path -LiteralPath (Join-Path $candidate 'aos.exe') -PathType Leaf) { return $candidate }
        }
    }
    return $null
}

function Resolve-GameDir {
    if ($GameDir) {
        $dir = [IO.Path]::GetFullPath($GameDir.Trim().Trim('"').TrimEnd('\'))
        if (-not (Test-Path -LiteralPath (Join-Path $dir 'aos.exe') -PathType Leaf)) {
            throw "aos.exe was not found in '$dir'. Pass the Ace of Spades folder that contains aos.exe."
        }
        return $dir
    }
    Write-Step 'Looking for Ace of Spades in your Steam libraries'
    $found = Find-GameDir
    if ($found) {
        Write-Good 'Found the game.'
        return $found
    }
    Write-Warn "Could not find Ace of Spades (Steam app $AppId) automatically."
    if ($Yes) { throw 'No game folder. Run again with -GameDir "C:\path\to\aceofspades".' }
    Write-Info 'In Steam: right-click Ace of Spades > Manage > Browse local files, then copy that folder path.'
    while ($true) {
        $answer = Read-Host '    Paste the Ace of Spades folder (the one with aos.exe), or leave empty to cancel'
        if ([string]::IsNullOrWhiteSpace($answer)) { throw 'Cancelled: no game folder chosen.' }
        $dir = $answer.Trim().Trim('"').TrimEnd('\')
        try { $dir = [IO.Path]::GetFullPath($dir) } catch { Write-Warn 'That is not a valid path.'; continue }
        if (Test-Path -LiteralPath (Join-Path $dir 'aos.exe') -PathType Leaf) { return $dir }
        Write-Warn "aos.exe is not in '$dir'."
    }
}

# ---------------------------------------------------------------------------
# Running processes, permissions

function Get-RunningGame { @(Get-Process -Name $GameProcesses -ErrorAction SilentlyContinue) }
function Get-RunningSteam { @(Get-Process -Name 'steam' -ErrorAction SilentlyContinue) }

$script:SteamAsked = $false
function Wait-ForClosedGame {
    if ((Get-RunningGame).Count) {
        Write-Warn 'Ace of Spades is running. Its files cannot be changed while it is open.'
        Write-Info 'Please close the game. Waiting for it to close (press Ctrl+C to stop)...'
        while ((Get-RunningGame).Count) { Start-Sleep -Seconds 2 }
        Write-Good 'The game is closed.'
    }
    if (-not $script:SteamAsked -and (Get-RunningSteam).Count) {
        $script:SteamAsked = $true
        Write-Info 'Steam is running. That is fine as long as it is not updating or verifying Ace of Spades right now.'
    }
}

function Test-Writable([string]$Dir) {
    $probe = Join-Path $Dir ('.aospatches-write-test-' + [Guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::WriteAllText($probe, 'test')
        Remove-Item -LiteralPath $probe -Force
        return $true
    } catch { return $false }
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Returns $true when an elevated copy was started and did the work.
function Request-Elevation([string]$Dir, [string]$Mode) {
    Write-Warn "Windows does not let this account change files in '$Dir'."
    if (Test-IsAdmin) { throw "The folder is not writable even as administrator. Check that '$Dir' is not read-only or blocked by antivirus." }
    Write-Info 'The script can run again as administrator just for this. Windows will ask you to confirm.'
    if (-not (Read-YesNo 'Relaunch as administrator?' $false)) { throw 'Cancelled: the game folder is not writable without administrator rights.' }
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        $scriptPath = Join-Path ([IO.Path]::GetTempPath()) 'AOSPatches-install.ps1'
        Write-Info 'Downloading the installer script for the elevated run...'
        Save-Download $InstallerUrl $scriptPath $false
    }
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $scriptPath), '-GameDir', ('"{0}"' -f $Dir), '-PauseAtEnd', '-Confirmed')
    if ($Mode -eq 'Uninstall') { $arguments += '-Uninstall' }
    if ($Yes) { $arguments += '-Yes' }
    if ($PackagePath) { $arguments += @('-PackagePath', ('"{0}"' -f [IO.Path]::GetFullPath($PackagePath))) }
    if ($ChecksumPath) { $arguments += @('-ChecksumPath', ('"{0}"' -f [IO.Path]::GetFullPath($ChecksumPath))) }
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList ($arguments -join ' ') -Verb RunAs -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "The administrator run did not finish (exit code $($process.ExitCode))." }
    return $true
}

# ---------------------------------------------------------------------------
# Downloads and checksums

function Enable-Tls12 {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch { }
}

function Save-Download([string]$Url, [string]$Destination, [bool]$ShowProgress = $true) {
    $request = [Net.HttpWebRequest]::Create($Url)
    $request.UserAgent = $UserAgent
    $request.AllowAutoRedirect = $true
    $request.Timeout = 60000
    $request.ReadWriteTimeout = 60000
    $response = $request.GetResponse()
    try {
        $total = $response.ContentLength
        $body = $response.GetResponseStream()
        $output = [IO.File]::Create($Destination)
        try {
            $buffer = New-Object byte[] 262144
            [long]$done = 0
            $lastShown = -1
            while (($read = $body.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $output.Write($buffer, 0, $read)
                $done += $read
                if ($ShowProgress -and $total -gt 0) {
                    $percent = [int](100 * $done / $total)
                    if ($percent -ne $lastShown) {
                        Write-Progress -Activity 'Downloading' -Status ('{0} of {1}' -f (Format-Size $done), (Format-Size $total)) -PercentComplete $percent
                        if ($percent % 10 -eq 0) { Write-Info ('{0,3}%  {1} of {2}' -f $percent, (Format-Size $done), (Format-Size $total)) }
                        $lastShown = $percent
                    }
                }
            }
        } finally { $output.Dispose(); $body.Dispose() }
        if ($ShowProgress) { Write-Progress -Activity 'Downloading' -Completed }
        if ($total -gt 0 -and $done -ne $total) { throw "Download was cut short ($done of $total bytes): $Url" }
    } finally { $response.Close() }
}

function Read-Checksums([string]$Path) {
    $table = @{}
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        $match = [regex]::Match($line, '^\s*([0-9a-fA-F]{64})\s+\*?(.+?)\s*$')
        if ($match.Success) { $table[$match.Groups[2].Value] = $match.Groups[1].Value.ToLowerInvariant() }
    }
    return $table
}

function Get-Sha256([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream)) -replace '-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}

function Get-StreamSha256([IO.Stream]$Stream) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Stream)) -replace '-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Confirm-Checksum([string]$File, [string]$Expected, [string]$Name) {
    $actual = Get-Sha256 $File
    if (-not $Expected) { throw "The checksum file has no entry for $Name; refusing to install an unverified download." }
    if ($actual -ne $Expected) { throw "SHA-256 mismatch for $Name. Expected $Expected, got $actual. The download is damaged or was tampered with; nothing was changed." }
    Write-Good "SHA-256 verified: $actual"
}

# Downloads (or takes) the package and returns @{ Zip; Name; Version; Sha256 }.
function Get-Package([string]$Work) {
    if ($PackagePath) {
        $zip = [IO.Path]::GetFullPath($PackagePath)
        if (-not (Test-Path -LiteralPath $zip -PathType Leaf)) { throw "Package not found: $zip" }
        $name = [IO.Path]::GetFileName($zip)
        Write-Step "Using local package $name"
        if ($ChecksumPath) {
            $table = Read-Checksums ([IO.Path]::GetFullPath($ChecksumPath))
            Confirm-Checksum $zip $table[$name] $name
        } else {
            Write-Warn 'No -ChecksumPath given; the local package is not verified.'
        }
        $version = if ($name -match '-(\d[^-]*?)\.zip$') { $Matches[1] } else { 'local' }
        return @{ Zip = $zip; Name = $name; Version = $version; Sha256 = (Get-Sha256 $zip) }
    }
    Write-Step 'Downloading the latest AOSPatches release'
    $sums = Join-Path $Work 'SHA256SUMS'
    Save-Download "$PatchesBase/SHA256SUMS" $sums $false
    $table = Read-Checksums $sums
    $version = 'latest'
    foreach ($key in $table.Keys) { if ($key -match '^AOSPatches-(.+)\.zip$') { $version = $Matches[1] } }
    Write-Info "Version: $version"
    $zip = Join-Path $Work 'AOSPatches.zip'
    Save-Download "$PatchesBase/AOSPatches.zip" $zip
    Confirm-Checksum $zip $table['AOSPatches.zip'] 'AOSPatches.zip'
    return @{ Zip = $zip; Name = "AOSPatches-$version.zip"; Version = $version; Sha256 = $table['AOSPatches.zip'] }
}

# ---------------------------------------------------------------------------
# Install manifest: header lines "#key=value", then one tab-separated row per
# file: action, original SHA-256, installed SHA-256, relative path.
#   added     the file did not exist; uninstall deletes it
#   replaced  the original is in the backup; uninstall copies it back
#   same      the file already had identical bytes; nothing to undo

function Get-StateRoot([string]$Dir) { Join-Path $Dir $StateFolder }

function Find-ActiveInstall([string]$Dir) {
    $root = Get-StateRoot $Dir
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return $null }
    $latest = Get-ChildItem -LiteralPath $root -Directory | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName 'manifest.txt') -PathType Leaf
    } | Sort-Object Name -Descending | Select-Object -First 1
    if ($latest) { return $latest.FullName }
    return $null
}

function Read-Manifest([string]$BackupDir) {
    $info = @{}
    $rows = New-Object System.Collections.Generic.List[object]
    $dirs = New-Object System.Collections.Generic.List[string]
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $BackupDir 'manifest.txt'), [Text.Encoding]::UTF8)) {
        if ($line.StartsWith('#')) {
            $pair = $line.Substring(1).Split(@('='), 2, [StringSplitOptions]::None)
            if ($pair.Count -eq 2) { $info[$pair[0]] = $pair[1] }
        } elseif ($line.StartsWith("dir`t")) {
            $dirs.Add($line.Substring(4))
        } elseif ($line) {
            $cells = $line.Split("`t")
            if ($cells.Count -eq 4) { $rows.Add(@{ Action = $cells[0]; Original = $cells[1]; Installed = $cells[2]; Path = $cells[3] }) }
        }
    }
    return @{ Info = $info; Rows = $rows; Dirs = $dirs }
}

function Write-Manifest([string]$BackupDir, [hashtable]$Info, $Rows, $Dirs) {
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($key in ($Info.Keys | Sort-Object)) { $lines.Add("#$key=$($Info[$key])") }
    foreach ($dir in $Dirs) { $lines.Add("dir`t$dir") }
    foreach ($row in $Rows) { $lines.Add(('{0}{4}{1}{4}{2}{4}{3}' -f $row.Action, $row.Original, $row.Installed, $row.Path, "`t")) }
    $temp = Join-Path $BackupDir 'manifest.tmp'
    [IO.File]::WriteAllLines($temp, $lines, (New-Object Text.UTF8Encoding $false))
    Move-Item -LiteralPath $temp -Destination (Join-Path $BackupDir 'manifest.txt') -Force
}

function Get-SafeRelativePath([string]$EntryName) {
    $relative = $EntryName.Replace('/', '\')
    if (-not $relative -or $relative.StartsWith('\') -or $relative -match '^[A-Za-z]:' -or $relative -match '(^|\\)\.\.(\\|$)' -or $relative.IndexOfAny([IO.Path]::GetInvalidPathChars()) -ge 0) {
        throw "Unsafe path in the package: $EntryName"
    }
    if ($relative.StartsWith("$StateFolder\", [StringComparison]::OrdinalIgnoreCase)) { throw "The package tries to write into $StateFolder." }
    return $relative
}

function Copy-WithHash([IO.Stream]$Source, [string]$Destination) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $output = [IO.File]::Create($Destination)
    try {
        $buffer = New-Object byte[] 262144
        while (($read = $Source.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $output.Write($buffer, 0, $read)
            [void]$sha.TransformBlock($buffer, 0, $read, $null, 0)
        }
        [void]$sha.TransformFinalBlock($buffer, 0, 0)
        return ([BitConverter]::ToString($sha.Hash) -replace '-', '').ToLowerInvariant()
    } finally { $output.Dispose(); $sha.Dispose() }
}

# ---------------------------------------------------------------------------
# Uninstall

function Invoke-Restore([string]$Dir, [string]$BackupDir, $Manifest, [bool]$Rollback = $false) {
    $rows = $Manifest.Rows.ToArray()
    $problems = 0
    $restored = 0
    $removed = 0
    for ($i = $rows.Count - 1; $i -ge 0; $i--) {
        $row = $rows[$i]
        $target = Join-Path $Dir $row.Path
        if ($i % 50 -eq 0 -and $rows.Count -gt 50) {
            Write-Progress -Activity 'Restoring' -Status $row.Path -PercentComplete ([int](100 * ($rows.Count - $i) / $rows.Count))
        }
        switch ($row.Action) {
            'added' {
                if (Test-Path -LiteralPath $target -PathType Leaf) {
                    if ($Rollback -or (Get-Sha256 $target) -eq $row.Installed) {
                        Remove-Item -LiteralPath $target -Force
                        $removed++
                    } else {
                        Write-Warn "Left in place because it changed after install: $($row.Path)"
                        $problems++
                    }
                }
            }
            'replaced' {
                $saved = Join-Path (Join-Path $BackupDir 'files') $row.Path
                if (-not (Test-Path -LiteralPath $saved -PathType Leaf)) { Write-Warn "Backup copy missing: $($row.Path)"; $problems++; continue }
                if ((Get-Sha256 $saved) -ne $row.Original) { Write-Warn "Backup copy is damaged: $($row.Path)"; $problems++; continue }
                $parent = Split-Path -Parent $target
                if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                Copy-Item -LiteralPath $saved -Destination $target -Force
                $restored++
            }
        }
    }
    Write-Progress -Activity 'Restoring' -Completed
    # Remove folders the install created, deepest first, if they are now empty.
    foreach ($relative in ($Manifest.Dirs.ToArray() | Sort-Object { $_.Length } -Descending)) {
        $path = Join-Path $Dir $relative
        if ((Test-Path -LiteralPath $path -PathType Container) -and -not (Get-ChildItem -LiteralPath $path -Force | Select-Object -First 1)) {
            Remove-Item -LiteralPath $path -Force
        }
    }
    return @{ Problems = $problems; Restored = $restored; Removed = $removed }
}

function Remove-StateIfEmpty([string]$Dir) {
    $root = Get-StateRoot $Dir
    if ((Test-Path -LiteralPath $root -PathType Container) -and -not (Get-ChildItem -LiteralPath $root -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $root -Force
    }
}

function Invoke-Uninstall([string]$Dir) {
    $backup = Find-ActiveInstall $Dir
    if (-not $backup) {
        Write-Warn "No install made by this script was found in '$Dir'."
        Write-Info 'If you copied AOSPatches by hand, delete winmm.dll, the aos*fix*.py / aos_steam_bridge.py / aosfix_runtime.py files and the relay folder.'
        return $false
    }
    $manifest = Read-Manifest $backup
    Write-Step "Uninstalling $($manifest.Info['product']) $($manifest.Info['version']) (installed $($manifest.Info['installed']))"
    Wait-ForClosedGame
    $result = Invoke-Restore $Dir $backup $manifest
    Write-Info "Restored $($result.Restored) original file(s), removed $($result.Removed) added file(s)."
    if ($result.Problems) {
        Write-Warn "$($result.Problems) file(s) could not be restored. The backup is kept in '$backup'."
        Write-Info 'Steam can repair the rest: Properties > Installed Files > Verify integrity of game files.'
        return $false
    }
    Remove-Item -LiteralPath $backup -Recurse -Force
    Remove-StateIfEmpty $Dir
    Write-Good 'Your game files are back to how they were before the install.'
    return $true
}

# ---------------------------------------------------------------------------
# Install

function Test-OurLoader([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $text = [Text.Encoding]::ASCII.GetString($bytes)
    return ($text.Contains('aosfix_runtime') -or $text.Contains('aos_mousefix_loader'))
}

function Invoke-Install([string]$Dir) {
    $label = 'AOSPatches'
    $work = Join-Path ([IO.Path]::GetTempPath()) ('AOSPatches-setup-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        $package = Get-Package $work

        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($package.Zip)
        try {
            $entries = @($archive.Entries | Where-Object { $_.FullName -and -not $_.FullName.EndsWith('/') })
            if (-not $entries.Count) { throw 'The package is empty.' }
            foreach ($entry in $entries) { [void](Get-SafeRelativePath $entry.FullName) }
            if (-not ($entries | Where-Object { $_.FullName -eq 'winmm.dll' })) {
                throw 'This does not look like an AOSPatches package (no winmm.dll).'
            }

            Write-Step 'Checking the game folder'
            Wait-ForClosedGame
            $previous = Find-ActiveInstall $Dir
            if ($previous) {
                $old = Read-Manifest $previous
                Write-Info "Found an earlier install: $($old.Info['product']) $($old.Info['version']). It is removed first so its backup stays correct."
                if (-not (Invoke-Uninstall $Dir)) { throw 'The earlier install could not be removed cleanly; fix that first (see above).' }
            }

            $pkg = Join-Path $Dir 'aos.pkg'
            if ((Test-Path -LiteralPath $pkg -PathType Leaf) -and (Get-Sha256 $pkg) -ne $RetailPkgSha) {
                Write-Warn 'Your aos.pkg is not the original Steam version, so AOSPatches will stay inactive.'
                Write-Info 'This happens after installing other mods or a modified client. Steam can restore the original:'
                Write-Info 'Properties > Installed Files > Verify integrity of game files. Then run this installer again.'
                if (-not (Read-YesNo 'Install anyway?' $false)) { throw 'Cancelled: unsupported aos.pkg.' }
            }
            $loader = Join-Path $Dir 'winmm.dll'
            if ((Test-Path -LiteralPath $loader -PathType Leaf) -and -not (Test-OurLoader $loader)) {
                Write-Warn 'Another mod already uses winmm.dll in the game folder. AOSPatches cannot run alongside it.'
                Write-Info 'If you continue, that file is backed up and -Uninstall puts it back.'
                if (-not (Read-YesNo 'Replace it with the AOSPatches loader?' $false)) { throw 'Cancelled: kept the other winmm.dll.' }
            }

            # Space: the new files plus a backup of every file they replace.
            [long]$needed = 0
            foreach ($entry in $entries) {
                $needed += $entry.Length
                $existing = Join-Path $Dir (Get-SafeRelativePath $entry.FullName)
                if (Test-Path -LiteralPath $existing -PathType Leaf) { $needed += (Get-Item -LiteralPath $existing).Length }
            }
            $drive = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($Dir))
            if ($drive.AvailableFreeSpace -lt $needed + 50MB) {
                throw "Not enough free space on $($drive.Name): need about $(Format-Size $needed), have $(Format-Size $drive.AvailableFreeSpace)."
            }

            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $backup = Join-Path (Get-StateRoot $Dir) $stamp
            $filesDir = Join-Path $backup 'files'
            New-Item -ItemType Directory -Path $filesDir -Force | Out-Null
            $info = @{
                product   = $label
                version   = $package.Version
                package   = $package.Name
                sha256    = $package.Sha256
                installed = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
                state     = 'installing'
            }
            $rows = New-Object System.Collections.Generic.List[object]
            $dirs = New-Object System.Collections.Generic.List[string]
            Write-Manifest $backup $info $rows $dirs

            Write-Step "Installing $label $($package.Version) into $Dir"
            Write-Info "Backup folder: $backup"
            $count = 0
            try {
                foreach ($entry in $entries) {
                    $count++
                    $relative = Get-SafeRelativePath $entry.FullName
                    $target = Join-Path $Dir $relative
                    if ($count % 25 -eq 0 -or $count -eq $entries.Count) {
                        Write-Progress -Activity "Installing $label" -Status "$count of $($entries.Count): $relative" -PercentComplete ([int](100 * $count / $entries.Count))
                    }
                    # Record every folder this install creates.
                    $parent = Split-Path -Parent $relative
                    $missing = New-Object System.Collections.Generic.List[string]
                    while ($parent -and -not (Test-Path -LiteralPath (Join-Path $Dir $parent))) { $missing.Add($parent); $parent = Split-Path -Parent $parent }
                    for ($j = $missing.Count - 1; $j -ge 0; $j--) {
                        New-Item -ItemType Directory -Path (Join-Path $Dir $missing[$j]) -Force | Out-Null
                        $dirs.Add($missing[$j])
                    }

                    $original = '-'
                    $action = 'added'
                    if (Test-Path -LiteralPath $target -PathType Leaf) {
                        $original = Get-Sha256 $target
                        $same = $false
                        if ((Get-Item -LiteralPath $target).Length -eq $entry.Length) {
                            $stream = $entry.Open()
                            try { $same = ((Get-StreamSha256 $stream) -eq $original) } finally { $stream.Dispose() }
                        }
                        if ($same) {
                            $rows.Add(@{ Action = 'same'; Original = $original; Installed = $original; Path = $relative })
                            continue
                        }
                        $saved = Join-Path $filesDir $relative
                        $savedParent = Split-Path -Parent $saved
                        if (-not (Test-Path -LiteralPath $savedParent)) { New-Item -ItemType Directory -Path $savedParent -Force | Out-Null }
                        Copy-Item -LiteralPath $target -Destination $saved -Force
                        if ((Get-Sha256 $saved) -ne $original) { throw "Backup of $relative could not be verified." }
                        $action = 'replaced'
                        # Record before overwriting, so a failure can always be undone.
                        $rows.Add(@{ Action = $action; Original = $original; Installed = '-'; Path = $relative })
                    } else {
                        $rows.Add(@{ Action = $action; Original = $original; Installed = '-'; Path = $relative })
                    }
                    $stream = $entry.Open()
                    try { $installed = Copy-WithHash $stream $target } finally { $stream.Dispose() }
                    $rows[$rows.Count - 1].Installed = $installed
                    if ($count % 200 -eq 0) { Write-Manifest $backup $info $rows $dirs }
                }
                $info.state = 'installed'
                Write-Manifest $backup $info $rows $dirs
            } catch {
                $failure = $_
                Write-Progress -Activity "Installing $label" -Completed
                Write-Warn "Install failed: $($failure.Exception.Message)"
                Write-Info 'Undoing the files copied so far...'
                $partial = @{ Rows = $rows; Dirs = $dirs; Info = $info }
                $undo = Invoke-Restore $Dir $backup $partial $true
                if (-not $undo.Problems) {
                    Remove-Item -LiteralPath $backup -Recurse -Force
                    Remove-StateIfEmpty $Dir
                    Write-Info 'The game folder is unchanged.'
                } else {
                    Write-Manifest $backup $info $rows $dirs
                    Write-Warn "Some files could not be undone; run this script with -Uninstall, or verify the game files in Steam. Backup: $backup"
                }
                throw $failure
            }
            Write-Progress -Activity "Installing $label" -Completed
            $added = @($rows | Where-Object { $_.Action -eq 'added' }).Count
            $replaced = @($rows | Where-Object { $_.Action -eq 'replaced' }).Count
            Write-Good "Done: $added file(s) added, $replaced replaced (originals backed up), $($rows.Count - $added - $replaced) already identical."
            if (-not $replaced -and -not $added) { Write-Info 'Nothing needed changing.' }
        } finally { $archive.Dispose() }
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Step 'All set'
    Write-Info 'Start Ace of Spades from Steam as usual.'
    Write-Info "Patch log: $(Join-Path $Dir 'aos_mousefix_loader.log')"
    Write-Info 'To undo everything later, run the installer again and choose U (Uninstall).'
}

# The one question: what to do with this folder. Returns Install, Uninstall or Quit.
function Select-Action([string]$Dir) {
    Write-Info "Game folder: $Dir"
    $previous = Find-ActiveInstall $Dir
    if ($previous) {
        $old = Read-Manifest $previous
        Write-Info "AOSPatches $($old.Info['version']) is already installed here (since $($old.Info['installed']))."
        if ($Yes -or $Confirmed) { return 'Install' }
        Write-Host ''
        Write-Host '    [Enter] Update / reinstall the latest AOSPatches' -ForegroundColor White
        Write-Host '    [U]     Uninstall and put the original files back'
        Write-Host '    [Q]     Quit without changing anything'
        while ($true) {
            $answer = (Read-Host '    Your choice').Trim().ToUpperInvariant()
            switch ($answer) {
                '' { return 'Install' }
                'Y' { return 'Install' }
                'U' { return 'Uninstall' }
                'Q' { return 'Quit' }
                'N' { return 'Quit' }
            }
        }
    }
    Write-Info 'AOSPatches fixes the mouse, equipment menu, scrolling and jumping of the original game.'
    Write-Info 'Original game files are backed up, every fix can be switched off, and you can uninstall anytime.'
    if ($Confirmed) { return 'Install' }
    if (Read-YesNo 'Install AOSPatches into this folder?' $true) { return 'Install' }
    return 'Quit'
}

# ---------------------------------------------------------------------------

function Invoke-Main {
    Write-Host ''
    Write-Host 'AOSPatches installer for Ace of Spades on Steam (app 224540)' -ForegroundColor Cyan
    if ($PSVersionTable.PSVersion.Major -lt 5) { throw 'Windows PowerShell 5.1 or newer is required.' }
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'This installer only runs on Windows.' }
    Enable-Tls12

    if (-not $GameDir -and $env:AOSPATCHES_GAMEDIR) { $script:GameDir = $env:AOSPATCHES_GAMEDIR }
    $dir = Resolve-GameDir
    $choice = if ($Uninstall) { 'Uninstall' } else { Select-Action $dir }
    if ($choice -eq 'Quit') { throw 'Cancelled: nothing was changed.' }

    if (-not (Test-Writable $dir)) {
        if (Request-Elevation $dir $choice) { return }
    }
    if ($choice -eq 'Uninstall') {
        if (-not (Invoke-Uninstall $dir)) { throw 'Uninstall did not complete; see the messages above.' }
    } else {
        Invoke-Install $dir
    }
}

# Exit codes when run as a file: 0 done, 1 failed, 2 cancelled (nothing changed).
$exitCode = 0
try {
    Invoke-Main
} catch {
    $message = $_.Exception.Message
    Write-Host ''
    if ($message -like 'Cancelled*') {
        $exitCode = 2
        Write-Host $message -ForegroundColor Yellow
    } else {
        $exitCode = 1
        Write-Host "ERROR: $message" -ForegroundColor Red
        Write-Host 'Nothing else was changed. Ask for help at https://github.com/KikoTs/AOSPatches/issues' -ForegroundColor Red
    }
}
if ($PauseAtEnd) { [void](Read-Host 'Press Enter to close this window') }
# Only set an exit code when run as a file; "irm | iex" must not close the window.
if ($PSCommandPath -and $exitCode) { exit $exitCode }
