-- SPDX-License-Identifier: MIT
-- The EVA kit (OpenSpec add-dock-land-eva): oxygen, suit integrity, jetpack fuel,
-- the return assist and the emergency teleport. Seconds, percent, metres.
-- Mods may override this file.
return {
  o2_max = 100,
  o2_drain = 0.35,            -- per second in vacuum or toxic air (a bit under five minutes)
  o2_jet = 1.5,               -- x while the jetpack burns
  o2_run = 1.3,               -- x while running
  warn = { 30, 15 },          -- % oxygen (and integrity) that warn, then call it critical
  integrity_max = 100,
  rad_k = 0.04,               -- integrity lost per second per unit of radiation (while suited)
  temp_k = 0.002,             -- ...per degree beyond temp_safe
  temp_safe = 60,             -- degrees away from 21 C that the suit shrugs off
  fall_safe = 12,             -- m/s landing speed that costs nothing
  fall_k = 3,                 -- integrity per m/s beyond that
  fuel_max = 100,
  fuel_hover = 6,             -- per second hovering in a pull
  fuel_boost = 14,            -- per second thrusting up in a pull
  fuel_free = 3,              -- per second at full thrust in zero-g
  fuel_assist = 2,            -- per second the return assist flies you home
  refill_r = 32,              -- within this of the standing Villa oxygen, fuel and integrity refill
  refill_rate = 30,           -- per second
  g_free = 0.1,               -- below this pull the jetpack flies in all six directions
  jet_accel = 7,              -- m/s^2 in zero-g
  jet_speed = 14,             -- m/s cap in zero-g
  brake = 4,                  -- m/s^2 of automatic braking when no thrust is asked for in zero-g
  boost_up = 11,              -- m/s^2 thrusting up in a pull (plus the pull itself)
  up_max = 7,                 -- m/s cap climbing in a pull
  down_max = 3.5,             -- m/s cap descending under thrust
  air_speed = 1.45,           -- x walk speed in the air under jet power
  assist_speed = 9,           -- m/s the return assist flies
  assist_stop = 3.0,          -- m from the stairs' foot where it lets go
  assist_blocked = 90,        -- ticks of being stuck before it gives up
  tele_charge = 2.5,          -- seconds of charge-up
  tele_cool = 240,            -- seconds before the next emergency teleport
  tele_loss = 0.5,            -- fraction of carried hands left behind (rounded up) as a cache
  gravity = 9.8,              -- the pull's scale: g x this
  flash = 1.2,                -- seconds of the teleport's white flash
}
