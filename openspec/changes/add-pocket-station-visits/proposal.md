## Why

Roadmap milestone 5, in Steve's words: travel to a space station, minimize the
saucer to the size of a big coin and put it in your pocket before exploring
the station. Trading face to face, the bar and a pickpocket who can run off
with your ship give the trader a life of its own and make the saucer feel
like something you own and carry.

## What Changes

- ADDED `station-visits`: Pocket configuration (fold, pocket, unpocket)
- ADDED `station-visits`: Unpocket in a hangar
- ADDED `station-visits`: Walkable station interiors
- ADDED `station-visits`: Station folk and furnishing
- ADDED `station-visits`: On-foot movement on every input path
- ADDED `station-visits`: Trading with NPC traders on foot
- ADDED `station-visits`: The pickpocket and the chase
- ADDED `station-visits`: The fence
- ADDED `station-visits`: Station visits save and replay

New data: `saucer/configs.lua` (third config `pocket`), the `walk` section of
`kits/station.lua`, `station/folk.lua` (species, vendors, drinks, chatter,
thief tuning), `meshes/npc.lua`, `meshes/hand.lua`, input action `size3`.
New scripts: `sim/stationgen.lua`, `sim/visit.lua`, `view/station.lua`.
Save state version 7.

## Impact

- Capability `station-visits` (`openspec/specs/station-visits/spec.md` once archived)
- Supersedes the station half of `add-on-foot-pocket-mode` (pocketing in ruins
  with Suit Charge and Lifeline stays planned there)
- Known answers: `tests/replays/slice_seed42.srep` re-recorded for state version 7
