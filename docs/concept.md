# Saucer — Game Concept & Design

> Status: draft v1.0 (2026-11-17). Updated with Steve's answers on combat, co-op, the mystery, WebXR, and art (v0.2), on co-op saucers, licensing, and hero meshes (v0.3), with Steve's correction of the core fantasy: you are a person on foot inside the saucer, and it reconfigures around you (v0.4), with the milestone 2 live-in interior (v0.5), with the milestone 3 one-sector loop (v0.6), and with Steve's request for true 3D: the saucer flies up and down, and sites grow in every direction and are huge (v0.7), and with Steve's belly tractor beam: loot is beamed up from a Tractor Room under the lower deck, only when the saucer is lined up over it, and shrinks on the way into the hold (v0.8), and with milestone 5's pocket saucer and station visits: the Pocket comes back, docked only (v0.9), and with milestone 6's presentation and packaging: the Grok Imagine art pass, synthesized audio, WebXR comfort and the first release (v1.0). · Owner: Steve Makesgames · Repo: <https://github.com/makesgamessteve-hash/saucer> (`main`)
> Licenses: code (including all Lua) is MIT · hand-authored art and audio are CC BY 4.0 · Grok Imagine–generated images are under xAI's terms for outputs (§11.6)
> Purpose: the source document for OpenSpec specs. Section 16 lists capabilities with SHALL requirements and scenarios ready to paste into `openspec/specs/` or `openspec/changes/`.

## 0. Repo state & consistency notes

- As of 2026-11-13 18:33 CET, `main` has a single commit ("Initial commit") holding only `LICENSE` (MIT, "Copyright (c) 2026 Steve"). There is no README, no `openspec/` folder, no source, no build files, no Lua, and no assets, so this document has no earlier decisions to conflict with.
- **Flag: licensing.** The MIT `LICENSE` covers only code. Add a `LICENSES/` folder (REUSE layout), with `MIT.txt`, `CC-BY-4.0.txt`, and `LicenseRef-xAI-Output.md`. Steve has to link xAI's exact terms in that last one. Also add a hand-written `LICENSING.md`, plus a generated `ATTRIBUTION.md` and `REUSE.toml`. Licenses by class:
  - **MIT:** code, including all Lua and mesh recipes
  - **CC BY 4.0:** hand-authored assets in `data/**/authored/`
  - **xAI's terms for outputs:** generated images in `data/**/generated/`

  See §11.6 for the full rules.
- **Flag: OpenSpec isn't initialised.** The first change should be `openspec init`, plus a `project.md` that records the conventions in §15 and §16 (C11, Lua 5.4, CMake, the coverage gates).
- **Decisions from Steve (v0.2):**
  - There are no lethal weapons, and the risk is losing loot. The only opponents are robot sentries, which you deal with using non-lethal tools.
  - Co-op comes later (split screen and networked), but the architecture has to be ready for it from day one.
  - Each universe has a seeded central mystery, which you can ignore.
  - WebXR is in the MVP. Targets are Windows, Linux, Web, and WebXR. macOS is out of scope.
  - Art is generated with Grok Imagine, and voxels are cut.
- **Decisions from Steve (v0.3):**
  - In co-op, each player has their own saucer (§3.6).
  - Generated images are covered by xAI's own terms for outputs, not CC BY 4.0, and every prompt is recorded in the repo (§11.6).
  - Hero meshes are generated in code from mesh-builder recipes (§11.8).
- **Decisions from Steve (v0.4), the core-fantasy correction:**
  - The game is played **first-person 3D from the player's own eyes**. The player is a person inside the saucer, not the saucer.
  - At its biggest the saucer is a **glass dome you walk around in**: an open-plan dome deck with a kitchen, a living room, and the helm, all under the glass. **Under the deck** a lower deck holds a bedroom, a bathroom, and the engine room, reached by stairs (§3.3).
  - You **fly from the helm**: walk to it, take the seat, and fly with a seated first-person view. Standing up leaves the saucer holding station.
  - Alien derelicts are **huge**, big enough that the whole saucer flies inside their great halls. Only very tight spaces (ducts, shafts) need a reconfiguration.
  - For those the saucer **reconfigures around the player**: it shrinks to a one-seat, car-sized Seat, packing every other room away into fold-space, and unfolds again when there is room. The pilot's eye stays fixed while the hull folds around it.
  - Sizes are simplified to two: **Villa** and **Seat**. Cruiser, Pod, and Pocket are cut from the MVP (they may return as mods).
  - Co-op is unchanged: every player still has their own saucer (§3.6).
- **Notes from milestone 2 (v0.5), the live-in interior:**
  - The game starts with you **waking up in the bedroom**. A title card offers Get up or Load saved game.
  - The bedroom and bathroom have **sliding doors** that open as you walk up and are solid when closed.
  - **Use** works on furniture: the kitchen (a meal gives ×1.5 Charge regeneration for five sim minutes), shower, engine console, lab bench, trade terminal, and **bed** (sleep until morning: refills Charge and **saves**; or load the last save). Sleeping is refused inside a derelict.
  - The **helm** is a low desk with a radar well plus two angled wing screens (Charge, hull, and shield on the left; hold slots and the size ladder on the right). It stays below the pilot's sight line.
  - **The fold is a packing.** The Villa's 11 room groups pack one by one, farthest from the pilot first. Each one flattens onto its floor, then slides into fold-space at the pilot's feet. The hull holds its full size during this room phase (the first half) and shrinks about the eye afterwards. Unfolding reverses it: the hull grows first, then the decks and rooms unpack nearest first.
  - So that the packing reads on screen, shrinking takes **1.5 s** (was 0.9 s) and growing **1.8 s** (was 1.2 s). Both values stay data in `saucer/configs.lua`.
- **Notes from milestone 3 (v0.6), the one-sector loop:**
  - The **lab bench** keeps a job queue: identify (3 Charge, 30 s × tier) and decode Echoes (20 s). It works in flight but only as the Villa; folded, the bench is packed away and jobs pause.
  - Docking at a trader (within 150 m) enables the **trade terminal**: sell, refill Charge (1 c per point) and repair hull (2 c per point). Trader stock and modules wait for a later milestone.
  - **Sentries are placed from the layout**, never saved: a Watcher at the far end of every great hall except the entrance, and a Snatcher per duct branch with its nest in the deepest small room. Each Snatcher is **leashed** to its branch (it only notices a Seat inside it). The tutorial derelict has none.
  - The **Jammer** also pulses 3 m all round (so a Snatcher right beside you is always hit), and jamming a Disabled sentry restarts its 12 s.
  - **Fold Retreat** lands you as the Villa 60 m from the last trader with hull 30 and shields down. The cache waits where the hull failed.
  - **The mystery is a chain you carry.** Each Echo becomes a hold item and the next one appears only after the previous one is decoded. Where reveals the **Resonant vault**, a monolith in open space; the Key (never decoded) opens it within 80 m. Inside is one unique Curio and the line "The signal continues beyond the fold."
  - Echoes and the Curio are never hot, never for sale, and never lost.
