# Retail Steam relay drop-in

This optional module targets the original Steam AoS client, AppID **224540**,
with the retail bundle hash already supported by the fix loader. It adds
BattleSpades Steam advertisements to the existing Internet/User browser and
routes a selected server through a separate native helper. Windows x64 and a
running, signed-in Steam account that owns AoS are required. Retail remains
32-bit Python 2.7; no Python installation is needed on the player's computer.

## Install and host

Close retail, then extract **AOSPatches.zip** beside `aos.exe`.
Keep the `relay` subfolder intact. It contains `aos-retail-relay.exe` and its
own `steam_api64.dll`. Never put that DLL over retail's original Steam DLL.
Launch the game through Steam normally. Relay entries are prefixed `[Steam]`.
They are searched worldwide; their ping is a Steam route estimate (`-1` means
not yet available), while ordinary Steam server entries retain their existing
query path. Favourites and History also include relay entries that are still
advertised. Refresh again after a server or Steam restarts.

On the hosting PC, run the updated BattleSpades source with:

```powershell
py -3.12 run_server.py --steam-p2p --steam-p2p-bridge "C:\path\AOSPatches\dist\relay\aos-retail-relay.exe"
```

From an updated BattleSpades checkout, pass `--steam-p2p-bridge` pointing to
`AOSPatches/dist/relay/aos-retail-relay.exe` as shown below. For a portable
server build, copy `dist/relay` beside the server EXE. The hosting integration
and server source remain in the separate BattleSpades repository. The original C++ client and its
bundled server were not modified or rebuilt by this feature. Older server
executables need rebuilding from the updated server source before these CLI
options exist.

An explicit path also works:

```powershell
py -3.12 run_server.py --steam-p2p --steam-p2p-bridge "C:\path\relay\aos-retail-relay.exe"
```

No manual port forwarding is needed for the Steam route. The host must keep
BattleSpades and Steam running. Closing its retail game does not close the
server. Its own entry joins locally only when a fresh local host record
matches the advertised session; another machine using that Steam account
cannot be mistaken for the local server.

`--steam-p2p-port 169` selects another Steam virtual port when hosting another
instance on the same Steam account. This is separate from the server's UDP
`--port`. The default virtual port is 168; the allowed range is 0–999.
`--steam-p2p-private` is for validation: it creates a friends-only advertisement
that the public retail-browser search does not enumerate.

Hosting remains optional and off unless `--steam-p2p` is specified. Existing
direct networking and legacy Steam master registration keep their settings.
The relay option does not rewrite `config.toml` or enable port-forwarded
master registration. Hosts configured with `revival.require_identity` are
rejected by this hosting option: retail relay identity does not provide an
AoSPlay ranked/join ticket, and this patch does not bypass that requirement.

## Runtime design

* Python controls asynchronous discovery and joining. Game datagrams travel
  between native UDP sockets and `ISteamNetworkingSockets`, outside Python.
* The helper runs as a separate hidden process and statically links its C++
  runtime. Its control channel binds only loopback and requires a fresh
  256-bit token before accepting responses. Commands and responses are bounded.
* Every remote Steam connection gets its own UDP source port. The server
  registers the authenticated Steam identity before allowing the first game
  datagram, then pins that identity to the ENet peer. Bans, vote-kick cooldowns,
  password lockouts and admin-login limits use it instead of banning localhost.
* Bridge frames are versioned. The host greeting must match the browser's
  session identifier before retail starts its existing connection handshake.
  ENet retains its own protocol 168, channels, compression and reliability.
* New joins cancel old joins. Leaving the browser or loading screen discards
  late completions. A helper failure returns an active relay player to the
  main menu; it does not attempt to splice a replacement into a live ENet match.
* The server retires relay clients when its helper fails and retries hosting
  after ten seconds with a new session identity. Players must rejoin. Steam
  failures leave the direct server running.
* Advertisements contain bounded text and transport metadata, never passwords
  or authentication secrets. Unknown retail modes and texture skins are skipped.
* Favourites/history use Steam host + virtual port, never the temporary local
  UDP endpoint. Retail's exposed rich-presence bindings suppress loopback
  advertisements while a relay match is active.

## Current boundaries

This is an initial implementation. Two-account Internet gameplay through SDR,
the complete live retail UI, full player-count load, long sessions, map changes,
minimize/restore and Steam restart recovery still require live validation.
Local native forwarding and a successful Steam initialization are not proof of
those behaviours. The test executable has an explicit loopback-only build
define; that alternative transport is absent from the shipping executable.

Steam friend-invite joining, a standalone GUI, Linux hosting, Steam-less
dedicated credentials, AoSPlay directory mirroring, and arbitrary third-party
mod APIs are not included in this version. Steam's public lobby search is
bounded, not an exhaustive global directory. No AppID 480 fallback is used.

The retail password prompt and dynamic-port parser were verified using the
installed bundle's actual code objects. Older project notes claiming the
password branch is disabled or that ServerInfo always forces port 32887 do
not describe this supported bundle.

## Disable and remove

Use Steam launch option `+legacynetwork`, or create an empty
`aos_networkfix.disabled` file beside `aos.exe`, then restart. Other fixes keep
working. Removing the network module, its controller and the added `relay`
folder removes this optional feature. EXE/PKG/PYD game files are never rewritten.
Local preferences and temporary own-host records live in
`%LOCALAPPDATA%/AoSRetailFixes`. Diagnostic messages use the existing patch log
and the BattleSpades server log; control tokens are not logged.

## Build and test

Build with Visual Studio C++ tools and a Steamworks SDK containing the modern
networking interfaces:

```powershell
.\build.ps1 -SteamSdk C:\path\steamworks_sdk
```

The relay build reads the SDK only; it has no build or source dependency on
BattleSpadesClient. The helper source is newly written for this retail bridge,
using Valve's SDK interfaces. No AGEX code is used. It is distributed under
the repository's AGPL license and its additional Steamworks linking permission.
Valve's redistributable remains Valve's binary.

```powershell
python2 -B src/retail/test_network.py
py -3 src/relay/smoke.py dist/relay/aos-retail-relay.exe
src/relay/build.ps1 -SteamSdk C:\path\steamworks_sdk -TestLoopback -OutputDirectory build/relay-test -BuildDirectory build/relay-test-objects
py -3 src/relay/smoke.py build/relay-test/aos-retail-relay-test.exe --loopback
```

Only the final two commands use the separately named local test executable.
Never substitute it for the packaged helper or count its results as an SDR
Internet test. The repository includes the helper, controller, retail hooks, build
instructions and tests. The runtime ZIP contains only installation files.
The optional full loopback test requires a separately installed `enet` Python
extension; see [BUILDING.md](BUILDING.md).
