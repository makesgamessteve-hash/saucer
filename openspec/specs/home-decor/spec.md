# home-decor Specification

## Purpose
The player furnishes the Villa and its garden within rules about where furniture may go.

## Requirements

### Requirement: Furniture
Traders SHALL sell furniture (floor lamp, beanbag, reading armchair, round rug, bookcase, aquarium, brass telescope, star hammock, singing crystal; mods may add kinds). The Home planner SHALL place an owned piece in front of the player on either deck, snapped to a 0.25 m grid and a quarter turn, and SHALL pick placed pieces up again. Placed pieces SHALL be solid for anyone walking the dome, rugs excepted.

#### Scenario: Place an aquarium
- **WHEN** a player who owns an aquarium uses the planner facing free floor and picks "Place Aquarium"
- **THEN** the aquarium stands there and blocks walking

### Requirement: Where furniture may not go
The planner SHALL refuse a spot too close to the hull, on a station, a door, the stairs or the walk to the helm, on another piece, or on the player, and say why.

#### Scenario: Keep the way clear
- **WHEN** a player tries to place a piece on the walk to the helm
- **THEN** nothing is placed and the message says to keep the way clear

### Requirement: Display slots
The dome SHALL have six display plinths. Using one SHALL put an identified find from the hold on it (or take it back to the hold); a displayed find leaves the hold.

#### Scenario: Show a find
- **WHEN** a player puts an identified Curio on display slot 1
- **THEN** it stands on the plinth, is no longer in the hold, and adds 3 to Comfort

### Requirement: The garden
Four garden beds SHALL take alien seeds (Glowmoss, Oquun sunvine, Velari emberleaf). A planted seed SHALL grow through seed, sprout, bloom and ripe over sim time while watered (each watering lasts 40 minutes), and a ripe plant SHALL give its harvest as a kitchen ingredient and start again.

#### Scenario: Harvest
- **WHEN** a watered Glowmoss has grown for 30 minutes of sim time
- **THEN** harvesting it gives a glowcap and the bed starts over

### Requirement: Comfort
Furniture, displayed finds and garden plants SHALL add up to a Comfort score, a second piece of the same kind counting half, a third a quarter and so on; levels SHALL be Bare, Homely (6), Cosy (12) and Beloved (20). Each point SHALL speed up Charge regeneration by 2%, at most 50%.

#### Scenario: Comfort speeds up Charge
- **WHEN** a player's Comfort is 14
- **THEN** their Charge regenerates 28% faster than with a bare dome

### Requirement: Guests in a decorated dome
A guest visiting a docked dome SHALL see its furniture, displays and garden, be blocked by its furniture, and be able to admire a displayed find (recorded for the guest).

#### Scenario: Admire
- **WHEN** a visiting guest uses the host's display slot 1 with a find on it
- **THEN** the guest's admired list names the host and the find
