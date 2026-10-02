# AOSPatches

Drag-and-drop bug fixes and quality-of-life patches for the **original Steam
Ace of Spades client**, plus an experimental Steam relay browser for
player-hosted BattleSpades servers.

- **Works with:** Ace of Spades on Steam (app **224540**), Windows. The Steam
  relay helper needs 64-bit Windows and Steam signed in to an account that owns
  the game.
- **Changes nothing permanently:** the game's EXE, PKG, PYD and Steam DLLs stay
  untouched. Every patch can be switched off on its own.
- **Download:** [latest release](https://github.com/KikoTs/AOSPatches/releases/latest)
  ([`AOSPatches-Installer.cmd`](https://github.com/KikoTs/AOSPatches/releases/latest/download/AOSPatches-Installer.cmd),
  [`AOSPatches.zip`](https://github.com/KikoTs/AOSPatches/releases/latest/download/AOSPatches.zip),
  [`SHA256SUMS`](https://github.com/KikoTs/AOSPatches/releases/latest/download/SHA256SUMS)).
  What changed: [CHANGELOG.md](CHANGELOG.md).

## What it fixes

| Patch | File | What it does |
| --- | --- | --- |
| Raw mouse | `aos_mousefix.py` | Raw (`WM_INPUT`) mouse aiming without Windows pointer acceleration; recovers after alt-tab, minimize and restore; falls back to stock input if raw input stops. |
| Equipment | `aos_equipmentfix.py` | DLC weapons/tools in the equipment menu and the Specialist and Medic characters. Server class/tool rules still apply. |
| Scrolling and timers | `aos_uifix.py` | Smooth fractional mouse-wheel scrolling (lists and match settings); cancels menu refresh timers when you leave a menu. |
| Jump prediction | `aos_movementfix.py` | Stops the local jump being snapped back to a stale position on the launch frame, on every server. |
| Steam relay browser | `aos_networkfix.py`, `aos_steam_bridge.py`, `relay/` | Experimental: `[Steam]` entries for BattleSpades servers hosted over Steam, joinable without port forwarding. |
| Loader | `winmm.dll`, `aosfix_runtime.py` | Loads the patches into the game and forwards all WinMM calls to Windows. |

The full list is in [CHANGELOG.md](CHANGELOG.md). Only the original retail
bundle is supported; with any other `aos.pkg` (for example after installing
another mod) the Python patches stay off. Supported `aos.pkg` SHA-256:

```text
c0d0cdc6f61f4b58172f74faf036c6f323b1cdbe59193f595fcce7d2a524e52c
```

## Install

### One click (recommended)

1. Download [`AOSPatches-Installer.cmd`](https://github.com/KikoTs/AOSPatches/releases/latest/download/AOSPatches-Installer.cmd).
2. Close the game and double-click the file. If Windows says it protected your
   PC, choose **More info** > **Run anyway** (it is a downloaded script).
3. Press **Enter** to confirm. When the window says **SUCCESS**, start Ace of
   Spades from Steam as usual.

The `.cmd` file downloads `install.ps1` from the latest release over HTTPS,
runs it with Windows PowerShell and keeps the window open so you can read the
result. Run it again later to update or uninstall.

The installer:

1. finds your Steam library and the Ace of Spades folder (or asks for it);
2. asks once before changing anything;
3. waits for the game to close if it is running;
4. downloads the latest release and checks its SHA-256 against the release's
   checksum file;
5. backs up every file it replaces into `AOSPatches-Backup\<date-time>\` in the
   game folder, then copies the new files in.

On a game that already has AOSPatches it offers **update** (Enter),
**uninstall** (U) or **quit** (Q). It runs on the Windows PowerShell 5.1 that
ships with Windows and needs no administrator rights unless your game folder is
not writable; it then explains why and relaunches as administrator only if you
agree.

### PowerShell one-liner

Close the game, open **PowerShell** (Start menu, type `powershell`) and run:

```powershell
irm https://github.com/KikoTs/AOSPatches/releases/latest/download/install.ps1 | iex
```

Prefer to read the script first? Download, inspect, then run it:

```powershell
irm https://github.com/KikoTs/AOSPatches/releases/latest/download/install.ps1 -OutFile install.ps1
notepad install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Options (with the downloaded file, after `AOSPatches-Installer.cmd`, or with
the one-liner as `& ([scriptblock]::Create((irm <url>))) <options>`):

| Option | Meaning |
| --- | --- |
| `-GameDir "D:\Steam\steamapps\common\aceofspades"` | Use this folder instead of searching (or set `AOSPATCHES_GAMEDIR`). |
| `-Uninstall` | Restore the backup and remove what the install added. |
| `-Yes` | Do not ask; install (or update) straight away. |
| `-PackagePath <zip> -ChecksumPath <SHA256SUMS>` | Install a ZIP you already downloaded. |

Exit codes: `0` done, `1` failed, `2` cancelled (nothing changed).

### Manual

1. Download [`AOSPatches.zip`](https://github.com/KikoTs/AOSPatches/releases/latest/download/AOSPatches.zip).
2. In Steam, right-click **Ace of Spades** > **Manage** > **Browse local files**.
3. Close the game and extract the ZIP into that folder, beside `aos.exe`. Keep the
   `relay` folder.
4. Start Ace of Spades from Steam as usual.

The ZIP contains only the files the game needs:

```text
winmm.dll
aosfix_runtime.py
aos_mousefix.py
aos_equipmentfix.py
aos_uifix.py
aos_movementfix.py
aos_networkfix.py
aos_steam_bridge.py
relay/
  aos-retail-relay.exe
  steam_api64.dll
```

If another mod already supplies `winmm.dll`, do not overwrite it: proxy
chaining is not implemented. When updating, replace the loader and the Python
files together (the installer does this for you).

## Switch a patch off

Restart the game after changing a setting.

| Patch | Steam launch option | Or create this empty file beside aos.exe |
| --- | --- | --- |
| Mouse | `+legacymouse` | `aos_mousefix.disabled` |
| Equipment | `+legacyequipment` | `aos_equipmentfix.disabled` |
| Scrolling/timers | `+legacyui` | `aos_uifix.disabled` |
| Jump prediction | `+legacymovement` | `aos_movementfix.disabled` |
| Steam networking | `+legacynetwork` | `aos_networkfix.disabled` |

Diagnostics go to `aos_mousefix_loader.log` in the game folder; relay
favourites/history live in `%LOCALAPPDATA%\AoSRetailFixes`.

## Uninstall

- **Installed with the installer:** double-click `AOSPatches-Installer.cmd`
  again and press **U**, or run the script with `-Uninstall`:

  ```powershell
  & ([scriptblock]::Create((irm https://github.com/KikoTs/AOSPatches/releases/latest/download/install.ps1))) -Uninstall
  ```

  It restores every replaced file byte for byte, deletes the files it added and
  removes its backup folder.
- **Installed by hand:** close the game and delete the ten files listed above
  (and the `relay` folder). Steam's *Verify integrity of game files* does not
  remove them, because they are extra files, not modified game files.

## Build

Requirements: Windows, PowerShell 5.1 or newer, Visual Studio (or Build Tools)
with the C++ x86/x64 tools and a Windows SDK, and the Steamworks SDK for the
relay helper. From the repository root:

```powershell
.\build.ps1 -SteamSdk C:\path\steamworks_sdk -Version 1.0.0
```

You can also set `STEAMWORKS_SDK`. To build only the six bug-fix files without
the Steam relay (no Steamworks SDK needed):

```powershell
.\build.ps1 -FixesOnly
```

`build.ps1` compiles into ignored `build/`, writes the runtime files to `dist/`
and runs `package.ps1`, which writes the release assets to `out/`:
`AOSPatches-<version>.zip`, `AOSPatches.zip` (same bytes), `install.ps1`,
`AOSPatches-Installer.cmd` and `SHA256SUMS`. None of these are committed. Builds are deterministic: the same
source revision, toolchain and SDK give the same bytes. The release workflow
uses the same pinned Steamworks SDK archive as the BattleSpades C++ client.
See [docs/BUILDING.md](docs/BUILDING.md) for tests and checks.

### Releasing

Add a section for the new version to [CHANGELOG.md](CHANGELOG.md), commit, then
push a tag:

```powershell
git tag v1.0.1
git push origin v1.0.1
```

[`.github/workflows/release.yml`](.github/workflows/release.yml) builds the ZIP
from source on GitHub's Windows runners and publishes the release with the
changelog section as its notes. It can also be started by hand from the
Actions tab (*Run workflow*, with a tag).

## Repository layout

```text
src/retail/     loader (C++), bootstrap and Python patch modules, tests
src/relay/      native Steam relay helper (C++) and its smoke test
docs/           building, networking, movement and validation notes
licenses/       retained third-party license texts
build.ps1       build dist/ from source, then package
package.ps1     package dist/ into the release assets in out/
install.ps1     automated installer/uninstaller (also attached to each release)
AOSPatches-Installer.cmd  double-click wrapper that downloads and runs install.ps1
```

## Hosting

The hosting side belongs to the separate
[BattleSpades server](https://github.com/KikoTs/BattleSpades). With Steam
running, point it at the helper from the release ZIP (or your own `dist/`):

```powershell
py -3.12 run_server.py --steam-p2p --steam-p2p-bridge "C:\path\relay\aos-retail-relay.exe"
```

See [docs/NETWORK.md](docs/NETWORK.md) for details and current limits.
Two-account Internet play through Steam Datagram Relay still needs live
validation; see [movement](docs/MOVEMENT.md) and [validation](docs/VALIDATION.md)
for the observed limits of the other patches.

## License and provenance

Copyright (c) 2026 Kiril Tsanov (KikoTs).

AOSPatches is **AGPL-3.0-or-later**, following BattleSpades, with additional
permissions for Steamworks and interaction with the proprietary retail runtime.
Read [LICENSE](LICENSE), [LICENSING.md](LICENSING.md), and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Valve's redistributable
`steam_api64.dll` keeps Valve's terms; no original game binary or asset is
included.

The Revival notices and implementation history are preserved in
[provenance](docs/PROVENANCE.md). No AGEX code is included. This project is not
affiliated with Valve or the owners of Ace of Spades.
