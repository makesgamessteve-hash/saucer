-- SPDX-License-Identifier: MIT
-- Sentry types (concept §8.2-8.3). Robots only, nothing lethal: Watchers
-- drain shields then hull; Snatchers steal one hot item from a Seat.
-- Mods may override this file.
return {
  alert_time = 0.75,      -- at least this long in Alert before Locked
  lose_time = 1.0,        -- out of sight this long: back to Dormant
  disabled_time = 12.0,   -- Jammer reboot
  watcher = {
    range = 100, half_angle = 0.62, sweep = 0.9, sweep_period = 9.0,
    -- size band by the civ's body scale: it ignores anything smaller (the Seat is class 1)
    band = { human = { 2, 4 }, tiny = { 2, 4 }, giant = { 3, 4 } },
    fire_every = 1.6, bolt_speed = 18, bolt_life = 5.0, bolt_damage = 9, bolt_radius = 0.4,
    foot_range = 45,      -- add-on-foot-excursions: a person on foot is seen this far (any size band)
    -- add-fun-fixes: a hull below the band (the Seat) is still seen this close, so a Seat dive is
    -- stealth, not a free pass; and bolts hit an ellipsoid this fraction of the hull (its lens shape)
    small_range = 25, hurt_scale = 0.8,
    -- add-fun-fixes: the light Watcher in a sector's tutorial derelict (site 1): shorter sight,
    -- a slower lock and soft bolts, so the first threat comes early and teaches the tools
    light = { range = 55, small_range = 15, alert_time = 1.5, bolt_damage = 4 },
  },
  snatcher = {
    sense = 22, chase_speed = 7.5, patrol_speed = 2.0, flee_speed = 9.0, latch_time = 3.0, latch_dist = 1.6,
    give_up = 34,
    foot_sense = 14,      -- add-on-foot-excursions: drawn to hot items in your hands from this close
  },
  -- add-wider-dark (concept §8.2-8.3): in danger 2+ sectors only
  clamp = { sense = 30, chase_speed = 9.0, drain = 1.5, shake_time = 2.0, grip = 1.0, per_site = 2 },
  lockdown = { seal_time = 60.0, rest = 10.0, thickness = 1.0 },
  decoy = { life = 8.0, range = 80, ahead = 8, start = 3, price = 60 },
  shroud = { drain = 1.2, still = 0.6 },
  spike = { time = 3.0, reach = 3.0 },
  -- add-home-among-stars: the Warden (danger 3 sectors) and two suit tools
  warden = { sense = 40, foot_sense = 24, speed = 5.0, chase_speed = 7.0, fire_every = 2.2, wake = 30,
             leash = 8, per_site = 1, drowsy = 0.5 }, -- drowsy: its speed with the site grid down
  grapple = { range = 25, speed = 14, suit = 4, max_time = 3.0 },
  cutter = { time = 6.0, reach = 2.5, suit = 6 },
  scanner = { charge = 2, cooldown = 5.0, reveal = 10.0 },
  jammer = { charge = 8, suit = 15, cooldown = 10.0, range = 15.0, half_angle = 0.6, near = 3.0 }, -- near: all-round pulse radius; suit: % on foot
  shield_regen = 4.0,     -- per second, after shield_delay without hits
  shield_delay = 4.0,
  -- add-playtest-recs: the trader's tow bill for a Fold Retreat, by sector
  -- danger (credits first; what you can't pay comes out of the Charge)
  -- add-fun-fixes: danger 1 bills too, and a retreat loses half the hot cargo (rounded up) for
  -- good; the rest stays behind as the cache
  retreat_bill = { 40, 80, 140 },
  retreat_lose = 0.5,
  tow_window = 600, tow_streak_max = 4, -- add-fun-fixes: repeat tows within 10 min cost 2x, 3x, 4x
  -- add-strategic-sentries (sim/stealth.lua): sentries build suspicion instead of seeing at once
  stealth = {
    -- the suspicion meter (0..1) of a Watcher or Spotter: it fills while it can see you, at
    -- fill x your signature x closeness (1 at the edge of its range, 1 + near at point blank), and
    -- drains at decay while it can't. Alert at `alert`, Locked at 1 (and alert_time in Alert)
    fill = 2.0, decay = 0.3, alert = 0.5, near = 1.5, light_fill = 0.6, after_lock = 0.45,
    -- your signature: hull base x (still + (1 - still) x min(speed / speed_ref, speed_cap)), plus
    -- beam while the tractor pulls and loud per Loud module (boosting shows up as speed)
    hull = { villa = 1.0, seat = 0.4, pocket = 0.2, foot = 0.5 }, still = 0.55, speed_ref = 10, speed_cap = 2.0,
    beam = 0.5, loud = 0.3, snatcher_beam = 1.3,
    -- the site alarm: every lock (or Spotter tag, or a cell theft caught) raises it by 1 (to max).
    -- Each level: meters fill by alarm_fill more, sweeps turn by alarm_sweep faster, turrets fire
    -- by alarm_fire faster. At wake_at the Snatchers wake, at lockdown_at the Lockdown seals.
    -- It cools by one level every cool_out s with nobody inside, cool_in s with you inside and unseen.
    alarm_max = 3, alarm_fill = 0.35, alarm_sweep = 0.25, alarm_fire = 0.3, wake_at = 2, lockdown_at = 2,
    cool_out = 30, cool_in = 90,
    light_alarm_max = 1,   -- the tutorial derelict's alarm stops at 1, and its light Watcher never fires faster
    -- sweep patterns (picked per turret from the site and room): a smooth sine, four stops, or a
    -- sine that holds at both edges; each turret's period is the base x one of these
    patterns = { "sine", "step", "hold" }, periods = { 0.8, 0.9, 1.0, 1.15, 1.3 },
    offset = 10,           -- lateral offset of an off-centre turret (m)
    -- cover: two pillars (w x h fraction of the hall height) and a low crate stack per Watcher hall
    pillar = { w = 4.0, h = 0.6, side = 10 }, crate = { s = 5.0 },
    -- guarded loot: one find per Watcher hall lies on the floor in its sweep (where the cone, `at` of
    -- its half angle below the axis, meets the floor), worth premium x
    guard = { premium = 1.6, at = 0.6, tier = 2 },
    -- a Watcher bolt hitting the hull shakes a beam pull in progress loose (it has to start over)
    hit_drops = true,
    -- sabotage: a power cell on the floor behind a Watcher; beam it out (at least `time` s) and
    -- the turret is dark for good; seen while pulling, the turret that saw you locks at once
    cell = { time = 3.0, back = 2.0, value = 45 },
    -- the Spotter drone: patrols the great halls, never fires; when its meter fills it tags you:
    -- every Watcher of the site jumps to tag_meter and the alarm rises
    spotter = { range = 45, small_range = 20, foot_range = 20, half_angle = 0.9, speed = 4.0, fill = 1.2,
                tag_meter = 0.9, rest = 8.0, lift = 4.0, min_watchers = 2 },
  },
  hull_regen = 0.1,       -- hull points per second in open space, after shield_delay (Steady doubles it)
}
