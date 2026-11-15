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
Stepping out of the saucer is post-MVP.

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
for the Villa; tractor loot through the glass; bank at the trader; basic
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

## 4. Presentation and packaging — next

**Goal.** It looks and ships like the retro-3D game in the concept.

**Deliverables.** Grok Imagine texture and sprite pass with every prompt in
`art/prompts/log.jsonl`; audio pass; WebXR comfort and diegetic controls;
touch polish; a Windows package.

**Done when.** `artpipe lint` is clean, a Windows zip or installer is
published, and XR seated + standing has been checked.

## 5. On-foot excursions — post-MVP

**Goal.** Step out of the saucer into a derelict for crawlspaces and
hand-locks. Cut from the MVP in v0.4 (was Pocket mode).

**Deliverables.** Pocket, deploy, recall; Suit Charge; 4-slot hands;
Lifeline failure; hand-locks that open doors for the saucer; on-foot grid
consoles.

**Done when.** A game test steps out, opens a hand-lock, fails with
Lifeline, and recovers the dropped cache.

## 6. The wider dark (M2) — later

**Goal.** A bigger universe, and local co-op with one saucer each.

**Deliverables.** Split-screen 2–4 (join flow, layouts, gifting, docking
and dome visits, party fold jumps, shared mystery); multiple sectors and
Fold Core jumps; civ trait generator and Xenoarchive; the full mystery
(Heart site, endings); requests and reputation; Clamp, Lockdown, Decoy,
Shroud, Override spike; a third kit and procedural music.

**Done when.** Four local players can share a sector in split screen, each
in their own saucer, and a party can follow a multi-sector mystery.

## 7. Home among the stars (M3) — later

**Goal.** Networked co-op and a dome that is truly yours.

**Deliverables.** Lockstep (then rollback) over UDP/WebRTC; an XR player
can join; display slots, Comfort, furniture, garden; Warden, cutter,
grapple; a mod browser; Hardcore mode.

**Done when.** Two machines (or a browser and a desktop) play one universe
without a desync, and a guest can visit a decorated dome.

## Later / maybe

Rivals, planet-surface cities, a fabricator, and a macOS port.
