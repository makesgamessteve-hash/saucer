# Saucer

A first-person retro-3D exploration game. You are a person living inside a
flying saucer: at its biggest it is a glass dome you walk around in — an
open-plan kitchen, living room and helm under the glass, with a bedroom,
bathroom and engine room on the deck below. Walk to the helm, take the seat
and fly through a randomly generated universe to huge alien derelicts, so big
that the whole saucer flies inside their halls. Only for really tight ducts
does the saucer reconfigure around you, folding everything else away until
it is a one-seat car (the Seat), and unfold again once there is room. No
lethal weapons: the risk is losing the loot you haven't banked yet.

The vertical slice (concept v0.4, [`docs/concept.md`](docs/concept.md)): walk
the two decks, take the helm, fly the Villa into a derelict's great halls,
hover over loot, walk down to the Tractor Room and beam it up (it shrinks on
the way into the hold), fold down to the Seat for a duct, come back
out, unfold, and leave the site to bank it. Keyboard/mouse, gamepad, touch
(mobile web) and basic WebXR are supported. The implementation plan is
[`docs/ROADMAP.md`](docs/ROADMAP.md).

| | |
|---|---|
| ![Kitchen and living room under the dome](docs/shots/kitchen_dome.png) | ![At the helm in a derelict's great hall](docs/shots/helm_great_hall.png) |
| ![Bedroom on the lower deck](docs/shots/bedroom.png) | ![Engine room](docs/shots/engine_room.png) |
| ![The Seat in a tight duct](docs/shots/seat_duct.png) | ![Waking up: the title card](docs/shots/wake_title.png) |
| ![The helm console: radar desk and wing screens](docs/shots/helm_console.png) | ![Folding: rooms pack away one by one](docs/shots/fold_packing.png) |
| ![The bedroom door slides open](docs/shots/door_open.png) | ![Sleep in the bed to save](docs/shots/bed_save.png) |
| ![The lab bench identifies and decodes](docs/shots/lab_bench.png) | ![Selling at the trade terminal](docs/shots/trade_terminal.png) |
| ![A Watcher locks on, Scanner cones shown](docs/shots/watcher_locked.png) | ![A Snatcher siphons from the Seat](docs/shots/snatcher_latch.png) |
| ![The Resonant vault](docs/shots/resonant_vault.png) | ![The vault opens: the Curio](docs/shots/vault_curio.png) |
| ![Detail pass: kitchen props under the dome frame](docs/shots/detail_02_kitchen.png) | ![Detail pass: engine room machinery](docs/shots/detail_03_engine_room.png) |
| ![Detail pass: a starship hall with panels, pipes and lit strips](docs/shots/detail_07c_derelict_hall_chase.png) | ![Detail pass: a station hall with hazard frames and glyphs](docs/shots/detail_08b_station_hall.png) |
| ![Detail pass: city towers with window grids](docs/shots/detail_09_city_towers.png) | ![Detail pass: a city plaza with paths, planters and a fountain](docs/shots/detail_10_city_plaza.png) |

[Play in browser](https://makesgamessteve-hash.github.io/saucer/) — the live
web build on GitHub Pages, rebuilt on every push to `main`.

## Layout

| Path | What |
|---|---|
| `engine/src/core` | C11 engine core (no SDL): sim loop, Lua runtime + `saucer.*` API, VFS, mods, input, physics, mesh builder, serializer, replays |
| `engine/src/platform` | SDL3 window/input/audio, OpenGL 3.3 / WebGL2 renderer |
| `web/` | emscripten shell page and WebXR glue |
| `data/base/` | the base game, itself a mod: Lua scripts, data tables, mesh recipes, palettes, sprites, sounds |
| `mods/` | user mods (`mods/<id>/mod.lua`), created beside the binary |
| `tests/` | C unit tests, Lua specs, headless game tests, replays, fixtures |
| `tools/` | `artpipe` (asset pipeline + license lint), `coverage.sh` |
| `openspec/` | project conventions and changes 0–24 |

Assets are never baked into the binary: the build copies `data/` next to the
executable, and the web build fetches the files listed in `data/index.json`.

## Build

Requirements: CMake ≥ 3.20, a C11 compiler, Ninja (optional). SDL3 is used
from the system if found, otherwise fetched and built (`SAUCER_FETCH_SDL`).

```sh
# Linux
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/saucer                    # windowed game
./build/saucer_headless --help    # no window, no SDL

# Windows (MSVC)
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
build\Release\saucer.exe

# Web (emscripten); serve build/web over HTTP and open saucer.html
# A live build is also at https://makesgamessteve-hash.github.io/saucer/
emcmake cmake -S . -B build/web -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/web
python3 -m http.server -d build/web 8000   # http://localhost:8000/saucer.html?seed=42
```

macOS is not a target for now.

## Controls

| | Keyboard / mouse | Gamepad | Touch | WebXR |
|---|---|---|---|---|
| Walk (on foot) / fly (at the helm) | W A S D | left stick | left stick | left stick (walks where you look) |
| Fly up / down (at the helm) | Space / Ctrl, or R / Z | right / left trigger | right slider, or the **up** / **dn** buttons | right stick (up / down) |
| Climb / dive | look up or down and fly forward (thrust follows your view) | right stick + left stick | drag + stick | right stick + left stick |
| Turn / look | mouse (click to capture, Esc releases), arrows | right stick | drag right half | head, right stick |
| Use: take the helm / stand up / furniture / pick a menu row | G / Return | X | Use button | left trigger |
| Menu up / down (title, bed) | W / S | left stick | left stick | left stick |
| Fold to the Seat / unfold the Villa | Q / E, wheel, 1–2 | LB / RB | buttons | A / B, or grip + stick (size lever) |
| Tractor beam: pull (at the beam console, or in the Seat) | F / left click | A | button | right trigger |
| Beam console: trim position / height / heading | W A S D / Space, Ctrl / mouse, arrows | left stick / triggers / right stick | left stick / slider / drag | left stick / right stick |
| Scanner / Jammer | V / T | Y / right stick click | SCAN / JAM buttons | X / Y |
| Run/boost, camera, help | Shift, C, H | LS, Back, Start | buttons | left grip, —, menu |

You wake up in the bedroom on the lower deck. The title card offers **Get
up** or **Load saved game**. Doors slide open as you walk up to them. Take
the stairs to the dome deck and walk to the helm at the front, then press
Use to fly. Press Use again to stand up (the saucer holds station). Use
also works at the kitchen (a meal makes Charge recharge faster for five
minutes), the shower, the engine console, the lab bench and the trade
terminal. At the bed, Use offers sleep until morning, which refills Charge
and **saves the game**, or loading the last save. Folding on foot forms
the Seat around wherever you stand and seats you in it. The rooms visibly
pack away one after another before the hull shrinks.

**The tractor beam** shines straight down from the saucer's belly, so the
saucer has to be put over the loot first. Hover above it (Villa: 3 to 45 m
above, inside a 20° cone), level and still, with long scrap (size L and up)
lying along the keel within 15°. The HUD scope at the bottom right shows
where the target is under the beam and a hint says what to fix ("OFF AXIS -
MOVE LEFT 3M", "LONG SCRAP - TURN RIGHT 40 DEG", "TOO HIGH - DESCEND 6M",
"LEVEL THE HULL", "HOLD STILL"). The Villa's beam is run from the **Tractor
Room**: stand up from the helm (the saucer holds station), take the stairs
down beside the engine, and press Use at the beam console. You look down
through the floor window; the stick, Space/Ctrl and turn trim the saucer
slowly, F pulls, Use gets up. The item rises up the beam and shrinks to fit
the hold while the belly hatch opens. Getting up, folding or drifting away
drops it. The Seat has a small beam of its own: hover just above small
loot and press F from the seat.

The loop (milestone 3): loot comes in unidentified. Queue it at the **lab
bench** (it works while you fly, as long as you are the Villa), then dock
at the trader and sell at the **trade terminal** (prices fall with every
sale of a kind and recover over time; every sale saves). Derelicts 2 and 3
are guarded: Watchers in the great halls ignore the Seat but stun the
Villa, and Snatchers in the ducts siphon hot loot from a Seat and carry it
to their nest. **V** scans, **T** jams. Nothing is lethal: at hull 0 you
Fold Retreat to the trader and your hot loot waits as a cache. Follow the
optional Echoes (Who → Where → Key) to the Resonant vault.

Press A on a second gamepad (with `--coop`) to join as player 2; each player
lives in and flies their own saucer. `--local-players 2 --viewports 2` starts split screen.

## Useful options

```
--seed N  --root DIR  --user-dir DIR  --mods a,b  --mods-dir DIR
--local-players N  --viewports N  --coop
--record FILE.srep  --play FILE.srep  --restore-every-tick
--screenshot FILE.png --screenshot-tick N     (exits after the capture)
--windowed            (with --script: run a scripted tour in a real window, e.g. tools/shots/m3.lua)
--headless --ticks N  --script tests/game/slice.lua  --test-lua tests/lua
```

## Tests

```sh
ctest --test-dir build --output-on-failure   # C unit, Lua specs, game tests, replays
tools/coverage.sh                            # coverage gate: >= 95% lines, C (gcovr) and Lua (luacov)
```

- **C unit tests** (`tests/c`): known-answer vectors for the RNG and the
  deterministic math (`tests/data/*_kat.txt`; regenerate with
  `SAUCER_WRITE_KAT=1`), VFS, serializer, replays, mods, renderer lists,
  input, touch, XR, engine lifecycle.
- **Lua specs** (`tests/lua/*_spec.lua`) for every base-game module.
- **Game tests** (`tests/game`): headless, seeded, scripted input
  (`saucer.test.press/axis/touch/xr/wait`). `slice.lua` plays the whole
  vertical slice (walk to the helm, fly into the halls, fold for a duct,
  unfold, bank, walk to the kitchen); `interior.lua` tours both decks on foot;
  `fold.lua` checks that the rooms pack away in a staggered order (farthest
  first) while the hull holds its size, then unpack nearest first;
  `home.lua` covers wake-up, doors, kitchen/engine/lab/trade Use, and sleep
  to save then load; `trade.lua` identifies, sells against the price
  formula, and saves and loads the economy; `sentries.lua` plays a sentry
  encounter (Watcher lock, Snatcher latch, Jammer, nest, Fold Retreat and the
  cache); `mystery.lua` plays the whole Echo chain to the vault's Curio and
  reloads it;
  `boot.lua` covers touch, XR and rendering; `coop.lua` runs two players;
  `mods.lua` loads the fixture mods.
- **Replays** (`tests/replays/*.srep`): recorded command frames with a state
  hash every 60 ticks; they must reproduce bit-for-bit on Linux, Windows and
  wasm. Re-record after an intended sim change with
  `saucer_headless --seed 42 --script tests/game/slice.lua --record tests/replays/slice_seed42.srep`.
  Saves are written by the sim itself (bed → sleep), and loading rebuilds
  the universe from the saved seed plus diffs. The committed replays never
  load a save, so they stay independent of the user directory.

CI (`.github/workflows/ci.yml`) runs linux-gcc with the coverage gate and an
Xvfb screenshot, linux-clang with ASan/UBSan, windows-msvc, emscripten
(tests under node plus the web build) and a lint job (OpenSpec validation,
asset licenses and prompt records). Pushing to `main` also builds the
emscripten web target and deploys it to
[GitHub Pages](https://makesgamessteve-hash.github.io/saucer/).

## Modding

Every mod is a folder with a `mod.lua` manifest (`id`, `version`, `api = 1`,
`depends`, `load_after`, `entry`, `license_code`, `license_assets`). Files in
later mods override files at the same path in earlier ones, scripts run in a
sandbox with an instruction budget, and `on_render` gets a read-only state.
See `tests/fixtures/mods/bigger_tractor` for a small example.

Notes for modders: index-map textures are 8-bit grayscale PNGs whose values
are palette indices (index 0 is transparent); palettes are PNG strips with
one row of 256 colours per palette. Library modules loaded with `require`
are shared between the sim and render hooks, so keep their module tables
free of mutable sim state.

## Art

Low-poly geometry built entirely by Lua mesh recipes (`data/base/meshes`),
palette-locked textures, sprites and a low-res target with nearest-neighbour
upscaling. Two textures were generated with Grok Imagine; every prompt is in
`art/prompts/log.jsonl`. `python3 tools/artpipe/artpipe.py build` rebuilds
the processed assets and `ATTRIBUTION.md`; `lint` checks licenses and prompts.

## License

Code: MIT. Hand-made and code-generated art and sound: CC BY 4.0. Images
generated with Grok Imagine: xAI output terms ("Created with Grok"). See
[LICENSING.md](LICENSING.md) and [ATTRIBUTION.md](ATTRIBUTION.md).
