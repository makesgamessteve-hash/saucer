-- SPDX-License-Identifier: MIT
-- A moon city end to end (OpenSpec add-cities): fold into the sector, fly the Villa to a dark
-- district's power coupling (the beam refuses nothing: it is a size-1 target), beam it home from the
-- console, see the district wake (its gates open, the grid reads 2/9, the beacon moves on), then
-- carry on: a second coupling, and the pull of a planet city (Charge drains while hovering).
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local cities = require("sim.cities")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs) do if m.text:find(s, 1, true) then return true end end
  return false
end
local function city_site(st)
  for i, s in ipairs(st.sector.sites) do if s.city then return i end end
end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")
local st = T.state()

-- 1. the moon city: a light pull, nine districts, only the spaceport live
game.enter_sector(st, 4)
local site = city_site(st)
local ruin = game.ruin(site)
T.assert(ruin.city.body == "moon" and #ruin.city.districts == 9, "a moon city of nine districts")
local function stage(pos)
  local s = get().ship
  s.pos, s.vel, s.yaw, s.pitch, s.bank = pos, { 0, 0, 0 }, 0, 0, 0
  T.wait(30)
end
local first = cities.candidates(st, get(), site, ruin)[1]
local spot = ap.beam_spot(first.pos, 1)
stage(vec.add(spot, { 30, 25, -30 }))
T.assert(get().site == site, "inside the city's bounds")
T.assert(said("moon city"), "the city announced itself")
T.assert(cities.grid(st, site, ruin) == 1, "grid 1/9 on arrival")
local shut = game.gates_closed(site)
T.assert(shut > 20, "the dark districts are gated shut (" .. shut .. ")")
T.screenshot("city_coupling.png")

-- 2. fly to it and beam it up from the console
T.assert(ap.fly(T, 1, get, spot, 0.3, 1500), "hovering over the power coupling")
T.assert(ap.to_console(T, 1, get), "at the beam console")
T.assert(ap.beam_up(T, 1, get, first), "beamed the coupling home")
T.assert(said("Power restored"), "the grid said so")
T.assert(cities.grid(st, site, ruin) == 2, "grid 2/9")
T.assert(game.gates_closed(site) < shut and game.gates_closed(site, first.district) == 0, "the district's gates opened")
T.assert(#get().hold == 0, "a coupling is no cargo")
T.assert(ap.back_to_helm(T, 1, get), "back at the helm")
local b = cities.beacon(st, site, ruin, get().ship.pos)
T.assert(b.short == "COUPLING" and b.dist > 10, "the beacon points on to the next coupling")
T.screenshot("city_restored.png")

-- 3. the planet city: the pull costs Charge in the open air
game.enter_sector(st, 3)
site = city_site(st)
ruin = game.ruin(site)
T.assert(ruin.city.body == "planet", "a planet city")
stage(vec.add(st.sector.sites[site].pos, { 1440, 650, 700 }))
get().ship.charge = 60
T.wait(120)
T.assert(get().ship.charge < 60 - 1, "hovering in the planet's pull spent Charge (" .. get().ship.charge .. ")")
print(string.format("city: planet charge %.1f, tick %d", get().ship.charge, st.tick))
