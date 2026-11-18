## Why

Steve corrected the core fantasy (concept v0.4, 2026-11-15): the game is
first-person 3D from the player's own eyes. The player is a person inside the
saucer, and the saucer reconfigures around them. At its biggest it is a glass
dome you walk around in (an open-plan kitchen, living room and helm under the
glass) with a lower deck under it (bedroom, bathroom, engine room). Alien
derelicts are so big that the saucer flies inside them; only very tight spaces
need it to shrink to a one-seat, car-sized Seat, packing all other space away.

Milestone 1 had the player *be* the saucer (a chase/cockpit camera on a hull
that shrank through four sizes to fit small doors). This change records the
correction and implements a playable vertical slice of it.

## What Changes

- ADDED `saucer-interior`: first-person avatar on foot; walkable two-deck Villa
  (dome deck: kitchen, living room, helm; lower deck via stairs: bedroom,
  bathroom, engine room) with collision on both decks and code-generated
  meshes from one layout table; a see-through glass dome; taking and leaving
  the helm (seated first-person flight, the saucer holds station when nobody
  flies); reconfiguration around the player's eye with a fold animation;
  tractoring from the helm or on foot through the glass; walking with
  keyboard/mouse, gamepad, touch and the WebXR head direction.
- ADDED `saucer-configurations`: two sizes, Villa and Seat (Cruiser, Pod and
  Pocket cut); reconfiguration keeps the eye point fixed; no flight while
  reconfiguring. Supersedes the four-size scenarios of
  `add-saucer-configurations` (that change's tasks are updated to match).
- ADDED `ruin-generation`: derelict scale. Great halls fit the whole Villa,
  joined by Villa-sized doors; only ducts (and the chambers behind them) need
  the Seat; ruin cells grow to 64 × 8 × 96 m.
- Input: the `door` action becomes `use` (G / Return, gamepad X, touch Use,
  XR left trigger); sizes 3–4 bindings removed. The engine only fills the
  command frame's head-aim while an immersive XR session runs.
- `on-foot` (stepping out of the saucer: Pocket, Suit Charge, Lifeline) is
  deferred to post-MVP; `add-on-foot-pocket-mode` stays planned.
- Co-op: unchanged in principle; every player still has their own saucer and
  now their own body inside it.

## Impact

- Capabilities: `saucer-interior` (new), `saucer-configurations`,
  `ruin-generation`, `player-input`, `retro-renderer` (glass, open lathe/tube
  mesh parts), `test-harness` (new game test `interior.lua`, re-recorded
  replay).
- Sim state version 2; replay and state hashes change (documented in the
  commit). Old saves/replays are not compatible.
- Code: `data/base/saucer/{configs,interior}.lua`,
  `data/base/scripts/sim/{avatar,ship,game,tractor,autopilot,ruin,sector}.lua`,
  `data/base/meshes/{interior,saucer,person}.lua`,
  `data/base/scripts/view/{render,assets,hud}.lua`, kits, input defaults,
  engine `sx_mesh` (tube), `sx_script` (`open` parts, proxy-aware vectors),
  `sx_touch` (Use button), `sx_engine` (XR aim gating).
