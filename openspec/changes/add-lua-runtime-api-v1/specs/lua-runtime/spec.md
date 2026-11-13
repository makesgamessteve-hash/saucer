## ADDED Requirements

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
