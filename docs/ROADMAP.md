# Saucer — implementation plan

> 2026-11-15. Adapts concept v0.3 §17 (MVP / M2 / M3) to the v0.4 first-person,
> interior-centric design. Design source: [`concept.md`](concept.md). OpenSpec
> changes live in `openspec/changes/`. This file is the living roadmap.

You play as a person inside the saucer. The Villa is a walkable glass-dome
home (kitchen, living room and helm on the dome deck; bedroom, bathroom and
engine on the lower deck). Derelicts are huge halls the whole Villa flies
into. The saucer folds to the one-seat Seat only for tight ducts. There are
no lethal weapons: the risk is losing loot you haven't banked.

Cruiser, Pod and Pocket are not in the base game (mods may add sizes).
Stepping out of the saucer was post-MVP; it is back since milestone 7
(on-foot excursions in derelicts).

## 0. Engine spine — done

**Goal.** A deterministic C11 + Lua 5.4 engine that runs on Windows, Linux
and Web (including basic WebXR), with tests from day one.

**Deliverables.** Fixed-tick sim, command frames, `saucer.*` API, VFS and
mods, mesh builder, retro renderer, artpipe skeleton, replay/hash harness,
one saucer per player (headless co-op ready), CI (gcc, clang + sanitizers,
MSVC, emscripten, lint), GitHub Pages deploy.

**Done when.** `ctest` is green on every CI job, C and Lua line coverage
are ≥ 95 %, and the web build is live on Pages.

## 1. Walkable home (vertical slice) — done

**Goal.** Prove the core fantasy: you live in the Villa, fly it from the
helm into huge derelicts, and fold to the Seat only when a duct demands it.

**Deliverables.** First-person avatar; two-deck interior with collision and
code-generated meshes; take/leave the helm; two sizes (Villa, Seat) with
Charge costs and a red ghost when unfold is blocked; derelict halls sized
for the Villa; tractor loot through the glass (since v0.8: from the Tractor Room, see 3⅞); bank at the trader; basic
keyboard/mouse, gamepad, touch and WebXR; `slice.lua` and `interior.lua`.

**Done when.** Those game tests pass (including wasm), the slice replay
hashes, and the game is playable at
<https://makesgamessteve-hash.github.io/saucer/>.

## 2. Live-in interior — done

**Goal.** The Villa feels like a home you use, not a set you walk through.

**Deliverables.** A helm console that does not swallow the view; a real
fold (rooms pack into fold-space, not a uniform scale); doors; usable
furniture (kitchen, living room, bedroom, bathroom, engine, and the lab
bench as a place); a title or wake-up in the home.

**Done when.** Folding shows rooms packing away; the helm view is usable in
flight; at least one Use interaction besides taking the helm exists;
screenshots and Pages are updated.

**Status (2026-11-15).** Done in OpenSpec change `add-live-in-interior`.
You wake up in the bedroom to a title card (Get up / Load saved game). The
bedroom and bathroom have sliding doors that open as you approach. Use
works at the kitchen (a meal speeds up Charge regeneration), shower, engine
console (Charge readout), lab bench, trade terminal, and bed (sleep until
morning, which saves; or load). The helm is a low desk with a radar plus
two side wing screens (Charge, hull, shield; hold slots and size ladder),
and it stays below the sight line in flight. The fold packs the 11 room
groups one by one, farthest from you first: each flattens, then slides into
fold-space. Only after that does the hull shrink about your eye. Unfolding
runs in reverse. Shrink now takes 1.5 s and grow 1.8 s (concept v0.5) so the
packing can be read. Tests: `tests/game/fold.lua`, `tests/game/home.lua`
(also with `--restore-every-tick`), and `tests/lua/home_spec.lua`.
Screenshots: `docs/shots/wake_title.png`, `door_open.png`,
`helm_console.png`, `fold_packing.png`, `fold_packing_late.png`,
`bed_save.png`.

## 3. One-sector loop — done

**Goal.** The explore → identify or sell loop is fun, and the only risk is
losing unbanked loot.

