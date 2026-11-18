# Change: Holodeck and home life (roadmap milestone 4)

## Why
The Villa is a home you live in between derelict runs, but apart from
sleeping, showering and a quick meal there was nothing to do there. Roadmap
milestone 4 asks for a holodeck with moddable programs, cooking, a
bookshelf and a TV, all tied back into exploring and the mystery.

## What Changes
- A Holodeck room on the lower deck (starboard aft, behind a lit arch from
  the engine room) in the detail-pass style: black grid walls, floor and
  ceiling, emitter studs, and a control panel by the arch.
- Holodeck programs are Lua data files under `holo/`, discovered through the
  VFS from base and every mod (`saucer.vfs.list("holo")`), so a mod adds a
  program by dropping in a file. Each program declares a look (sky, fog,
  light), props, use spots, optional flight gates and hooks. Base programs:
  Sunset Beach and Quiet Forest (relax, Calm), Seat Flight Course (fly a
  simulated Seat through seven rings against the clock, best time saved,
  first clear pays 25 c), Derelict Replay (a hologram of an explored site
  with your recorded route and pick-ups) and Resonant Memory (a decoded
  alien place that points at the mystery's next Echo).
- Programs run in a separate simulated space with its own camera; the
  saucer holds station meanwhile. A co-op player can join a running
  program as a guest.
- Programs come as starters, from data cores found in derelict vaults (the
  lab bench decodes them) or from the trader's shop.
- Upgrade modules (emitter array: space 6/10/15 m half width; detail
  lattice: more props; guest pattern buffer: co-op slots 1/2/4) are found
  or bought and installed at the holodeck panel.
- Cooking at the stove opens a galley panel: recipes from trader groceries
  and alien ingredients give small timed buffs (well fed, calm, keen,
  steady) that scale Charge regen, Scanner and Jammer cooldowns, Scanner
  reveal time and hull regen. Cooking takes a few seconds at the stove.
- A bookshelf that fills with found books and logs, decoded Echo
  transcripts and holodeck memories. Reading opens a page view; a clue's
  first read marks a lead (teal radar marker) on the site it names.
- A TV on the living-room coffee table picks up channels from the nearest
  trader station and alien stations and cities in range. Every show comes
  with a gentle hint about the game right now.
- Vault finds per kit (`home/finds.lua`): data cores, modules, books and
  alien ingredients beamed up like loot; books and ingredients unpack when
  the hold banks.
- The trade terminal gains a shop (`home/shop.lua`) and scrolls long lists.

## Impact
- Affected specs: holodeck, home-life
- Affected code: `data/base/holo/*.lua` (new), `data/base/home/*.lua` (new),
  `data/base/scripts/sim/{holo,kitchen,books,tv,finds,buffs}.lua` (new),
  `data/base/scripts/view/holo.lua` (new), `sim/{game,home,lab,trade,items,
  tractor,mystery,save,autopilot}.lua`, `view/{render,hud}.lua`,
  `saucer/{interior,decor,configs}.lua`, `meshes/{interior,props}.lua`
- Determinism and saves: all new state is plain tables in the player
  (`holo`, `pantry`, `shelf`, `buffs`, `trails`, `leads`, counters) and is
  saved; seated modes (`holo_run`, `tv`, `reading`, `cooking`) are
  transient. Program scenes derive from the world seed. Save format stays 2;
  the sim version is 6. The slice replay was re-recorded deliberately
  because vault finds and the moved engine station change the run.
