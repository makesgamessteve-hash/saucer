# Tune the sentry economy

## Why
The fun audit after add-strategic-sentries found beam-only play out-earning careful play (BeamOnly/Human 1.33x,
BeamOnly/Stealth 1.60x against a target of at most 0.75x), with near-misses far under 2 per site-minute. Most of
BeamOnly's money came from the tutorial derelict: one light Watcher, an alarm capped at 1, and light bolts that never
shook the beam loose.

## What Changes
- The tutorial derelict bites harder: its light Watcher sees 70 m (a Seat 18 m), fills at 0.8 (was 0.6), locks
  after 1.2 s (was 1.5) and fires 6-damage bolts (was 4).
- Its alarm can reach 2 (it has no Snatchers or Lockdowns to wake), and its light Watcher fires faster with the
  alarm by half as much as a full one (`light_fire`).
- A light bolt shakes a beam pull loose too (`light_drops`).

## Impact
- Specs: sentries-and-tools (MODIFIED: light sentry, hit shakes the beam, site alarm)
- Code: data/base/sentries/sentries.lua, sim/stealth.lua, sim/sentry.lua, sim/autopilot.lua (`gentle_tutorial` for game tests about other things);
  tests/lua/strategic_spec.lua, loop_spec.lua, tests/game slice/tractor/trade/story
- Replays re-recorded (sentry timing changes the hash); no state version bump.
