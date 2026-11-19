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
(mobile web) and WebXR (seated or standing, snap or smooth turning, comfort
vignette) are supported. The implementation plan is
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
| ![The holodeck: arch, panel and grid room](docs/shots/m4_holodeck_room.png) | ![Holodeck program: Sunset Beach](docs/shots/m4_program_beach.png) |
| ![Holodeck program: the Seat flight course](docs/shots/m4_program_seat_course.png) | ![Holodeck program: the decoded alien memory](docs/shots/m4_program_memory.png) |
| ![Cooking ember-spiced noodles](docs/shots/m4_cooking.png) | ![Reading a found log at the bookshelf](docs/shots/m4_bookshelf_reading.png) |
| ![The TV gives a hint](docs/shots/m4_tv.png) | ![Docked: the Villa folds down into your hand](docs/shots/m5_pocketing_fold.png) |
| ![The saucer as a coin in your palm](docs/shots/m5_coin_in_hand.png) | ![The station market and its stalls](docs/shots/m5_station_market.png) |
| ![The Drift bar: bartender and patrons](docs/shots/m5_bar_npcs.png) | ![Selling to the scrap dealer on foot](docs/shots/m5_trade_on_foot.png) |
| ![Chasing the pickpocket](docs/shots/m5_pickpocket_chase.png) | ![Unpocketing: the Villa grows onto the far hangar's pad](docs/shots/m5_unpocket_far_hangar.png) |

[Play in browser](https://makesgamessteve-hash.github.io/saucer/) — the live
web build on GitHub Pages, rebuilt on every push to `main`.

**Download:** [Saucer v0.1.0](https://github.com/makesgamessteve-hash/saucer/releases/tag/v0.1.0)
has a Windows x64 zip (unzip and run `saucer.exe`), a Linux x64 tarball
and a web zip (serve the folder over HTTP and open `index.html`). Releases
are built by `.github/workflows/release.yml` whenever a `v*` tag is pushed.

| Before milestone 6 | After the art pass |
|---|---|
| ![Before: the station market](docs/shots/m6_before_07_station_market.png) | ![After: textured hall, signs and a crowd](docs/shots/m6_after_07_station_market.png) |
| ![Before: a derelict hall](docs/shots/m6_before_05b_derelict_hall_chase.png) | ![After: floor grating and glyph inscriptions](docs/shots/m6_after_05b_derelict_hall_chase.png) |
| ![Before: a city plaza](docs/shots/m6_before_06b_city_plaza.png) | ![After: hex paving](docs/shots/m6_after_06b_city_plaza.png) |
| ![Before: space](docs/shots/m6_before_09_space_sky.png) | ![After: nebulae, a planet and a galaxy](docs/shots/m6_after_09_space_sky.png) |
| ![Before: the title](docs/shots/m6_before_01_title.png) | ![After: the title emblem](docs/shots/m6_after_01_title.png) |
| ![Before: the bedroom](docs/shots/m6_before_04_lower_deck_bedroom.png) | ![After: wood, fabric and wall panels](docs/shots/m6_after_04_lower_deck_bedroom.png) |
| ![Before: the Drift bar](docs/shots/m6_before_08_bar_npcs.png) | ![After: folk sprites and the bar sign](docs/shots/m6_after_08_bar_npcs.png) |
| ![Before: the touch overlay](docs/shots/m6_before_10_touch_hud.png) | ![After: highlights, short labels, the floating stick](docs/shots/m6_after_10_touch_hud.png) |

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
| `openspec/` | project conventions and changes 0–25 |

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
| Turn / look | mouse (click to capture, Esc releases), arrows | right stick | drag right half | head; right stick snap-turns 30° (smooth if snap is off) |
| Use: take the helm / stand up / furniture / pick a menu row | G / Return | X | Use button | left trigger |
| Menu up / down (title, bed) | W / S | left stick | left stick | left stick |
| Fold to the Seat / unfold the Villa | Q / E, wheel, 1–2 | LB / RB | buttons | A / B, or grip + stick (size lever) |
| Tractor beam: pull (at the beam console, or in the Seat) | F / left click | A | button | right trigger |
| Beam console: trim position / height / heading | W A S D / Space, Ctrl / mouse, arrows | left stick / triggers / right stick | left stick / slider / drag | left stick / right stick |
| Scanner / Jammer | V / T | Y / right stick click | SCAN / JAM buttons | X / Y |
| Run/boost, camera, help | Shift, C, H | LS, Back, Start | buttons | left grip, —, menu |
| Holodeck program: use a spot / leave at the arch / end a flight run | G / Return | X | Use button | left trigger |
| TV next channel, book next page (on the sofa / at the shelf); get up | G / Return; W A S D | X; left stick | Use; stick | left trigger; left stick |
| Pocket the saucer (docked at a station only) | 3, or Q past the Seat | LB past the Seat | fold button past the Seat | A past the Seat, or the size lever |
| On foot in a station: talk, trade at a stall, the bar, grab the thief | G / Return | X | Use button | left trigger |
| On foot in a station: hold the coin in your fist / pocket it | F | A | tractor button | right trigger |
| On foot in a station: sprint | Shift | LS | run button | left grip |
| Unpocket in a hangar (Villa / Seat) | E or 1 / 2 | RB | unfold button | B, or the size lever |
| Step out in a derelict (set the Seat down within 2 m of a deck) | 3, or Q past the Seat | LB past the Seat | fold button past the Seat | A past the Seat, or the size lever |
| On foot in a derelict: crouch / jet-hop | Ctrl / Space (you also duck into low openings by yourself) | left / right trigger | **dn** / **up** | right stick down / up |
| On foot in a derelict: take loot by hand, turn a hand-lock, shut a grid (hold still) | G / Return | X | Use button | left trigger |
| On foot in a derelict: deploy the Seat and board | E or 1 / 2 | RB | unfold button | B, or the size lever |
| Sector map, party fold jumps, Xenoarchive, requests, the Heart vote | Tab | D-pad right | MAP button | right grip |
| Decoy flare (3 per refill; Watchers and Clamps chase it) | B | D-pad down | DECOY button | — |
| Shroud (hides a still saucer; drains Charge) | X | D-pad left | — | — |
| Grapple (on foot in a derelict, 25 m) | Y | D-pad up | GRP button | — |
| Override spike (hold at a Clamp or Lockdown node, on foot) | N (hold) | B (hold) | — | — |

You wake up in the bedroom on the lower deck. The title card offers **Get
up** or **Load saved game**. Doors slide open as you walk up to them. Take
the stairs to the dome deck and walk to the helm at the front, then press
Use to fly. Press Use again to stand up (the saucer holds station). Use
also works at the stove (cook a meal for a buff), the shower, the engine console, the lab bench and the trade
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

**A story for every run.** Each universe seed also generates a story (no network, no LLM): one of five plot
skeletons filled with that run's civilisations, Echo and betrayals, and now and then a twist. Its clues (wreck
logs, murals, city archive records) are beam targets that point to the next place; the **holotable** in the
living room keeps the Story page, and the Heart ends it. Mystery: off (the sandbox) has no story. Tests:
`tests/lua/story_spec.lua`, `tests/game/story.lua`.

**Home life** (milestone 4). The **holodeck** is the starboard-aft room on
the lower deck, through the lit arch from the engine room; its panel stands
beside the arch. Pick a program and you step into a simulated space: Sunset
Beach and Quiet Forest (lie back for Calm), the Seat Flight Course (fly a
simulated Seat through seven rings against the clock; the first clear pays
25 c), Derelict Replay (walk round a hologram of a site you explored, with
your route and pick-ups) and Resonant Memory (a decoded alien place that
points at the next Echo). Use at a spot does its thing; Use at the arch you
came in by (or anywhere while flying) ends the program. More programs come
from **data cores** in derelict vaults (decode them at the lab bench) or the
trader's shop, and modules found or bought there add space, detail and
co-op guest slots (install them at the panel). The **stove** cooks recipes
from trader groceries and alien ingredients found in vaults for small timed
buffs (well fed, calm, keen, steady; shown top right). The **bookshelf**
fills with found books and logs, Echo transcripts and holodeck memories; a
clue's first read marks a lead (a teal marker on the radar). The **TV** on
the sofa picks up channels from the nearest trader, station and city in
range, each with a gentle hint about what to do next. Holodeck programs are
Lua files under `holo/`, so a mod adds one by dropping in a file (see
`tests/fixtures/mods/holo_garden`).

**Station visits** (milestone 5). Dock at the trader and pick the third
size, **Pocket** (3, or fold once more past the Seat): you step out into
the station's arrival hangar and the saucer folds down into your palm, the
size of a big coin, then you slip it into your pocket. Pocket only works
docked. Walk the station in first person: a concourse with strolling folk
of five species, a **market** whose stall keepers buy and sell face to face
(the scrap dealer pays extra for materials and modules, the curio dealer
for curios and tools; the grocer, archivist and outfitter sell stock, and
the chandler tops up Charge and patches the hull) and a **bar** with drinks
that give buffs and rumours that mark leads. Mind the hooded **pickpocket**:
he follows anyone with a saucer in their pocket. Turn round and look at him
and he melts away; hold the coin in your fist (F) and he cannot take it. If
he lifts it, sprint after him (the HUD shows where he is and how long
before he gets away) and press Use to grab him. If he escapes, the fence at
the bar sells it back, takes your best loot for it or, if you are broke,
hears you out. To leave, walk into either hangar and press E (or 1 / 2):
the coin grows out of your hand onto the pad into the Villa (or the Seat)
and you are aboard at that hangar's space door. It only unfolds in a hangar
with a free bay. The station layout comes from the seed, so it is the same
every visit, and saves made on foot load back on foot.

**On-foot excursions** (milestone 7). Every derelict hides a second layer
that only a person fits: off one great hall a 1 m **crawlspace** leads to a
**chamber** with a hand-lock, a grid console and a Delicate find, and next
to the same hall a **strongroom** is sealed by a shutter. Set the Seat down
by the crawlspace's lit mouth (within 2 m of the deck) and pick Pocket (3,
or fold past the Seat): you step out and the saucer folds into your hand
and pocket. Crawl through (you duck by yourself), take the **Delicate**
find by hand (a beam would crush it; four hands' worth, nothing bigger than
size M), hold Use at the **hand-lock** until the coupling locks home (the
strongroom's shutter grinds open for the saucer) and at the **grid console**
to put every sentry in that derelict to sleep until you leave. Your **Suit
Charge** is the only meter on foot: it drains, faster in crawlspaces and
under a Watcher's lock, hops and the Jammer spend it, stun bolts bite it,
and the HUD warns at 30% and 10%. Press E to deploy the Seat (it needs a
2.2 m sphere of room, so never in a crawlspace) and board: your hands empty
into the hold and the suit refills. Let it run dry and the **Lifeline**
fires: the screen whites out, the Seat deploys on your trail and you wake at
its helm, and what you carried stays behind as a **cache** (on the radar and
the HUD) to walk back for. Then fly through the door you opened and beam up
the strongroom's loot. Watchers see you on foot whatever their size band
and Snatchers tear hot items out of your hands; nothing is lethal.

| | |
|---|---|
| ![Stepping out: the Seat folds into your hand](docs/shots/m7_step_out_fold.png) | ![Crawling through a 1 m crawlspace](docs/shots/m7_crawlspace.png) |
| ![Turning the hand-lock in the chamber](docs/shots/m7_hand_lock.png) | ![Shutting the sentry grid down at its console](docs/shots/m7_grid_console.png) |
| ![Suit Charge critical](docs/shots/m7_suit_critical.png) | ![The Lifeline pulls you back into the Seat](docs/shots/m7_lifeline_pullback.png) |
| ![Walking back for the dropped cache](docs/shots/m7_recover_cache.png) | |

**The wider dark** (milestone 8). Up to **four local players** share the
universe in split screen, each in their own saucer. Start with `--coop`;
press A on a free gamepad, or press **F2** to give the right half of the
keyboard to the next player (`--split-keyboard` does it at start-up). Any
of Use, Menu, Tractor or a size button on a free slot joins. Two players
split side by side (`--split horizontal` stacks them); three or four get
quarters (the spare quarter shows the sector map). Split keyboard for the
second player: I J K L move, arrows look, O / U up / down, Return use,
Comma / Period fold, 7 8 9 sizes, Right Shift tractor, Semicolon scan,
Apostrophe jam, Slash boost, End camera, Home menu, Backslash map, [ decoy,
] shroud, P spike. Eject loot from the **party** panel for a partner to
beam up, dock at another player's Villa and walk round their dome, or
hand things over at the gift table.

The galaxy has **seven sectors** (Home Drift and six more, each with its
own danger, civilisations and music). Open the **sector map** (Tab) and
pick a sector to propose a **party fold jump**; everyone agrees from their
own map, the jump waits until every saucer is the Villa, outside the sites
and has the Fold Core's Charge, then spools for three seconds and the whole
party arrives in formation. Charge comes back in open space. The starting
Fold Core reaches one link of the map; Fold Core upgrades at the trade
terminal (they need reputation there) reach further. Every civilisation is generated from
traits (body, temperament, aesthetic, values and a music scale); the finds
you identify fill its page in the **Xenoarchive** (map → Xenoarchive), and
stations post **requests** that pay credits and reputation. Deeper sectors
add **Clamps** (they grab your hull: no size changes and a Charge drain
until you hold Boost or Jam them) and a **Lockdown** node that seals its
hall's big doors for 60 s when a Watcher locks on. A **Decoy** flare draws
every sentry that sees it for 8 s, the **Shroud** hides a saucer that holds
still, and on foot the **Override spike** (hold 3 s at a disabled sentry or
a Lockdown node) shuts it down for good. The **hive**, the third ruin kit, appears in
the new sectors. The mystery goes on past the vault: the **Witness** Echo
only translates once your Xenoarchive has 25% of its civilisation, it names
the **Heart Key**, and carrying the Key into the core room of **the
Heart** opens it. Everyone at the Heart votes from the map (seal, restore
or take); a tie goes to whoever set the last Key, and the ending changes
the galaxy. The music is generated from each civ's scale and the moment
(space, a site, an alert).

| | |
|---|---|
| ![Two players, vertical split](docs/shots/m8_coop_2p.png) | ![Four players at the Heart](docs/shots/m8_coop_4p.png) |
| ![The sector map](docs/shots/m8_sector_map.png) | ![A party fold jump spooling](docs/shots/m8_fold_jump.png) |
| ![The Xenoarchive](docs/shots/m8_xenoarchive.png) | ![A hive ruin, the third kit](docs/shots/m8_hive_kit.png) |
| ![A Clamp and a decoy flare](docs/shots/m8_clamp_decoy.png) | ![The Heart opens to the Key](docs/shots/m8_heart_site.png) |

**Home among the stars** (milestone 9). **Network co-op**: two to four
machines play one universe in lockstep, each player in their own saucer and
window (or headset). On the desktop one player hosts and the others join
over UDP:

```sh
saucer --host                       # waits on UDP port 47800 for one guest
saucer --host 47800 --net-players 4 # waits for three guests
saucer --join 192.168.1.20          # or --join host.example.org:47800
#   --net-delay N  lockstep input delay in ticks (1-12, default 3; raise it on slow links)
```

The host forwards UDP port 47800 (or the port it picked) if guests come over
the internet. The window title shows the session status. Everyone must run
the same version with the same mods (a guest with a different set is
refused and told why); a machine that leaves is dropped after 8 s and the
others play on. Every 60 ticks the machines compare state hashes and stop
with "DESYNC at tick N" if they ever differ. In the **browser**, press
**Online co-op** on the start page (or open `saucer.html?net=1`): the host
picks Host and copies the offer code to the guest by any chat, the guest
pastes it and sends the answer code back, and the game starts over a WebRTC
data channel (no server of ours in between; STUN only). The web transport
is tested headless; a session between two real browsers is not verified
yet. A browser and a desktop cannot play together yet. A player in a WebXR headset can host or
join; their headset shows their own saucer.

**The dome is yours**: traders sell furniture (lamps, rugs, an aquarium, a
telescope, a hammock, a singing crystal and more) that the **Home planner**
by the helm walk places anywhere on both decks; six **display slots** show
off identified finds; four **garden** beds behind the stairwell grow alien
seeds (water them) into kitchen ingredients. Furniture, displays and plants
add up to **Comfort** (Bare, Homely, Cosy, Beloved), and each point speeds
up Charge regeneration by 2%. Docked guests walk your decorated dome and can
admire what you display. The deepest derelicts (danger 3) keep a **Warden**:
it patrols its great halls, hunts what it sees with stun bolts and wakes
every Snatcher of the site; decoy it, Shroud, or Jam it and spike it. On
foot, **Y** fires the **grapple** and holding **N** with no sentry in reach
runs the **cutter** through a sealed shutter or a Lockdown seal. The
**mod browser** (title card or bed) lists every mod with its description and
why it did not load, and switches mods on or off from the next start.
**Hardcore** (title card, or `--hardcore`) is opt-in for a whole universe:
a Fold Retreat loses all cargo for good, the Lifeline loses what you held,
and there is no loading from the bed.

**After the first playtest** (OpenSpec `add-playtest-recs`): the trade
terminal sells **saucer upgrades**: the helm beam relay (pull small finds
from the helm, no trip to the Tractor Room), and from Fold Core T2 tractor
coils, hold racks, shield cells and a second lab bench. Decodes jump the lab
queue. Folding into deeper danger for the first time asks first (**fold
warning**), the first Watcher lock tips you off about the Seat, and a Fold
Retreat at danger 2 or 3 costs a **tow bill** (credits, then Charge). A shut
grid leaves the Warden awake but slower; the pickpocket strikes on the first
visit and then about one in four. In co-op, **twin vaults** need one saucer
on the shutter anchor while the other beams, traders post **party
requests**, and the party panel has **I'm ready to fold**. Story items ask
before they are sold, and the HUD keeps its messages and alerts short.

| | |
|---|---|
| ![Two network windows side by side: host and guest in one universe](docs/shots/m9_network_two_windows.png) | ![A decorated dome](docs/shots/m9_decorated_dome.png) |
| ![The garden at four stages](docs/shots/m9_garden.png) | ![Finds on the display slots](docs/shots/m9_display_slots.png) |
| ![The mod browser](docs/shots/m9_mod_browser.png) | ![Hardcore on the title card](docs/shots/m9_hardcore.png) |
| ![The Warden hunting in its great hall](docs/shots/m9_warden.png) | |

## Useful options

```
--seed N  --root DIR  --user-dir DIR  --mods a,b  --mods-dir DIR
--local-players N  --viewports N  --coop
--split-keyboard      (with --coop: the right half of the keyboard is player 2; F2 does it in game)
--split horizontal    (two players stacked instead of side by side)
--host [PORT]  --join HOST[:PORT]  --net-players N  --net-delay N   (network co-op)
--hardcore            (a new game starts in Hardcore)
--record FILE.srep  --play FILE.srep  --restore-every-tick
--screenshot FILE.png --screenshot-tick N     (exits after the capture)
--windowed            (with --script: run a scripted tour in a real window, e.g. tools/shots/m3.lua)
--ticks-per-frame N   (windowed scripts: simulate N ticks per drawn frame, 1-600)
--realtime            (windowed scripts: pace to the wall clock, 60 ticks a second; env SAUCER_REALTIME=1)
--headless --ticks N  --script tests/game/slice.lua  --test-lua tests/lua
```

### Recording a scripted tour in real time

A windowed script (`--windowed --script ...`) steps one tick per drawn frame as fast as the machine draws,
which on a fast GPU or a software renderer (Xvfb + llvmpipe, about 100 fps) plays the game faster than
60 ticks a second. For screen recordings add `--realtime` (or set `SAUCER_REALTIME=1`): every frame then
sleeps off the rest of its 1/60 s. With `--ticks-per-frame N` a frame is due N/60 s after the previous one.
A machine too slow to keep 60 ticks a second just runs as fast as it can (the schedule restarts after a
quarter second of lag, with no catch-up burst). The simulation, and so the replay hash, is the same either way.

```sh
xvfb-run -a -s "-screen 0 1280x720x24" build/saucer --windowed --realtime --width 1280 --height 720 \
  --script tools/shots/m4.lua
```

## Tests

```sh
ctest --test-dir build --output-on-failure   # C unit, Lua specs, game tests, replays
tools/coverage.sh                            # coverage gate: >= 95% lines, C (gcovr) and Lua (luacov)
```

`tools/coverage.sh` runs the Lua specs and every game test under luacov in
parallel (`SAUCER_JOBS`, default `nproc`), each with its own stats file that
`tools/luacov_merge.lua` merges; luacov's line hook makes the sim 20-40x
slower, so the slowest run (`mystery.lua`, about 20 min) sets the pace. Every
CTest test has a 30 min timeout (`SAUCER_TEST_TIMEOUT`), each luacov run 40 min
(`SAUCER_COV_TIMEOUT`), and the CI jobs have their own limits, so a game test
that never ends fails instead of hanging CI.

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
  reloads it; `holodeck.lua` runs the beach and the flight course, loots a
  data core, decodes it, runs the replay and the alien memory, reads a found
  log, watches the TV, cooks for a buff and installs a bought module;
  `station.lua` docks, pockets the saucer, walks the station, sells at a
  stall, tops up at the chandler, drinks at the bar, gets robbed and runs the
  thief down, saves, unpockets in the far hangar and flies away (also with
  `--restore-every-tick` and on seed 7);
  `hatch.lua` lands the Villa on a platform (refusing a drop-off and a slope), opens
  the hull hatch after the suit seals, walks down the stairs, walks away so the
  hatch shuts, folds the Villa into the pocket from outside, unfolds it on its
  gear, climbs back in and lifts off (also with `--restore-every-tick`);
  `dock.lua` approaches a station's hangar bay (the tractor beam takes over,
  pulling away lets go, Land asks for a tow), docks on the pad with the clamps
  closed, walks out through the hatch into the bay's air, through the bay door
  into the station and back, folds the Villa into the pocket, refuses an unfold
  into a wall and unfolds it in the open, then lifts off and rides the beam out
  (also with `--restore-every-tick`);
  `land_anywhere.lua` reads the landing readout and lands on a wreck's hull, a moon,
  a planet and an asteroid city's plazas and a rooftop pad (checking what the saucer says it stands on and
  the suit's environment), then pulls the ground away from under the gear and watches the thrusters take over
  (also with `--restore-every-tick`);
  `excursion.lua` sets the Seat down by a derelict's crawlspace, steps out,
  crawls to the chamber, lifts a Delicate find, turns the hand-lock, shuts
  the grid, saves, lets the suit run dry for the Lifeline, recovers the
  dropped cache by hand, deploys and boards, then flies through the opened
  shutter and beams up the strongroom's loot (also with
  `--restore-every-tick` and on seed 7);
  `boot.lua` covers touch, XR and rendering; `coop.lua` runs two players;
  `mods.lua` loads the fixture mods (one adds a holodeck program);
  `netplay.lua` runs as two processes on loopback (`tools/net_loopback.cmake`:
  a host and a guest in a WebXR session decorate the dome, dock and visit,
  and must end on the same final hash after at least ten hash checks; also on
  seed 7 with a longer delay), `netdesync.lua` checks that a forced
  divergence is reported on both sides, and `modbrowser.lua` switches a mod
  off and on across two starts (`tools/mod_browser.cmake`).
