-- SPDX-License-Identifier: MIT
-- add-realistic-lighting: the light switches through real input, the light list a frame builds
-- (sun outside, none inside, the saucer's own lights) and the shadow quality presets.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ruinm = require("sim.ruin")
local dock = require("sim.dock")
local get = function() return T.state().players[1] end
local function L() return saucer.render.lights(1) end
local function count(kind, owner)
  local n = 0
  for _, a in ipairs(L().active) do
    if a.kind == kind and (owner == nil or a.owner == owner) then n = n + 1 end
  end
  return n
end

T.wait(30)
ap.wake(T, 1, get)
T.assert(L().on, "the light model is on")
T.assert(L().n > 0 and L().dropped == 0, "a frame submits lights")
-- in the Villa the cabin lamps light the rooms; 6 switches them off and on
T.assert(get().lights.cabin, "cabin lamps on by default")
local lit = L().n
T.press(1, "cabin_lights")
T.wait(4)
T.assert(get().lights.cabin == false, "6 switches the cabin lamps off")
T.assert(L().n < lit, "fewer lights with the cabin lamps off")
T.press(1, "cabin_lights")
T.wait(4)
T.assert(get().lights.cabin, "and on again")
-- the pad's light button: a tap while walking is the cabin lamps
T.press(1, "lights", 3)
T.wait(2)
T.assert(get().lights.cabin == false, "a tap on foot in the Villa switches the cabin lamps")
T.press(1, "cabin_lights")
T.wait(2)

T.assert(ap.take_helm(T, 1, get), "at the helm")
-- outside: the star is the first and strongest light, and it casts the sun's shadow cascades
local s = get().ship
local site1 = T.state().sector.sites[1]
local lo, hi = ruinm.bounds(game.ruin(1), site1.pos, 0)
s.vel = { 0, 0, 0 }
s.pos = { (lo[1] + hi[1]) / 2 + 40, hi[2] + 60, lo[3] - 90 }
T.wait(6)
local a1 = L().active[1]
T.assert(a1 and a1.kind == "sun" and a1.shadow, "outside the star leads the light list")
T.assert(L().cascades >= 1 and L().atlas > 0, "the star casts shadows")
T.assert(L().ambient[1] < 0.06, "space is dark: little ambient")

-- headlights (4) and floods (5): spot and omni lights of the saucer's own
T.press(1, "headlights")
T.wait(4)
T.assert(get().lights.head, "4 switches the headlights on")
local own = 1000 + get().index
T.assert(count("spot", own) == 2, "two headlight spots")
T.press(1, "floods")
T.wait(4)
T.assert(get().lights.flood and count("point", own) == 1, "5 switches the floods on: an all-round light")
T.press(1, "lights", 40)
T.wait(2)
T.assert(get().lights.flood == false, "holding the pad's light button switches the floods")
T.press(1, "lights", 3)
T.wait(2)
T.assert(get().lights.head == false, "a tap at the helm is the headlights")

-- inside a derelict room: no sun, only the place's own coloured lamps
local found
for i, site in ipairs(T.state().sector.sites) do
  local r = game.ruin(i)
  if r and not found and not r.city then
    for _, room in ipairs(r.rooms) do
      local mn, mx = ruinm.room_box(room, ruinm.kit_of(r.kit), site.pos)
      if not found and mx[1] - mn[1] > 14 and mx[3] - mn[3] > 14 and mx[2] - mn[2] > 8 then
        found = { (mn[1] + mx[1]) / 2, mn[2] + 4, (mn[3] + mx[3]) / 2 }
      end
    end
  end
end
T.assert(found, "a derelict hall to visit")
s.pos, s.vel = found, { 0, 0, 0 }
T.wait(8)
T.assert(count("sun") == 0, "no sunlight inside a derelict")
T.assert(count("point") >= 1, "lamps light the hall")
local colours = {}
for _, a in ipairs(L().active) do colours[string.format("%.2f,%.2f,%.2f", a.color[1], a.color[2], a.color[3])] = true end
local nc = 0
for _ in pairs(colours) do nc = nc + 1 end
T.assert(nc >= 1, "coloured lamps")
T.press(1, "headlights")
T.wait(4)
T.assert(count("spot", own) == 2, "headlights inside too")
-- add-lighting-mood: the headlight beams show in the air of the dark hall
T.assert(L().haze >= 1 and L().haze <= 4 and L().haze_steps == 8, "high: beams and halos glow")
T.assert(#L().glow == L().haze, "the glowing lights are listed")

-- the hangar bay: lit inside, no sun
local b = dock.bay(T.state(), 1)
s.pos, s.vel = { b.pad[1], b.floor + 4, b.pad[3] }, { 0, 0, 0 }
T.wait(8)
T.assert(count("sun") == 0 and count("point") >= 4, "the hangar is lit by its lamps")

-- quality presets
T.assert(saucer.render.settings({ shadows = "low" }).shadows == "low", "low shadows")
T.wait(4)
T.assert(L().omni <= 1 and L().atlas == 512, "low: one omni map, a small atlas")
T.assert(L().haze >= 1 and L().haze <= 2 and L().haze_steps == 4, "low: cheap beams, two at most")
saucer.render.settings({ shadows = "off" })
T.wait(4)
T.assert(L().atlas == 0 and L().cascades == 0, "off: no shadow maps")
T.assert(L().haze == 0 and L().haze_steps == 0, "off: no beams or halos")
saucer.render.settings({ shadows = "high" })
T.wait(4)
T.assert(L().atlas == 1024, "high again")
T.assert(not pcall(saucer.render.settings, { shadows = "ultra" }), "an unknown preset is an error")
T.assert(saucer.render.lights(9) == nil, "no such view")
print("lighting ok")
