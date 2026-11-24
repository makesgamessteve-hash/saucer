## ADDED Requirements

### Requirement: Material slot per vertex
Mesh vertices SHALL carry a material slot 0-7 (13 floats per vertex) set from the part style, and a mesh without materials SHALL keep the hash it had before the slot existed.

#### Scenario: Slot round trip
- **WHEN** `tests/c/test_render_input.c` runs `material_slot_round_trip` and `mesh_hash_material`
- **THEN** each vertex carries its part's slot and a slot-0 mesh hashes as before

### Requirement: Pillow patch primitive
The mesh builder SHALL offer a patch part: a corner, two edges and a bulge along their normal, with smooth analytic normals, for organic skins.

#### Scenario: Patch shape
- **WHEN** `tests/c/test_render_input.c` runs `mesh_patch`
- **THEN** the corners stay on the base plane, the centre bulges by the given height and degenerate patches add nothing
