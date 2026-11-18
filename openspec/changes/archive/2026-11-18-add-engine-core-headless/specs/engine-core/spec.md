## ADDED Requirements

### Requirement: Fixed simulation tick
The engine SHALL advance game simulation in fixed steps of 1/60 s, independent of render frame rate, and SHALL interpolate rendering between the last two sim states.

#### Scenario: Slow frame
- **WHEN** a render frame takes 50 ms
- **THEN** the engine runs 3 sim ticks before the next render, capped at 8 ticks per frame

### Requirement: Headless mode
The engine SHALL run with `--headless` using null renderer and null audio backends, without creating a window, and SHALL exit with status 0 on script success and non-zero on any assertion failure or Lua error.

#### Scenario: CI run without display
- **WHEN** `saucer --headless --script tests/game/boot.lua` runs on a machine with no display
- **THEN** the game boots, runs the script, and exits 0

### Requirement: Supported platforms
The engine SHALL build and pass CI on Windows (MSVC), Linux (GCC and Clang), and Web (emscripten, WebGL2), and the web build SHALL support WebXR sessions. macOS SHALL NOT be a required target.

#### Scenario: CI matrix
- **WHEN** a PR is opened
- **THEN** the windows-msvc, linux-gcc, linux-clang, and emscripten jobs all build and run the test suites, and no macOS job is required
