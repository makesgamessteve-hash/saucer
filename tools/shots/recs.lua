-- SPDX-License-Identifier: MIT
-- Screenshot tour for OpenSpec add-playtest-recs (single player). Run from
-- the folder that should receive shots_recs/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/recs.lua
-- Played for real on command frames; staged: the credits, Fold Core tier and
-- the data core put in the hold (so the shop and the sale warning have
-- something to show). Co-op shots: tools/shots/recs_coop.lua.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local items = require("sim.items")
local galaxy = require("sim.galaxy")
local panel = require("sim.panel")
local get = function() return T.state().players[1] end
local D = "shots_recs/"
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end
local function look_at(q)
  local e = game.viewpoint(get())
  ap.look(T, 1, get, saucer.math.atan2(q[1] - e[1], q[3] - e[3]), ap.pitch_to(e, q), 160)
end
-- move the panel cursor onto the row starting with prefix (no pick)
local function sel_to(prefix)
  for _ = 1, 40 do
    local want = panel.find(T.state(), get(), prefix)
    if not want or get().panel.sel == want then return want end
    T.axis(1, "move_z", -1, 1, true) T.wait(1) T.axis(1, "move_z", 0, 1, true) T.wait(1)
  end
end

T.wait(30)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)

-- 1. the fold warning: a fresh player picks a danger-2 sector
local p = get()
local g = galaxy.generate(T.state().seed)
local target
for _, s in ipairs(g.sectors) do
  if s.danger >= 2 and galaxy.hops(T.state().seed, T.state().sector_id, s.id) <= galaxy.core(p).hops then target = target or s end
end
if not target then
  p.fold_tier = 2
  for _, s in ipairs(g.sectors) do
    if s.danger >= 2 and galaxy.hops(T.state().seed, T.state().sector_id, s.id) <= galaxy.core(p).hops then target = target or s end
  end
end
p.credits = 20
T.press(1, "map")
T.wait(2)
T.assert(ap.pick(T, 1, get, target.name), "map row " .. target.name)
T.wait(4)
T.assert(get().panel and get().panel.kind == "fold_warn", "fold warning open")
sel_to("Not yet")
shot("02_fold_warning")
ap.pick(T, 1, get, "Not yet")
T.wait(2)

-- 2. the trader: upgrades on the terminal and the story-item sale warning
local tp = T.state().sector.trader.pos
ap.travel(T, 1, get, { tp[1] + 50, tp[2], tp[3] + 50 }, 6, 6000)
T.wait(20)
p = get()
p.credits, p.fold_tier = 900, 2
p.hold[#p.hold + 1] = items.stamp(p, { type = "core", name = "Data core", home = { kind = "program", id = "beach" }, value = 30 }, 2)
ap.walk_to_station(T, 1, get, "trade")
T.press(1, "use")
T.wait(2)
T.assert(ap.pick(T, 1, get, "Upgrade Helm beam relay"), "bought the relay")
T.wait(4)
sel_to("Upgrade Hold racks")
shot("01_upgrades_shop")
T.assert(ap.pick(T, 1, get, "Sell Data core"), "sell row")
T.wait(4)
sel_to("CONFIRM: sell")
shot("06_sell_warning")
ap.pick(T, 1, get, "Close")
T.wait(2)

-- 3. a Villa in a Watcher's hall: the first lock brings the Seat tip; the HUD stack at 1280x720
ap.take_helm(T, 1, get)
local site = 2
local ruin, origin = game.ruin(site), T.state().sector.sites[site].pos
local w
for i, d in ipairs(game.sentries(site)) do if d.kind == "watcher" and not w then w = i end end
T.assert(w, "a Watcher at site 2")
local wdef = game.sentries(site)[w]
ap.travel(T, 1, get, ap.route(ruin, origin, wdef.room)[1].pos, 4, 6000)
-- fly in waypoint by waypoint, so the shot lands right after the first lock
local function tipped() return get().hints and get().hints.seat ~= nil end
for _, wp in ipairs(ap.route(ruin, origin, wdef.room)) do
  for _ = 1, 40 do
    if tipped() or ap.fly(T, 1, get, wp.pos, wp.tol or 2, 30) then break end
  end
  if tipped() then break end
end
ap.wait_until(T, 1, tipped, 3000)
T.wait(20)
shot("03_seat_hint")
T.wait(240)
shot("04_hud_alerts_1280x720")
print("recs tour done")
