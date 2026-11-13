## ADDED Requirements

### Requirement: Three license classes
The repository SHALL license code under MIT, hand-made and code-generated art under CC BY 4.0, and Grok Imagine outputs under `LicenseRef-xAI-Output`, with the texts in `LICENSES/` and the mapping in `LICENSING.md` and `REUSE.toml`.

#### Scenario: License files present
- **WHEN** the repository is checked out
- **THEN** `LICENSES/MIT.txt`, `LICENSES/CC-BY-4.0.txt`, `LICENSES/LicenseRef-xAI-Output.md`, `LICENSING.md`, `REUSE.toml` and `ATTRIBUTION.md` exist

### Requirement: Spec-driven changes
Every feature SHALL start as an OpenSpec change whose scenarios map to named tests, and a change SHALL only be archived once its scenarios pass in CI.

#### Scenario: Validation
- **WHEN** `openspec validate --all --strict` runs in CI
- **THEN** every spec and change validates
