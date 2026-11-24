## ADDED Requirements

### Requirement: Spine relic generator
The game SHALL generate a spine relic from seed, civ and origin: a maw, three hub halls joined by trunks and a Core in a straight line about 900 m long, returning the ruin table shape plus spaces, fold bays, branches and locks, validated with up to 8 tries before it fails loudly. Collision SHALL be the ruin's boxes only.

#### Scenario: Ruin shape
- **WHEN** `tests/lua/relic_spec.lua` runs "is one straight spine about 900 m long: maw, three halls with trunks, the Core"
- **THEN** it passes

#### Scenario: Broken layouts
- **WHEN** `tests/lua/relic_spec.lua` runs "rejects broken layouts with a reason"
- **THEN** it passes

### Requirement: Space classes
A relic SHALL build a maw door of at least 34x20 m, hub halls of at least 96x48x96 m, trunks of at least 40x24 m and a Core of at least 128x64x128 m, and every Villa-class space SHALL fit the Villa with room to turn.

#### Scenario: Classes measured
- **WHEN** `tests/lua/relic_spec.lua` runs "meets the scale rules: a 34 x 20 maw, 96 x 48 x 96 halls, 40 x 24 trunks, a 128 m Core"
- **THEN** it passes

### Requirement: Villa main route
The maw SHALL reach the Core through Villa-class doors only, and Villa-class spaces SHALL make up at least 75% of the navigable length.

#### Scenario: Villa route
- **WHEN** `tests/lua/relic_spec.lua` runs "keeps the Villa on the route: every big room Villa-reachable, Villa share at least 75%"
- **THEN** it passes

### Requirement: Seat branch
The slice relic SHALL have one Seat branch: a 2.6x2.1 m port, an 80 m passage of 4x4 m with one elbow and a 12x8x12 m reliquary holding three class-1 finds behind a Seat-lock, entered only through class-1 doors.

#### Scenario: Branch shape
- **WHEN** `tests/lua/relic_spec.lua` runs "has one Seat branch: a 2.6 x 2.1 port, an 80 m 4 x 4 passage with one elbow, a 12 x 8 x 12 reliquary"
- **THEN** it passes

### Requirement: Fold bays at Seat ports
Fold bays of at least 44x20x44 m with a cradle SHALL stand on the hall floors, the hall with the Seat port SHALL have 4, and a bay marker SHALL lie within 30 m of the port.

#### Scenario: Bay at the port
- **WHEN** `tests/lua/relic_spec.lua` runs "puts fold bays of at least 44 x 20 x 44 m with cradles in the halls, four in the port's hall"
- **THEN** it passes

### Requirement: Regrow from a bay marker
A Seat at a fold bay's marker SHALL pass the Villa regrow clearance check at any yaw.

#### Scenario: Regrow any yaw
- **WHEN** `tests/game/relic.lua` regrows at a bay marker at 8 yaws
- **THEN** every regrow succeeds and costs no Charge

### Requirement: Charge plan
A relic's validated full clear SHALL never need more than 100 Charge between cradle visits.

#### Scenario: Charge plan holds
- **WHEN** `tests/lua/relic_spec.lua` runs "plans the Charge of a full clear within the tank: the shrink costs, the cradle regrow is free"
- **THEN** it passes

### Requirement: Seat-lock
The reliquary's shutter SHALL stay solid until a Seat holds Use for 1.5 s with its nose within 3.5 m of the lock's socket; it SHALL then stop being solid and stay open across saves and restores. A Villa SHALL NOT be offered the socket.

#### Scenario: Turning the lock
- **WHEN** `tests/game/relic.lua` holds Use at the socket in the Seat, briefly and then for 1.5 s
- **THEN** the short press leaves it shut, the long one opens it, and it is still open after a restore

### Requirement: Relic loot
The slice relic SHALL hold six class 2-3 finds in its halls, three class-1 finds in the reliquary paying double, and a fixed class-4 idol in the Core that only the Villa's beam lifts. It SHALL have no sentries.

#### Scenario: Warren classes
- **WHEN** `tests/lua/relic_spec.lua` runs "spreads six finds over the halls, three class-1 finds in the reliquary and the XL idol in the Core"
- **THEN** it passes

#### Scenario: Finds in play
- **WHEN** `tests/game/relic.lua` lists the relic's candidates
- **THEN** there are 6 hall finds, 3 reliquary finds and the idol, which the Seat cannot lift

### Requirement: Skins outside the boxes
Relic skins (cushions, ribs, bands, door frames) SHALL lie on or outside every flyable box, and their breathing SHALL be render-only.

#### Scenario: Skin outside envelope
- **WHEN** `tests/lua/relic_spec.lua` runs "keep every cushion, rib, band and frame out of every flyable box (collision is the boxes only)"
- **THEN** no skin AABB intersects a room's flyable box

### Requirement: Relic slice debug entry
`--relic-slice` SHALL add the Vyrr relic to the first sector and start the party outside its maw; without it, sectors, state hashes and replays SHALL NOT change.

#### Scenario: Only with the flag
- **WHEN** `tests/lua/relic_spec.lua` runs "adds the Vyrr relic only with the debug entry, and only once"
- **THEN** it passes and every replay still matches its recorded hashes
