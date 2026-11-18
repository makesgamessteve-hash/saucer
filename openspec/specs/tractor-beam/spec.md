# tractor-beam Specification

## Purpose
The belly beam pulls finds up under alignment, level and line-of-sight rules, from the Tractor Room or the Seat's mini beam.

## Requirements

### Requirement: Belly beam alignment
Loot SHALL be collected only by a cone-shaped beam pointing from the saucer's belly emitter down the hull's banked down axis. A target SHALL be captured only when its size fits the beam's class, its depth along the axis lies between the beam's minimum and its range, and its angle off the axis is at most the half angle.

#### Scenario: Off axis
- **WHEN** the saucer hovers so the target lies outside the cone
- **THEN** the beam refuses with status "axis" and a hint naming the direction to move

### Requirement: Orientation, level and line of sight
Long scrap (size L and up) SHALL lie along the keel within the keel tolerance, either end first. The hull SHALL be level within the level limit and move no faster than the stillness limit, and nothing solid SHALL lie between the emitter and the target.

#### Scenario: Long scrap across the keel
- **WHEN** a long item lies more than the keel tolerance off the hull's heading
- **THEN** the beam refuses with status "yaw" and a hint naming the turn

#### Scenario: Lined up
- **WHEN** the target is inside the cone at a valid depth, the keel fits, and the hull is level and still with a clear line of sight
- **THEN** the status is "lock"

### Requirement: Tractor Room
The Villa SHALL have a Tractor Room on a deck below the lower deck, reached by stairs, with a floor window around the belly hatch and a beam console. The Villa's beam SHALL fire only while the player sits at the console. At the console the movement controls SHALL trim the saucer slowly in the operator's frame, and Use SHALL get up. Getting up, folding, or the saucer drifting out of the beam SHALL drop a target being pulled.

#### Scenario: Fired from the helm
- **WHEN** the pilot presses tractor at the Villa's helm
- **THEN** nothing is pulled and a message sends the player to the Tractor Room

#### Scenario: Getting up mid-pull
- **WHEN** the player leaves the console while a target is rising
- **THEN** the target stays where it lay and is still collectable

### Requirement: Seat mini beam
The Seat SHALL fire a small belly beam directly from the seat with the same alignment rule, a shorter range, a wider cone and size class S only.

#### Scenario: Seat pickup
- **WHEN** the Seat hovers lined up just above a small item and the pilot presses tractor
- **THEN** the item is pulled into the hold

### Requirement: Shrinking pull
A captured target SHALL rise up the beam axis into the hatch over its depth divided by the pull speed (with a minimum time) while its drawn scale falls to the configuration's shrink factor, the belly hatch SHALL open while pulling, and on arrival the target SHALL be picked up exactly as before (hot loot, unidentified items, Echoes, nests, caches and the Curio). The pull SHALL be deterministic and part of the snapshot.

#### Scenario: Halfway up
- **WHEN** a pull is half done
- **THEN** the target is above where it lay, drawn smaller than full size, and the hatch is open

#### Scenario: Arrival
- **WHEN** the pull completes
- **THEN** the item is in the hold and the target is gone from the world

### Requirement: Helm beam relay
With the helm beam relay fitted, a player at the Villa's helm SHALL be able to pull a size S or M target that the beam has locked without going to the Tractor Room; bigger targets SHALL still need the console. The HUD beam hint SHALL say "F PULLS (HELM RELAY)" for a target the relay can take.

#### Scenario: A small find from the helm
- **WHEN** a Villa with the relay hovers locked over a size S find and its pilot presses Tractor at the helm
- **THEN** the beam pulls the find up without the console
