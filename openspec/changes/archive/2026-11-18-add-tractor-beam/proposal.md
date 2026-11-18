# Change: Belly tractor beam, the Tractor Room and shrinking loot (v0.8)

## Why
The owner asked: "I want the player to collect the loot/scrap with some
kind of tractor beam that also shrinks. This has to be done from a special
room at the bottom of the saucer. The saucer has to be positioned at the
fitting position and orientation to make that possible."

Until now the tractor grabbed whatever the pilot looked at, from the helm,
in any orientation. Collecting loot is now a small flying puzzle: put the
saucer over the item, line it up, then run the beam from a room in the belly.

## What Changes
- A third deck in the Villa, the **Tractor Room** (`saucer/interior.lua`),
  reached by a new belly stair beside the engine. It has a floor window
  around the belly hatch, a sling seat with two console arms over the
  glass, a cargo tube up to the hold, hold racks with a lit cubby per hold
  slot, hazard stripes, lit rims and warning panels (`meshes/interior.lua`).
  The walking code supports any number of decks and flights.
- **The beam** (`sim/tractor.lua`): a cone from the belly emitter straight
  down the hull's (banked) down axis. Per configuration (`saucer/configs.lua`
  `beam`): emitter, half angle, minimum depth, range, size class, pull speed,
  shrink factor, stillness and level limits, keel tolerance for long scrap.
  The capture rule, checked in order: size class, depth (`min..range`), cone
  angle, keel alignment for long scrap (size L and up lie at their own
  angle), level hull, holding still, line of sight. `tractor.scan` returns
  the target the beam would take, or the nearest one for the indicator,
  with a hint ("OFF AXIS - MOVE LEFT 3M", "LONG SCRAP - TURN RIGHT 40 DEG",
  "TOO HIGH - DESCEND 6M", "LEVEL THE HULL", "HOLD STILL", ...).
- **The Villa runs the beam from the console**: at the helm the HUD scope and
  hint show the alignment; pressing F there says to go down. Hover-hold keeps
  the saucer in place. Use at the console sits down (the view looks down
  through the glass); there the stick trims slowly in the operator's frame,
  lift trims height, turn trims yaw and the bank settles (`flight.trim`);
  F pulls; Use gets up. Getting up, folding or drifting away drops the item.
- **The Seat (one-seat car)** has no room for a Tractor Room: it fires a mini
  belly beam straight from the seat (class S only, short range, wider cone),
  with the same alignment rule.
- **The pull shrinks the loot**: the target rises up the beam axis into the
  hatch over `depth / pull_speed` seconds (at least 0.6 s) while it scales
  down to `shrink` (12 % for the Villa, 35 % for the Seat); the belly iris
  opens, the item lands in the hold (hold racks light up). `pick_up` is
  unchanged: hot loot, unidentified items, Echoes, nests, caches and the
  Curio work as before.
- **Visuals and sound**: translucent beam cone (idle / lock / pull tints),
  a bright core and rising motes while pulling, a target ring tinted by the
  status, the item's axis and the keel line for long scrap, the six-leaf
  hatch iris and belly glass, the console scope and pull bar, the HUD scope
  with depth and keel readouts. The emitter ring and lenses on the hull.
  Sound hooks reuse `tractor`, `pickup` and `denied`.
- Vault Echoes sit away from the far wall so the Villa can hover over them.
- Autopilot drivers for tests (`beam_spot`, `hover_over`, `to_console`,
  `trim_to`, `pull`, `beam_up`, `back_to_helm`; `grab` rewritten).
- Determinism and save: the beam state is part of the snapshot; the console
  seat and hatch are transient (save format unchanged). Replays re-recorded.
- Input: no new actions. Touch, gamepad and WebXR reuse tractor (F / X /
  trigger), use, move, lift and turn.

## Impact
- Affected specs: tractor-beam (new)
- Affected code: `data/base/saucer/{configs,interior,decor}.lua`,
  `data/base/scripts/sim/{tractor,game,flight,avatar,autopilot,save,ruin}.lua`,
  `data/base/scripts/view/{render,hud,assets}.lua`,
  `data/base/meshes/{interior,saucer}.lua`, tests, README, docs.
- Supersedes the "aim at what you look at" tractor of
  `add-items-identification-tractor`.
- Gap: sentries do not react to the beam yet.
