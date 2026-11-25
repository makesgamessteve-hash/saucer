-- SPDX-License-Identifier: MIT
-- The megacity round a city's core end to end (OpenSpec add-alien-cities-2): fold into the planet city's sector,
-- fly out over the outer districts, see the near ones turn solid (a megaform stops the saucer), fly off and see them
-- go, and check that flights through the streaming ring end in one state with and without a restore half way;
-- fly into an organ's hall and beam up a find.
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

-- 5. an organ: fly in through its mouth, beam a find up from the console; a restore keeps it taken
local od
for _, x in ipairs(p.districts) do if x.organ and not od then od = x end end
T.assert(od ~= nil, "an outer district with an organ")
local og = od.organ
local h = og.hall
local W = mega.WALL
local out_pt, in_pt
local cy = p.frame.y + 14
if og.side <= 2 then
  local fx = og.side == 1 and h[1] - W or h[4] + W
  local dir = og.side == 1 and -1 or 1
  out_pt, in_pt = { fx + dir * 60, cy, (h[3] + h[6]) / 2 }, { fx - dir * 50, cy, (h[3] + h[6]) / 2 }
else
  local fz = og.side == 3 and h[3] - W or h[6] + W
  local dir = og.side == 3 and -1 or 1
  out_pt, in_pt = { (h[1] + h[4]) / 2, cy, fz + dir * 60 }, { (h[1] + h[4]) / 2, cy, fz - dir * 50 }
end
local yaw = math.atan(in_pt[1] - out_pt[1], in_pt[3] - out_pt[3])
stage(out_pt, yaw)
T.assert(ap.fly(T, 1, get, in_pt, 3, 900), "flew in through the organ's mouth")
T.assert(mega.in_hall(od, get().ship.pos) == og, "inside the organ's hall")
local tractor = require("sim.tractor")
local cand
for _, c in ipairs(tractor.candidates(st, get(), 0, nil)) do
  if c.organ == od.id and (not cand or math.abs(c.pos[1] - in_pt[1]) + math.abs(c.pos[3] - in_pt[3]) < math.abs(cand.pos[1] - in_pt[1]) + math.abs(cand.pos[3] - in_pt[3])) then cand = c end
end
if not cand then
  -- (no find within beam sense of the mouth: go to the first one)
  local f = og.finds[1].pos
  T.assert(ap.fly(T, 1, get, { f[1], cy, f[3] }, 3, 1800), "flew to a find")
  for _, c in ipairs(tractor.candidates(st, get(), 0, nil)) do if c.organ == od.id and not cand then cand = c end end
end
T.assert(cand ~= nil, "a find in the hall")
T.assert(ap.fly(T, 1, get, ap.beam_spot(cand.pos, get().ship.size), 0.5, 1800), "over the find")
T.assert(ap.to_console(T, 1, get), "at the beam console")
local hold = #get().hold
T.assert(ap.beam_up(T, 1, get, cand), "beamed the find up")
T.assert(#get().hold == hold + 1 and get().looted[cand.key], "the find is in the hold and taken")
local snap = T.snapshot()
T.restore(snap)
T.assert(get().looted[cand.key], "still taken after a restore")
T.assert(ap.back_to_helm(T, 1, get), "back at the helm")
T.screenshot("megacity_organ.png")

-- 5b. the undercity: down the shaft at the back of the hall into the warren, along to the sanctum, beam a find there
local w = od.warren
if not w then
  for _, x in ipairs(p.districts) do if x.warren and not w then od, w = x, x.warren end end
end
T.assert(w ~= nil, "an organ with a warren under it")
local sh = w.shaft
local sx, sz = (sh[1] + sh[3]) / 2, (sh[2] + sh[4]) / 2
stage({ sx, od.y + 24, sz }, 0)
T.assert(mega.in_hall(od, get().ship.pos) == od.organ, "over the shaft, in the hall")
T.assert(ap.fly(T, 1, get, { sx, w.y0 + 18, sz }, 3, 1500), "flew down the shaft")
T.assert(mega.in_warren(od, get().ship.pos) == w, "in the warren")
local sc = w.sanctum
T.assert(ap.fly(T, 1, get, { sc[1], w.y0 + 18, sc[3] }, 4, 3600), "flew along the corridor to the sanctum")
local deep
for _, c in ipairs(tractor.candidates(st, get(), 0, nil)) do if c.kind == "slot" and c.pos[2] < od.y and not deep then deep = c end end
T.assert(deep ~= nil, "a find in the sanctum")
T.assert(ap.fly(T, 1, get, ap.beam_spot(deep.pos, get().ship.size), 0.5, 1800), "over the sanctum's find")
T.assert(ap.to_console(T, 1, get), "at the beam console in the warren")
hold = #get().hold
T.assert(ap.beam_up(T, 1, get, deep), "beamed the sanctum's find up")
T.assert(#get().hold == hold + 1 and get().looted[deep.key], "the sanctum's find is in the hold and taken")
-- the sanctum's archive record, read in place
local rec
for _, c in ipairs(tractor.candidates(st, get(), 0, nil)) do if c.kind == "clue" then rec = c end end
T.assert(rec ~= nil, "the sanctum keeps an archive record")
game.pick_up(st, get(), rec, 0)
T.assert(get().looted[rec.key], "the record is read")
T.assert(ap.back_to_helm(T, 1, get), "back at the helm in the warren")
T.screenshot("megacity_warren.png")

-- 6. the moon and the asteroid cities
for _, sid in ipairs({ 4, 2 }) do
  game.enter_sector(st, sid)
  local i = city_site(st)
  local r = game.ruin(i)
  local q = game.mega_plan(st, i)
  local all = #r.city.districts + #q.districts
  T.assert(all >= 24 and all <= mega.DISTRICTS, r.city.body .. " city: " .. all .. " districts")
end
print(string.format("megacity: planet %d districts (%d outer), %d live over the ring, tick %d", total, #p.districts, live, st.tick))
