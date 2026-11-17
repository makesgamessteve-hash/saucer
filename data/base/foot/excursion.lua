-- SPDX-License-Identifier: MIT
-- On-foot excursions in derelicts (concept §4, OpenSpec add-on-foot-excursions).
-- Mods may override this file. Units: meters, seconds, percent of the suit.
return {
  suit = {
    max = 100,
    drain = 0.65,        -- per second outside the saucer (a full suit lasts about 2.5 minutes)
    crawl = 1.6,         -- drain multiplier in a crawlspace (cramped, the cooling struggles)
    locked = 2.0,        -- drain multiplier while a Watcher has you Locked
    bolt = 14,           -- a stun bolt's bite out of the suit
    hop = 3,             -- a jet-hop's cost
    warn = { 30, 10 },   -- HUD warnings (percent)
  },
  hands = 4,             -- slots, separate from the hold; they empty into the hold when you board
  carry = 2,             -- the biggest item size you can carry by hand
  body = {
    radius = 0.3, stand = 1.75, crouch = 0.8, eye = 1.62, crouch_eye = 0.62,
    crawl_speed = 1.3,   -- crouched or crawling
    gravity = 9.0,       -- the suit's mag-boots pull you to the deck
    hop = 4.0,           -- jet-hop launch speed
    max_fall = 18,
  },
  stand_dist = 2.0,      -- step out only with a deck this close under the Seat (or the Villa's belly)
  deploy = { clear = 2.2, ahead = 1.6, lift = 1.15 }, -- a 2.2 m clearance sphere in front of you
  reach = 2.0,           -- hand-locks, consoles and loot within this of your eyes
  lock_time = 2.0,       -- seconds to turn a hand-lock's coupling
  console_time = 2.5,    -- seconds to shut a grid down at its console
  path_every = 30,       -- ticks between Lifeline trail points
  path_max = 160,
  white = 1.5,           -- seconds of white-out when the Lifeline pulls you back
  hand_time = 1.2,       -- the coin rests in your palm this long before it goes into the pocket
  shutter_time = 1.6,    -- seconds a shutter takes to slide open (render)
  delicate_value = 1.6,  -- Delicate finds are worth more (the beam would crush them)
}
