-- SPDX-License-Identifier: MIT
-- add-alien-stations: fly to the (much bigger, alien) trader station, see its family in the hull and the walk-in
-- layout, dock on the tractor beam, pocket the saucer and walk the alien wing chamber by chamber (shafts too),
-- then walk back to the arrival hangar, unfold and fly out again.
local T = saucer.test
local ap = require("sim.autopilot")
local visit = require("sim.visit")
local sg = require("sim.stationgen")
local sh = require("sim.stationhull")
local sector = require("sim.sector")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")
local st = T.state()

-- the hull and the inside agree on the family; the hull is big and clear of everything around
local H = sh.for_trader(st, 1)
local fam = H.family
T.assert(fam == sh.family_of(sg.seed_for(st, 1)), "the hull's family is the walk-in seed's")
local e = H.info.extent
T.assert(e.hi[1] - e.lo[1] > 1800 and e.hi[2] - e.lo[2] > 1600 and e.hi[3] - e.lo[3] > 1600, "a big station")
local tp = st.sector.trader.pos
for _, site in ipairs(st.sector.sites) do
  T.assert(sector.box_gap(site.pos, vec.add(tp, e.lo), vec.add(tp, e.hi)) > 0, "no site inside the hull")
end
saucer.log.info(string.format("alien: family %s, %.0f x %.0f x %.0f m, trader %.0f m out", fam,
  e.hi[1] - e.lo[1], e.hi[2] - e.lo[2], e.hi[3] - e.lo[3], math.sqrt(tp[1] * tp[1] + tp[2] * tp[2] + tp[3] * tp[3])))

-- fly in and dock
T.assert(ap.travel(T, 1, get, { tp[1] + 50, tp[2], tp[3] + 50 }, 6, 9000), "flew to the trader")
T.assert(get().docked == 1, "docked")

-- pocket the saucer and step out
T.press(1, "size2")
T.assert(ap.wait_until(T, 1, function() return get().ship.size == 2 and not get().ship.morph end, 600), "the Seat")
T.press(1, "size3")
T.wait(1)
T.assert(get().mode == "foot", "stepped out")
T.assert(ap.wait_until(T, 1, function() return get().station.coin == "pocket" end, 600), "the coin in the pocket")
local L = visit.layout(T.state(), get())
T.assert(L.family == fam, "the inside is the hull's family")
T.assert(L.wing and L.wing >= 4, "an alien wing of " .. tostring(L.wing) .. " chambers")

-- walk the wing: every chamber, in the order it grew
local W = sg.kit().walk.alien
local seen, looks = 0, {}
for _, a in ipairs(L.areas) do
  if a.kind == "chamber" then
    local c = sg.center(a)
    -- stand clear of the chamber's furniture: its doorway's inside is always free
    local d = a.door_at
    local tx, tz = c[1], c[2]
    if not sg.free(L, tx, tz) then tx, tz = (c[1] + d[1]) / 2, (c[2] + d[2]) / 2 end
    T.assert(ap.foot_to(T, 1, get, tx, tz, 0.8, 4000, true), "walked into the " .. a.name)
    local here = visit.area(T.state(), get())
    T.assert(here.id == a.id, "standing in the " .. a.name .. " (" .. tostring(here.name) .. ")")
    T.assert(a.name == W.names[fam][a.alien], "named by the family")
    seen = seen + 1
    looks[a.alien] = true
  end
end
T.assert(seen == L.wing, "walked all " .. seen .. " chambers")
local nlooks = 0
for _ in pairs(looks) do nlooks = nlooks + 1 end
T.assert(nlooks >= 4, "at least four kinds of chamber (" .. nlooks .. ")")

-- on to the far hangar (in the first pod, out on the hull), unfold and fly out of the pod's mouth
local far = sg.hangars(L)[2]
T.assert(far, "a second hangar")
T.assert(ap.foot_to(T, 1, get, far.pad[1], far.pad[2] + 3, 0.6, 6000, true), "walked to the far hangar")
T.assert(visit.area(T.state(), get()) == far, "standing in the far hangar")
T.press(1, "size1")
T.wait(1)
T.assert(get().station.coin == "grow" and get().ship.size == 1, "the coin is unfolding into the Villa")
T.assert(ap.wait_until(T, 1, function() return get().mode == "helm" end, 400), "aboard at the helm")
local bay = get().ship.pos
local inside_hull = function(p)
  for _, b in ipairs(sh.world_solids(T.state())) do
    if p[1] > b[1][1] and p[1] < b[2][1] and p[2] > b[1][2] and p[2] < b[2][2] and p[3] > b[1][3] and p[3] < b[2][3] then return true end
  end
  return false
end
T.assert(not inside_hull(bay), "the far bay is clear of the hull's solids")
local away = vec.add(bay, vec.scale(vec.fwd(get().ship.yaw), 200))
T.assert(ap.fly(T, 1, get, away, 6, 3000), "flew out of the pod")
T.assert(not get().docked, "left the station behind")
saucer.log.info("alien: walked " .. seen .. " chambers")
