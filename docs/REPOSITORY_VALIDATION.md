# Standalone repository validation - 2026-10-02

This records the AOSPatches extraction, separate from the original gameplay
and server test runs in the other validation documents.

Passed on Windows:

- The fixes-only build compiles the x86 loader and produces exactly six runtime
  files, both in `dist/` and at the root of `AOSPatches.zip`.
- The full build compiles the x86 loader and x64 relay helper with `/W4 /WX /MT`
  and produces exactly ten runtime files. No source tree, documentation,
  compiler output, tests or local configuration are in the archive.
- The ZIP integrity check passes, every entry matches `dist/`, and the complete
  AGPL license, additional permissions, third-party notices and Revival notice
  are retained as comments in `aosfix_runtime.py`.
- The production helper has no `AOS_RELAY_TEST_PORT` transport switch.
- Valve's bundled `steam_api64.dll` has a valid Authenticode signature.
- All 59 existing fix tests, 18 movement tests and 20 networking tests pass
  under Python 2.7 x86, including tests against the locally installed retail
  bundle: **97 Python tests** in total.
- All retail Python source and packaged runtime modules compile under both
  Python 2.7 and Python 3.12 without writing bytecode into `dist/`.
- The rebuilt loader passes 10,000 forwarded WinMM timer calls and audio-device
  checks.
- The rebuilt production helper initializes under AppID 224540, validates the
  signed-in Steam identity and reports relay access available. No remote player
  was connected during that probe.

No original game files or C++ client files were modified. BattleSpades keeps
its server implementation and existing patch source; this is an independent
copy with its own Git repository and build scripts.

## Release packaging - 2026-10-02 (v1.0.0)

- Build output (`dist/`, `AOSPatches.zip`) removed from the repository; releases
  publish it instead. `build.ps1`/`package.ps1` build it from source alone.
- Two consecutive full builds produced byte-identical `winmm.dll`,
  `aos-retail-relay.exe` and ZIP (`/Brepro`, fixed ZIP order and timestamps).
- 59 fix, 18 movement and 20 networking tests pass under Python 2.7 x86 against
  the installed retail bundle; the rebuilt loader passes the 10,000-call WinMM
  smoke test.
- `install.ps1` was tested on Windows PowerShell 5.1 against a copy of the game
  in a folder whose path has spaces and Cyrillic letters: a fixes-only install
  over an earlier manual install, a clean install, and the full AoS Revival
  0.1.12 client (1,289 added, 16 replaced, 3,736 identical files). After each
  `-Uninstall`, every file and folder of the copy matched the pre-install
  snapshot byte for byte. An unwritable folder is detected and elevation is
  only offered, never forced.
- 1.1.0: `AOSPatches-Installer.cmd` with the fixes-only `install.ps1` was run
  against a fresh copy of the game in a folder whose path has spaces and
  Cyrillic letters, with the folder passed both as `AOSPATCHES_GAMEDIR` and as
  a forwarded `-GameDir` argument: install (9 replaced, 1 identical), then
  uninstall from the update/uninstall menu; all 15,246 files and every folder
  matched the pre-install snapshot byte for byte. Declining the question exits
  with code 2 and changes nothing.

Two-account Internet SDR gameplay and full retail UI validation remain
outstanding as described in [NETWORK_VALIDATION.md](NETWORK_VALIDATION.md).
