## ADDED Requirements

### Requirement: Lockstep sessions
A network game SHALL run the same deterministic simulation on every machine: each machine SHALL send its local slot's command frames, scheduled `--net-delay` ticks (1-12, default 3) after they were sampled, and SHALL advance a tick only when it holds that tick's frame for every slot in the session. Frames SHALL be resent until acknowledged.

#### Scenario: Two machines stay in step over a lossy link
- **WHEN** a host and a guest play 1200 ticks while every third datagram to the host and every fourth to the guest is dropped
- **THEN** both ran the same ticks with the same states and compared at least ten hashes without a mismatch

#### Scenario: Four players
- **WHEN** a host waits for three guests with `--net-players 4`
- **THEN** the session starts once all three have joined and each guest plays slot 2, 3 or 4

### Requirement: Players who leave
A slot whose machine has left SHALL play empty frames from the tick after its last frame, on every machine alike.

#### Scenario: A guest drops out
- **WHEN** a guest stops sending for 8 seconds
- **THEN** the others play on with that slot idle and stay in step

### Requirement: Joining and leaving
A guest SHALL say hello with the game's network API version and the hash of its loaded mod set; the host SHALL answer with the session's seed, slot and delay, or refuse with the reason (a different game version, a different set of mods, or a full or running session). A guest's slot SHALL join the game on its first frame. A peer silent for 8 seconds, or one that says goodbye, SHALL count as gone and the others play on.

#### Scenario: Different mods are refused
- **WHEN** a guest with a different mod set joins
- **THEN** its status reads "rejected: a different set of mods" and no session starts

#### Scenario: The host leaves
- **WHEN** the host closes the game during a session
- **THEN** the guest's status says the host left and the guest plays on alone

### Requirement: Desync detection
Every 60 ticks each machine SHALL send the state hash of that tick, and every machine SHALL compare the hashes it receives against its own. On a mismatch the session SHALL stop advancing, report the first tick that differs, and keep sending until the others have seen it.

#### Scenario: A desync is reported on both sides
- **WHEN** one machine's sim is changed behind the protocol's back
- **THEN** both machines report "DESYNC at tick" with the same tick and stop

### Requirement: UDP on the desktop
`--host [PORT]` (default 47800) SHALL bind a UDP port and wait for guests; `--join HOST[:PORT]` SHALL join one. The window title SHALL show the session's status. A two-process loopback test SHALL run in CI.

#### Scenario: Loopback
- **WHEN** `tools/net_loopback.cmake` runs a host and a guest on 127.0.0.1 with the same game test
- **THEN** both exit 0, compared at least ten hashes, and print the same final tick and hash

### Requirement: WebRTC on the web
The web build SHALL carry the same protocol over an unordered WebRTC data channel without retransmits. Signaling SHALL need no server: the host's page shows an offer code ("SXO1." and base64 of the SDP, seed and player count), the guest pastes it and gets an answer code ("SXA1.") to send back. The web shell's "Online co-op" button SHALL open this panel and show the session status.

#### Scenario: Two pages connect
- **WHEN** a host page's offer code is pasted into a guest page and the answer back into the host
- **THEN** the data channel opens on both and datagrams reach the engine on the other side

### Requirement: An XR player can join
A machine in a WebXR session SHALL be able to host or join a network game. Its headset views SHALL show that machine's own slot; the headset never changes the simulation.

#### Scenario: A guest in a headset
- **WHEN** the guest of a network game is in an XR session
- **THEN** its slot joins, it plays in step with the host and its views follow its own saucer
