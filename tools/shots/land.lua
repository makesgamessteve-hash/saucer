-- SPDX-License-Identifier: MIT
-- Screenshot tour for add-dock-land-eva slice 3 (land anywhere). Run from the folder that should receive shots_eva/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/land.lua
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local landing = require("sim.landing")
local R = require("view.render")
local sm = saucer.math
local get = function() return T.state().players[1] end
local D = "shots_eva/"
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
local function cam(pos, yaw, pitch) free = { pos = pos, yaw = yaw, pitch = pitch or 0, fov = 62, near = 0.1, far = 6000 } end
local function orbit(ang, dist, h, pitch)
  local s = get().ship
  local a = s.yaw + sm.pi + ang
  cam({ s.pos[1] + sm.sin(a) * dist, s.pos[2] + h, s.pos[3] + sm.cos(a) * dist }, a + sm.pi, pitch)
end
local function city_site(st) for i, s in ipairs(st.sector.sites) do if s.city then return i end end end
local function spot_on(site, kind)
  local ruin = game.ruin(site)
  local r, hh = require("sim.ship").dims_of(1)
  for _, sd in ipairs(ruin.solids) do
    if sd.kind == kind then
      local pos = { (sd[1][1] + sd[2][1]) / 2, sd[2][2] + 24, (sd[1][3] + sd[2][3]) / 2 }
      local rep = landing.probe(T.state(), get(), pos, 0)
      if rep.ok and not game.blocked(T.state(), get(), { pos[1], rep.target, pos[3] }, r, hh, 0) then return pos end
    end
  end
end
local function put(pos, yaw)
  local s = get().ship
  s.pos, s.vel, s.yaw, s.pitch, s.bank = { pos[1], pos[2], pos[3] }, { 0, 0, 0 }, yaw or 0, 0, 0
  T.wait(12)
end
local function land()
  T.press(1, "land")
  ap.wait_until(T, 1, function() return landing.landed(get()) end, 60 * 40)
  T.wait(20)
end
local function lift()
  free = nil
  T.press(1, "land")
  ap.wait_until(T, 1, function() return get().berth == false end, 60 * 20)
end

T.wait(40)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local st = T.state()

game.enter_sector(st, 4)
local site = city_site(st)
get().site = site
local pad = spot_on(site, "pad")
put({ pad[1], pad[2] + 10, pad[3] }, 0.6)
shot("40_readout_green_over_a_rooftop_pad")
-- a step under half the hull: the markers go red
local step = { { pad[1] + 2, pad[2] - 24, pad[3] - 30 }, { pad[1] + 30, pad[2] - 21.5, pad[3] + 30 } }
saucer.physics.add_box(step[1], step[2], 1)
put({ pad[1], pad[2] - 4, pad[3] + 0 }, 0.6)
get().ship.pos = { pad[1] + 6, pad[2] - 6, pad[3] }
T.wait(6)
shot("41_readout_red_too_steep")
saucer.physics.remove(saucer.physics.add_box({ 0, -9000, 0 }, { 1, -8999, 1 }, 1))
game.rebuild(T.state())
put(pad, 0.6)
land()
orbit(0.9, 60, 6, -0.05)
shot("42_landed_on_a_moon_city_rooftop_pad")
lift()
local plaza = spot_on(site, "platform")
put(plaza, 0.6)
land()
orbit(0.9, 60, 6, -0.05)
shot("43_landed_on_a_moon_plaza")
lift()

game.enter_sector(st, 3)
site = city_site(st)
get().site = site
put(spot_on(site, "platform"), 0.3)
land()
orbit(1.1, 55, 5, -0.05)
shot("44_landed_on_a_planet_plaza")
lift()

game.enter_sector(st, 2)
site = city_site(st)
get().site = site
put(spot_on(site, "platform"), 0.3)
land()
orbit(1.1, 55, 5, -0.05)
shot("45_landed_on_asteroid_rock")
lift()
