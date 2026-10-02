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

Two-account Internet SDR gameplay and full retail UI validation remain
outstanding as described in [NETWORK_VALIDATION.md](NETWORK_VALIDATION.md).