**Deliverables.** Lab identification; trader prices and demand; Watcher and
Snatcher with Scanner and Jammer; hot/banked items and Fold Retreat; a
3-node seeded mystery you can ignore; save/load with per-player records.

**Done when.** Headless tests cover identify, trade, a sentry encounter,
the mystery chain, and save/restore, on all CI platforms.

**Status (2026-11-15).** Done in OpenSpec change `add-one-sector-loop`
(it also completes most of the trading, sentries-and-tools,
hazards-and-failure, mystery and items changes). Loot comes in as
"Unknown <Civ> <Category> T<tier>"; the lab bench identifies it in
30 s × tier for 3 Charge and decodes Echoes, while you fly, as long as you
are the Villa. Dock at the trader and the trade terminal pays
base × tier × (1+affixes) × civ rarity × demand × 0.6 (or 0.4 unidentified).
Demand falls 0.05 per sale and recovers 0.01 per sim minute, and every
transaction saves. Derelicts 2 and 3 are guarded (the tutorial one is not):
ceiling Watchers in the great halls ignore the Seat but stun the Villa's
shields and hull, and duct Snatchers siphon one hot item from a Seat in 3 s
and carry it to a nest you can tractor it back from. Scanner (V) reveals
them for 10 s; Jammer (T, touch JAM) disables them for 12 s. At hull 0 the
saucer Fold Retreats to the trader and the hot items stay behind as a cache.
The optional mystery runs Who → Where → Key; decoding Where reveals the
Resonant vault, and the Key opens it for a unique Curio and a teaser. Save
diffs now include traders, the clock, nests, caches, the vault, credits and
the lab queue. Tests: `tests/game/trade.lua`, `sentries.lua`, `mystery.lua`
(the last two also pass with `--restore-every-tick`), and
`tests/lua/loop_spec.lua`. Screenshots: `docs/shots/lab_bench.png`,
`trade_terminal.png`, `watcher_locked.png`, `snatcher_latch.png`,
`resonant_vault.png`, `vault_curio.png`. Deferred: trader stock and
modules, grid consoles, on-foot Snatchers.

## 3½. True 3D — done

**Goal.** Steve: "adapt the engine to be true 3d. The saucer should be able
to fly up and down. The alien ships/stations/cities should also expand in
all directions and should be huge."

**Status (2026-11-15).** Done in OpenSpec change `add-true-3d-flight`
(concept v0.7). Flight has six axes: thrust follows where you look, so you
climb or dive by looking up or down. Lift is Space/Ctrl or R/Z, the gamepad
triggers, the touch slider or the new up/dn buttons, or the XR right stick.
Dampening brakes to an altitude hold. The hull banks up to about 10° into
turns, with the interior and your eye locked to it, and the deck otherwise
stays level. Derelicts grow in all six directions through hatches and
shafts. Each kit (starship, station, and the new city kit) guarantees a
minimum vertical span and number of levels. Spines, trusses and towers make
every site span well over 100 m on every axis, and the sites sit at
different heights. The radar is 3D and the HUD has an altitude tape and
UP/DN cues. Sentries, scanner, jammer, mystery and caches work in 3D.
Physics has a grid broadphase, and rendering has chunk culling, LOD and fog.
Tests: `tests/game/vertical.lua`, `tests/game/derelict3d.lua` (seeds 42 and
7), `tests/c/test_phys3d.c`, plus new flight and ruin specs with layout
known answers. The sim version is 5 and the save format is 2. Screenshot
tour: `tools/shots/true3d.lua`. Known gaps: XR has no bank and no
head-steered flight path, the hull never truly pitches, and the trader
station has no collision.

## 3¾. Detail pass — done

**Goal.** Steve: "add details to the saucer and to the alien structures".

