# Third-party notices

AOSPatches source is AGPL-3.0-or-later with the additional permissions in
[LICENSING.md](LICENSING.md). The following notices retain their original scope.

## AoS Revival

The mouse, wheel, timer and movement work was informed by Revival-original
contributions. The complete scoped original-code/MIT notice is preserved in
[licenses/LICENSE-Revival.txt](licenses/LICENSE-Revival.txt). It expressly
excludes proprietary upstream game code, assets and third-party components.
See [implementation provenance](docs/PROVENANCE.md) for the source of each fix.

## Earlier BattleSpades MIT notice

The following notice is retained from BattleSpades for any earlier
MIT-licensed contributions present in the extracted work:

```
MIT License

Copyright (c) 2026 KikoTs and the BattleSpades contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Valve Steamworks runtime

`relay/steam_api64.dll` in the release ZIP is the unmodified x64 Steamworks redistributable.
Copyright Valve Corporation. All rights reserved. This file is subject to
Valve's Steamworks SDK terms, not the AGPL. The project license and additional
permission do not replace those terms. The proprietary SDK source, headers,
import libraries and tools are not part of this repository.

Valve documents the runtime beside applications using its API in the
[Steamworks API overview](https://partner.steamgames.com/doc/sdk/api).
Obtain the SDK through [Steamworks](https://partner.steamgames.com/doc/sdk).

## Game and platform dependencies

The original Ace of Spades game, its Python runtime, native modules and assets
are provided by the player's own installation and are not distributed here.
Windows system libraries are loaded from Windows. No game-content license or
trademark permission is granted by this repository.

Native binaries are built using Microsoft's C++ runtime in static-link mode.
Microsoft runtime components retain their applicable Visual Studio terms.
No CPython, Pyglet, ENet or pyenet runtime is bundled by AOSPatches; the native
loopback development test optionally uses an operator-provided pyenet build.
