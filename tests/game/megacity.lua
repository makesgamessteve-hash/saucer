-- SPDX-License-Identifier: MIT
-- The megacity round a city's core end to end (OpenSpec add-alien-cities-2): fold into the planet city's sector,
-- fly out over the outer districts, see the near ones turn solid (a megaform stops the saucer), fly off and see them
-- go, and check that flights through the streaming ring end in one state with and without a restore half way.
-- Then the moon and asteroid cities: each ringed by its outer districts.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local mega = require("sim.citymega")
local get = function() return T.state().players[1] end
local function city_site(st)
  for i, s in ipairs(st.sector.sites) do if s.city then return i end end
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")
local st = T.state()

-- 1. the planet city and its ring
game.enter_sector(st, 3)
local site = city_site(st)
local ruin = game.ruin(site)
local p = game.mega_plan(st, site)
local total = #ruin.city.districts + #p.districts
T.assert(total >= 24 and total <= mega.DISTRICTS, "the core and its ring: " .. total .. " districts")
local function stage(pos, yaw)
  local s = get().ship
  s.pos, s.vel, s.yaw, s.pitch, s.bank = pos, { 0, 0, 0 }, yaw or 0, 0, 0
  T.wait(2)
end

-- 2. over an outer district: it and its neighbours are solid; a megaform stops the saucer
local d = p.districts[(#p.districts + 1) // 2]
local o
for _, x in ipairs(d.organs) do if x.gx == 1 and not o then o = x end end
T.assert(o ~= nil, "a megaform on the district's west row")
local R = require("sim.config").get(get().ship.size).diameter / 2
stage({ o.x0 - R - 40, p.frame.y + 30, o.z0 + o.w2 / 2 }, math.pi / 2)
local live = count(mega.live(site))
T.assert(mega.live(site)[d.k] ~= nil and live <= mega.PER_PLAYER, "the district is solid (" .. live .. " live)")
local before = T.snapshot()
T.axis(1, "move_z", 1, 240)
local x = get().ship.pos[1]
T.assert(x > o.x0 - R - 39 and x + R <= o.x0 + 0.5, string.format("the megaform's face stopped the saucer (%.1f vs %.1f)", x + R, o.x0))
local after = T.snapshot()

-- 3. the same flight with a restore half way ends in the same state
T.restore(before)
T.axis(1, "move_z", 1, 120)
local mid = T.snapshot()
T.restore(mid)
T.assert(count(mega.live(site)) > 0, "a restore makes the near districts solid again")
T.axis(1, "move_z", 1, 120)
T.assert(T.snapshot() == after, "a restore half way changes nothing")

-- 4. back over the core: the ring's boxes leave the physics world
local n = saucer.physics.count()
stage({ p.frame.cx, p.frame.y + 500, p.frame.cz })
T.assert(count(mega.live(site)) == 0, "nothing of the ring is solid over the core")
T.assert(saucer.physics.count() < n, "the boxes went (" .. n .. " -> " .. saucer.physics.count() .. ")")

-- 5. the moon and the asteroid cities
for _, sid in ipairs({ 4, 2 }) do
  game.enter_sector(st, sid)
  local i = city_site(st)
  local r = game.ruin(i)
  local q = game.mega_plan(st, i)
  local all = #r.city.districts + #q.districts
  T.assert(all >= 24 and all <= mega.DISTRICTS, r.city.body .. " city: " .. all .. " districts")
end
print(string.format("megacity: planet %d districts (%d outer), %d live over the ring, tick %d", total, #p.districts, live, st.tick))
