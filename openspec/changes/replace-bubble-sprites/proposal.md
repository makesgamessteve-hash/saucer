## Why

Steve said he really doesn't like the bubble sprites used in multiple places, and asked for a better representation for each of the bubbles. Today a soft circular glow (and two orb sprites for loot and echoes) stands in for lights, motes, pulses, markers, signals, steam, pools of light and more. From any distance they all read as the same soap-bubble.

## What Changes

- **Procedural billboard forms** in the renderer, still cheap on WebGL2: flare, spark, ring, shard, streak, chevron and slit, plus the old soft disk as a fallback. A bright form still only adds light (it never paints dark blocks).
- **Each use gets the form that fits what it is**, through `view/sprites.lua`:
  - real lights (sun, lamps, thrusters, dock emitters, organ cores, hearts, holosigns) become a spiked **flare**
  - motes and processions become **shards**; sky-lane pulses and tractor motes become **streaks** (pulses are a thin emissive rod along the lane)
  - echoes, curios, clues, lock sockets and glyphs become a **ring**
  - loot, coin glints and decoy/gift blinks become a **spark** (loot keeps its mesh)
  - warnings and scanner marks become a **chevron**
  - hull signals, approach lights and sentry eyes become a **slit**
  - a sentry's floor cone becomes a flat **pool** of light on the floor, not a standing bubble
  - a hall's "shadow" becomes a tall dark **figure**; a ripple becomes a real **ring** on the floor
  - cooking steam becomes a rising **streak**
- The soft circular disk is no longer the default look of any of those uses. Palette orb sprites (`loot.png`, `echo.png`, `beam.png`) are no longer drawn as the thing they stood for.

## Impact

- Visual only: simulation, placement, random streams and replays are unchanged.
- A small renderer addition (`view:billboard` `form=`, shader forms). Lua call sites go through `view/sprites.lua`.
- Crowd folk sprites, sky backdrops and other non-bubble billboards are untouched.
