## ADDED Requirements

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
