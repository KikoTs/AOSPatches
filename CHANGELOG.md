# Changelog

All notable changes to AOSPatches. Versions follow [Semantic Versioning](https://semver.org/).
Each release on the [releases page](https://github.com/KikoTs/AOSPatches/releases)
uses its section below as the release notes.

## [1.0.0] - 2026-10-02

First tagged release. It packages the retail patches that were first published as
committed files in the repository (commit `e3f0ef6`), and adds an automated installer.

Works with the original Steam **Ace of Spades** (app 224540) on Windows, retail
`aos.pkg` SHA-256 `c0d0cdc6f61f4b58172f74faf036c6f323b1cdbe59193f595fcce7d2a524e52c`.
Any other `aos.pkg` (for example after installing another mod) leaves the
Python patches switched off and the game unchanged.

### Mouse and input

- Raw mouse input (`WM_INPUT`): relative device counts go straight to the game,
  so aiming no longer follows Windows pointer acceleration. Based on AoS Revival's
  raw-input design. Menus keep normal cursor input.
- Works with the window the game has already created, including late window
  creation and window recreation; checks raw-input ownership and never takes over
  another program's registration.
- Absolute-position devices (tablets, some remote-desktop mice) are handled.
- Recovers after focus loss, minimize and restore: capture is dropped and
  reacquired cleanly, with a short grace period after the window comes back.
- If raw packets stop arriving, the game falls back to stock input and switches
  back to raw input as soon as real motion returns. The first returning packet
  is discarded so the camera never moves twice. Button-only packets cannot
  trigger the switch. Fixes the jitter and sensitivity changes reported after
  repeated minimizing.
- Three consecutive read errors switch to stock input permanently for that
  session, so control is never lost.
- Disable with the Steam launch option `+legacymouse` or an empty
  `aos_mousefix.disabled` file.

### Movement

- Fixes the jump "launch reset": on every server, the local player's jump now
  keeps its real post-physics position and velocity instead of being snapped back
  to a stale network position on the launch frame (a source of jump
  rubber-banding).
- Only that one exact statement is suppressed. Walking, collision, input timing,
  movement history, teleports and ordinary server corrections stay native.
- Checks the loaded `aoslib.character` and `aoslib.world` binaries against the
  known retail SHA-256 values and skips itself if either is different or already
  patched. All changes are in memory; no EXE, PKG or PYD file is rewritten.
- Disable with `+legacymovement` or `aos_movementfix.disabled`.

### Equipment

- The equipment menu offers the DLC weapons and tools bundled with the game.
- The Specialist and Medic characters can be selected.
- Server class and tool restrictions still apply; Steam ownership, item data and
  networking are untouched. No assets are supplied.
- Disable with `+legacyequipment` or `aos_equipmentfix.disabled`.

### UI

- Smooth (fractional) mouse-wheel scrolling: high-resolution wheels and touchpads
  now scroll lists instead of being ignored or jumping. Non-finite deltas are
  rejected; direction changes reset the remainder.
- Scrolling also works in the match-settings panel when the pointer is over it.
- Menu timer cleanup: leaving a squads/server menu cancels its pending refresh
  timers, and a refresh that closes the menu stops immediately instead of
  touching a closed menu.
- Disable with `+legacyui` or `aos_uifix.disabled`.

### Network and relay browser

- Optional: player-hosted BattleSpades servers advertised over Steam appear in
  the existing Internet/User server browser with a `[Steam]` prefix, searched
  worldwide. Ping shows the Steam route estimate (`-1` until available).
- Favourites and History also keep relay entries (stored by Steam host and
  virtual port in `%LOCALAPPDATA%\AoSRetailFixes`).
- Joining cancels any earlier join; leaving the browser or loading screen drops
  late results. If the helper fails during a match, the player returns to the
  main menu instead of a broken session.
- The game's own ENet connection is used unchanged; it only receives a temporary
  loopback endpoint after the host's greeting has been verified.
- No port forwarding needed. Requires 64-bit Windows and Steam signed in to an
  account that owns the game.
- Experimental: local forwarding and Steam initialization are tested; two-account
  Internet play through Steam Datagram Relay still needs live validation.
- Disable with `+legacynetwork` or `aos_networkfix.disabled`.

### Steam bridge (relay helper)

- New native x64 helper, `relay/aos-retail-relay.exe`, with its own copy of
  Valve's `steam_api64.dll`, so the game's original Steam DLL is never replaced.
- Game datagrams travel between local UDP sockets and Steam networking entirely
  in native code; Python only controls discovery and joining.
- The control channel binds to loopback only and requires a fresh 256-bit token;
  commands and responses are size-bounded, text is hex-encoded UTF-8.
- Each remote player gets its own UDP source port, and the authenticated Steam
  identity is pinned to its game connection (used for bans, vote-kicks and
  password lockouts on the server).
- Advertisements never contain passwords or secrets.
- Hosting is part of the separate [BattleSpades server](https://github.com/KikoTs/BattleSpades)
  (`--steam-p2p --steam-p2p-bridge <path to aos-retail-relay.exe>`).

### Runtime and loader

- `winmm.dll` proxy loader for the 32-bit game: forwards every WinMM call to the
  Windows system DLL and runs the embedded bootstrap on the game's Python main
  thread. No code injection into other processes, no executable byte patches, no
  background threads.
- Every patch can be switched off on its own; a missing or failing patch never
  stops the game from starting. Errors go to `aos_mousefix_loader.log`.
- Patch coordinator installs each fix when its game module loads and replaces
  methods atomically, rolling back if any part fails.
- Unknown `aos.pkg` versions skip all Python patches.
- Replaces the earlier AGEX-derived mouse and equipment files; no AGEX code is
  included.

### Distribution

- New `install.ps1`: finds the Steam game folder, downloads the latest release,
  verifies its SHA-256, backs up every file it replaces, and installs. Can also
  install the full AoS Revival client instead. `-Uninstall` restores the backup.
- Releases are built from source by GitHub Actions and published with
  `AOSPatches-<version>.zip`, a version-less `AOSPatches.zip`, `install.ps1`
  and `SHA256SUMS`.
- Build output (`dist/`, `AOSPatches.zip`) is no longer committed to the
  repository. Builds are deterministic (`/Brepro`, fixed ZIP order and timestamps).

[1.0.0]: https://github.com/KikoTs/AOSPatches/releases/tag/v1.0.0
