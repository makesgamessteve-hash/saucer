## ADDED Requirements

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
- **WHEN** P1 at Pod tries to grow to Villa while P2's saucer is inside the Villa volume
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
