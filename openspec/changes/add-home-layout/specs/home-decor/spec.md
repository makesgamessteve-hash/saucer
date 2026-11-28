## ADDED Requirements

### Requirement: Edit mode
The player SHALL enter and leave an edit mode from the Home planner or the Edit action, while on foot in a Villa that is not folding. In edit mode, Use SHALL pick up a movable piece as a ghost, or place that ghost when the spot is legal. The Menu action (or Cancel on the planner) SHALL put the piece back. A green ghost SHALL mean the spot is legal; a red ghost SHALL show why it is not.

#### Scenario: Pick up, move and place the sofa
- **WHEN** the player is in edit mode and uses a movable sofa, then walks and uses a legal open spot
- **THEN** the sofa is picked up as a ghost, then sits in the new spot, and `tests/lua/homeedit_spec.lua` covers this

#### Scenario: Fine rotation and cancel
- **WHEN** the player holds Boost while placing, or cancels with Menu
- **THEN** the ghost turns in 15° steps, or the piece returns to where it was

### Requirement: Built-in furniture is movable
Each movable built-in in `saucer/interior.lua` SHALL have a stable id. Edit mode SHALL relocate that piece; it SHALL NOT go into the furniture store. Helm, engine core, stairs, hatch, tractor room, holodeck arch, stove and lab bench SHALL stay fixed. A Use station tagged on a piece SHALL move with it.

#### Scenario: A built-in keeps its id and a fixed system cannot be picked up
- **WHEN** `tests/lua/layout_spec.lua` runs
- **THEN** every movable built-in has a stable id, and a fixed system cannot be picked up

### Requirement: Wall, on-top and ceiling placement
Furniture data MAY set `place` to `floor` (the default), `wall`, `top` or `ceiling`. A wall piece SHALL snap to a wall face, an on-top piece SHALL sit on a single furniture top, and a ceiling piece SHALL hang from the deck ceiling. Those kinds SHALL be sold at traders.

#### Scenario: Each placement kind has a legal spot and a refused one
- **WHEN** `tests/lua/homeedit_spec.lua` runs
- **THEN** wall, on-top and ceiling pieces each have a legal spot and a refused one

### Requirement: Reachability
A place SHALL be refused when it would leave a Use station, a door or the hatch unreachable on a 0.25 m walk raster flooded from the stair foot, and the message SHALL say why.

#### Scenario: Blocking the walk to the helm is refused
- **WHEN** `tests/lua/walkgrid_spec.lua` runs
- **THEN** a placement that blocks the walk to a station or door is refused

### Requirement: Undo
Each saucer SHALL keep an undo stack of house edits. The Undo action, or Undo on the planner, SHALL reverse the last edit. Anyone in that house MAY undo. Undoing a just-moved built-in SHALL put it back.

#### Scenario: Undo puts the sofa back
- **WHEN** `tests/lua/homeedit_spec.lua` runs
- **THEN** undo puts a just-moved built-in back

## MODIFIED Requirements

### Requirement: Guests in a decorated dome
A guest visiting a docked dome SHALL see its furniture, displays and garden, be blocked by its furniture, and SHALL be able to do the same home-life acts as the host: edit furniture, use the planner, garden, kitchen, bookshelf, TV, shower, holodeck, holotable and display slots. Picked-up furniture SHALL go to the host's store, harvests to the host's pantry, and displayed finds SHALL stay in the house unless gifted. Helm, fold, tractor, lab, trade, hatch and sleep-and-save SHALL stay host-only. Two people grabbing the same piece or the same spot on one tick SHALL use the shared-loot tie-break (lowest `(record_index + tick) mod n`).

#### Scenario: Admire
- **WHEN** a visiting guest uses the host's display slot 1 with a find on it
- **THEN** the guest's admired list names the host and the find

#### Scenario: A guest moves the host's lamp and cannot pocket it
- **WHEN** a visiting guest packs up a bought lamp in the host's dome
- **THEN** the lamp goes into the host's store, not the guest's

#### Scenario: A guest is refused at the host's lab bench
- **WHEN** a visiting guest uses the host's lab bench
- **THEN** the use is refused and the lab stays host-only
