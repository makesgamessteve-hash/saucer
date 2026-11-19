-- SPDX-License-Identifier: MIT
-- add-dock-land-eva slice 3: land anywhere. A moon city (vacuum, light pull), a planet city (toxic air) and an
-- asteroid city (vacuum, no pull): find a rooftop and the open ground, read the landing readout on the way
-- down, land, check what the saucer says it stands on and the suit's environment; then a sky-bridge-like
-- support loss: the ground goes, the thrusters take over.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local landing = require("sim.landing")
local env = require("sim.env")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end
local function city_site(st)
  for i, s in ipairs(st.sector.sites) do if s.city then return i end end
end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")
local st = T.state()

-- the first rooftop pad ("pad") or plaza platform ("platform") of the city a hull can land on -> spot over it
local function find_spot(site, kind)
  local ruin = game.ruin(site)
  local p = get()
  local r, hh = require("sim.ship").dims_of(1)
  for _, sd in ipairs(ruin.solids) do
    if sd.kind == kind then
      local pos = { (sd[1][1] + sd[2][1]) / 2, sd[2][2] + 24, (sd[1][3] + sd[2][3]) / 2 }
      local rep = landing.probe(st, p, pos, 0)
      if rep.ok and not game.blocked(st, p, { pos[1], rep.target, pos[3] }, r, hh, 0) then return pos, sd[2][2] end
    end
  end
  return nil
end

local function land_at(pos, label)
  local s = get().ship
  s.pos, s.vel, s.yaw, s.pitch, s.bank = { pos[1], pos[2], pos[3] }, { 0, 0, 0 }, 0, 0, 0
  T.wait(10)
  local lr = landing.readout(T.state(), get())
  T.assert(lr and not lr.void and lr.ok and lr.dist > 15 and lr.dist < 40 and lr.slope < 1, label .. ": the readout says it can land (" .. (lr and lr.dist or "?") .. " m)")
  T.press(1, "land")
  T.wait(2)
  T.assert(get().berth and get().berth.phase == "descend", label .. ": settling")
  T.assert(ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 40), label .. ": touched down")
  T.assert(said("Touchdown on"), label .. ": says what it stands on")
end
local function lift()
  T.press(1, "land")
  T.assert(ap.wait_until(T, 1, function() return get().berth == false end, 60 * 20), "lifted off")
end

-- a big wreck's hull: the first level top on the first derelict that a hull can sit on
do
  local ruin = game.ruin(1)
  local o = st.sector.sites[1].pos
  local p = get()
  local r, hh = require("sim.ship").dims_of(1)
  local spot
  for dx = -260, 260, 6 do
    for dz = -260, 260, 6 do
      local hit = saucer.physics.raycast({ o[1] + dx, o[2] + 300, o[3] + dz }, { 0, -1, 0 }, 700, 1)
      if hit and not spot then
        local pos = { o[1] + dx, o[2] + 300 - hit.t + 24, o[3] + dz }
        local rep = landing.probe(st, p, pos, 0)
        if rep.ok and not game.blocked(st, p, { pos[1], rep.target, pos[3] }, r, hh, 0) then spot = pos end
      end
    end
  end
  T.assert(spot, "found a flat top on the derelict")
  get().site = 1
  land_at(spot, "wreck")
  T.assert(get().berth.surface == "a wreck's hull", "a wreck's hull")
  lift()
end

-- the moon: vacuum, a light pull
game.enter_sector(st, 4)
local site = city_site(st)
local spot, top = find_spot(site, "platform")
T.assert(spot, "found open moon ground")
get().site = site
land_at(spot, "moon ground")
T.assert(get().berth.surface == "the moon's surface" and said("the moon's surface"), "the moon's surface")
local e = env.at(st, get())
T.assert(e.vacuum and math.abs(e.g - 0.16) < 1e-9, "vacuum, 0.16 g")
lift()
spot = find_spot(site, "pad")
T.assert(spot, "found a moon rooftop")
land_at(spot, "moon roof")
T.assert(get().berth.surface == "moon city rooftop", "a rooftop")
lift()

-- the planet: toxic air, a heavy pull
game.enter_sector(st, 3)
site = city_site(st)
spot = find_spot(site, "platform")
T.assert(spot, "found open planet ground")
get().site = site
land_at(spot, "planet")
e = env.at(st, get())
T.assert(e.toxic and e.g > 1.1, "toxic air, 1.2 g")
lift()

-- the asteroid: vacuum, almost no pull
game.enter_sector(st, 2)
site = city_site(st)
spot = find_spot(site, "platform")
T.assert(spot, "found asteroid rock")
get().site = site
land_at(spot, "asteroid")
e = env.at(st, get())
T.assert(e.vacuum and e.g < 0.1, "vacuum, no pull")

-- the ground gives way: a platform under the gear is removed
lift()
local PY = -600
local plat = { { -80, PY - 20, -80 }, { 80, PY, 80 } }
game.extra_solids[#game.extra_solids + 1] = plat
saucer.physics.add_box(plat[1], plat[2], 1)
get().site = 0
local s = get().ship
s.pos, s.vel = { 0, PY + 22, 0 }, { 0, 0, 0 }
T.wait(5)
T.press(1, "land")
T.assert(ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 30), "on the platform")
for i, b in ipairs(game.extra_solids) do if b == plat then table.remove(game.extra_solids, i) break end end
game.rebuild(T.state())
T.assert(ap.wait_until(T, 1, function() return get().berth and get().berth.phase == "lift" end, 120), "the thrusters take over")
T.assert(said("GROUND GIVES WAY"), "and says so")
T.assert(ap.wait_until(T, 1, function() return get().berth == false end, 60 * 20), "gear up")
print("land_anywhere: ok")