- **Network**: `tests/c/test_net.c` runs the lockstep protocol over a lossy
  in-memory transport (two and four players, desyncs, rejects, timeouts);
  `tests/web/net_web.test.js` runs the web transport headless under node with
  a fake RTCPeerConnection pair (offer and answer codes, the data channel).
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
See `tests/fixtures/mods/bigger_tractor` for a small example. A `description`
in `mod.lua` shows in the in-game **mod browser**, which writes the folders
you switch off to `<user-dir>/mods.txt` (used when `--mods` is not given).

Notes for modders: index-map textures are 8-bit grayscale PNGs whose values
are palette indices (index 0 is transparent); palettes are PNG strips with
one row of 256 colours per palette. Library modules loaded with `require`
are shared between the sim and render hooks, so keep their module tables
free of mutable sim state.

## Art

Low-poly geometry built entirely by Lua mesh recipes (`data/base/meshes`),
palette-locked textures, sprites and a low-res target with nearest-neighbour
upscaling. The textures, sprites, signs, glyphs, sky backdrops and the title
emblem were generated with Grok Imagine (22 prompts, every one in
`art/prompts/log.jsonl`) and then downscaled and quantized to small
palettes. Sounds are synthesized in code (`artpipe` writes the `.wav`s).
`python3 tools/artpipe/artpipe.py build` rebuilds the processed assets and
`ATTRIBUTION.md`; `lint` checks licenses and prompts.

### WebXR comfort

"VR seated" uses the `local` space with your eyes at the cockpit eye;
"VR standing" uses `local-floor` and your real height. The right stick
snap-turns 30° per flick by default; `saucer.xr.set_comfort({snap = false})`
switches to smooth turning and `{vignette = 0..1}` sets the comfort
vignette. The flat HUD is off in the headset: your controllers show as
hands, and the left wrist panel shows charge, hold and beam lock. Seated
and standing sessions are covered by `tests/game/xr.lua`.

## License

Code: MIT. Hand-made and code-generated art and sound: CC BY 4.0. Images
generated with Grok Imagine: xAI output terms ("Created with Grok"). See
[LICENSING.md](LICENSING.md) and [ATTRIBUTION.md](ATTRIBUTION.md).
