## ADDED Requirements

### Requirement: Layout resolved per saucer
Walking collision, Use stations and interior meshes SHALL use `layout.of(p)` for that saucer: the base `saucer/interior.lua` table plus any moved built-ins. When that saucer has no overrides, `layout.of(p)` SHALL return the base table itself so an untouched game keeps the same collision. Group meshes SHALL rebuild for a changed revision, a group at a time.

#### Scenario: A saucer with no moves shares the base layout table
- **WHEN** `tests/lua/layout_spec.lua` runs its scenario of this name
- **THEN** it passes
