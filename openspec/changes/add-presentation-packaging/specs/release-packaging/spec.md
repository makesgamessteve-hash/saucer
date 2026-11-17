## ADDED Requirements

### Requirement: Published builds
Pushing a `v*` tag SHALL build a Windows x64 zip (windows-msvc, with `saucer.exe`, `data/`, `mods/` and the license files), a Linux x64 tarball and a web zip, smoke-test them and attach all three to the GitHub Release for that tag.

#### Scenario: Tag v0.1.0
- **WHEN** the tag v0.1.0 is pushed
- **THEN** the release workflow succeeds and the v0.1.0 release lists the Windows zip, the Linux tarball and the web zip
