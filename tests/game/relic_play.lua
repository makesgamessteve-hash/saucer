-- SPDX-License-Identifier: MIT
-- add-relic-stations (plan phase 8): a relic in normal play. Fold to sector 3 (every universe has a relic there),
-- pick it up on the scanner from 2 km out, fly through its maw into its halls (its sentries are up, its decay
-- drawn), reach the heart, then save and load mid-dungeon: the explored rooms, the scan and the heart are still
-- remembered and the run goes on.
local T = saucer.test
local ap = require("sim.autopilot")
local relic = require("sim.relic")
local game = require("sim.game")
local ruinm = require("sim.ruin")
local save = require("sim.save")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs) do if m.text:find(s, 1, true) then return true end end
  return false
end
local function park(pos, yaw)
  local s = get().ship
  s.pos, s.vel, s.yaw = { pos[1], pos[2], pos[3] }, { 0, 0, 0 }, yaw or 0
  T.wait(relic.NOTE_EVERY + 2)
end

T.wait(5)
T.assert(ap.wake(T, 1, get), "woke")
T.assert(ap.take_helm(T, 1, get), "at the helm")
game.enter_sector(T.state(), 3)
T.wait(2)
local state = T.state()
local i
for k, s in ipairs(state.sector.sites) do if s.kit == "relic" then i = k end end
T.assert(i ~= nil, "sector 3 holds a relic")
local site = state.sector.sites[i]
T.assert(site.relic and not site.relic_civ, "a normal-play relic")
local r = game.ruin(i)
T.assert(r and r.relic, "it is generated")
local n = 0
for _, d in ipairs(game.sentries(i)) do if d.relic then n = n + 1 end end
T.assert(n >= 3, "it is guarded: " .. n)
T.assert(relic.found(state, i) == nil, "not yet scanned")

-- 2 km out in front of the maw: the scanner picks it up, once
local kit = ruinm.kit_of(r.kit)
local door = ruinm.entrance(r, site.pos)
park({ door[1], door[2], door[3] - 2000 }, 0)
T.assert(relic.found(T.state(), i) ~= nil, "scanned from 2 km")
T.assert(said("Relic signature"), "the scanner said whose it is")

-- through the maw, into the first halls and on to the heart
local function into(id)
  local mn, mx = ruinm.room_box(r.rooms[id], kit, site.pos)
  park({ (mn[1] + mx[1]) / 2, mn[2] + kit.wall + 8, (mn[3] + mx[3]) / 2 }, 0)
end
into(r.relic.halls[1])
T.assert(get().site == i, "inside the relic site")
into(r.relic.halls[2])
into(r.relic.core)
T.assert(#relic.rooms_seen(T.state(), i) >= 3, "three rooms remembered")
T.assert(relic.found(T.state(), i).heart ~= nil, "the heart reached")
T.assert(said("The heart hall"), "the heart hall said so")
T.screenshot("relic_play_heart.png")

-- save and load mid-dungeon
into(r.relic.halls[2])
T.assert(save.write(T.state()), "saved")
local seen = #relic.rooms_seen(T.state(), i)
local rec = save.read()
T.assert(rec ~= nil, "read back")
save.apply(T.state(), rec, game)
T.wait(2)
T.assert(T.state().sector_id == 3, "loaded in sector 3")
T.assert(#relic.rooms_seen(T.state(), i) == seen, "explored rooms kept")
T.assert(relic.found(T.state(), i) and relic.found(T.state(), i).heart, "scan and heart kept")
T.assert(#game.sentries(i) > 0, "sentries back")
T.wait(60)
print(string.format("relic_play: site %d civ %s, %d sentries, %d rooms seen, %d slots", i, tostring(site.civ), n, seen,
  #r.slots))
