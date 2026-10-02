# AOSPatches

Drag-and-drop bug fixes and quality-of-life patches for the **original Steam
Ace of Spades client**. Includes an experimental Steam relay browser for
player-hosted BattleSpades servers.

## Install

1. [Download AOSPatches.zip](https://github.com/KikoTs/AOSPatches/raw/refs/heads/main/AOSPatches.zip).
2. Close the game and extract the ZIP beside `aos.exe`. Keep the `relay` folder.
3. Launch Ace of Spades through Steam normally.

The ZIP and [`dist/`](dist) contain only the files to copy into the game:

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

No installer or separate Python installation is needed. The original game's
EXE, PKG, PYD and Steam DLLs stay intact. The additional helper needs 64-bit
Windows and Steam signed into an account that owns the game. Keep its
`steam_api64.dll` inside `relay/`.

If another mod already supplies `winmm.dll`, do not overwrite it: proxy
chaining is not implemented. When updating AOSPatches, replace its loader
and Python files together.

## Included

- Raw mouse input, with focus/minimize/restore recovery and stock-input fallback.
- Equipment menu weapon choices and Specialist/Medic selection, while retaining
  server class/tool restrictions. No assets or Steam ownership are supplied.
- Fractional mouse-wheel scrolling and menu timer cleanup.
- The jump-launch prediction repair on every server; native walking and
  ordinary server corrections remain in use.
- Experimental `[Steam]` browser entries and a separate native relay helper
  for compatible BattleSpades servers.

Only the inspected retail bundle is supported. Unknown `aos.pkg` hashes skip
the Python patches. The supported SHA256 is:

```text
c0d0cdc6f61f4b58172f74faf036c6f323b1cdbe59193f595fcce7d2a524e52c
```

The relay implementation has local forwarding and Steam initialization tests.
Two-account Internet SDR gameplay and the complete live retail UI still need
validation. See [networking](docs/NETWORK.md), [movement](docs/MOVEMENT.md),
and [validation](docs/VALIDATION.md) for the observed limits.

## Disable or remove

Restart the game after changing a setting.

| Feature | Steam launch option | Or create this empty file beside aos.exe |
| --- | --- | --- |
| Mouse | `+legacymouse` | `aos_mousefix.disabled` |
| Equipment | `+legacyequipment` | `aos_equipmentfix.disabled` |
| Scrolling/timers | `+legacyui` | `aos_uifix.disabled` |
| Jump prediction | `+legacymovement` | `aos_movementfix.disabled` |
| Steam networking | `+legacynetwork` | `aos_networkfix.disabled` |

To uninstall, close the game and remove the ten added files listed above.
Diagnostics go to `aos_mousefix_loader.log`; relay favourites/history live in
`%LOCALAPPDATA%/AoSRetailFixes`.

## Build

Use Windows PowerShell 5.1 or newer, Visual Studio C++ x86/x64 build tools,
and a Steamworks SDK with the modern networking interfaces. From this repo:

```powershell
.\build.ps1 -SteamSdk C:\path\steamworks_sdk
```

You can also set `STEAMWORKS_SDK`. To build only the six bug-fix files without
the optional Steam networking feature or SDK dependency:

```powershell
.\build.ps1 -FixesOnly
```

Both builds replace this repo's `dist/` and `AOSPatches.zip` with **runtime
files only**. Source, tests, documentation and compiler intermediates are
excluded. Intermediates stay in ignored `build/`; complete notices are
included as inert comments in the runtime Python module. `package.ps1`
repackages an existing clean `dist/` and rejects unexpected files.

The source is in [`src/retail`](src/retail) and [`src/relay`](src/relay).
No BattleSpades or BattleSpadesClient checkout is required to build. The
Steamworks SDK is provided separately and is not committed here.
See [BUILDING.md](docs/BUILDING.md) for tests and distribution checks.

## Hosting

The hosting option belongs to the separate
[BattleSpades server](https://github.com/KikoTs/BattleSpades). From an updated
server checkout, with Steam running, point it at this build's helper:

```powershell
py -3.12 run_server.py --steam-p2p --steam-p2p-bridge "C:\path\AOSPatches\dist\relay\aos-retail-relay.exe"
```

This repository contains the retail patches and shared native helper, not
the BattleSpades server or C++ client. [Hosting details](docs/NETWORK.md).

## License and provenance

Copyright (c) 2026 Kiril Tsanov (KikoTs).

AOSPatches is **AGPL-3.0-or-later**, following BattleSpades, with additional
permissions for Steamworks and interaction with the proprietary retail runtime.
Read [LICENSE](LICENSE), [LICENSING.md](LICENSING.md), and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Valve's redistributable retains
Valve's terms; no original game binary or asset is included.

The Revival notices and implementation history are preserved in
[provenance](docs/PROVENANCE.md). No AGEX code is included. This project is not
affiliated with Valve or the owners of Ace of Spades.
