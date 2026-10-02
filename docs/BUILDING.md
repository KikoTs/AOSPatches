# Build and validate

Run commands from the AOSPatches root. Build prerequisites are Windows,
PowerShell 5.1+, Visual Studio's C++ x86/x64 tools and a Windows SDK. The full
relay build additionally needs a separately obtained Steamworks SDK:

```powershell
.\build.ps1 -SteamSdk C:\path\steamworks_sdk
```

`build.ps1 -FixesOnly` requires no Steamworks SDK. Each build stages its output
under ignored `build/`, then replaces only this repository's `dist/` after
compilation succeeds. `AOSPatches.zip` contains exactly the runtime files in
`dist/`, at the ZIP root. There is no extra directory to strip on installation.
Both `dist/` and the ZIP are checked in for direct download; commit their
matching source and build changes together when updating them.

The loader is x86 and the relay helper is x64. Both use `/MT /W4 /WX`; compiler
objects, generated headers, import libraries and scripts stay out of `dist/`.
The build does not edit an installed game or any sibling project.

## Python 2 regression suite

Use a Windows Python 2.7 x86 interpreter. Set the bundle path to your own
legitimate installation to enable the bytecode integration tests:

```powershell
$env:AOS_RETAIL_BUNDLE = 'C:\path\aceofspades\aos.pkg'
python2 -B src/retail/test_fixes.py
python2 -B src/retail/test_movement.py
python2 -B src/retail/test_network.py
python2 -B src/retail/smoke_winmm.py dist/winmm.dll
```

No retail bytecode, game modules or assets are committed here. The tests read
the locally installed bundle and reject an unsupported hash.

## Steam helper

With Steam signed in to an account that owns AppID 224540:

```powershell
py -3 src/relay/smoke.py dist/relay/aos-retail-relay.exe
```

This verifies initialization and relay availability, not a remote connection.
The optional local native transport test uses a separately named executable:

```powershell
src/relay/build.ps1 -SteamSdk C:\path\steamworks_sdk -TestLoopback -OutputDirectory build/relay-test -BuildDirectory build/relay-test-objects
py -3 src/relay/smoke.py build/relay-test/aos-retail-relay-test.exe --loopback
```

The full loopback test also needs a compatible `enet` Python extension
(pyenet), installed separately or exposed through `PYTHONPATH` from a compatible
BattleSpades build. That test dependency is not needed to build or use the
patches. No helper test binary is packaged in `dist/`.

## Evidence

[VALIDATION.md](VALIDATION.md) and [NETWORK_VALIDATION.md](NETWORK_VALIDATION.md)
record the original patch validation and its limits. They are historical test
results, not claims that a fresh build has passed Internet gameplay tests.
See [REPOSITORY_VALIDATION.md](REPOSITORY_VALIDATION.md) for checks made when
extracting this standalone project.
