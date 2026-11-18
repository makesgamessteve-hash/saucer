## ADDED Requirements

### Requirement: Real-time pacing of scripted windowed runs
A scripted windowed run (`--windowed` with `--script`, or `--screenshot`) SHALL, when `--realtime` is given or `SAUCER_REALTIME` is set to anything but empty or `0`, sleep after each frame so that frames of N simulated ticks are due N/60 s of wall clock apart, so a recording plays at the speed of the game. A run that falls more than a quarter second behind SHALL restart its schedule instead of simulating extra ticks to catch up. The simulation result SHALL NOT depend on the flag.

#### Scenario: A fast renderer is held to 60 ticks a second
- **WHEN** a script that waits 1200 ticks runs windowed with `--realtime` on a renderer that draws 100 frames a second
- **THEN** the run takes about 20 seconds of wall clock

#### Scenario: Several ticks per frame
- **WHEN** `--ticks-per-frame 5` is combined with `--realtime`
- **THEN** each frame is due 5/60 s after the previous one

#### Scenario: A slow machine does not burst
- **WHEN** a frame finishes more than 0.25 s late
- **THEN** the next frame is not shortened to catch up and the schedule restarts from now
