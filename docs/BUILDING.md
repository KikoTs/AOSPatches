# Build and validate

Run commands from the AOSPatches root. Build prerequisites are Windows,
PowerShell 5.1+, Visual Studio's C++ x86/x64 tools and a Windows SDK. The full
relay build additionally needs a separately obtained Steamworks SDK:

```powershell
.\build.ps1 -SteamSdk C:\path\steamworks_sdk -Version 1.0.0
```

`build.ps1 -FixesOnly` requires no Steamworks SDK. Each build stages its output
under ignored `build/`, then replaces only this repository's `dist/` after
compilation succeeds, and runs `package.ps1 -Version <version>`. That writes
the release assets to ignored `out/`:

| File | Contents |
| --- | --- |
| `AOSPatches-<version>.zip` | exactly the runtime files in `dist/`, at the ZIP root |
| `AOSPatches.zip` | the same bytes, for the stable `releases/latest/download/AOSPatches.zip` link |
| `install.ps1` | the installer from the repository root |
| `SHA256SUMS` | SHA-256 of the three files above |

`dist/`, `out/` and the ZIPs are build output and are not committed; releases
publish them. `package.ps1` refuses a `dist/` with missing or unexpected files,
and checks every ZIP entry against `dist/` byte for byte.

Builds are deterministic: the compiler and linker run with `/Brepro`, and ZIP
entries have a fixed order and the commit's timestamp (or `SOURCE_DATE_EPOCH`).
The same source revision, toolchain and SDK give the same bytes. The release
workflow uses the Steamworks SDK archive pinned by the BattleSpades C++ client
(`rlabrecque/SteamworksSDK` at `df2baab`, SHA-256
`4df87731a1179f20a9253a4348f6bd8381a8e46e5e3dc58f9db705ef200eea61`), extracted
with its top-level folder stripped. Its `steam_api64.dll` is identical to the
one shipped in earlier builds.

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

Run these after `build.ps1`, which leaves the runtime files in `dist/`.

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

## Releases

Add the version's section to `CHANGELOG.md`, then push a `v*` tag. The
[release workflow](../.github/workflows/release.yml) builds on GitHub's Windows
runners with Windows PowerShell 5.1 and publishes the four files above, using
the changelog section as the release notes. It can be re-run for an existing tag
from the Actions tab; a re-run replaces that release's assets.

## Evidence

[VALIDATION.md](VALIDATION.md) and [NETWORK_VALIDATION.md](NETWORK_VALIDATION.md)
record the original patch validation and its limits. They are historical test
results, not claims that a fresh build has passed Internet gameplay tests.
See [REPOSITORY_VALIDATION.md](REPOSITORY_VALIDATION.md) for checks made when
extracting this standalone project.
