## ADDED Requirements

### Requirement: Edit and undo actions
The command set SHALL include `edit` (toggle edit mode on foot in the Villa) and `undo` (reverse the last house edit). They SHALL be bound by default on keyboard. Touch and the Home planner SHALL offer the same acts as rows, so `sx_touch.c` and `web/shell.html` stay unchanged.

#### Scenario: The edit and undo actions exist on the default keyboard bindings
- **WHEN** `tests/lua/homeedit_spec.lua` runs its scenario of this name
- **THEN** it passes