**Status (2026-11-16).** Done in OpenSpec change `add-detail-pass`. The
Villa has decor in every room (kitchen appliances, cushions, shelves,
plants, bed dressing, a bathroom with basin, mirror and towels, lab jars),
railings with balusters, lit stair nosings, dome struts, trim and ceiling
ribs. The engine room has tanks, pipes and two spinning rotors and pistons.
The hull has seams, lights, antennas, a dish and glowing thrusters.
Derelicts get seeded, visual-only detail per kit (`view/detail.lua`): wall
panels, pipes, lit strips, glyphs, beams, cables, torn sections, floating
debris and props. Towers get window grids, ledges and roof gardens,
trusses get bracing and solar wings, spines get ribs and nozzles, and
cities get sky bridges. Each kit has its own texture. Detail meshes are
budgeted, built lazily (6 per frame), drawn within 480 m and culled per
chunk, and far saucers skip their rooms. Tests: `tests/lua/detail_spec.lua`.
Screenshot tour: `tools/shots/detail.lua`. Known gaps: props, debris and
bridges have no collision, and the engine rotors only approximate the bank.

## 3⅞. Belly tractor beam — done

**Goal.** Steve: "collect the loot/scrap with some kind of tractor beam that
also shrinks. This has to be done from a special room at the bottom of the
saucer. The saucer has to be positioned at the fitting position and
orientation to make that possible."

**Status (2026-11-16).** Done in OpenSpec change `add-tractor-beam`. A cone
beam fires straight down from the belly. It takes a target only inside its
depth range and cone, with long scrap along the keel, the hull level and
still, and a clear line of sight (`sim/tractor.lua`). The Villa runs it from
the new **Tractor Room** (a third deck down a stair beside the engine:
floor window, belly hatch iris, sling seat with console arms, cargo tube,
hold racks). At the console the controls trim the hovering saucer, F pulls
and the item rises and shrinks into the hold. The Seat has a mini beam fired
from the seat. HUD scope and hints, console scope, beam cone, motes, target
ring and keel line. Tests: `tests/game/tractor.lua` and unit specs.
Screenshot tour: `tools/shots/tractor.lua`. Known gaps: sentries ignore the
beam; the Tractor Room has no own sound loop (it reuses the tractor sounds).

## 4. Holodeck and home life — done

**Goal.** Steve: a holodeck with different programs that can be extended
and upgraded later, plus cooking, reading and watching TV in the saucer.

**Deliverables.** A Holodeck room on the lower deck with a program library;
each program is a Lua mod under `data/base/holo/` (relax scenes, a Seat
flight course, replays of explored derelicts, recreations of decoded alien
places that feed the mystery). Programs come as loot (data cores the lab
decodes) or from traders; upgrade modules add room size, detail and
co-op slots. Cooking at the kitchen from trader and alien ingredients, with
small buffs. A bookshelf that fills with found books and logs (lore and
clues). A TV that picks up channels from nearby stations and cities, used
as a gentle hint system.

**Done when.** A game test loads and runs two holodeck programs, installs
an upgrade, cooks a meal for a buff, reads a found log and gets a hint from
the TV; a mod adds a program without engine changes.