- **Decisions from Steve (v0.7), true 3D:**
  - The saucer **flies up and down**. Flight has six axes: forward and back thrust follows where you look (yaw *and* pitch, so you climb or dive by looking up or down), plus strafe, lift (Space/Ctrl, R/Z, gamepad triggers, the touch slider or the new **up**/**dn** hold buttons, and the XR right stick's vertical axis), yaw and pitch. Pitch reaches ±83°, so you can look straight up or down a shaft. Dampening brakes to a hover that holds altitude.
  - The hull still never pitches or flips. Gravity plating keeps the deck level, so walking around inside stays comfortable. It does **bank** into turns and strafes, by at most about 10° (0.18 rad). The interior and the pilot's eye are locked to the saucer frame and bank with it. There is no bank in XR or mid-fold.
  - **Sites grow in all six directions and are huge.** Rooms attach above and below through floor and ceiling hatches, and shafts climb or drop many levels. Every kit has a minimum vertical span and a minimum number of levels. Exterior hull spines (ships), trusses (stations) and towers (the new **city** kit) make each site span well over 100 m on every axis. The three sites sit at different heights, 1.3–1.6 km apart.
  - The helm radar is 3D: contacts hang on stalks above or below the disc. The HUD has an altitude tape and "UP/DN n m" cues. Sentries work in 3D: Watchers look along a hatch's axis or down a shaft from its top, cones use pitch, and Snatchers patrol vertical chutes.
  - For performance, physics uses a uniform-grid broadphase. Rendering uses per-room chunks with cone culling, a far silhouette LOD beyond 1.1 km, and culling beyond 3.2 km in the fog.
- **Notes from the tractor beam (v0.8):** Steve: "collect the loot/scrap with some kind of tractor beam that also shrinks. This has to be done from a special room at the bottom of the saucer. The saucer has to be positioned at the fitting position and orientation to make that possible."
  - The beam is a **cone straight down from the belly emitter**, along the hull's down axis (tilted by the bank). It takes a target only when: its size fits the beam's class; it lies between the minimum depth and the range below the emitter (Villa 3–45 m, Seat 0.1–10 m); it is inside the cone (Villa 20° half angle, Seat about 29°); **long scrap** (size L and up, which lies at its own angle) runs along the keel within 15° (Seat 20°), either end first; the hull is **level** (bank at most 4°) and **still** (Villa 1.5 m/s); and nothing solid is in the way.
  - The Villa's beam runs from the **Tractor Room**, a third deck under the lower deck, down a stair beside the engine. It has a floor window round the belly hatch, a sling seat with two console arms, a cargo tube up to the hold and hold racks that light a cubby per slot. Line up from the helm (the HUD scope and hint say how), walk down (hover-hold keeps the saucer there), sit at the console (Use) and look down through the glass. There the stick and lift **trim** the saucer slowly in the operator's frame, turn trims the heading, F pulls and Use gets up.
  - **The pull shrinks the loot.** The target rises up the beam into the hatch at the pull speed (at least 0.6 s), shrinking to 12 % of its size (Seat: 35 %), while the belly iris opens. Then it is in the hold like before (hot, unidentified, Echoes, nests, caches, the Curio). Getting up, folding or drifting out of the beam drops it where it lay.
  - **The Seat** has no room for a Tractor Room: its small mini beam fires straight from the seat with the same rule (class S only).
- **Notes from milestone 5 (v0.9), pocket saucer and station visits:** Steve: "travel to a space station, minimize the saucer to the size of a big coin and put it in his/her pocket before exploring the station."
  - **Pocket returns** as a third configuration (class 0, 5 cm across), but **only while docked at a station**. Folding to it costs 30 Charge from the Villa (10 from the Seat); unfolding costs half. You step out into the station's arrival hangar, the saucer folds down into your palm (2.4 s) and goes into your pocket. F holds it in your fist instead.
  - **Unpocketing** only works in a hangar (or, later, open space) whose bay outside is free: the coin grows from your hand onto the pad (2.2 s), and you are aboard at that hangar's space door, still docked, free to fly off.
  - **Station interiors** are generated from the station seed with the `walk` section of the station kit: an arrival hangar and a far hangar, a concourse spine with passages, a market of four or five stalls and a bar, furnished in the detail-pass style and peopled by five species (stall keepers, a bartender, patrons, strollers). Nothing about a layout is saved; it is rebuilt from the seed.
  - **On-foot trading:** vendors buy at the trader's price times their own multiplier (the scrap dealer pays 1.25× for materials, the curio dealer for curios), the grocer, archivist and outfitter sell stock, the chandler tops up Charge and patches the hull, and the bar sells buff drinks and rumours that mark leads.
  - **The pickpocket** is the non-lethal risk on foot: he stalks a pocketed coin, is spooked if you look straight at him, steals it from behind and flees along the walk graph after a 1.5 s head start. Grab him (Use) to get it back; if he keeps away for 35 s the coin goes to the fence at the bar (buy back, trade your best item, or plead if broke). While he has it you cannot unfold.
  - The §3.5 stepping-out-in-derelicts rules (Suit Charge, Lifeline) remain post-MVP (roadmap milestone 7).
- **Notes from milestone 6 (v1.0), presentation and packaging:** the look in §11 is now real: Grok Imagine sources for the Villa materials, the kit floors, the station hall, the sky (nebulae, a planet, a galaxy), folk sprites, shop signs, glyph decals and the title emblem, all downscaled and quantized by `tools/artpipe` (prompts in `art/prompts/log.jsonl`). Audio (§12) is synthesized in code: engine hum, beam, holodeck, station and derelict loops plus door, scan, jam, alert, locked, hit, click and coin. WebXR (§10.1) gets snap turning (30°, as commands so replays stay exact) or smooth turning, a motion vignette, seated (`local`) and standing (`local-floor`) sessions, and diegetic hands with a wrist panel in place of the HUD; teleport on foot and the throttle orb are still to come. Touch gets near-miss presses, highlights, a floating stick and a vibration tick. Builds ship as GitHub Releases (v0.1.0: Windows zip, Linux tarball, web zip).
- All names in this doc (capabilities, Lua modules, folders) are proposals. Nothing in the repo constrains them yet.

---

## 1. Pillars

1. **Safe home, dangerous outside.** The dome is sacred: nothing hostile ever enters it. Risk grows the further you are from it (dome → small saucer → on foot), and the risk is always *losing loot*, never dying. Every system has to respect this gradient.
2. **Size is the key.** Shrinking and growing the saucer is the main verb, not decoration. Ruins are gated by opening sizes, and each size trades capability for access.
3. **Every ruin tells a dead civilization's story.** Procgen is driven by a civilization: its body size, aesthetics, tech, and how it died. Loot, layout, and hazards all come from that story.
4. **Curiosity pays.** Unknown tech is the reward. Identifying, using, displaying, or selling it is a meaningful choice, and every one of those choices feeds back into the home. For players who want it, a seeded central mystery ties the ruins together.
5. **Open and moddable by construction.** All gameplay is Lua, and all content lives in plain folders beside the binary. The base game is just the first mod.

## 2. Core loop

**Moment-to-moment (seconds):** walk across the dome to the helm → take the seat → fly the whole Villa into a derelict's great hall → hover over artifacts and line the saucer up → walk down to the Tractor Room and beam them up (they shrink on the way into the hold) → notice a duct too tight for the Villa → the saucer folds down around you into the Seat → squeeze through → grab what's in there → come back out and unfold the Villa in the hall → stand up and walk around your home while it holds station → read a sentry's telegraph and dodge it, jam it, or out-size it → decide: bank what you've got (leave the site), or go deeper.

**Per session (20–40 min):** pick a site from the sector map (each one shows a scan-revealed risk rating and civ origin) → fly there at Villa size → explore it, shrinking deeper in (and stepping out on foot for crawlspaces) → come back out, grow to Villa, and walk the dome → identify artifacts at the lab bench → decide what to install, display, or sell → dock at a trader → sell, buy upgrades, take requests → choose the next site, or follow a **Resonant** marker left by a decoded Echo.

**Long-term (hours):** upgrade the saucer (modules, Fold Core tiers, dome rooms) → push into riskier, richer sectors via longer fold jumps → fill in the **Xenoarchive** (a per-civ catalog whose completion unlocks lore, blueprints, and decor) → follow the universe's central mystery to its Heart site, or ignore it → make the dome your own museum and home.

## 3. The saucer

### 3.1 Size configurations

The units are meters, and size classes double as the connector classes used by ruin generation (§5.4).

v0.4 simplifies the sizes to two. Derelicts are built big enough for the Villa (§5.4), so the Seat is only for tight spaces.

| Config | Class | Hull Ø × height | Interior available | Speed | Tractor max item class / range | Charge to enter |
|---|---|---|---|---|---|---|
| **Villa** | XL (4) | 26 × 12 | Glass dome deck (kitchen, living room, helm) and lower deck (bedroom, bathroom, engine room); you walk it on foot | 30 m/s cruise | XL / 45 m | — (default) |
| **Seat** | S (1) | 1.8 × 1.4 | One seat under a bubble canopy, about the size of a one-seat car | 10 m/s, agile | S / 10 m | 20 (unfolding back to the Villa costs half, 10) |

Cut in v0.4: Cruiser, Pod, and Pocket. Mods can add sizes back through `saucer/configs.lua`. v0.9 brings **Pocket** back as a third size (class 0, 5 × 1.4 cm, docked only, §0 milestone 5 notes).

**Interior fiction ("Fold"):** shrinking folds rooms away into a fold-space; it doesn't destroy them. Their contents persist, but you can only walk into a room while the saucer's config makes it available. That's a deliberate tension: to *work* on loot (lab, workshop) you need to unfold back to the Villa.

**Cargo rule:** the hold is one shared fold-space with a total capacity in slots, and it's the same at every size. Your size limits what you can *pick up* (the tractor class) and what you can *use* (the rooms), not what you can carry. Small fits are easy to explain and easy to test.

### 3.2 Transition rules

- **Around the player:** a reconfiguration keeps the player's eye point fixed. At the helm that's the pilot's eye; on foot the Seat forms around wherever you stand, facing where you look, and you end up seated in it. Unfolding puts the helm back around the pilot's eye.
- **Shrink:** always allowed if you have enough Charge. It takes 1.5 s in v0.5 (0.9 s in v0.4): rooms pack away one by one in the first half, then the hull shrinks about the eye, during which shields are down and the hull is immune to collision damage (so you can't get crushed mid-transition).
- **Grow:** before growing, the engine sweeps the target hull cylinder plus a 0.5 m margin at the current position (against static geometry, and in co-op against other players' saucers and on-foot players, §3.6). If it's blocked, the UI shows a red ghost hull and the grow is refused, with no cost. It takes 1.8 s in v0.5 (1.2 s in v0.4) with shields down: the hull grows first, then the rooms unpack. No flying while the saucer reconfigures.
- Each step costs Charge (table above). Growing costs half of what shrinking costs. Charge regenerates slowly while you're in open space, or quickly at a trader.
- You can skip steps (Villa→Seat in one press). The cost is the sum of the steps and the time is the longest single step.
- No transitions while a sentry is clamped onto the hull (the Clamp, M2). That's the only lock. Snatchers can only latch onto a Seat hull (§8.2).
- ~~Pocket~~: cut in v0.4. Standing up is something you do inside the Villa, not outside it.

### 3.3 Dome & interior as home

- **You live in it, first-person (v0.4).** The player is a person on foot with a body (radius 0.3 m, eye height 1.62 m) who walks the Villa with collision on both decks. The same Lua layout table (`data/base/saucer/interior.lua`) drives collision and the code-generated interior meshes.
- **Dome deck (under the glass):** open plan, 20 m across, under a 360° glass dome. The **kitchen** is on one side (counters, an island, a fridge, stools), the **living room** on the other (sofa, rug, table, armchair, plants), and the **helm** at the front (console and pilot seat). The outside is always visible through the glass.
- **Lower deck (under the dome deck):** reached by a straight stair. It holds a **bedroom** (bed, wardrobe), a **bathroom** (shower, tub), and the **engine room** around the glowing fold engine core, with portholes in the hull.
- **Helm:** walk up to it and press Use to take the seat. From there you fly with a seated first-person view. Use again stands you up, and the saucer holds station (it brakes and stays put) while nobody is at the helm.
- **Lab bench:** identifies artifacts (§6.2).
- **Workshop:** installs or removes modules, repairs the hull using materials, and runs the fabricator (later).
- **Display slots:** shelves and plinths where you place identified Curios. Each displayed piece adds a small passive "Comfort" bonus (faster Charge regen), and it counts toward Xenoarchive sets.
- **Holodeck (milestone 4):** the starboard-aft room of the lower deck, behind a lit arch from the engine room. Programs are Lua data files under `holo/` (any mod can add one): relax scenes, a Seat flight course, replays of explored derelicts (the route recorded while inside), and recreations of decoded alien places that point at the mystery. They come as starters, from data cores found in vaults (the lab decodes them) or from traders. Modules add space, detail and co-op guest slots. A program runs in its own simulated space while the saucer holds station.
- **Galley, bookshelf and TV (milestone 4):** the stove cooks recipes from trader groceries and alien ingredients for small timed buffs (Charge regen, Scanner/Jammer cooldowns, Scanner reveal, hull regen). The living-room bookshelf fills with found books and logs, Echo transcripts and holodeck memories; a clue's first read marks a lead on the radar. The TV picks up channels from nearby stations and cities and works as a gentle hint system.
- **Garden (post-MVP):** plants grown from alien seeds, which give slow, cozy progression.
- **Rule:** hostile entities, hazards, and damage volumes are culled at the dome boundary. When the hull takes damage you get alarms, lighting changes, and a camera shake (haptics in XR). There's no player health stat at all.

### 3.4 Upgrades (module slots)

Slots: **Drive**, **Shield**, **Scanner**, **Tractor**, **Fold Core**, **Utility ×2** (and more Utility slots from hull tiers). Non-lethal tools such as the Jammer, Shroud, and Decoy launcher go in Utility slots (§8.3).

- The Fold Core tier sets max Charge, transition costs, and fold-jump range. It's the main progression gate into further sectors.
- Every module is an alien artifact (with affixes) or a trader-bought standard part (no affixes, reliable).

### 3.5 Pocket mode & stepping out (cut in v0.4)

v0.4 cuts the Pocket. Being on foot now means walking around inside your own Villa; stepping out of the saucer into a derelict may come back post-MVP. The original v0.3 notes are kept below for reference.


- Pocketing requires a "standable" surface within 2 m (a floor collider and gravity, or a mag-floor tag) and a suit with Charge.
- While the saucer is pocketed you're on foot (§4) and it can't be damaged.
- **Deploy:** this always deploys at Seat size, and needs a 2.2 m clearance sphere in front of the player. Then you can grow as normal.
- **Recall** (hold Interact for 1.5 s): deploy and board in one action, wherever there's clearance.

### 3.6 Co-op: one saucer each (M2 local, M3 networked; architecture in the MVP)

**Every player has their own saucer**, with their own dome, hold, Charge, modules, credits, Xenoarchive, and hot/banked items. A shared saucer would break the one-seat Seat size and the "my home" pillar. Up to 4 players share one universe and **one sector at a time**.

- **Size rules:** each saucer changes size independently. Clearance checks for grow and deploy (§3.2, §3.5) treat **other players' saucers and on-foot players as solid**, so you can never grow into a friend. Pocketed saucers aren't obstacles.
- **Saucer-to-saucer contact:** soft separation only. There's no hull damage, no knockback beyond pushing the saucers apart, and no griefing. **Anti-blocking:** if a player pushes against another player's saucer for 2 s without moving, the two saucers *fold-phase* through each other for 3 s (a visible shimmer, and they don't collide with each other), so a friend parked in a duct can never soft-lock you.
- **Loot ownership:**
  - **Personal loot instances:** every Module, Curio, Tool, and Material loot slot rolls separately for each player (§5.5). You only see your own instance, and other players' instances show as faint ghosts. Nobody competes for loot, and co-op never halves the reward.
  - **Shared world objects:** Keys, power cells, Echoes, doors, grid consoles, and Snatcher nests are single objects in the world. **Claims:** the first tractor lock or hand-grab to complete wins. If two players complete on the same tick, the tie goes to the player with the lowest `(record_index + tick) mod n`, which is deterministic and rotates fairly. A Key opens its lock for everyone.
  - Hot and banked status is tracked per player. A site banks for each player when *that* player leaves its boundary.
  - **Gifting:** eject an item (from the hold in the Villa, or from your hands on foot once excursions exist) as a world pickup tagged "for P*n*" or "anyone". Ownership transfers when someone picks it up. If the receiver is inside a site, the item becomes hot for them.
  - **Snatchers** steal from any player. A stolen item in a nest can only be picked up by its original owner.
  - **Failure is per player:** Fold Retreat and Lifeline affect only the player who failed. Everyone else carries on.
- **Economy:** wallets are per player. Trader stock, demand, and requests are shared world state, so selling the same item depresses the price for everyone. The first player to deliver claims a request.
- **Dome visits ("docking"): yes, in M2.** Two Villas outside any ruin boundary can dock if both players accept. The guest walks into the host's dome as a guest avatar. Guests can look at the displays and use a shared **gift table**, but they can't use the host's lab bench or workshop, or take displayed items. The host's dome rules (absolute safety) apply. Undocking returns the guest to their own cockpit.
- **Fold jumps:** a party vote. Every player has to be at Villa size and outside ruins, so all players stay in the same sector.
- **Split screen (M2):**
  - 2 players get a vertical split (or horizontal, as an option), and 3–4 players get a quad.
  - Each viewport keeps the same pixel scale (for example, 480×270 total becomes 240×270 for each viewport in a 2-way split).
  - The HUD and trade screens are per viewport and don't pause the game. The pause menu pauses everyone.
  - Each viewport gets its own audio listener.
  - **XR isn't combined with split screen:** an XR player is the only local player, but can join networked co-op (M3).
- **Mystery sharing:** the mystery state is per universe and shared. Picking up an Echo puts the physical item in the picker's hold, and every player's journal gets the decoded text once anyone decodes it. Translation gates (§5.6) pass if *any* present player meets them. At the Heart site, the players present vote on the ending. A tie goes to the player who inserted the last Key. Everyone present gets the centerpiece.
- **Saves:** one universe save holds the world state and one **player record** per participant, indexed by join order (`record_index`). Record 0 is the universe owner. Local co-op uses one file. In networked play, the host stores everything (portable player records come later).

## 4. On-foot play

On foot is the high-risk, high-access layer, and it's the only way into **F-class** spaces (crawlspaces, maintenance shafts, 0.8 m openings).

- **Why step out:** F-class crawlspaces; *hand-locks* (consoles, power couplings, and valves that need hands, which open doors for the saucer); fragile loot that the tractor would destroy ("Delicate" tag); and surfaces of dead cities (later).
- **Movement:** first-person walk, crouch/crawl, a short jet-hop (suit thrusters), and mag-boots on mag-floors in zero-g. There are no weapons and no combat move set, by design.
- **Suit:** has its own Suit Charge (oxygen/life support), which drains outside (faster in hazards) and refills instantly when you re-board. You get a HUD warning at 30% and 10%.
- **Hands:** an on-foot inventory of 4 slots that's separate from the hold. Items move to the hold automatically when you re-board.
- **Tools (MVP: Scanner pulse, Jammer, hand-grab; later: Override spike, Decoy, cutter, grapple):** artifacts of the Tool category can be equipped on foot (§8.3).
- **Sentries on foot:** Watchers drain Suit Charge with stun bolts, and Snatchers grab an item out of your hands. Grid consoles are on-foot-only hand-locks that shut down a zone's sentries.
- **Failure on foot ("Lifeline"):** if Suit Charge hits 0 (there's no health stat), the screen whites out, the pocket saucer auto-deploys at the nearest valid clearance (along the path you came in by), and you wake up in the Seat. Whatever was in your hands drops as a **cache** marked on the site map, and you can recover it. Nothing else is lost.

## 5. Procedural generation

### 5.1 Determinism & seeds

- **PRNG:** PCG32 for streams, and SplitMix64 to derive child seeds. It's integer-only and implemented in C, so results are bit-identical on every platform, including wasm.
- **Seed derivation:** `child = splitmix64(parent ^ hash64(tag_string) ^ index)`. Hierarchy: `universe → sector(x,y,z) → site(i) → ruin → room(j) → loot_slot(k)`.
- **No float math in generation decisions.** Generation uses integer/fixed-point (16.16) math for anything that affects topology or loot, and floats only for final vertex placement.
- **Identity:** every generated item has an ID of `(site_seed, slot_index)`. Saves store diffs against the regenerated state (§13.4) and never store the generated content itself.
- **Mod-proofing:** the save header stores the active mod set and a hash of each mod's version. If a different mod set would change generation, the game warns you before loading.

### 5.2 Universe & sectors

- **Galaxy:** a 3D grid of sectors (starting at 16×16×4), seeded from the universe seed, which you can type or share as an 8-character base32 code.
- **Sector:** a bounded volume about 20 km across, with flight time compressed by a "cruise" mode. Each sector contains:
  - 8–16 **sites**: wrecks (starships), stations, debris fields, and later city shards/planetoid ruins.
  - 1–2 **traders** (living stations or a wandering merchant).
  - 0–3 **sector hazards** (a radiation belt, an ion storm, a gravity well).
  - A **danger tier** (1–5) that rises with distance from the start sector, and drives loot tier and threat density.
- **Fold jumps** between sectors: a loading transition, range set by the Fold Core tier.

### 5.3 Civilizations

Each civ is generated from a seed plus Lua-defined trait tables (moddable):

| Trait | Values (examples) | Drives |
|---|---|---|
| **Body scale** | tiny / human / large / giant | Default connector class (tiny→S/F, giant→L/XL), door sizes, furniture scale, and therefore which saucer size you need |
| **Shape language** | angular, organic, crystalline, modular-industrial | Which kit variant / module meshes get used |
| **Palette** | one 16-color palette from a curated set + hue shift | Textures, lighting, UI tint on that civ's items |
| **Glyph set** | procedural glyph alphabet | Signage, item names, archive pages |
| **Tech domain(s)** | gravitics, optics, bio, fold, energy, cognition | Item base types and affix pools |
| **Fate** | war, plague, ascension, entropy, flight | Decay pass: breaches, scorch marks, overgrowth, missing cores, hazard types |
| **Temperament** | defensive, mercantile, reclusive | Density of automated defenses and locks, how valuable their loot is |

A sector draws from 2–4 civs, and a civ can appear across neighbouring sectors, which makes Xenoarchive sets achievable.

### 5.4 Ruin generation (kits + grammar)

0. **Scale (v0.7, true 3D):** rooms attach on all six faces (side doors on the higher floor, floor and ceiling hatches, multi-level shafts), so a site is a 3D sprawl rather than a floor plan. Per-kit grids are 72 × 60 × 120 cells (starship), 80 × 72 × 110 (station) and 110 × 90 × 120 (city). Exterior solids add spines, trusses or towers. If 8 tries cannot meet the kit's minimum span and levels, a hand-placed three-level layout (hall → shaft → duct vault) is used. **(v0.4):** derelicts are huge. Their **great halls** (about 56 × 24 × 64 m in the starship kit, joined by 34 × 16 m doors) take the whole Villa. A chain of great halls runs from the entrance to the Vault, and **ducts** (2.6 × 2.1 m openings into 3 × 3 m-class rooms, sometimes chambers behind) branch off them. Only the ducts need the Seat. Ruin cells use a 64 × 8 × 96 m grid.
1. **Kit:** a folder of modules (each one is a `module.lua` descriptor declaring a mesh recipe (§11.8), collision, and generated textures). Each module defines its cell footprint on a **4 m grid**, plus **sockets** (position, facing, class XL/L/M/S/F, and tags such as `door`, `breach`, `duct`). Kits belong to a site archetype (starship, station, city) and declare which shape languages they fit.
2. **Mission graph (grammar):** a Lua graph grammar rewrites `Start → Hub → … → Vault` into a graph of rooms with **locks** and **keys**:
   - *Size lock*: the opening class is smaller than the incoming path, so you have to shrink. This is the signature lock.
   - *Hand lock*: a console on an F-reachable side opens a door, so you have to step out.
   - *Power lock*: a power cell item, or Charge spent at a coupling.
   - *Hazard lock*: a radiation or debris zone that needs a module, or speed and route knowledge.
   - Rules are weighted by civ traits (reclusive → more hand locks; giant → more size locks going *down*).
3. **Embedding:** this places modules onto the 3D grid to satisfy the graph (with backtracking and socket-class compatibility). Corridors are filled with connector modules. The C helper `procgen.grid_*` does the overlap tests.
4. **Decay pass (civ fate):** removes or opens walls (creating alternate breaches), scatters debris props, places hazards, and dims lights.
5. **Population:** loot slots are weighted by graph depth (the Vault gets the best). Sentries go at chokepoints, grouped into zone grids, each with a reachable grid console and a Snatcher nest. Mystery archive rooms are injected when this site hosts an Echo (§5.6).
6. **Validation:** flood-fill reachability per size class, with the player's possible transitions modelled as a state machine. **Every loot slot, the Vault, every grid console, and any Echo archive room must be reachable** by the saucer at some size or on foot. If validation fails, the generator retries with `seed+1` up to 8 times, then falls back to a guaranteed simple layout and logs a warning (tests treat that warning as a failure).

MVP target ruin size: 12–30 rooms, generated in under 50 ms on desktop and under 200 ms on web.

### 5.5 Loot generation

- **Item = base type × tier (1–5) × origin civ × affixes (0–3).**
- **Categories:** **Module** (installs into saucer slots), **Tool** (on-foot equip), **Curio** (display/collect; high sale value), **Material** (repair/crafting), **Key** (ruin-local: power cells, access shards).
- **Item size class** (S/M/L/XL) is what decides tractor eligibility. Delicate items need hands.
- **Affixes** are defined in Lua tables per tech domain: a prefix or suffix, with stat ranges rolled from the item's seed. For example, *"Resonant"* (+15–30% shield regen) or *"…of Ten Suns"* (+energy capacity).
- **Quirks** are negative affixes, such as *Unstable* (random Charge drain), *Loud* (attracts defenses), or *Bonded* (can't be removed once installed). There's roughly a 25% chance on tier 3+ items, and they're hidden until identified. They're the reason identification matters.
- **Co-op:** Module, Curio, Tool, and Material slots roll one instance per player, from `child(slot_seed, "owner", record_index)`. Keys and Echoes are shared world objects (§3.6).
- **Rarity:** the number and quality of affixes. Rarity is shown by the item's sprite glow color once identified.

### 5.6 The central mystery ("the Silence")

Every universe seed generates one central mystery: *why did all these civilizations go silent?* It's optional. The economy and progression never require it, and you can turn it off or set how many hints you get at universe creation (Mystery: **On / Hints / Off**). With it off, the game is a pure endless sandbox.

**Generation** (seeded from `child(universe, "mystery")`, written as Lua tables and moddable):
1. **Cause:** picked from a template table. Each template declares the *revelation types* it needs and the endings it offers. Examples:
   - *Fold Plague*: a fold-drive accident that unravelled space.
   - *Ascension Engine*: a civ that uploaded everyone and pulled others along with it.
   - *The Gardener*: a self-replicating AI that "pruned" civs.
   - *Star Eater*: an anomaly that consumes suns.
   - *Exodus*: they all fled together, toward something.
2. **Cast:** an *Origin civ* (where it started), 1–3 *Witness civs* (who left records), and one *Heart site* in a far sector (in the MVP, inside the one sector).
3. **Clue graph:** a DAG of 5–9 **Revelations** (3 in the MVP). Each node has:
   - a type: **Who**, **What**, **Where**, **How**, or **Key**
   - a host site, chosen deterministically from the Witness civs' sites, biased toward rising danger tiers
   - a carrier: an **Echo** item (a new non-sellable Curio subtype) that comes as a glyph tablet, recording, star chart, or key fragment
   - prerequisites (the earlier nodes it depends on)
4. **Constraint injection:** when a host site's ruin is generated, the generator receives "must contain an *archive room* holding Echo X at depth ≥ N", and validation (§5.4 step 6) guarantees it can be reached.
5. **Decoding:** reading an Echo at the lab bench reveals its text and unlocks the next node's site, which shows on the map as a **Resonant** marker. Some Echoes need the Witness civ's Xenoarchive at ≥ 25% before they can be translated, which is how the mystery ties into the archive. Text comes from Lua templates filled with generated civ, glyph, and place names, so mods can swap them out.
6. **Resolution:** collecting every **Key** fragment opens the Heart site, a unique vault variant of a kit. At its core you choose one of the 2–3 endings the Cause offers (e.g., *Seal*, *Restore*, or *Take*). Each ending:
   - awards a unique dome centrepiece
   - changes the universe state (for example: new traders appear, a sector's hazards calm, or one civ's sentries go permanently dormant)
   - writes a "chronicle" page

   After that, play carries on as a sandbox.

**Co-op:** the mystery is shared per universe. Anyone's decoding updates everyone's journal, translation gates pass if any present player meets them, and the players present vote on the ending (§3.6).

**Determinism:** the whole mystery (cause, cast, graph, host sites, and Echo IDs) is a pure function of the universe seed and the mod set. The save stores only which nodes have been found and decoded, and the chosen ending.

**MVP slice:** one Cause template (*Fold Plague*) and a 3-node chain inside the single sector: *Who* (a glyph tablet) → *Where* (a star chart that reveals a Resonant site) → *Key*. The Key opens a sealed Resonant vault holding a unique Curio, plus a teaser line: "the signal continues beyond the fold" (it pays off in M2). There are no endings in the MVP.

## 6. Items, alien tech & identification

### 6.1 Use vs sell

| Category | Use | Sell |
|---|---|---|
| Module | Install for stat gains/new abilities (e.g., a gravitic tractor that can lift XL items at M size) | Medium value |
| Tool | Equip on foot | Medium |
| Curio | Display in the dome (Comfort + set bonuses + archive) | **High**, especially to collectors with matching requests |
| Material | Repair hull, (later) fabricate | Low, bulk |
| Key | Use inside its ruin only; it fades if taken out | — |
| Echo (mystery) | Decode at the lab bench; it advances the mystery and can go on display | Not sellable, and never lost |

### 6.2 Identification

- An unidentified item shows: its category glyph, origin civ (palette tint), size class, and tier (shown as 1–5 pips, ±1 fuzz).
- There are three ways to identify an item:
  1. **Lab bench** (Villa only): takes in-game time of `30 s × tier` and costs a little Charge. The result is full and safe. Several items can queue up while you fly.
  2. **Trial use:** install or equip it unidentified. Affixes reveal themselves over time, but quirks apply immediately.
  3. **Sell unidentified:** at 40% of the identified base value, with no affix premium.
- Identifying adds the item's type to the Xenoarchive.

## 7. Economy & trading

- **Currency:** Credits (₵). **Charge** is a resource, not a currency. It can be bought at traders.
- **Price formula (Lua, moddable):** `price = base[type] × tier_mult[tier] × (1 + Σ affix_value) × civ_rarity × demand`, then a sell-to-trader discount: 60% identified, 40% unidentified.
- **Demand:** each trader has a demand value per (category, civ), from 0.5 to 1.5. Each sale of a matching item lowers it by 0.05, and it recovers by 0.01 per in-game minute. That stops farming one item type and encourages roaming.
- **Requests:** each trader posts 3 requests ("any tier 2+ Curio of the Vell", "an optics Module"), paying 2× and giving reputation (later: rep unlocks better stock).
- **Sinks:** standard modules, hull repair, Charge refills, dome rooms and furniture, Fold Core upgrades (the big one), and identification at a trader (instant, ₵) if you don't have a lab bench.
- **MVP tuning target:** one good run (about 20 min) at danger tier 1 pays for one standard module (around ₵500). The first Fold Core upgrade costs about 5 runs.

## 8. Threats, sentries & risk

**Risk means losing loot, never dying.** Nothing in Saucer is lethal: not to you, and not to the robots either. Risk is **legible**: a site's scan gives a 1–5 rating plus the hazard and sentry types present. Risk is also **graded by distance from the dome**.

### 8.1 Risk layers & what's at stake

| Layer | What can affect you | What you can lose |
|---|---|---|
| Dome (Villa interior) | Nothing | Nothing |
| Saucer, Villa | Hazards and Watchers wear down shields and hull | At hull 0: **Fold Retreat**, which drops your *hot* items |
| Saucer, Seat | The above, plus Snatchers can siphon a hot item from the hold | Single hot items, then Fold Retreat |
| On foot | Hazards and Watchers drain Suit Charge, and Snatchers grab from your hands | Items in your hands (**Lifeline**, §4) |

- **Hot items** (tracked per player in co-op): anything you've picked up at the current site stays *hot* until you leave the site boundary (the ruin's bounding volume plus 200 m). Leaving the site *banks* those items. Banked items, installed modules, identified cargo, credits, and the dome can **never** be lost.
- **Fold Retreat (hull 0):** an emergency fold to the last trader you visited. Your hot items drop as a **cache** at the point of failure (marked on the site map and recoverable), and you pay for repairs.
- **No health stat.** On foot, Suit Charge is the only meter, and when it hits zero the Lifeline kicks in.

### 8.2 Sentries (the only "enemies")

Sentries are dormant robots left behind by a civilization. They are robots only: there are no living enemies. They share one state machine with telegraphs you can read:
**Dormant** (grey, asleep) → **Alert** (yellow light, a rising tone, it searches) → **Locked** (red beam, steady tone, it acts) → **Disabled** (sparking and rebooting, it ignores you) → back to **Dormant** when its reboot timer ends. Sentries are **leashed** to their ruin: they never leave its bounding volume, and they never cross the dome boundary (§3.3).

| Sentry | MVP | Behavior | Effect when Locked | Counter-play |
|---|---|---|---|---|
| **Watcher** | ✅ | Static turret with a cone sensor that sweeps on a visible path. Each one is calibrated to a size band set by the civ's body scale (e.g., it ignores anything smaller than M). | Fires slow, dodgeable *stun bolts* that drain shields, then hull (or Suit Charge on foot) | Avoid the cone, shrink below its size band, Jam it, use cover, or shut down its grid |
| **Snatcher** | ✅ | A small drone that patrols between waypoints and is drawn to hot items. | Latches onto a Seat hull (3 s to siphon one hot item from the hold) or onto you on foot once excursions exist (it grabs one item from your hands), then flees to its **nest**. | Jam it before the latch finishes. Boost or fold to shake it off. Follow it to the nest to get the item back. It can't latch onto the Villa. |
| **Clamp** | M2 | A drone that clamps onto the hull | Blocks size transitions and drains Charge | Boost to shake it, shrink below its grip, or Jam it |
| **Warden** | M3 | A patrolling hunter that tracks your size class and can follow you through openings of its own class | Fires stun bolts and calls nearby Snatchers | Decoy it, Shroud, or use routes too small for it |
| **Lockdown node** | M2 | A wall unit that wakes up when an alarm goes off | Seals doors in its zone for 60 s | Override it, or take a different route |

**Sentry grids:** every sentry belongs to a zone grid. A **grid console** is a hand-lock (§5.4) that disables every sentry in its zone until you leave the site, which makes stepping out on foot a way to get past sentries.

### 8.3 Non-lethal toolset

All tools are items (Module or Tool category), so alien affixes and quirks apply to them (e.g., a *Wide* Jammer, or a *Loud* Decoy that's an Unstable quirk).

| Tool | Where | MVP | Effect | Cost / limits |
|---|---|---|---|---|
| **Scanner pulse** | Saucer + suit | ✅ | Reveals sentry cones, patrol paths, and nests for 10 s, and color-codes opening classes | 2 Charge, 5 s cooldown |
| **Jammer** | Saucer Utility + on-foot Tool | ✅ | An EMP cone that sends sentries straight to **Disabled** (a 12 s reboot) | 8 Charge (saucer) or 15% suit, 10 s cooldown, 15 m range |
| **Grid console** | Ruin hand-lock | ✅ | Disables the zone's sentries until you leave the site | You have to step out on foot |
| **Decoy flare** | Both | M2 | Sentries track the decoy for 8 s | Consumable (Material crafting) |
| **Shroud** | Saucer Utility | M2 | Watchers can't see you while you're hovering still | Drains Charge continuously |
| **Override spike** | On-foot Tool | M2 | Plug it into a *Disabled* sentry to shut it down permanently. The sentry drops a **sentry core** (a sellable Material). | Takes 3 s of channelling, and the sentry has to stay Disabled the whole time |

**Why this fits the dome-safe pillar:** sentries only act within their ruin, the dome is always out of their reach, and the worst a sentry can do is make you lose *this site's* loot. The tension is "how much do I risk carrying out?", not "will I die?". *Cozy* difficulty removes sentries entirely.

### 8.4 Environmental hazards

- **Radiation zones** (MVP): drain shields, then hull. On foot they drain Suit Charge 3× faster.
- **Drifting debris** (MVP): physics props that do damage on impact above 6 m/s.
- **Collapsing sections:** scripted and telegraphed with creaks and dust.
- **Vacuum vents:** push forces.
- **Dark zones:** no lights, so the scanner matters.
- **Reactor-fate ruins:** a soft 10-minute timer while the hazard zones grow. The choice is between going deeper and getting out.

**Difficulty options:** *Cozy* (hazards only, no sentries), *Standard* (the default), and *Hardcore* (opt-in: Fold Retreat also loses all hot *and* banked hold cargo, but never modules or the dome).

## 9. Progression

- **Saucer power:** modules and affixes, Fold Core tiers 1–5 (Charge, jump range, cheaper transitions), and hull tiers (more Utility slots).
- **Access:** later tools unlock new lock types (for example, a cutter opens sealed F-class panels). Fold Core range unlocks danger tiers.
- **Mystery:** decoded Echoes, Resonant sites, and the Heart site endings (§5.6). It's optional and runs alongside everything else.
- **Knowledge:** Xenoarchive completion per civ. At 25/50/100% you unlock a lore page, a blueprint (fabricate a known affix), and a signature decor piece.
- **Home:** dome rooms (garden, observatory, trophy hall), furniture, and lighting themes. This is purely cozy and purely self-directed.
- **No XP or levels.** All progression is in the saucer, the archive, and the home.

## 10. Controls

General (v0.4): the camera is always the player's own eyes. On foot you walk the decks; at the helm it's a seated first-person view; in the Seat you're under its canopy. An optional third-person chase cam exists for flat screens only. The same move actions walk on foot and fly at the helm. **Use** (G / Return, gamepad X, touch Use button, XR left trigger) takes the helm, stands up, and later interacts. The deck always stays level (no hull pitch or flip), which is good for comfort and essential for VR. Since v0.7 the saucer flies in full 3D: forward thrust follows the look pitch, and it banks gently (at most about 10°) into turns on flat screens, never in XR.

**Input architecture (MVP, required for co-op later):** devices map to **players** and players map to **actions**. Every connected device is *claimed* by a local player slot (P1–P4). In the MVP only P1 exists, but the claim screen and code path are real. Each sim tick, each player's actions are packed into one **command frame** (§14.1), and gameplay code only ever reads command frames, never devices. Bindings are stored per player profile.

| Action | KB/M | Gamepad | Touch (mobile web, M2) | WebXR controllers (MVP) | WebXR hands (MVP) |
|---|---|---|---|---|---|
| Move / strafe | WASD | L-stick | Left virtual stick | L-stick (saucer-relative) | Grab the **throttle orb** on the console and push it |
| Yaw | Mouse | R-stick X | Drag right half | R-stick X snap-turn 30° (or smooth) | Twist the throttle orb |
| Look | Mouse | R-stick | Drag right half | Head | Head |
| Up / down | Space / Ctrl (or R / Z) | RT / LT | Vertical slider, or the **up** / **dn** hold buttons (v0.7) | R-stick Y | Lift or lower the throttle orb |
| Boost | Shift | L3 | Double-tap stick | L-stick click | Fist-squeeze the orb |
| Shrink / grow | Q / E (or wheel) | LB / RB | − / + buttons | A / B, or grab the **size lever** | Grab the size lever and pull or push it to a detent |
| Pick size directly | 1–2 (v0.4) | D-pad (hold) | Long-press opens a radial | Lever detents | Lever detents |
| Tractor / interact | LMB / F | A / X | Tap target (auto-aim cone) | Trigger (point ray) | Pinch-point ray |
| Scan pulse | R | Y | Scan button | X | Tap the wrist scanner |
| Jammer | T | R3 | Jam button | Y | Palm-forward + pinch |
| Use: take the helm / stand up (v0.4) | G / Return | X | Use button | Left trigger | Press the console button |
| Map / inventory | M / Tab | View / Menu | Top-bar icons | Wrist menu (menu button) | Palm-up wrist menu |

- All actions are rebindable through an input-action map in Lua (`data/base/input/default.lua`), one set of bindings per player profile.
- **Touch (M2):** auto-hover holds altitude when you release the slider, and an optional assist keeps you centred in corridors. Hit targets are at least 9 mm. Touch mode switches on when the first touch event arrives on the web.

### 10.1 WebXR (MVP)

- **Modes:** *Seated* (the default, and the most comfortable) and *Standing* (room-scale inside the dome, limited to the guardian bounds). Both take place in the dome cockpit, which is a stable, level frame of reference. The console sits at a reachable height, recalibrated with "hold menu to recenter".
- **Size transitions in XR:** the cockpit geometry changes around you, but **your own scale never changes**. The interior walls fold in with a 0.6–1.0 s animation, the horizon stays still, and you get a short haptic pulse.
- **On foot in XR:** teleport by default (an arc from the pinch or trigger), with smooth locomotion as an option and snap or smooth turning.
- **Comfort options:** vignette strength (on by default during acceleration), snap or smooth turn, teleport or smooth on foot, seated height offset, haptics in place of camera shake (camera shake is never used in XR), reduced flashing, and **XR-safe retro**: vertex snapping and affine warping are forced off in XR (they shimmer per eye), and dithering is reduced.
- **UI:** diegetic only. Dome console panels and a wrist menu, with no head-locked HUD.
- **Rendering:** stereo into the XR framebuffer (WebGL2), with a per-eye low-res target (default 720×800 per eye, nearest-upscaled) and a 72/90 Hz render rate. The sim stays at a fixed 60 Hz with interpolation.

## 11. Art direction: retro 3D built for generated art

All 2D art (textures, sprites, skyboxes, icons, decals) is generated with **Grok Imagine** and then curated and processed through a deterministic pipeline. The style is chosen to make the most of what image generation does well (rich 2D surfaces, single-view objects, painterly skies) and to avoid what it does badly (keeping multiple views of one object consistent, precise geometry, legible text).

### 11.1 Style: "late-90s low-poly sci-fi, palette-locked"

- **Geometry is simple and made by hand or by code. The detail comes from generated textures.**
  - **Kit modules** (walls, corridors, hangars) are built from primitive shapes declared in Lua recipes (boxes, wedges, cylinders, rings, and extrusions with box-projected UVs) by the C **mesh builder** (`saucer.mesh.build`). That means no 3D modelling is needed to make a kit.
  - **Hero meshes** (the saucer at each size, sentries, the trader station, cockpit props) are **also generated in code** from Lua mesh recipes (§11.8), at ≤ 3k triangles each, with generated textures. The base game has no hand-modelled meshes and no glTF.
- **Billboards and sprites** are used for all loot items, Echoes, particles, signage, debris clutter, and the sentry eye glows:
  - Y-axis billboards with a slow bob or spin for items, so only **one view** is ever needed. That removes the multi-view consistency problem entirely.
  - Camera-facing billboards for particles and glows.
- **The render target is low-res** (default 480×270, nearest-upscaled). Optional vertex snapping, affine warping, and dithering are flat-screen only (§10.1). Lighting is vertex lighting plus a few point lights, and each sector has distance fog.
- **Readability rules:** opening classes get color-coded rim lights when scanned (XL blue, L green, M yellow, S orange, F white). Sentry states always use the same lights (grey, yellow, red, then sparking). Radiation hazards pulse magenta. Dead ruins are dark and loot glows.
- **The dome:** warm interior light against the cold outside. The safe-place pillar, made visible.

### 11.2 Palette & texture limits

- **Indexed-color textures + palette LUT:** every texture is stored as an 8-bit indexed PNG, which the shader looks up through a 256×N palette LUT texture.
  - Each civ uses one **16-color ramp set**: 4 ramps × 4 shades, plus emissive colors.
  - There's a shared 16-color neutral/UI palette.
  - **Procedurally generated civs reuse authored art by swapping palettes.** There can be endless civs but only around 6 *style families* of art, so this reuse is essential.
- **Sizes** (all powers of two):

  | Asset | Size |
  |---|---|
  | Tiling surfaces | 64×64 (default) or 128×128 |
  | Hero textures | at most 256×256 |
  | Item and Echo sprites | 64×64 |
  | Large props and sentry decals | 128×128 |
  | Particles | 16×16 or 32×32 |
  | UI icons | 32×32 |
  | Skyboxes | 512×256 equirect per sector style |
  | Kit atlases | 1024×1024 |

- **Alpha is 1-bit (cutout)** on sprites. That avoids halos when downsampling and sorting problems with transparency.
- Textures use nearest filtering with no mipmaps at the default resolution. Mipmaps are on in XR to reduce shimmer.

### 11.3 Consistency per civilization ("style cards")

Each style family has a style card at `data/base/art/styles/<family>.lua`:
- shape-language words (e.g., *crystalline, faceted, cold*)
- 4–6 material words (*frosted glass, etched silver, blue resin*)
- a motif (*hexagonal lattices*)
- lighting words (always *flat, evenly lit*)
- a palette ID
- 1–3 **reference images** (previously accepted outputs) passed to Grok Imagine's image-editing / reference mode so new outputs stay on-model

The palette lock in §11.2 then pulls any drift in color back into line. Generated civs get assigned a family plus a palette shift, so they look related but distinct.

### 11.4 Prompt style guide

Prompts are built from templates (`tools/artpipe/prompts/*.txt`) combining the style card with the asset type. Nobody writes them freehand.

- **Tiling surface:** `"{surface} panel, {shape words}, {material words}, {motif}, seamless tileable texture, orthographic top-down view, flat even lighting, no shadows, no perspective, 1990s video game texture, low detail, bold shapes, limited colors, no text, no letters, no logos, no watermark"`
- **Item sprite:** `"single {object} alien artifact, {shape words}, {material words}, centered, three-quarter view, isolated on solid magenta #FF00FF background, flat lighting, crisp silhouette, chunky readable shapes, retro game sprite, no text, no shadow on background"`
- **Signage / glyph decal:** this is generated procedurally in code from the civ glyph set. **Text is never generated** with the image model.
- **Skybox:** `"{sector mood} nebula and starfield, deep space, painterly, wide panorama, no planets in foreground, no text"`
- **Rules:**
  - Never name living artists, studios, franchises, or existing games.
  - Never include real logos or real text.
  - Every prompt, including rejected ones, is recorded in the repo (§11.6).

### 11.5 Pipeline (`tools/artpipe`, outside the game binary)

1. **Generate:** run the prompt template and style card through Grok Imagine, in batches of 4–8 candidates per asset. Every request is appended to `art/prompts/log.jsonl`, with the full prompt, every parameter, the model/version, the date, and each generation ID (§11.6). Raw downloads go to `art/raw/` (Git LFS).
2. **Curate:** a human picks or rejects each candidate, using a checklist:
   - no text or logos
   - no recognisable IP
   - the silhouette reads at 64 px
   - it fits the style card

   The outcome of every candidate, accepted or rejected, is written back to the log entry.
3. **Process (deterministic):**
   1. crop, then key out the magenta background
   2. box-downscale to the target size
   3. **palette-quantize** to the civ palette with ordered dithering (4×4 Bayer, strength set per asset type)
   4. threshold alpha
   5. emit an indexed PNG
4. **Tile-check (surfaces):** do a half-offset wrap and measure the seam error along the edges. Anything over the threshold gets auto-fixed (seam blend, then re-quantize) or sent back to step 1.
5. **Pack:** write the files to `data/base/generated/textures/<family>/…`, `generated/sprites/…`, and `generated/skyboxes/…` (hand-made assets go under `authored/`). Build the kit atlases, one per license class, and generate a `.meta.lua` sidecar for each file with:
   - palette ID
   - tiling flags
   - sprite pivot
   - `license`
   - credit
   - a `generation` block (the full prompt record)
   - a `processing` block (settings and the source/output hashes)

   Then run `artpipe attrib` to regenerate `ATTRIBUTION.md` and `REUSE.toml`.
6. **CI lint** (blocking). It fails if:
   - any asset lacks a sidecar, a `license` field, or a credit
   - the license isn't one of the three allowed SPDX IDs
   - a generated asset lacks a complete prompt record, or its `request_id` isn't in `art/prompts/log.jsonl`
   - a generated asset sits outside `generated/`, or an `authored/` asset carries a generation block
   - an atlas mixes license classes
   - sizes aren't powers of two, or a PNG isn't indexed or uses colours outside its palette
   - `artpipe verify` finds an output hash mismatch
   - `ATTRIBUTION.md` or `REUSE.toml` is stale, or `reuse lint` fails

   The xAI-terms placeholder only *warns* on PRs, but it fails the release job.

### 11.6 Licensing classes, prompt records & attribution

Saucer has **three license classes**, identified by SPDX IDs in every asset sidecar (`license = "..."`):

| Class (SPDX) | Covers | Where |
|---|---|---|
| `MIT` | Engine C, tools, tests, **all Lua** (scripts, data tables, style cards, **mesh recipes**, prompt templates), and content procedurally generated at runtime (glyph decals, meshes) | `engine/`, `tools/`, `tests/`, `data/**/*.lua`, `mods/**/*.lua` |
| `CC-BY-4.0` | **Hand-authored, non-generated** art and audio (sounds, music, fonts, hand-drawn textures/sprites), plus third-party CC BY assets, which keep their original authors' attribution | `data/base/authored/**` |
| `LicenseRef-xAI-Output` | **Images generated with Grok Imagine**, and every processed derivative of them (quantized, cropped, atlased). These are covered by **xAI's terms for outputs**, not by CC BY 4.0. | `data/base/generated/**` only |

- **Separate folders:** generated and authored assets never share a folder. Atlases never mix classes, so there's one atlas per class per kit.
- **Mixed assets:** a hand-edited image that started from a generated one counts as **generated**. This conservative rule lives in `LICENSING.md`, and Steve can revise it later.
- **xAI's terms aren't restated or interpreted here.** `LICENSES/LicenseRef-xAI-Output.md` contains a pointer to xAI's terms for outputs: **Steve has to add the exact URL(s)** and the date he retrieved them. Until he does, the license lint warns on every PR, and the release job fails (§11.5).
- **Prompt records (every prompt is documented in the repo):**
  - `art/prompts/log.jsonl` is append-only and has one line per generation *request*, accepted or rejected. Each line records:
    - `request_id`, date, operator
    - the tool (`Grok Imagine`) and its model/version as shown
    - the full prompt text and the template ID plus style card it was built from
    - every parameter used (aspect, size, count, seed if exposed, reference image IDs)
    - each returned **generation ID**
    - the outcome (accepted or rejected, with a reason)
  - Each **accepted** asset's sidecar (`<file>.meta.lua`) holds:
    - a `generation` block: `request_id`, `generation_id`, and the full prompt and params, copied in so the asset is self-describing
    - a `processing` block: artpipe version, palette, dither, crop, downscale, and the hashes of the source and the output
    - `license = "LicenseRef-xAI-Output"`
  - The raw downloads are kept in `art/raw/` (Git LFS), so `artpipe verify` can re-run processing and check the output hashes.
- **Generated licensing files** (by `tools/artpipe attrib`, and committed; CI checks they're up to date):
  - `ATTRIBUTION.md`, grouped by class:
    - **CC BY entries:** title, author, source, license, changes
    - **xAI-output entries:** asset, a "generated with Grok Imagine, subject to xAI's terms for outputs" line linking `LICENSES/LicenseRef-xAI-Output.md`, and a link to the prompt record
  - `REUSE.toml`, so `reuse lint` passes (REUSE layout, with `LICENSES/MIT.txt`, `LICENSES/CC-BY-4.0.txt`, and `LICENSES/LicenseRef-xAI-Output.md`)
- **Hand-written files:**
  - `LICENSING.md`: explains the three classes, the folder map, and the mixed-asset rule
  - the root `LICENSE`: MIT, unchanged
- **Mods:** the manifest declares `licenses = { code = "MIT", assets = { "CC-BY-4.0", "LicenseRef-xAI-Output" } }`, and every mod asset needs a sidecar with a `license` field.
  - The engine loads assets that have no license field, but it logs a warning and flags the mod as "unlicensed assets" on the mod screen.
  - In-repo mods (`mods/example_*`) are held to the same strict CI lint as the base game, including prompt records for generated assets.
  - The credits screen lists every mounted mod by license class.

### 11.7 Voxels: cut

Voxels are **cut**:
- Image generation produces 2D images, while voxel art needs either hand-built models (MagicaVoxel time Steve doesn't have) or 3D generation, so voxels wouldn't share the pipeline above.
- Voxels next to palette-locked textured low-poly and billboards would look inconsistent.
- Dropping them removes a loader, a mesher, and their test surface, which matters with a 95% coverage gate.
- The **mesh builder** covers the chunky, blocky props voxels would have been used for. If voxels come back later, it would be as a mod-provided extension.

### 11.8 Mesh recipes: all 3D geometry is code

There are **no hand-modelled meshes and no glTF in the MVP.** Every mesh is built at load time by the C mesh builder from a **Lua recipe**: kit modules, and the **hero meshes** too (the saucer at each size, the sentries, the trader station, the cockpit console, lever, throttle orb, and furniture). Recipes are code, so they're MIT. Their textures come from the art pipeline.

- **Recipe file:** `data/base/meshes/<id>.lua` returns `function(params, rng) -> recipe`. `params` are typed and declared in the file, for example `config = "villa"|"seat"` for the saucer, or `civ`, `variant`, and `lod` for a Watcher.
- **Primitives:** `box`, `wedge`, `cylinder`, `cone`, `sphere`, `hemisphere`, `ring` (a segmented torus), `lathe` (revolve a 2D profile, which is how the saucer hull is made), and `extrude` (a 2D polygon plus depth).
- **Operations:** `transform` (translate, rotate, scale), `mirror`, `radial_array(n)`, `linear_array(n, step)`, and `merge`.
- **Named nodes and pivots** make up a hierarchy so Lua can animate parts: the Watcher's eye, the Snatcher's claws, the size lever, and the station's spinning ring.
- **Materials per part:** a texture ID (from `generated/` or `authored/`), a palette ID, the UV mode (`box`, `cylindrical`, `spherical`, or `planar`) with a scale, and an emissive flag. Colour variety comes from the palette LUT (§11.2), so one hull texture serves every civ.
- **Collision is declared, not derived:** each recipe declares simple collision shapes (cylinders, boxes, capsules) explicitly. The sim never depends on render-mesh floats, which keeps determinism easy.
- **Determinism:** recipes may only use the `rng` and `params` they're given, plus `saucer.math`. Vertex positions are quantized to 1/1024 m before they're hashed, and the same recipe and params give the same hash on every platform.
- **Budgets and caching:** hero meshes have at most 3k triangles (kit modules at most 1.5k) and take at most 5 ms to build on desktop (20 ms on web). Results are cached by `hash(recipe id, params, mod set)`. `lod` changes segment counts.
- **Saucer sizes:** the saucer recipe is built once per config, giving 4 meshes. A size transition scales the old mesh toward the new size and swaps them at the midpoint behind a fold shimmer, so nothing is rebuilt at runtime.
- **Procedural variety:** sentry and station recipes take a civ seed and shape language, so each civ's robots differ (number of eye facets, claw count, ring radius) while staying recognisable.
- **Dev tool:** `saucer --mesh-preview meshes/saucer.lua --param config=pod` opens an orbit viewer that hot-reloads the recipe. The nightly golden screenshots include every hero recipe.
- **Later:** a `gltf-import` capability for mods that want authored meshes. It's not needed by the base game.

## 12. Audio direction

- Ambient drones per sector, plus a procedural music layer per civ: a scale and instrument set picked from a seed, stems crossfaded by depth and danger.
- The dome interior has warm, muffled ambience (a hum, rain-like hull ticks). Leaving the dome (shrinking or stepping out) audibly "opens" the mix. That's the safety pillar in sound.
- **Sentry telegraphs** are always audible and spatialized: a soft idle hum when Dormant, a rising tone on Alert, a steady tone on Locked, and a falling crackle when Disabled. In co-op, each local viewport has its own listener.
- SFX are lo-fi: 22 kHz-feel synth/sampled, with a distinct chord per size transition (descending when shrinking, ascending when growing).
- Formats: `.ogg` for music and ambience, `.wav` for short SFX. 3D positional audio is simple (pan plus distance attenuation and a low-pass filter).

## 13. Modding, assets & loading

### 13.1 Runtime layout (beside the binary)

```
saucer(.exe)                  # engine binary (or saucer.html/.js/.wasm on web)
data/
  base/                       # the base game IS a mod
    mod.lua                   # manifest
    scripts/                  # gameplay Lua (MIT)
    civs/ kits/ items/ affixes/ input/ ui/   # Lua data tables
    art/styles/                               # style cards (Lua, MIT)
    meshes/                                   # mesh recipes for kits + hero meshes (Lua, MIT)
    palettes/                                 # palette LUT definitions (Lua, MIT)
    generated/textures/ sprites/ skyboxes/    # Grok Imagine outputs (LicenseRef-xAI-Output), .meta.lua with prompt records
    authored/textures/ sprites/ sounds/ music/ fonts/   # hand-authored (CC-BY-4.0), .meta.lua sidecars
mods/
  <mod_id>/mod.lua ...        # user mods, same structure
```

The repository (not shipped next to the binary) also holds `art/prompts/log.jsonl`, `art/raw/` (Git LFS), `LICENSES/`, `LICENSING.md`, `ATTRIBUTION.md`, and `REUSE.toml`. Release packages include `LICENSES/`, `LICENSING.md`, and `ATTRIBUTION.md`.

User data (saves, config, logs) goes in `SDL_GetPrefPath("makesgames", "saucer")` and never beside the binary.

### 13.2 Manifest (`mod.lua`)

```lua
return {
  id = "base", name = "Saucer", version = "0.1.0",
  api = 1,                       -- Lua API major version this mod targets
  depends = {},                  -- e.g. { "base >=0.1" }
  load_after = {},
  entry = "scripts/main.lua",
  licenses = { code = "MIT", assets = { "CC-BY-4.0", "LicenseRef-xAI-Output" } },  -- per-asset license in each .meta.lua
}
```

### 13.3 Virtual file system & load order

- The engine mounts `data/base`, then every enabled mod in topological order (`depends`/`load_after`, ties broken alphabetically) into one VFS. **A later mod's file overrides an earlier one with the same path.** Data tables can also be *merged* through the registry API instead of replaced (`registry.extend("affixes", {...})`).
- Every asset load (`require`, textures, meshes, sounds) goes through the VFS. **Nothing is baked into the binary**, except a tiny built-in fallback (font, error texture, error mesh) so a broken mod still shows an error screen.
- **Hot reload (desktop, dev flag):** a file watcher reloads changed Lua or assets, and the gameplay state gets an `on_reload` hook.
- **Web:** assets are served as plain files next to `saucer.wasm`, listed in a generated `data/index.json` and fetched on demand (an async VFS backend). That keeps "folders beside the binary" true on the web and avoids a monolithic `--preload-file` bundle. Web mods (later) are dropped in as a zip and stored in IndexedDB.
- **Sandbox:** mod Lua gets a restricted environment: no `io`, `os.execute`, `package.loadlib`, `load` with binary chunks, or `debug` (except in test mode). File access only goes through `saucer.vfs` (read-only) and `saucer.save` (namespaced per mod). There's a per-frame instruction budget: if a script exceeds it, the engine logs the overrun and kills the script after 3 strikes.
- **Versioning:** `api` is semver-major. The engine refuses to load mods with a mismatched major version and shows why.

### 13.4 Saves

A save is a Lua-table-shaped binary (or JSON in debug), with one universe save holding the world plus one **player record** per participant, indexed by `record_index` (§3.6). It holds: universe seed, mod set and versions, per-player state, saucer config and modules, the hold, the dome layout, the archive, and **per-site diffs** (looted slot IDs, opened locks, caches, disabled sentry grids), and **mystery progress** (nodes found and decoded, and the ending chosen). Ruins regenerate from their seeds on load.

## 14. C engine vs Lua responsibility map

**Rule of thumb:** C owns *platform, performance, and determinism primitives*. Lua owns *rules, content, and pacing*. If a designer or modder would ever want to change it, it belongs in Lua.

| System | C engine | Lua (base mod) |
|---|---|---|
| Platform (window, GL context, input devices, timing, files) | ✅ SDL3, emscripten, WebXR glue (JS library + C shim) | — |
| Main loop | Fixed 60 Hz sim tick driven only by command frames, plus interpolated render | Tick hooks |
| Input | Devices → player claims → action map → **command frames** (quantized), recording and injection | Action definitions, default bindings, rebinding UI |
| Players & viewports | Player slots P1–P4 with stable `record_index`, one saucer entity per player, viewport layout (1, 2 split, 4 quad, or XR stereo), one camera + listener per viewport | Per-player saucer/state, HUD per viewport, co-op rules (claims, gifting, docking) |
| Rendering | GL 3.3 core / WebGL2 renderer, low-res target, indexed-palette LUT shader, sprites and billboards, fog, lights, XR stereo | Material and palette choices, camera modes, post-FX settings |
| Meshes | **Mesh builder**: primitives, operations, UV modes, named nodes, quantized hashing, cache (no glTF in MVP) | **Mesh recipes** for kit modules and all hero meshes (saucer per size, sentries, station, cockpit props) |
| Assets & VFS | Loaders (indexed PNG via stb_image + palette, OGG via stb_vorbis, WAV), `.meta.lua` sidecars incl. license field, VFS, mod mounting, hot reload | Manifests, registries |
| Entities | Entity store + core components (transform, renderable, collider, body, audio source, `owner_player`) | Script components, behaviors, state machines |
| Physics/collision | Kinematic saucer/character controllers (saucers collide softly with each other, plus fold-phase pairs), cylinder/capsule sweeps vs static BVH, sensor cones, triggers, raycasts, **clearance queries**, all in deterministic math | Size rules, damage rules, tractor logic |
| Determinism | PRNG (PCG32/SplitMix64), deterministic math (`saucer.math`: fixed-point and table-based trig), fixed Lua string-hash seed, sim state snapshot/restore and hashing | Must use only `saucer.math`/`saucer.rng` in sim code |
| Procgen | Grid occupancy/overlap tests, flood-fill reachability | Civ gen, mission grammar, embedding strategy, decay, loot, mystery, validation rules |
| Gameplay | — | Saucer configs, transitions, on-foot, hazards, **sentry state machines**, tools, items, identification, economy, mystery, progression |
| UI | Immediate-mode UI primitives (rects, text, sprites, 9-slice), font rendering, world-space panels (XR), touch widgets | All screens, HUD, menus, dome panels, wrist menu |
| Audio | Mixer, streaming, 3D panning/attenuation, low-pass (one listener per viewport, mixed) | Music logic, which sounds play |
| Save | Serializer (tables ↔ binary), atomic write, slots (IndexedDB on web) | Save schema, diff logic, migrations |
| Net (later) | Transport (UDP on desktop, WebRTC data channel on web), lockstep/rollback scheduler | Lobby UI |
| Testing | Headless mode (null renderer/audio), command injection, replay record/play, state hashing, `--local-players N` | Test scripts, bot scripts, assertions |

### 14.1 Co-op-ready architecture (MVP obligations, co-op ships later)

Co-op is planned in two forms: **local split screen (M2)** and **networked (M3)**. **Each player has their own saucer** (§3.6), there are up to 4 players, and they share one universe and one sector. The MVP ships single-player but must already follow these rules:

1. **The sim is a pure function:** `state[t+1] = step(state[t], commands[t][P1..Pn])`. There's no wall clock, no device reads, no unordered iteration, and no platform libm in the sim. Render and audio only read state.
2. **Input as commands:** each player has one `CommandFrame` per tick: `{player, tick, buttons:u32, axes:int16[6], aim:int16[3]}`. Command frames are the *only* sim input, and they're exactly what replays record and what the network sends later. XR poses are quantized into `aim` and console-interaction events.
3. **Player-indexed state:** every player-specific value lives under `players[i]`: the camera, **their saucer entity**, hands, suit, hold, credits, archive, hot/banked items, bindings, and UI focus. There are no globals like "the player" or "the saucer". `players[i].record_index` (join order within the universe) is stable across sessions and is the only player identity the sim uses. Profile IDs never reach the sim.
4. **One saucer per player:** saucer entities have an `owner` (a record index). Each saucer's hull is a dynamic kinematic collider. `saucer.physics.clearance` includes other saucers' hulls and on-foot players' capsules, and saucer-to-saucer contact is a soft separation with the fold-phase anti-blocking rule (§3.6).
5. **Per-player loot instances:** a loot slot's item seed is `child(slot_seed, "owner", record_index)`. In single-player, record 0 always gives the same items whatever the profile. Shared world objects (Keys, Echoes, and so on) use `slot_seed` directly and record a `claimed_by` field.
6. **Viewports:** the renderer always renders a *list* of viewports, each with its own camera, HUD root, and audio listener. The MVP has 1 (or one stereo pair in XR), and the headless tests run 2.
7. **Snapshot/restore:** the full sim state can be serialized and restored within one tick (needed later for rollback and late joining). A test runs it every tick on replays and compares the hashes.
8. **Lua determinism:**
   - Lua 5.4 is built with a fixed `luai_makeseed`.
   - `math.random` is replaced by a per-system `saucer.rng`.
   - `math.sin`, `cos`, `sqrt` and similar are replaced by deterministic `saucer.math` versions inside the sim environment.
   - `os.time` and `os.clock` aren't available.
   - `pairs()` over sim tables is only allowed through `saucer.util.sorted_pairs`, which is enforced by luacheck and a debug-mode guard.
9. **Simultaneous sites:** up to 4 ruins can be active at once (one per player), each with its own sim budget. Ruins that no player is in are frozen.
10. **Network model (M3):** deterministic lockstep with input delay (2–4 ticks), rollback once snapshot cost allows it, and host authority for saves. Desync detection compares state hashes every 60 ticks, the same mechanism replays use.

### 14.2 Suggested Lua API surface (`api = 1`)

All engine functions are under the global `saucer` table. Gameplay code is event-driven and reads input only through command frames.

```lua
-- lifecycle hooks (defined by the mod entry script)
function on_init(ctx) end            -- after mods mounted
function on_tick(dt, cmds) end       -- fixed 1/60 s; cmds[i] = CommandFrame for player i
function on_render(alpha, view) end  -- per viewport; read-only view of sim state; UI drawing
function on_event(ev) end            -- collisions, triggers, sim events (deterministic order)
function on_reload() end             -- dev hot reload

saucer.log.info(fmt, ...) / .warn / .error
saucer.vfs.read(path) -> string | nil, err ; saucer.vfs.list(dir) -> {paths}
saucer.registry.define(kind, id, tbl) ; .extend(kind, tbl) ; .get(kind, id) ; .all(kind)

saucer.rng.new(seed) -> rng          -- rng:int(lo,hi) rng:fixed() rng:pick(t) rng:weighted(t) rng:child(tag, idx)
saucer.hash64(...) -> int
saucer.math.sin/cos/atan2/sqrt (deterministic) ; .fx(n) fixed-point helpers ; .vec3 ops
saucer.util.sorted_pairs(t)

saucer.players.count() ; .get(i) -> player ; .on_join(fn) ; .on_leave(fn)     -- MVP: count()==1
player.record_index ; player.saucer -> entity id ; player.viewport -> view
saucer.claims.try(entity, player) -> ok ; .owner(entity) -> record_index|nil    -- shared-object claims
saucer.input.define_action(name, kind) ; .bindings(player) ; .rebind(player, name, binding)
saucer.input.device_mode(player) -> "kbm"|"pad"|"touch"|"xr"
cmd:pressed(action) ; cmd:held(action) ; cmd:axis(action) -> fixed ; cmd:aim() -> vec3

saucer.entity.spawn(prefab_or_tbl) -> id ; .destroy(id) ; .get(id, comp) ; .set(id, comp, tbl)
saucer.entity.query{ with = {"collider","tag:loot"} } -> iterator (stable id order)
saucer.physics.raycast(o, d, maxd, mask) -> hit ; .sweep_cylinder(pos, r, h, mask) -> bool, hit
saucer.physics.clearance(pos, shape) -> bool          -- grow/deploy rules
saucer.physics.cone_visible(origin, dir, half_angle, range, target) -> bool   -- sentry sensors
saucer.physics.move(id, velocity, dt) -> moved, hits

saucer.procgen.grid_new(dims) -> grid ; grid:place(module, cell, rot) -> ok ; grid:overlaps(...)
saucer.procgen.reachable(graph, start, classes) -> set
saucer.mesh.build{ parts = { {box=...}, {lathe={profile=...}}, {radial_array={n=6, part=...}} }, collision = {...}, nodes = {...} } -> mesh
saucer.mesh.recipe(id, params) -> mesh                -- builds data/<mod>/meshes/<id>.lua, cached
mesh:node(name) -> node ; node:set_transform(tbl)

saucer.render.viewports() -> {view} ; view:camera(tbl) ; .set_palette(id) ; .post(tbl) ; .sprite(...) ; .billboard(...) ; .light(...)
saucer.xr.available() ; .session() -> nil|"seated"|"standing" ; .comfort() -> tbl ; .haptic(player, hand, strength, ms)
saucer.ui.begin_panel(view_or_worldpanel, ...) / .text / .button / .image / .end_panel  -- immediate mode
saucer.audio.play(sound, opts) -> handle ; .music(stems, opts) ; .stop(handle)
saucer.save.write(slot, tbl) ; .read(slot) -> tbl ; .mod_store() -> namespaced table
saucer.time.tick() -> int ; .sim_seconds()

-- test mode only (headless): saucer.test.*
saucer.test.command(player, frame, ticks) ; .press(player, action, ticks) ; .axis(player, action, v, ticks)
saucer.test.wait(ticks) ; .state_hash() ; .snapshot() ; .restore(snap) ; .assert(cond, msg) ; .screenshot(name)
```

## 15. Testing strategy

**Gates (CI blocks merge):** ≥ **95% line coverage** for C (`engine/`) and for Lua (`data/base/scripts` and data loaders) separately, plus ≥ 85% C branch coverage. All game tests and replays have to pass on every platform in the parity matrix (§15.4).

**The one exclusion:** the thin `engine/src/platform/` backends (raw SDL, GL, and WebXR JS glue) are kept small, under about 2k LOC. They're excluded from the C coverage number but covered by smoke tests (§15.4). Every other C module talks to them only through interfaces with null and mock implementations.

### 15.1 C unit tests
- **Framework:** `utest.h` (single header, MIT), run by CTest.
- **Coverage:** built with `--coverage` and reported through `gcovr` (GCC/Clang). A gcovr HTML artifact is uploaded.
- **Targets:**
  - PRNG and `saucer.math` known-answer vectors (bit-exact on every platform)
  - VFS mount and override order
  - mod manifest parsing and dependency sort
  - the serializer round trip and corrupted-file handling
  - snapshot/restore round trip
  - clearance, sweep, and cone queries
  - flood fill
  - mesh builder output and every base recipe (quantized vertex/index hashes, triangle and build-time budgets)
  - indexed PNG + palette loading
  - the device → player → action → command-frame mapper (including 2–4 players)
  - the viewport layout math
  - the Lua binding layer (each `saucer.*` function called from a C test harness with a real Lua state)
  - the XR pose quantizer
- **Sanitizers:** ASan and UBSan in a Linux debug CI job.

### 15.2 Lua unit tests
- **Framework:** `busted`-compatible specs, run **inside the engine binary** (`saucer --test-lua tests/lua`) so they get the real sandbox and API, with `saucer.*` mockable through test doubles. Coverage comes from `luacov` via debug hooks, enabled only in test mode.
- **Targets:**
  - transition rules (costs, clearance refusals, chaining)
  - cargo, tractor class, and hot/banked rules
  - sentry state machines and the tool effects on them
  - the price formula and demand decay
  - identification outcomes
  - affix rolls per seed
  - mission grammar rewrite rules
  - the decay pass
  - mystery generation (graph validity, host-site assignment) and Echo decoding
  - save diff apply/merge
- **Lint:** luacheck with custom rules: no `pairs` over sim tables, no `math.random`, `math.sin` or similar in sim modules, and no global "player".

### 15.3 Automated game tests (headless, deterministic)
- `saucer --headless --seed <n> --mods base [--local-players N] --script tests/game/<name>.lua` runs the full sim with a null renderer and null audio at a fixed tick, as fast as possible.
- **Scripted scenario tests:** bots inject command frames and assert on game state. Examples:
  - "fly to site 3, shrink to Seat, enter the duct, tractor the item, exit, grow, sell"
  - "jam the Watcher, then pass its cone"
  - "a Snatcher steals a hot item, follow it to the nest, recover the item"
  - "decode three Echoes and open the Resonant vault"
- **Replays:** a `.srep` file has a header (engine version, seed, mod set hash, player count) and per-tick, per-player **command frames**, plus a **state hash** every 60 ticks. CI replays the committed golden replays and fails on the first diverging hash, reporting the tick. Replays get re-recorded through a dedicated, reviewed change.
- **Co-op readiness tests:**
  - A 2-player headless replay (two saucers) must produce stable hashes, and must cover: independent sizes, a grow blocked by the other saucer, a fold-phase unblock, per-player loot instances, and a same-tick Key claim.
  - A snapshot/restore-every-tick replay must match the straight-through hashes.
  - A 2-viewport render test runs with the null renderer and checks that each viewport gets its own camera.
- **Procgen property tests:** for N seeds (500 per PR, 10,000 nightly), generate the mystery, sector, sites, and ruins, and assert the invariants:
  - every loot slot, the Vault, and every Echo archive room are reachable
  - no fallback layout was used
  - the time budget is met
  - module overlap is zero
  - the mystery DAG is acyclic and its Key nodes are reachable
  - the seed → layout hash is stable
- **Golden screenshots** (non-blocking at first): a few fixed camera shots per kit, rendered at 320×180 with a software GL (Mesa llvmpipe), compared with a perceptual diff.

### 15.4 Platform parity matrix

Targets are **Windows, Linux, Web, and WebXR**. macOS is out of scope for now: no CI, no QA, and no platform code beyond what SDL gives for free.

| Check | Linux (gcc + clang) | Windows (MSVC) | Web (emscripten) | WebXR |
|---|---|---|---|---|
| Build | ✅ | ✅ | ✅ | ✅ (same web build, XR flag) |
| C unit tests + coverage | ✅ (coverage gate here) | ✅ (tests only) | ✅ under Node (tests only) | — |
| Lua unit tests + coverage | ✅ (coverage gate here) | ✅ | ✅ under Node | — |
| Headless game tests + golden replays | ✅ | ✅ | ✅ under Node | ✅ (sim is identical) |
| **Cross-platform hash equality** (replays, procgen, mystery) | ✅ | ✅ | ✅ | ✅ |
| Render smoke (boot, 60 frames, screenshot) | ✅ llvmpipe | ✅ WARP/Mesa | ✅ headless Chromium (Playwright, SwiftShader WebGL2) | ✅ headless Chromium + **mock `navigator.xr`** feeding scripted head and controller poses |
| XR interaction smoke (grab lever → size change; pinch → tractor) | — | — | — | ✅ (scripted poses → command frames → state assertions) |
| Manual QA per milestone | ✅ | ✅ | ✅ desktop + Android Chrome | ✅ Quest Browser (seated + standing) |

Compiler and determinism flags: no `-ffast-math`, `-ffp-contract=off`, `/fp:precise` on MSVC, and deterministic `saucer.math` for anything that affects the hash.

### 15.5 CI pipeline
1. Lint and format: clang-format, luacheck with determinism rules, `openspec validate --strict`, and the art/license lint plus `reuse lint` (§11.5).
2. Build matrix: linux-gcc, linux-clang, windows-msvc, emscripten.
3. C unit tests + coverage gate.
4. Lua unit tests + coverage gate.
5. Headless game tests, replays, co-op readiness tests, and the PR set of procgen properties. The hashes from all platforms are compared in a final job.
6. Web render smoke and WebXR mock smoke.
7. Nightly: 10k-seed procgen, a long soak run (2 h simulated), and golden screenshots.

### 15.6 Process (OpenSpec)
- Every feature starts as an OpenSpec change (`openspec/changes/<id>/proposal.md`, `tasks.md`, and spec deltas). Each spec scenario maps to at least one test (unit or game test), and the test is named after the scenario so traceability can be grepped.
- A change only gets archived when its scenarios pass in CI.

## 16. Proposed OpenSpec capabilities & changes

Format follows OpenSpec (`### Requirement:` + `#### Scenario:` with WHEN/THEN). Requirements and scenarios are written out in full for the **MVP** capabilities. The later ones are listed with their purpose only.

**Changes in v0.7:**
- **`saucer-flight-3d`:** six-axis flight that follows the look pitch, lift on every device, a capped bank with the interior locked to the saucer frame, and a 3D radar and altitude tape.
- **`ruin-generation-3d`:** six-direction growth, hatches and shafts, per-kit minimum span and levels, exterior solids, the city kit, and layout known answers.
- **`derelict-play-3d`:** collision on every axis with a broadphase, and 3D sentries and tools.
- Recorded in the OpenSpec change `add-true-3d-flight`. The sim version is 5 and the save format is 2.

**Changes in v0.6:**
- **`trading`, `items-and-identification`:** the lab queue, unknown labels, the terminal with refills and repairs, saved on every transaction.
- **`sentries-and-tools`:** layout-derived placement, the Snatcher leash, the Jammer's 3 m pulse and timer restart. Grid consoles are deferred.
- **`hazards-and-failure`:** shields and hull, Fold Retreat to the last trader, caches.
- **`mystery`:** the carried chain, the Resonant vault and the Curio. **`persistence`:** traders, clock, nests, caches, vault, credits and lab queue in the diffs.
- Recorded in the OpenSpec change `add-one-sector-loop`.

**Changes in v0.5:**
- **`saucer-interior`:** wake-up/title start, doors, furniture Use (kitchen, shower, engine, lab bench, trade terminal, bed), the helm console, and the room-packing fold.
- **`persistence`:** sleeping in the bed saves (seed plus diffs, per-player records). Loading is offered on the title card and at the bed.
- **`saucer-configurations`:** shrink takes 1.5 s, grow 1.8 s.
- Recorded in the OpenSpec change `add-live-in-interior`.

**Changes in v0.4:**
- **New capability `saucer-interior`:** a first-person avatar on foot, the walkable two-deck Villa interior (dome deck with kitchen, living room, and helm; lower deck with bedroom, bathroom, and engine room), taking and leaving the helm, and reconfiguration around the player.
- **`saucer-configurations`:** two sizes (Villa, Seat). Cruiser, Pod, and Pocket are cut. The Seat is only for tight spaces.
- **`ruin-generation`:** derelicts are scaled up so the Villa fits their great halls, and only ducts gate on the Seat.
- **`on-foot`:** stepping out of the saucer (Pocket, Suit Charge, Lifeline) is deferred to post-MVP.
- Recorded in the OpenSpec change `add-walkable-saucer-interior`.

**Changes in v0.3:**
- **`multiplayer-foundation`:** reworked for one saucer per player. Removed: the pilot/crew requirement. Added: one saucer per player, saucers as obstacles to each other, anti-blocking fold-phase, per-player loot instances, shared-object claims, and per-viewport listeners.
- **`mesh-builder`:** glTF removed. Every base mesh, including the hero meshes, now comes from a deterministic Lua recipe. New requirements: hero meshes from recipes, deterministic recipes, declared collision and named nodes, build budget and cache.
- **`art-pipeline`:** reworked around three license classes: a license field on every asset, separated generated assets, a prompt record for every generated asset, reproducible processing (`artpipe verify`), generated licensing files (`ATTRIBUTION.md`, `REUSE.toml`), and the xAI terms reference.
- **`mod-loading`:** added the asset license declaration requirement. **`save-system`:** added player records. **`hazards-and-failure`:** hot/banked items are now tracked per player.
- **`coop-local` (M2):** now also covers docking/dome visits, gifting, party fold jumps, and shared mystery progress, with preview requirements in §16.4. New later capability: `gltf-import` (mods only).
- Change 0 (`init-openspec-project`) now creates `LICENSES/`, `LICENSING.md`, and `REUSE.toml` instead of `LICENSE-ASSETS`. The change order is unchanged.

**Changes in v0.2:**
- **Added (MVP):** `player-input`, `multiplayer-foundation`, `mesh-builder`, `art-pipeline`, `webxr`, `sentries-and-tools`, `mystery`
- **Renamed:** `input-actions` → `player-input`; `deterministic-rng` → `deterministic-sim`, which now also covers deterministic math and Lua determinism
- **Removed:** `voxel-assets` (voxels are cut, §11.7); `defenses-ai` (replaced by `sentries-and-tools`)
- **Moved into the MVP:** `webxr`
- **Added (later milestones):** `coop-local`, `coop-network`, `sentries-advanced`, `mystery-full`
- **Upgraded:** `retro-renderer` is now fully specified (indexed palettes, viewports, XR-safe effects)
- **Platforms:** macOS removed from every requirement

### 16.1 Capability list

| # | Capability | MVP | Purpose |
|---|---|---|---|
| 1 | `engine-core` | ✅ | Boot, fixed-tick loop, SDL3 platform, GL/WebGL2 context, headless mode, platform targets (Windows, Linux, Web) |
| 2 | `deterministic-sim` | ✅ | PCG32/SplitMix64 seeds, deterministic math, Lua determinism rules, cross-platform identity |
| 3 | `asset-vfs` | ✅ | Folder-based VFS, loaders, no baked-in content |
| 4 | `mod-loading` | ✅ | Manifests, dependency order, overrides, sandbox, API versioning |
| 5 | `lua-runtime` | ✅ | Embedded Lua 5.4, `saucer.*` API v1, hooks with command frames, instruction budget, read-only render |
| 6 | `player-input` | ✅ | Device → player claims, action map, quantized command frames, per-player rebinding |
| 7 | `multiplayer-foundation` | ✅ | Player-indexed state (`record_index`), one saucer per player, saucer-vs-saucer clearance and soft collision with fold-phase, per-player loot instances, shared-object claims, viewport list, snapshot/restore (co-op-ready, single-player in MVP) |
| 8 | `test-harness` | ✅ | Headless scripts, replays of command frames, state hashing, parity matrix, coverage gates |
| 9 | `retro-renderer` | ✅ | Low-res target per viewport, indexed palette LUT, billboards, optional retro effects (XR-safe) |
| 10 | `mesh-builder` | ✅ | Deterministic Lua mesh recipes for **all** geometry (kit modules + hero meshes: saucer per size, sentries, station, cockpit props); no mesh files |
| 11 | `art-pipeline` | ✅ | `tools/artpipe` (generate → curate → quantize → tile-check → pack → attrib), three license classes, prompt log + per-asset prompt records, separated `generated/` vs `authored/`, generated `ATTRIBUTION.md`/`REUSE.toml`, CI license/prompt lint |
| 12 | `webxr` | ✅ | Seated/standing dome cockpit, controller + hand mapping, comfort options |
| 13 | `saucer-configurations` | ✅ | Two sizes (Villa, Seat), transitions around the player, clearance, Charge costs, interior folding, tractor class |
| 13a | `saucer-interior` | ✅ | First-person avatar, walkable two-deck Villa (dome deck and lower deck), helm, reconfiguration around the eye |
| 14 | `ruin-generation` | ✅ (2 kits) | Kits, mission grammar, embedding, decay, validation, injected archive rooms; great halls fit the Villa, ducts need the Seat |
| 15 | `sector-generation` | ✅ (1 sector) | Sites, traders, danger tier from seed |
| 16 | `items-and-identification` | ✅ | Item model, affixes/quirks, Echoes, lab bench |
| 17 | `trading` | ✅ | Price formula, demand, buy/sell at one trader |
| 18 | `on-foot` | post-MVP | Pocket/deploy/recall, walking outside the saucer, Suit Charge, hands inventory, Lifeline |
| 19 | `sentries-and-tools` | ✅ (Watcher, Snatcher, Scanner, Jammer, grid console) | Sentry state machine, non-lethal tools |
| 20 | `hazards-and-failure` | ✅ (subset) | Hot/banked items, Fold Retreat, radiation, debris, dome safety |
| 21 | `mystery` | ✅ (3-node chain) | Seeded central mystery, Echo placement and decoding, On/Hints/Off |
| 22 | `save-system` | ✅ | Seed + diffs, per-player records, atomic writes, mod-set check |
| — | `touch-controls` | ✅ basic (polish in presentation) | Mobile web virtual controls, auto-hover, assists |
| — | `coop-local` | M2 | Split-screen 2–4 players, each with their own saucer: join flow, split layouts, gifting, docking/dome visits, party fold jumps, shared mystery progress and ending vote |
| — | `fold-jumps` | M2 | Multi-sector travel, Fold Core range |
| — | `civilizations` | M2 (MVP has 2 hand-tuned trait sets) | Full trait generation, glyphs, style-family assignment, procedural music |
| — | `xenoarchive` | M2 | Per-civ catalog, completion rewards, Echo translation gate |
| — | `requests-and-reputation` | M2 | Trader requests, reputation unlocks |
| — | `sentries-advanced` | M2/M3 | Clamp, Lockdown node, Warden; Decoy, Shroud, Override spike |
| — | `mystery-full` | M2 | Multiple causes, 5–9 node chains across sectors, Heart site, endings, universe-state changes |
| — | `dome-home` | M3 (two-deck home in the slice; lab bench in the one-sector loop) | Display slots, Comfort, rooms, furniture, garden |
| — | `coop-network` | M3 | Lockstep (later rollback) over UDP/WebRTC, lobby, desync detection, host-stored player records |
| — | `gltf-import` | Later (mods only) | Optional glTF mesh loading for mods; the base game never needs it |

### 16.2 Proposed changes (in order)

0. `init-openspec-project`: `openspec init`, `project.md` (conventions, license classes, coverage gates, platform targets), README, `LICENSING.md`, a `LICENSES/` folder (MIT, CC-BY-4.0, and a `LicenseRef-xAI-Output.md` placeholder for Steve's link), and stubs for `REUSE.toml` and `ATTRIBUTION.md`
1. `add-engine-core-headless`: CMake + presets (MSVC, GCC, Clang, emscripten), the fixed tick loop, null renderer/audio, and a CI matrix skeleton with 95% coverage gates from day one
2. `add-deterministic-sim`
3. `add-asset-vfs-and-mod-loading` (covers `asset-vfs` + `mod-loading`)
4. `add-lua-runtime-api-v1`
5. `add-player-input-commands`
6. `add-multiplayer-foundation`
7. `add-test-harness-replays`
8. `add-retro-renderer-basic`
9. `add-mesh-builder` (includes the recipes for the saucer, Watcher, Snatcher, trader station, and cockpit props)
10. `add-art-pipeline-tools` (includes the license lint, the prompt log, `artpipe verify`, and `artpipe attrib`)
11. `add-webxr-cockpit`
12. `add-saucer-configurations`
13. `add-ruin-generation-mvp` (starship + station kits)
14. `add-sector-generation-mvp`
15. `add-items-identification-tractor`
16. `add-trading-mvp`
17. `add-on-foot-pocket-mode`
18. `add-sentries-and-tools-mvp`
19. `add-hazards-and-failure-mvp`
20. `add-mystery-clue-chain-mvp`
21. `add-save-system`
22. `add-walkable-saucer-interior` (first-person avatar, two-deck Villa, two sizes, derelict scale; defers `on-foot`)
23. `add-holodeck-home-life` (holodeck programs and modules, cooking buffs, bookshelf, TV hints; roadmap milestone 4)
24. `add-pocket-station-visits` (Pocket configuration docked only, walkable station interiors, on-foot trading, the pickpocket; roadmap milestone 5)

Changes 1–8 are the architectural spine. Determinism, command frames, and viewports have to land before any gameplay, so co-op and XR aren't retrofitted later. Change 22 reworks 12 and 13 around the v0.4 fantasy. The living implementation plan is `docs/ROADMAP.md`.

### 16.3 MVP requirements & scenarios

They're listed in the same order as the changes in §16.2.

---
**Capability: `engine-core`** (`openspec/specs/engine-core/spec.md`)

### Requirement: Fixed simulation tick
The engine SHALL advance game simulation in fixed steps of 1/60 s, independent of render frame rate, and SHALL interpolate rendering between the last two sim states.

#### Scenario: Slow frame
- **WHEN** a render frame takes 50 ms
- **THEN** the engine runs 3 sim ticks before the next render, capped at 8 ticks per frame

### Requirement: Headless mode
The engine SHALL run with `--headless` using null renderer and null audio backends, without creating a window, and SHALL exit with status 0 on script success and non-zero on any assertion failure or Lua error.

#### Scenario: CI run without display
- **WHEN** `saucer --headless --script tests/game/boot.lua` runs on a machine with no display
- **THEN** the game boots, runs the script, and exits 0

### Requirement: Supported platforms
The engine SHALL build and pass CI on Windows (MSVC), Linux (GCC and Clang), and Web (emscripten, WebGL2), and the web build SHALL support WebXR sessions. macOS SHALL NOT be a required target.

#### Scenario: CI matrix
- **WHEN** a PR is opened
- **THEN** the windows-msvc, linux-gcc, linux-clang, and emscripten jobs all build and run the test suites, and no macOS job is required

---
**Capability: `deterministic-sim`** (`openspec/specs/deterministic-sim/spec.md`), renamed from `deterministic-rng`

### Requirement: Bit-identical generation across platforms
The PRNG and seed derivation SHALL produce identical outputs for identical inputs on Windows, Linux, and wasm builds.

#### Scenario: Known-answer test
- **WHEN** `saucer.rng.new(42)` draws 1,000 `int(0, 2^31-1)` values
- **THEN** they match the committed reference vector on every CI platform

### Requirement: Hierarchical seeds
Child seeds SHALL be derived as `splitmix64(parent ~ hash64(tag) ~ index)`, so generating one child never consumes another child's stream.

#### Scenario: Order independence
- **WHEN** site 5 of sector (0,0,0) is generated before or after site 2
- **THEN** site 5's layout hash is identical in both cases

### Requirement: Deterministic math in the sim
Sim code (C and Lua) SHALL use only `saucer.math` for trigonometry, square roots, and fixed-point arithmetic. The Lua sim environment SHALL replace `math.random`, `math.sin`, `math.cos`, `math.sqrt`, and similar with deterministic versions, and SHALL NOT expose `os.time` or `os.clock`.

#### Scenario: Known-answer trig
- **WHEN** `saucer.math.sin` is evaluated at 4,096 fixed inputs
- **THEN** the results match the committed vector bit-for-bit on every platform

### Requirement: Stable Lua iteration and hashing
The embedded Lua SHALL be built with a fixed string-hash seed, and sim code SHALL iterate non-array tables only through `saucer.util.sorted_pairs`, which luacheck enforces.

#### Scenario: Two runs, same order
- **WHEN** the same replay runs twice in separate processes
- **THEN** event dispatch order and the final state hash are identical

---
**Capability: `asset-vfs`** (`openspec/specs/asset-vfs/spec.md`)

### Requirement: Assets beside the binary
The engine SHALL load all gameplay scripts, models, textures, sprites, sounds, and music from the `data/` and `mods/` folders beside the executable (or the served web root), and SHALL NOT embed game content in the binary other than a fallback font, error texture, and error mesh.

#### Scenario: Missing texture
- **WHEN** a model references a texture path that doesn't exist in the VFS
- **THEN** the engine logs a warning naming the path and renders the error texture

#### Scenario: Web build
- **WHEN** the web build starts
- **THEN** it fetches `data/index.json` and loads assets over HTTP on demand, with no preloaded data bundle

---
**Capability: `mod-loading`** (`openspec/specs/mod-loading/spec.md`)

### Requirement: Load order and override
The engine SHALL mount `data/base` first and then enabled mods in dependency order (ties broken alphabetically by id), and a file at the same VFS path in a later mod SHALL override the earlier one.

#### Scenario: Mod overrides a sound
- **WHEN** mod `loud_shrink` contains `sounds/shrink.wav` and depends on `base`
- **THEN** playing `sounds/shrink.wav` plays the mod's file

#### Scenario: Dependency cycle
- **WHEN** mod A depends on B and B depends on A
- **THEN** neither loads, and the mod screen shows the cycle

### Requirement: Script sandbox
Mod Lua SHALL run without access to `io`, `os.execute`, `package.loadlib`, binary chunk loading, or `debug`, and SHALL access files only through `saucer.vfs` and `saucer.save`.

#### Scenario: Forbidden call
- **WHEN** a mod script calls `io.open("x")`
- **THEN** a Lua error naming the mod is raised and logged, and the game keeps running

### Requirement: API versioning
The engine SHALL refuse to load a mod whose manifest `api` major version differs from the engine's, and SHALL show the reason.

#### Scenario: Old mod
- **WHEN** a mod declares `api = 0` on an engine with API 1
- **THEN** the mod is skipped and listed as "incompatible API 0 (engine 1)"

### Requirement: Mods declare asset licenses
A mod manifest SHALL declare `licenses = { code = ..., assets = {...} }` using SPDX IDs (including `LicenseRef-*`). The engine SHALL load assets without a sidecar `license` field, but SHALL log a warning and mark the mod "unlicensed assets" on the mod screen. The credits screen SHALL list every mounted mod grouped by license class.

#### Scenario: Unlicensed sprite in a user mod
- **WHEN** a user mod contains a sprite whose sidecar has no `license`
- **THEN** the sprite loads, a warning names it, and the mod screen shows "unlicensed assets"

---
**Capability: `lua-runtime`** (`openspec/specs/lua-runtime/spec.md`)

### Requirement: Lifecycle hooks
The runtime SHALL call `on_init` once after mounting, `on_tick(dt, cmds)` each sim tick with that tick's per-player command frames, `on_render(alpha, view)` once per viewport per frame, and `on_event(ev)` for each queued event, in mod load order.

#### Scenario: Tick count
- **WHEN** the headless game runs for 120 ticks
- **THEN** `on_tick` has been called exactly 120 times with `dt == 1/60`, and `#cmds == saucer.players.count()` on every call

### Requirement: Instruction budget
The runtime SHALL enforce a per-tick instruction budget per mod, and SHALL disable a mod's hooks after 3 overruns, logging each one.

#### Scenario: Infinite loop
- **WHEN** a mod's `on_tick` loops forever
- **THEN** that tick is aborted, a warning is logged, and after the third overrun the mod is disabled while the game continues

### Requirement: Render cannot mutate the sim
`on_render` SHALL receive a read-only view of sim state. In debug and test builds, writes to sim state from render code SHALL raise an error.

#### Scenario: Illegal write
- **WHEN** an `on_render` handler assigns to an entity's position in a debug build
- **THEN** a Lua error naming the file and line is raised, and the sim state hash is unchanged

---
**Capability: `player-input`** (`openspec/specs/player-input/spec.md`)

### Requirement: Devices claimed by players
Every input device SHALL be claimed by exactly one local player slot (P1–P4), and the claim screen SHALL let a device join or leave a slot. In the MVP, all devices default to P1.

#### Scenario: Second gamepad
- **WHEN** a second gamepad connects while P1 uses KB/M
- **THEN** it's offered "Press A to join as P2", and with co-op disabled (MVP) it stays unclaimed and has no effect on the sim

### Requirement: Command frames are the only sim input
Each tick, the engine SHALL pack each active player's actions into a `CommandFrame` `{player, tick, buttons:u32, axes:int16[6], aim:int16[3]}`, with quantized axes, and the sim SHALL NOT read devices directly.

#### Scenario: Replay equivalence
- **WHEN** a recorded session's command frames are replayed headless with no devices attached
- **THEN** every 60-tick state hash matches the live session

### Requirement: Per-player rebinding
Bindings SHALL be defined as named actions in Lua data, stored per player profile, and rebindable at runtime.

#### Scenario: Rebind Shrink
- **WHEN** P1 rebinds Shrink from `Q` to `Z`
- **THEN** `Z` shrinks, `Q` does nothing, and the binding persists after a restart

---
**Capability: `multiplayer-foundation`** (`openspec/specs/multiplayer-foundation/spec.md`)

### Requirement: Player-indexed state
All player-specific state (camera, saucer entity, hands, suit, hold, credits, archive, hot/banked items, UI focus, bindings) SHALL live under `players[i]`, keyed in the sim only by the stable `record_index`, and no sim code SHALL reference a global player or saucer.

#### Scenario: Two headless players
- **WHEN** a headless test runs with `--local-players 2` and both players are given different command streams
- **THEN** each player's state changes only from their own commands, and the replay hashes are stable across platforms

### Requirement: One saucer per player
Each player SHALL own exactly one saucer entity (`owner = record_index`), whose size configuration, Charge, hold, and interior are independent of every other player's.

#### Scenario: Independent sizes
- **WHEN** P1 shrinks to Seat while P2 stays Villa in a 2-player headless test
- **THEN** only P1's saucer changes size, and only P1's Charge drops

### Requirement: Saucers are obstacles to each other
Clearance checks for grow and deploy SHALL treat other players' unpocketed saucer hulls and on-foot player capsules as solid. Saucer-to-saucer contact SHALL only separate the saucers, with no hull damage.

#### Scenario: Grow blocked by a friend
- **WHEN** P1 at Seat tries to unfold to Villa while P2's saucer is inside the Villa volume
- **THEN** the grow is refused at no cost, and P1 sees the red ghost hull

#### Scenario: Bump
- **WHEN** two saucers collide at full speed
- **THEN** both are pushed apart, and neither loses hull or shields

### Requirement: Anti-blocking fold-phase
When a player's movement pushes into another player's saucer for 2 continuous seconds without making progress, those two saucers SHALL stop colliding with each other for 3 s.

#### Scenario: Friend parked in a duct
- **WHEN** P2's Seat sits idle in a 2.5 m duct and P1's Seat pushes into it for 2 s
- **THEN** P1 passes through P2 within the next 3 s, and both then collide normally again

### Requirement: Per-player loot instances
Module, Curio, Tool, and Material loot slots SHALL roll one item per player, from `child(slot_seed, "owner", record_index)`, and each instance SHALL be visible and collectible only by its owner.

#### Scenario: Same slot, two players
- **WHEN** P1 and P2 both tractor loot slot 7
- **THEN** each gets their own item, and P1's item is identical to the one a single-player record 0 would get

### Requirement: Shared-object claims
Keys, power cells, Echoes, and other shared world objects SHALL exist once. The first completed pickup claims the object. Same-tick ties SHALL go to the player with the lowest `(record_index + tick) mod n`.

#### Scenario: Same-tick grab
- **WHEN** P1 (record 0) and P2 (record 1) complete a pickup of one Key on tick 101 with n = 2
- **THEN** P2 gets the Key ((1+101) mod 2 = 0 is lower than (0+101) mod 2 = 1)

### Requirement: Multiple viewports
The renderer SHALL render an ordered list of viewports (1, 2 split, 4 quad, or an XR stereo pair), each with its own camera, HUD root, and audio listener, at a uniform pixel scale, and the MVP SHALL use this path even when there's only one viewport.

#### Scenario: Split layout
- **WHEN** the viewport count is set to 2 in a test build with a 480×270 internal target
- **THEN** two 240×270 viewports render with independent cameras, and `on_render` is called once per viewport

### Requirement: Snapshot and restore
The full sim state SHALL be serializable to a snapshot and restorable within one tick, and doing so SHALL NOT change any future state hash.

#### Scenario: Restore every tick
- **WHEN** a golden replay runs with snapshot → restore before every tick
- **THEN** all state hashes equal the straight-through run

---
**Capability: `test-harness`** (`openspec/specs/test-harness/spec.md`)

### Requirement: Replays with state hashes
The engine SHALL record and play back `.srep` replays (header + per-tick, per-player command frames) and SHALL compute a deterministic state hash every 60 ticks. Playback SHALL fail on the first hash mismatch and report the tick.

#### Scenario: Divergence
- **WHEN** a code change alters the saucer's acceleration
- **THEN** the golden replay fails, reporting the first tick whose hash differs

### Requirement: Cross-platform determinism
Golden replays and procgen hashes SHALL produce identical results on Linux, Windows, and wasm (Node) CI runners, and in the WebXR mock run.

#### Scenario: CI matrix
- **WHEN** the replay `mvp_loop.srep` runs on linux-gcc, linux-clang, windows-msvc, and emscripten/Node
- **THEN** all final state hashes are equal

### Requirement: Coverage gates
CI SHALL fail when C line coverage (excluding `engine/src/platform/`) or Lua line coverage (`data/base/scripts`) falls below 95%, or C branch coverage falls below 85%.

#### Scenario: Under-tested change
- **WHEN** a PR drops Lua coverage to 94.2%
- **THEN** the coverage job fails and reports the uncovered files

---
**Capability: `retro-renderer`** (`openspec/specs/retro-renderer/spec.md`)

### Requirement: Low-res target
The renderer SHALL render each viewport to a configurable low-res target (default 480×270 on flat screens, 720×800 per eye in XR) and integer-upscale it with nearest filtering.

#### Scenario: Resolution change
- **WHEN** the internal resolution is set to 320×180
- **THEN** the frame is rendered at 320×180 and upscaled, and the sim state hash is unaffected

### Requirement: Indexed textures with palette LUT
Textures SHALL be loaded as 8-bit indexed images and colored through a palette LUT selected per material, so the same texture can be rendered with any civ palette.

#### Scenario: Palette swap
- **WHEN** a kit module's palette is changed from `vell` to `orun`
- **THEN** the same texture renders with the `orun` colors and no texture is reloaded

### Requirement: Sprites and billboards
The renderer SHALL draw Y-axis and camera-facing billboards with 1-bit alpha cutout, sorted correctly against opaque geometry.

#### Scenario: Loot item
- **WHEN** a loot item is spawned
- **THEN** it's drawn as a Y-axis billboard with its sprite, bobbing as defined in its Lua data

### Requirement: Retro effects are optional and XR-safe
Vertex snapping, affine warping, and dithering SHALL each be toggleable. Vertex snapping and affine warping SHALL be forced off during XR sessions.

#### Scenario: XR session starts
- **WHEN** a WebXR session begins with vertex snapping enabled in the flat-screen settings
- **THEN** vertex snapping is disabled for the XR views and restored when the session ends

---
**Capability: `mesh-builder`** (`openspec/specs/mesh-builder/spec.md`)

### Requirement: Primitive mesh building
The engine SHALL build meshes from Lua-declared primitives (box, wedge, cylinder, cone, sphere, hemisphere, ring, lathe, extrude) and operations (transform, mirror, radial_array, linear_array, merge), with per-part material, palette, and UV mode (box, cylindrical, spherical, planar).

#### Scenario: Kit module
- **WHEN** `saucer.mesh.build{parts={{box={4,4,4}},{cylinder={r=1,h=4}}}}` is called
- **THEN** a mesh is returned whose quantized vertex/index hash matches the committed reference

### Requirement: Hero meshes from recipes
All base-game meshes, including the saucer in each size configuration, every sentry, the trader station, and the cockpit console, lever, and throttle orb, SHALL be produced from Lua recipes in `data/base/meshes/`. The base game SHALL NOT ship mesh files.

#### Scenario: Saucer per config
- **WHEN** `meshes/saucer.lua` is built with `config = "villa"` and `"seat"`
- **THEN** two meshes are returned whose bounding cylinders match the hull sizes in `saucer/configs.lua` within 1 cm

#### Scenario: No mesh files
- **WHEN** CI scans `data/base/`
- **THEN** it finds no `.glb`, `.gltf`, `.obj`, or `.vox` files

### Requirement: Deterministic recipes
Recipes SHALL use only their `params`, the `rng` they're given, and `saucer.math`. The same recipe and params SHALL produce the same quantized hash (positions at 1/1024 m) on every platform.

#### Scenario: Civ variant
- **WHEN** `meshes/watcher.lua` is built with civ seed `0x51` on Linux, Windows, and wasm
- **THEN** all three hashes are equal, and a different civ seed gives a different hash

### Requirement: Declared collision and named nodes
Recipes SHALL declare collision shapes explicitly, and the sim SHALL use only those shapes. Recipes SHALL expose named nodes with pivots so Lua can animate them.

#### Scenario: Animated eye
- **WHEN** a Watcher's script rotates node `eye` by 30°
- **THEN** only the eye's geometry moves, and the Watcher's collision shape is unchanged

### Requirement: Build budget and cache
A hero mesh SHALL have at most 3k triangles and build in at most 5 ms on desktop (20 ms on web). Results SHALL be cached by `hash(recipe id, params, mod set)`.

#### Scenario: Second request
- **WHEN** the same recipe and params are requested twice
- **THEN** the second request returns the cached mesh without rebuilding

---
**Capability: `art-pipeline`** (`openspec/specs/art-pipeline/spec.md`)

### Requirement: License field on every asset
Every non-Lua asset under `data/` and in-repo `mods/` SHALL have a `.meta.lua` sidecar with a `license` field set to one of `MIT`, `CC-BY-4.0`, or `LicenseRef-xAI-Output`, plus a credit.

#### Scenario: Missing license
- **WHEN** a PR adds `authored/sounds/hum.ogg` with a sidecar that has no `license` field
- **THEN** the art lint job fails and names the file

### Requirement: Separated generated assets
Assets licensed `LicenseRef-xAI-Output` SHALL live only under `generated/` folders, and assets under `authored/` SHALL NOT carry a `generation` block or the xAI license. Atlases SHALL NOT mix license classes.

#### Scenario: Misfiled asset
- **WHEN** a generated sprite is committed under `authored/sprites/`
- **THEN** lint fails with "generated asset outside generated/"

### Requirement: Prompt record for every generated asset
Every generated asset's sidecar SHALL contain a `generation` block (`request_id`, `generation_id`, full prompt, template ID, style card, all params, model/version, date) that resolves to a matching entry in `art/prompts/log.jsonl`. Every generation request, accepted or rejected, SHALL have a log entry.

#### Scenario: No prompt record
- **WHEN** a PR adds `generated/textures/vell/hull_03.png` whose sidecar lacks `generation.prompt` or whose `request_id` isn't in the log
- **THEN** lint fails and names the missing field or ID

### Requirement: Reproducible processing
`tools/artpipe process` SHALL produce byte-identical output for the same raw image, palette, and settings, and `artpipe verify` SHALL re-process every raw file in `art/raw/` and compare the result to the sidecar's output hash.

#### Scenario: Tampered output
- **WHEN** a processed PNG is edited by hand without updating its sidecar
- **THEN** `artpipe verify` fails, reporting a hash mismatch

### Requirement: Palette and size conformance
Art lint SHALL reject textures whose dimensions aren't powers of two within the size limits in §11.2, and textures that aren't indexed, or that use colors outside their declared palette.

#### Scenario: Off-palette pixel
- **WHEN** a processed texture contains a color index outside its palette
- **THEN** lint fails and reports the first offending pixel

### Requirement: Generated licensing files
`ATTRIBUTION.md` (grouped by license class) and `REUSE.toml` SHALL be generated from the sidecars by `artpipe attrib`, and CI SHALL fail if the committed versions differ from freshly generated ones, or if `reuse lint` fails.

#### Scenario: Stale attribution
- **WHEN** a PR adds a CC BY sound without regenerating `ATTRIBUTION.md`
- **THEN** CI fails with a diff of the expected file

### Requirement: xAI terms reference
`LICENSES/LicenseRef-xAI-Output.md` SHALL contain at least one URL to xAI's terms for outputs, plus a retrieval date. Until it does, lint SHALL warn on PRs and the release job SHALL fail.

#### Scenario: Placeholder present
- **WHEN** a release build is triggered while the file still contains `TODO: link xAI terms`
- **THEN** the release job fails, and the message asks for the terms URL

---
**Capability: `webxr`** (`openspec/specs/webxr/spec.md`)

### Requirement: Enter XR from the web build
When `navigator.xr` supports `immersive-vr`, the web build SHALL offer an "Enter VR" control, and it SHALL start the session in the dome cockpit in Seated mode by default, with Standing mode available.

#### Scenario: Unsupported browser
- **WHEN** the browser lacks WebXR
- **THEN** no VR control is shown, and the flat-screen game is unaffected

### Requirement: Player scale is constant
During size transitions in XR, the player's world scale and horizon SHALL remain constant, and only the cockpit geometry SHALL change.

#### Scenario: Shrink in VR
- **WHEN** the player pulls the size lever from Villa to Seat
- **THEN** the interior folds in around the player over the transition time, the head height is unchanged, and the player feels one haptic pulse

### Requirement: Controller and hand mapping
XR controller and hand-tracking input SHALL map to the same named actions as other devices (§10), through quantized poses and diegetic console interactions (throttle orb, size lever, console buttons, wrist menu).

#### Scenario: Grab the lever by hand
- **WHEN** a tracked hand pinches the size lever and moves it one detent toward "smaller"
- **THEN** a Shrink action is emitted in that tick's command frame

### Requirement: Comfort options
XR SHALL provide a vignette (on by default), snap or smooth turning, teleport or smooth on-foot locomotion, a seated height offset, and reduced flashing, and SHALL never apply camera shake or roll.

#### Scenario: Hull hit in VR
- **WHEN** debris strikes the hull during an XR session
- **THEN** controllers get a haptic pulse, and the camera doesn't shake

---
**Capability: `saucer-configurations`** (`openspec/specs/saucer-configurations/spec.md`)

See also `saucer-interior` in change `add-walkable-saucer-interior`.

### Requirement: Two sizes, Villa and Seat
The saucer SHALL have two configurations defined in `data/base/saucer/configs.lua`: the Villa (class 4, 26 × 12 m, the walkable interior) and the Seat (class 1, 1.8 × 1.4 m, one seat under a canopy). Folding to the Seat SHALL cost 20 Charge and unfolding half that. Cruiser, Pod and Pocket are not part of the base game. Mods MAY add sizes through that data file.

#### Scenario: Fold down and back
- **WHEN** the Villa with 100 Charge folds to the Seat and later unfolds in open space
- **THEN** the Seat uses its own 1.8 m hull for collision at once, and Charge ends at 70 before regeneration

#### Scenario: Data-driven sizes
- **WHEN** a mod changes the Seat's hull diameter to 2.4 m
- **THEN** clearance checks and collision use 2.4 m for the Seat

### Requirement: Shrink always succeeds with Charge
Shrinking SHALL succeed whenever the saucer has enough Charge and isn't clamped. It SHALL complete in 1.5 s, with shields disabled and collision damage ignored during the transition.

#### Scenario: Shrink in tight space
- **WHEN** the saucer is Villa with 50 Charge and the player selects Seat
- **THEN** the saucer becomes Seat after 1.5 s and Charge drops by 20

#### Scenario: Not enough Charge
- **WHEN** Charge is 3 and the player selects Seat from Villa
- **THEN** the transition is refused and the HUD shows "Not enough Charge"

### Requirement: Unfolding needs room
Unfolding SHALL be refused at no cost when the Villa's hull around the pilot's eye plus a 0.5 m margin would intersect static geometry or another player's saucer, and the HUD SHALL show a red ghost Villa where it was asked to unfold.

#### Scenario: Blocked in a duct
- **WHEN** the Seat is inside a duct and the player asks for the Villa
- **THEN** the request is refused with "No room to grow here", Charge is unchanged and a red ghost is shown

### Requirement: No flight while reconfiguring
Flight input SHALL be ignored while the saucer reconfigures (1.5 s folding, 1.8 s unfolding), and Charge SHALL NOT regenerate during it.

#### Scenario: Busy
- **WHEN** the player asks for another size during a reconfiguration
- **THEN** the request is refused as busy

### Requirement: Interior folding
Interior rooms SHALL be accessible only while the saucer is the Villa, and their contents SHALL persist through any sequence of transitions.

#### Scenario: Lab unavailable in the Seat
- **WHEN** the saucer is the Seat
- **THEN** the lab bench can't be used, and its queued identifications pause until the saucer is the Villa again

### Requirement: Tractor size limit
The tractor SHALL only pick up items whose size class is at most the current configuration's tractor class, and the hold SHALL keep the same total capacity at all sizes.

#### Scenario: Item too big
- **WHEN** the saucer is Seat (S) and targets an M-class item
- **THEN** pickup is refused with the hint "Unfold the Villa to lift this"

---
**Capability: `ruin-generation`** (`openspec/specs/ruin-generation/spec.md`)

### Requirement: Kit-based modular ruins
Ruins SHALL be assembled from kit modules on a 4 m grid, connected through typed sockets (XL/L/M/S/F), with no overlapping module volumes.

#### Scenario: Socket compatibility
- **WHEN** a corridor module with an M socket is placed
- **THEN** it only connects to sockets of class M, or a size-transition module that steps M to S or L

### Requirement: Size-gated mission graph
Each ruin SHALL be generated from a mission graph containing at least one size lock and, in kits that support it, at least one hand lock on the critical path to the Vault.

#### Scenario: MVP starship
- **WHEN** a starship ruin is generated from any seed
- **THEN** reaching its Vault requires at least one shrink below the entry size

### Requirement: Reachability validation
After generation, every loot slot and the Vault SHALL be reachable by some sequence of moves, size transitions, and on-foot segments, given the abilities available at MVP. Otherwise the generator SHALL retry with derived seeds up to 8 times and then use the fallback layout.

#### Scenario: Property test
- **WHEN** 500 seeds are generated in CI
- **THEN** all pass validation without using the fallback layout

### Requirement: Generation budget
Ruin generation SHALL finish within 50 ms (desktop) and 200 ms (web) for ruins of up to 30 rooms.

#### Scenario: Budget check
- **WHEN** the nightly job generates 10,000 ruins
- **THEN** the 99th-percentile generation time is within budget

---
**Capability: `sector-generation`** (`openspec/specs/sector-generation/spec.md`)

### Requirement: Seeded sector contents
A sector SHALL be generated deterministically from its seed, with 8–16 sites, 1–2 traders, a danger tier, and site risk ratings visible after a scan.

#### Scenario: Same seed, same sector
- **WHEN** sector seed `0xBEEF` is generated twice
- **THEN** the site list, positions, archetypes, and risk ratings are identical

---
**Capability: `items-and-identification`** (`openspec/specs/items-and-identification/spec.md`)

### Requirement: Deterministic items
An item's base type, tier, origin civ, affixes, and quirks SHALL be derived from `(site_seed, slot_index)`.

#### Scenario: Reload consistency
- **WHEN** a player saves before looting slot 7, reloads, and loots it
- **THEN** the item is identical to the one rolled before the reload

### Requirement: Identification
Unidentified items SHALL hide their affixes and quirks. The lab bench SHALL identify an item in `30 s × tier` of sim time, and installing an unidentified module SHALL apply its quirks immediately.

#### Scenario: Hidden quirk
- **WHEN** an unidentified "Unstable" module is installed
- **THEN** the Charge drain applies at once, and the HUD shows "Unknown effect"

### Requirement: Echoes are not sellable
Echo items SHALL be marked non-sellable and non-installable, and SHALL never be lost through a failure.

#### Scenario: Trade screen
- **WHEN** the player opens a trade screen holding an Echo
- **THEN** the Echo is listed as "Not for sale"

---
**Capability: `trading`** (`openspec/specs/trading/spec.md`)

### Requirement: Price formula and demand
Sell price SHALL be `base × tier_mult × (1 + Σaffix_value) × civ_rarity × demand × sell_ratio`, with a sell ratio of 0.6 for identified items and 0.4 for unidentified. Each matching sale SHALL lower demand by 0.05 (floor 0.5), and demand SHALL recover by 0.01 per sim minute (cap 1.5).

#### Scenario: Saturation
- **WHEN** the player sells 4 identical Curios in a row
- **THEN** each successive offer is lower, and the 4th is priced at a demand 0.15 below the first (plus any recovery in between)

### Requirement: Buy and sell at a trader
Docking at a trader SHALL open a trade screen listing hold items with offers, and trader stock with prices. Transactions SHALL be atomic and saved immediately.

#### Scenario: Sell
- **WHEN** the player sells an item offered at ₵120
- **THEN** credits increase by 120, the item leaves the hold, and the save reflects both

---
**Capability: `on-foot`** (`openspec/specs/on-foot/spec.md`)

### Requirement: Pocket and deploy
From Seat, on a standable surface, the player SHALL be able to step out, which pockets the saucer. Deploying SHALL place the saucer at Seat size only if a 2.2 m clearance sphere is free.

#### Scenario: Pocket from Villa
- **WHEN** the saucer is Villa, landed on a standable surface, and the player presses Step Out
- **THEN** the saucer chains shrinks to Seat (spending Charge), the player is placed on foot, and the saucer is pocketed

#### Scenario: Deploy blocked
- **WHEN** the player is in a 1 m crawlspace and presses Recall
- **THEN** recall is refused with "No room to deploy"

### Requirement: Suit Charge and Lifeline
On foot, Suit Charge SHALL drain over time (faster in hazards). There SHALL be no health stat. At zero Suit Charge, the saucer SHALL auto-deploy at the nearest valid point along the player's recorded path, and the player's hand-held items SHALL drop as a recoverable cache.

#### Scenario: Suit runs out
- **WHEN** Suit Charge reaches 0 while holding 2 items
- **THEN** the player is placed in the Seat at the nearest valid deploy point, a cache with both items appears where the player fell, and the cache is marked on the site map

---
**Capability: `sentries-and-tools`** (`openspec/specs/sentries-and-tools/spec.md`)

### Requirement: Sentry state machine
Every sentry SHALL follow Dormant → Alert → Locked → Disabled → Dormant with distinct light and sound telegraphs for each state, and SHALL stay leashed inside its ruin's bounding volume.

#### Scenario: Telegraph before acting
- **WHEN** a Watcher first detects the player
- **THEN** it spends at least 0.75 s in Alert (yellow light, rising tone) before becoming Locked

### Requirement: Watcher
A Watcher SHALL detect targets only within its sensor cone and its civ's size band, and when Locked it SHALL fire stun bolts that reduce shields, then hull, or Suit Charge on foot.

#### Scenario: Shrink below the band
- **WHEN** the saucer shrinks to Seat inside the cone of a Watcher whose band is M–XL
- **THEN** the Watcher returns to Dormant within 2 s

### Requirement: Snatcher
A Snatcher SHALL target only hot items. It SHALL latch onto a Seat hull (siphoning one hot item after 3 s) or onto the player on foot once excursions exist (taking one held item), then carry the item to its nest, where the player can recover it. It SHALL NOT be able to latch onto the Villa.

#### Scenario: Recover from the nest
- **WHEN** a Snatcher steals a hot item and reaches its nest
- **THEN** the item sits in the nest as a pickup, and picking it up restores it as a hot item

### Requirement: Non-lethal tools
The MVP SHALL provide a Scanner pulse (reveals sentry cones, paths, and nests for 10 s) and a Jammer (sends sentries in a 15 m cone to Disabled for 12 s), both with Charge costs and cooldowns defined in Lua data. Neither the tools nor the sentries SHALL destroy anything.

#### Scenario: Jam a latching Snatcher
- **WHEN** the player Jams a Snatcher 2 s into a latch
- **THEN** the latch is cancelled, no item is taken, and the Snatcher reboots for 12 s

### Requirement: Grid consoles
Ruins containing sentries SHALL include at least one grid console as an on-foot hand-lock that disables every sentry in its zone until the player leaves the site.

#### Scenario: Grid off
- **WHEN** the player uses a grid console on foot
- **THEN** every sentry in that zone enters Disabled and stays Disabled until the player leaves the site

### Requirement: The dome is out of reach
Sentries SHALL NOT target, affect, or path into the dome interior.

#### Scenario: Inside the dome near a Watcher
- **WHEN** the player walks the Villa dome while a Locked Watcher fires at the hull
- **THEN** the hull takes damage, and nothing affects the player or the dome's contents

---
**Capability: `hazards-and-failure`** (`openspec/specs/hazards-and-failure/spec.md`)

### Requirement: The dome is safe
Damage volumes and hostile entities SHALL NOT affect the player while they're inside the dome interior, regardless of what's happening to the hull.

#### Scenario: Hull hit while walking the dome
- **WHEN** debris strikes the Villa hull while the player is at the lab bench
- **THEN** hull integrity drops, an alarm plays, and the player's Suit Charge and held items are unaffected

### Requirement: Hot and banked items
Items picked up at a site SHALL be *hot*, tracked per player, until that player leaves that site's boundary (its bounding volume plus 200 m), at which point they SHALL become *banked*. Banked items, installed modules, credits, and the dome SHALL NOT be lost through any failure on Standard or Cozy difficulty.

#### Scenario: Banking
- **WHEN** the player leaves a ruin's boundary carrying 2 hot items
- **THEN** both items are marked banked and are no longer eligible for loss

### Requirement: Fold Retreat
At zero hull, the saucer SHALL fold to the last visited trader, and all hot items SHALL drop as a recoverable cache at the point of failure.

#### Scenario: Hull destroyed in a ruin
- **WHEN** hull reaches 0 holding 3 hot items and 2 banked items
- **THEN** the saucer appears at the trader with the 2 banked items, a 3-item cache sits in the ruin, and it's marked on the site map

### Requirement: Non-lethal damage
No hazard or sentry SHALL reduce anything other than shields, hull, or Suit Charge, and none SHALL end the save on Cozy or Standard difficulty.

#### Scenario: Repeated failure
- **WHEN** the player triggers Fold Retreat 10 times in a row
- **THEN** the save remains playable, with all banked items intact

---
**Capability: `mystery`** (`openspec/specs/mystery/spec.md`)

### Requirement: Mystery from the universe seed
The central mystery (cause, cast, clue graph, host sites, Echo IDs) SHALL be a pure function of the universe seed and mod set, generated from Lua templates.

#### Scenario: Same seed, same mystery
- **WHEN** universe `SAUCER01` is created twice
- **THEN** the cause, the clue DAG, and the host site of every Echo are identical

### Requirement: Clue placement is reachable
Each Echo SHALL be placed in an archive room of its host site's ruin, and ruin validation SHALL guarantee the room is reachable.

#### Scenario: Property test
- **WHEN** 500 universe seeds are generated in CI
- **THEN** every Echo's archive room passes reachability validation

### Requirement: Decoding unlocks the chain
Decoding an Echo at the lab bench SHALL reveal its generated text and mark the next node's host site as Resonant on the map once that node's prerequisites are met.

#### Scenario: MVP chain
- **WHEN** the player decodes the Who and Where Echoes, then recovers the Key
- **THEN** the Resonant vault opens and contains the unique mystery Curio

### Requirement: Optional mystery
The mystery SHALL be configurable at universe creation as On, Hints, or Off. When Off, no Echoes or Resonant markers SHALL be generated, and no other system SHALL change.

#### Scenario: Sandbox only
- **WHEN** a universe is created with Mystery Off
- **THEN** no archive rooms, Echoes, or Resonant markers exist, and sites, traders, and prices are generated normally

---
**Capability: `save-system`** (`openspec/specs/save-system/spec.md`)

### Requirement: Seed plus diffs
Saves SHALL store the universe seed, the mod set with versions, the player/saucer/hold/dome state, and per-site diffs, and SHALL NOT store generated geometry.

#### Scenario: Mod set changed
- **WHEN** a save made with mod `bigger_ruins` is loaded without it
- **THEN** the player is warned that generation may differ and can cancel

### Requirement: Atomic write
Saves SHALL be written to a temp file and atomically renamed (IndexedDB transaction on web).

#### Scenario: Crash during save
- **WHEN** the process is killed mid-write
- **THEN** the previous save loads intact

### Requirement: Player records
The universe save SHALL hold one player record per participant, keyed by `record_index` in join order (record 0 is the universe owner). Each record holds that player's saucer, hold, credits, archive, dome, and hot/banked state.

#### Scenario: Single-player compatibility
- **WHEN** a single-player save is loaded with `--local-players 2` in a test build
- **THEN** the existing record becomes record 0, unchanged, and a new record 1 is created with a starter saucer

---

### 16.4 Preview: `coop-local` requirements (M2, not in the MVP)

Draft requirements, so MVP work doesn't box co-op into a corner:

- Docking SHALL require both saucers at Villa, outside any ruin boundary, and both players' consent. A docked guest SHALL NOT be able to use the host's lab bench or workshop, or take displayed items. *Scenario:* when a guest tries to take a displayed Curio, the interaction is refused and the item stays put.
- Gifted items SHALL transfer ownership on pickup, and SHALL become hot for the receiver if the receiver is inside a site. *Scenario:* when P1 ejects a Module tagged "for P2" inside a ruin, only P2 can pick it up, and it's hot for P2.
- Decoding an Echo SHALL update every player's journal, and Heart site endings SHALL be decided by a vote of the players present. A tie goes to the player who inserted the last Key. *Scenario:* in a 2–2 tie, the last Key's inserter decides.
- Fold jumps SHALL require every player to be at Villa size, outside ruins, and voting yes. *Scenario:* when P2 is inside a ruin, the jump option is greyed out, with "P2 is inside a site".
- XR sessions SHALL NOT be combined with local split screen. *Scenario:* when a second local player joins during an XR session, the join is refused with an explanation.

## 17. Scope and implementation plan

The living plan is [`docs/ROADMAP.md`](ROADMAP.md). It adapts the v0.3 MVP / M2 / M3 split to the v0.4 first-person, interior-centric design. Summary:

- **Done — engine spine:** deterministic C + Lua engine, tests and coverage gates, CI on Windows, Linux and Web, GitHub Pages.
- **Done — walkable home (vertical slice):** first-person Villa with two walkable decks, helm flight, Seat only for tight ducts, huge derelict halls, tractor and bank. Basic KB/M, gamepad, touch and WebXR.
- **Done — belly tractor beam (v0.8):** loot is beamed up from the Tractor Room under the lower deck once the saucer is lined up over it (position, keel, level, still), and it shrinks into the hold. The Seat has a mini beam.
- **Next — live-in interior:** a usable helm console, a real fold (rooms pack away, not a uniform scale), doors, and furniture you can use.
- **Then — one-sector loop:** lab identification, trading, non-lethal sentries (the risk is losing unbanked loot), a 3-node mystery you can ignore, and save/load.
- **Then — presentation and packaging:** Grok Imagine art pass with logged prompts, audio, WebXR and touch polish, Windows package.
- **Post-MVP — on-foot excursions:** stepping out of the saucer (Pocket, Suit Charge, Lifeline, hand-locks). Cut from the MVP in v0.4.
- **M2 "The wider dark":** local split-screen co-op (one saucer each), multiple sectors, the full mystery, archive, requests, advanced sentries.
- **M3 "Home among the stars":** networked co-op, dome customization, Warden and later tools, mod browser, Hardcore.
- **Later / maybe:** rivals, planet-surface cities, a fabricator, and a macOS port.

**Targets** remain Windows, Linux, Web and WebXR (Quest Browser as the QA device). macOS is out of scope. Co-op architecture (one saucer per player, command frames, viewports) is already in the spine; split-screen and network ship in M2/M3.

## 18. Open questions & actions for Steve

There are no blocking open questions right now. All earlier questions are answered and folded into the doc (v0.2: §§5.6, 8, 10.1, 11, 14.1; v0.3: §§3.6, 11.6, 11.8, 14.1, 16).

**Action needed (before the first release, not blocking development):** add the exact URL(s) of xAI's terms covering Grok Imagine outputs, and the date you retrieved them, to `LICENSES/LicenseRef-xAI-Output.md`. Until then, the license lint warns on PRs and the release job fails (§11.6).