**Status (2026-11-17).** Done in OpenSpec change `add-holodeck-home-life`.
The Holodeck is the starboard-aft room of the lower deck behind a lit arch
from the engine room, with its panel by the arch (`sim/holo.lua`,
`view/holo.lua`). Programs are files under `holo/` found through the VFS in
base and every mod: Sunset Beach and Quiet Forest (Calm), the Seat Flight
Course (seven rings, best time, first-clear bonus), Derelict Replay (a
hologram of an explored site with the recorded route and pick-ups) and
Resonant Memory (a decoded alien place that marks the next Echo's site).
Vault finds per kit bring data cores (decoded at the lab), modules (space
6/10/15, detail, guest slots), books and alien ingredients; the trader sells
groceries, a program, modules and books. The stove cooks for timed buffs,
the bookshelf reads books, logs and transcripts (clues mark radar leads) and
the TV gives hints from the nearest stations. Tests:
`tests/game/holodeck.lua`, the `holo_garden` fixture mod in
`tests/game/mods.lua`, `tests/lua/homelife_spec.lua`. Screenshot tour:
`tools/shots/m4.lua`. Known gaps: co-op guests see the host's program but
there is no shared game in it yet; programs have no sound of their own; the
TV picture is a simple animated card, not a rendered scene.

## 5. Pocket saucer and station visits — done

**Goal.** Steve: travel to a space station, shrink the saucer to the size
of a big coin, put it in your pocket and explore the station on foot.

**Deliverables.** A fourth configuration, Pocket (coin-sized), allowed only
while docked; fold, pocket and unpocket (only in open space or a hangar);
first-person on-foot movement; walkable station areas (market, bar,
hangars) generated from the station kit; on-foot trading and NPC traders;
a non-lethal pocket risk (e.g. a pickpocket you can chase down).

**Done when.** A game test docks, pockets the saucer, walks the station,
trades on foot, unpockets in a hangar and flies away.

**Status (2026-11-17).** Done in OpenSpec change `add-pocket-station-visits`.
Pocket is the third configuration (the saucer has Villa, Seat and Pocket;
5 cm across), chosen with 3 or by folding once more past the Seat, and only
while docked. You step out into the arrival hangar, the saucer folds into
your hand and goes into your pocket; F holds it in your fist. Stations are
generated from their seed and the `walk` section of the station kit
(`sim/stationgen.lua`): arrival and far hangars, a concourse with passages,
a market with four or five stalls (scrap, curio, grocer, archivist,
outfitter, chandler) and a bar with a bartender, patrons, drinks for buffs
and rumours for leads, furnished in the detail-pass style with folk of five
species (`station/folk.lua`, `meshes/npc.lua`, `view/station.lua`). A
hooded pickpocket stalks pocketed coins; look at him to spook him, chase
him down to get it back, or deal with the fence at the bar if he escapes.
Unpocketing works in either hangar with a free bay and grows the saucer
from your hand onto the pad; you are aboard at that hangar's space door.
Movement uses the interior walk axes on every input path (WebXR walks where
you look). Visits are plain player state, saved and replayed (sim version
7). Tests: `tests/game/station.lua` (plus restore-every-tick and seed 7),
`tests/lua/station_spec.lua`; the slice replay was re-recorded. Screenshot
tour: `tools/shots/m5.lua`. Known gaps: one station (the trader) has an
interior so far; NPCs follow fixed paths and do not path around players;
co-op players see each other on foot but the thief only targets one coin at
a time; unpocketing in open space outside a station is not exposed yet
(the hook exists for milestone 7).

## 6. Presentation and packaging — done

**Goal.** It looks and ships like the retro-3D game in the concept.

**Deliverables.** Grok Imagine texture and sprite pass with every prompt in
`art/prompts/log.jsonl`; audio pass; WebXR comfort and diegetic controls;
touch polish; a Windows package.

**Done when.** `artpipe lint` is clean, a Windows zip or installer is
published, and XR seated + standing has been checked.

**Status (2026-11-17).** Done in OpenSpec change `add-presentation-packaging`.
Art: 17 new Grok Imagine sources (22 prompts logged in total) go through
`tools/artpipe` into 23 retro textures and four new palettes: wood, fabric,
tile, floor, metal and panel materials on the Villa's furniture, floors,
walls and stairs; floor grating, tiles and hex paving on derelict floors
and glyph inscriptions in big rooms; textured station walls, floor and
ceiling with shop and bar signs and a crowd of folk sprites; a second
nebula, a planet and a galaxy in the sky; the title emblem. `artpipe lint`
is clean. Audio: 13 synthesized sounds (five loops: engine hum, beam,
holodeck, station, derelict; door, scan, jam, alert, locked, hit, click and
coin), looping voices with handles in the engine (`saucer.audio.play` with
`loop`, `saucer.audio.set`, `saucer.audio.stop`) and a render-side director
(`view/audio.lua`). WebXR: snap turning by default (a right-stick flick is
one 30° turn, sent as the new `snap_left` / `snap_right` commands so
replays stay exact; smooth turning when switched off), a comfort vignette
while the view moves, seated (`local`) and standing (`local-floor`) sessions
with their own buttons in the web shell, tracked controllers drawn as hands
and a wrist panel (charge, hold, beam lock) in place of the flat HUD.
Touch: near-miss presses, held highlights, short labels, a floating stick,
the lift level and a vibration tick on presses. Packaging:
`.github/workflows/release.yml` builds and smoke-tests a Windows zip
(windows-msvc), a Linux tarball and a web zip on a `v*` tag and attaches
them to the release: [v0.1.0](https://github.com/makesgamessteve-hash/saucer/releases/tag/v0.1.0).
XR seated and standing were checked with automated tests
(`tests/game/xr.lua` drives both sessions through `saucer.test.xr` the way
`web/saucer_xr.js` does; `tests/lua/presentation_spec.lua`), not on a
headset or the WebXR emulator. Screenshot tour: `tools/shots/m6.lua`. Known
gaps: hands are boxes posed by yaw only (no pitch or roll yet); the wrist
panel is bars, not text; no teleport locomotion; no music; no installer
(zip only); Windows and Linux builds are unsigned.

## 7. On-foot excursions — done

**Goal.** Step out of the saucer into a derelict for crawlspaces and
hand-locks. Cut from the MVP in v0.4 (was Pocket mode); builds on the
Pocket configuration and on-foot movement from milestone 5.

**Deliverables.** Deploy and recall in derelicts; Suit Charge; 4-slot hands;
Lifeline failure; hand-locks that open doors for the saucer; on-foot grid
consoles.

**Done when.** A game test steps out, opens a hand-lock, fails with
Lifeline, and recovers the dropped cache.

**Status (2026-11-17).** Done in OpenSpec change `add-on-foot-excursions`
(supersedes `add-on-foot-pocket-mode`). Every derelict now gets, from a
child rng of its seed and on its own cell grid (rooms, slots and the layout
hash are unchanged), a 1 m crawlspace off a great hall leading to a chamber
with a hand-lock, a grid console and a Delicate find, plus a strongroom next
to the same hall whose Seat-sized door is sealed by a shutter
(`sim/footgen.lua`; all 600 ruins of seeds 1-200 get them). Set the Seat or
the Villa down within 2 m of a deck and pick Pocket (3, or fold past the
Seat on any device): you step out and the saucer folds into your hand and
pocket (`sim/excursion.lua`, reusing milestone 5's Pocket configuration and
walking). On foot you walk, run, crouch, duck into low openings by yourself,
crawl and jet-hop; your Suit Charge is the only meter (drains, faster in
crawlspaces and under a Watcher's lock; hops, the Jammer and stun bolts
spend it; warnings at 30% and 10%); four hand slots take loot up to size M,
and Delicate finds only by hand. Holding Use at the hand-lock opens the
strongroom's shutter for the saucer; at the grid console it puts the
derelict's sentries to sleep until you leave. Deploy (E, 1, 2) needs a
2.2 m sphere ahead of you or around you, so never in a crawlspace; the Seat
grows from the coin and you board with your hands emptied into the hold. At
zero suit the Lifeline whites out the screen, deploys the Seat at the newest
point of your trail with room for it and leaves your hands as a cache to
walk back for. Watchers see you on foot whatever their size band;
Snatchers tear hot items out of your hands (on-foot Snatchers fit, so they
are in). Presentation: shutter, lock, console and crawl-mouth props, the
hand, coin and fold, other players on foot, the suit/hands/coin HUD with
the cache bearing and work bar, the derelict audio loop, a chase camera and
XR wrist bars (suit, hands, work) (`view/excursion.lua`). State version 8;
everything saves, restores every tick and replays. Game test
`tests/game/excursion.lua` (also restore-every-tick and seed 7), specs in
`tests/lua/excursion_spec.lua`, screenshot tour `tools/shots/m7.lua`.
Known gaps: one crawlspace, chamber and strongroom per derelict (the entrance
hall is tried first); no zero-g mag-floors, dead-city
surfaces or new on-foot tools; on foot in XR the hands are the controllers
(no coin model in the hand); the Lifeline trail can put the Seat in the
chamber if that was your newest roomy point.

## 8. The wider dark (M2) — done

**Goal.** A bigger universe, and local co-op with one saucer each.

**Deliverables.** Split-screen 2–4 (join flow, layouts, gifting, docking
and dome visits, party fold jumps, shared mystery); multiple sectors and
Fold Core jumps; civ trait generator and Xenoarchive; the full mystery
(Heart site, endings); requests and reputation; Clamp, Lockdown, Decoy,
Shroud, Override spike; a third kit and procedural music.

**Done when.** Four local players can share a sector in split screen, each
in their own saucer, and a party can follow a multi-sector mystery.

**Status (2026-11-17).** Done in OpenSpec change `add-wider-dark`.
**Local co-op** (`sim/coop.lua`): with `--coop` the input layer builds
frames for four slots; a free slot joins on its first Use, Menu, Tractor
or size press (pad A, or F2 / `--split-keyboard` hands the right half of
the keyboard to the next player as its own device). Each joiner gets a new
Villa in formation; the viewport count follows the players (two split
side by side, `--split horizontal` stacks them; three or four get
quarters and a spare quarter shows the sector map). The party panel ejects
loot for a partner's beam, docks at another player's Villa for a walk
round their dome (guests are drawn in the host's dome) and hands items
over at the gift table. **Galaxy** (`sim/galaxy.lua`, `galaxy/galaxy.lua`):
seven sectors linked into a map with a spine Home Drift → Salt Hollow →
Salt Lantern → The Heart; sector 1 generates exactly as before. Each
sector keeps its own world state (`state.visited`, per-player away
state). A party fold jump is proposed on the sector map, agreed by every
player, waits until every saucer is the Villa, outside the sites and has
the Fold Core's Charge, spools 3 s and lands the party in formation;
Fold Core tiers (reach in links) are bought at trade terminals with
reputation. **Civilisations** (`civs/traits.lua`, `sim/civs.lua`): traits
(body, shape, temperament, aesthetic, values, music scale, kits, tint)
generated per universe; the **Xenoarchive** (`sim/archive.lua`) fills per
civ as finds are identified and gates the mystery. **Requests and
reputation** (`sim/requests.lua`): trader requests pay double and raise
reputation, which lifts sale prices and unlocks Fold Core tiers; the
terminal also sells Decoy flares. **The mystery** (`sim/mystery.lua`,
`sim/heart.lua`): after the vault, the Witness Echo in Salt Hollow only
translates with 25% of its civ archived, decoding it (Act III) unlocks
the Heart Key in Salt Lantern, and carrying the Key within 45 m of the
core of the Heart site opens it; everyone at the Heart votes from the map
(seal, restore, take; a tie goes to whoever set the last Key) and the
ending changes the galaxy (Act IV, a centerpiece for everyone inside).
**Advanced sentries and tools** (`sim/advsentry.lua`; danger 2+ only, so
Home Drift is unchanged): Clamps grip a hull (no resizing, Charge drain;
Boost or Jam), a Lockdown node seals its hall's big doors for 60 s on a
Watcher lock (Jam or spike), Decoy flares draw sentries for 8 s, the
Shroud hides a still saucer for Charge, and the on-foot Override spike
shuts a disabled sentry or a Lockdown node down for good. Nothing is
lethal. **The hive** (`kits/hive.lua`) is the third new kit (organic
cells and chutes) for hive-building civs. **Procedural music**
(`view/music.lua`): per-civ scale, root and tempo; space, site and alert
stems played from four generated note samples with pitch (the audio API
gained `pitch`). State version 9; everything saves, restores every tick
and replays (`.srep` gains `slots`). Game test `tests/game/widerdark.lua`
(four players, three party jumps, the Witness gate, the Heart Key, the
vote), `tests/game/coop_replay.lua` + `tests/replays/coop_seed42.srep`,
specs in `tests/lua/widerdark_spec.lua`, screenshot tour
`tools/shots/m8.lua`. Known gaps: the game test sets Act I as solved and
seeds the gate civ's archive through the API (Act I is played by
`tests/game/mystery.lua`, identification by `tests/game/trade.lua`); one
Heart site and three endings; the music has no stereo pan; split screen
in a real headset is untested (joins are refused while XR is active);
autopilot needs a climb-first waypoint out of the Heart's shaft.

## 9. Home among the stars (M3) — done

**Goal.** Networked co-op and a dome that is truly yours.

**Deliverables.** Lockstep (then rollback) over UDP/WebRTC; an XR player
can join; display slots, Comfort, furniture, garden; Warden, cutter,
grapple; a mod browser; Hardcore mode.

**Done when.** Two machines (or a browser and a desktop) play one universe
without a desync, and a guest can visit a decorated dome.

**Status (2026-11-17).** Done in OpenSpec change `add-home-among-stars`.
**Netplay** (`engine/src/core/sx_net.c`): deterministic lockstep in a star
(the host is slot 1, guests 2-4). Each machine sends its slot's command
frames `--net-delay` ticks ahead (default 3), redundantly until acked, and
advances only with every slot's frame; HELLO carries the network API and the
mod-set hash, so a different version or mod set is refused with the reason;
a machine silent for 8 s is dropped and its slot plays empty frames. Every
60 ticks each side sends its state hash; a mismatch stops the session on
both sides with the first differing tick. Desktop transport: UDP
(`sx_net_udp.c`, `--host [PORT]`, `--join HOST[:PORT]`, `--net-players`),
the window title shows the status. Web transport: an unordered WebRTC data
channel without retransmits (`web/saucer_net.js`), signaled by copy-paste
offer and answer codes from the shell's **Online co-op** panel (no server).
A WebXR player can host or join (their headset follows their own slot).
Split screen got a compact HUD for two and four players. **The dome**
(`sim/decor.lua`, `home/decor.lua`): nine furniture kinds from traders,
placed with the Home planner on a 0.25 m grid with quarter turns (solid for
guests), six display slots for identified finds, four garden beds with
three alien seeds that grow while watered into kitchen ingredients, and
Comfort (diminishing per kind, Bare to Beloved) that speeds up Charge
regeneration by 2% a point (at most 50%); docked guests walk the decorated
dome and admire the displays. **The Warden** (`sim/warden.lua`, danger 3
only): patrols its great halls through big doors, hunts with stun bolts,
sounds the Lockdown alarm and wakes the site's Snatchers (double sense for
30 s); Decoy and Shroud work on it, only the Jammer stuns it and the
Override spike then shuts it down. **Tools** (`sim/tools.lua`): the grapple
(X on foot, 25 m) and the cutter (hold N with no sentry to spike: a sealed
shutter or a Lockdown seal in 6 s). **Mod browser** (`sim/modbrowser.lua`,
`saucer.mods`): lists every mod folder with its description and load status
and switches mods for the next start (`<user-dir>/mods.txt`). **Hardcore**
(`sim/hardcore.lua`, title card or `--hardcore`): Fold Retreat loses all
cargo, the Lifeline loses your hands, no loading from the bed. Decor,
Hardcore and tool state are created on first use, so old saves and replays
keep their hashes. Tests: `tests/c/test_net.c` (lossy lockstep, four
players, desyncs, rejects, timeouts), `tests/web/net_web.test.js` (the web
transport under node with a fake RTCPeerConnection pair),
`tests/lua/homestars_spec.lua`, and the Done-when as two processes on
loopback: `tests/game/netplay.lua` via `tools/net_loopback.cmake` (a host
and a guest in a WebXR session decorate the dome, dock, the guest walks it
and admires the display; both must end on the same tick and hash after at
least ten hash checks; also on seed 7 with delay 5), `tests/game/netdesync.lua`
(a forced divergence is caught on both sides) and `tests/game/modbrowser.lua`
across two starts. Screenshot tour `tools/shots/m9.lua` and
`tools/shots/m9_net.sh` (two windows on loopback). Known gaps: lockstep
only, no rollback; a browser and a desktop cannot share a session (UDP vs
WebRTC; a relay would bridge them); guests join only before the session
starts; no signaling server (codes are copy-pasted); the mod browser has no
download source; the grapple has no touch button; the Xenoarchive set bonus
for displays is not in; Wardens in the scripted mystery game test are
switched off through the API (their own spec covers them).

## Later / maybe

Rivals, planet-surface cities, a fabricator, and a macOS port.
