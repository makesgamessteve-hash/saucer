-- SPDX-License-Identifier: MIT
-- Screenshot tour for the gameplay gaps (OpenSpec add-playtest-recs 5.3-5.5): the trader's shelf of
-- saucer modules, installing one at the lab bench (the HUD's UNKNOWN EFFECT), and the Tractor Room
-- target queue. Run from the folder that should receive shots_gameplay/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/gameplay.lua
-- Played on command frames; staged: credits, an unidentified Unstable module in the hold, the SHOTS selector.
-- Grid consoles: tools/shots/gameplay_grid.lua. Twin spots: tools/shots/gameplay_twin.lua.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local items = require("sim.items")
local panel = require("sim.panel")
local tractor = require("sim.tractor")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local D = "shots_gameplay/"
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
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

-- 1. the trader's shelf: three modules, identified, no quirks
local tp = T.state().sector.trader.pos
ap.travel(T, 1, get, { tp[1] + 50, tp[2], tp[3] + 50 }, 6, 6000)
T.wait(20)
local p = get()
p.credits = 900
ap.walk_to_station(T, 1, get, "trade")
T.press(1, "use")
T.wait(2)
sel_to("Buy module")
shot("01_trader_module_shelf")
T.assert(ap.pick(T, 1, get, "Buy module"), "bought a module")
T.wait(3)
sel_to("Buy module")
shot("02_trader_bought_one")
ap.pick(T, 1, get, "Close")
T.wait(2)
T.assert(#get().hold == 1 and get().hold[1].category == "module", "the module is in the hold")

-- 2. at the lab bench: install it, then a surprise from the hold (an unidentified Unstable module)
p = get()
p.hold[#p.hold + 1] = items.stamp(p, { type = "foldcore", name = "Fold Shard", size = 2, category = "module", value = 140,
  affixes = { { id = "resonant", stat = "shield_regen", value = 25 } }, quirk = "unstable" }, 2, "velari")
ap.walk_to_station(T, 1, get, "lab")
T.press(1, "use")
T.wait(2)
sel_to("Install Unknown")
shot("03_lab_bench_install_rows")
T.assert(ap.pick(T, 1, get, "Install Unknown"), "installed the unknown module")
T.wait(2)
ap.pick(T, 1, get, "Install")
T.wait(2)
sel_to("Identify fitted")
shot("04_lab_bench_fitted")
ap.pick(T, 1, get, "Close")
T.wait(2)
ap.take_helm(T, 1, get)

-- 3. the Tractor Room target queue: queue the long scrap off axis; trim over it and the beam takes it by itself
local st = T.state()
local ruin, origin = game.ruin(1), st.sector.sites[1].pos
local long, vault
for _, c in ipairs(tractor.candidates(st, get(), 1, ruin)) do
  if c.axis and ruin.rooms[c.room].class >= 4 and not long then long = c end
end
for _, r in ipairs(ruin.rooms) do if r.kind == "vault" then vault = r end end
local vroute = ap.route(ruin, origin, vault.id)
local hi
for i, id in ipairs(ap.chain(ruin, vault.id)) do if id == long.room then hi = i end end
local to_hall = {}
for i = 1, 3 * hi do to_hall[#to_hall + 1] = vroute[i] end
T.assert(ap.travel(T, 1, get, vroute[1].pos, 4, 6000), "to the mouth")
T.assert(ap.follow(T, 1, get, to_hall, 1500), "flew the Villa into the hall")
local spot = ap.beam_spot(long.pos, 1)
local wrong = long.axis + 1.05
ap.fly(T, 1, get, spot, 0.3, 1500, { spot[1] + saucer.math.sin(wrong) * 80, spot[2], spot[3] + saucer.math.cos(wrong) * 80 })
ap.wait_until(T, 1, function() return vec.len(get().ship.vel) < 0.2 end, 600)
T.assert(ap.to_console(T, 1, get), "at the console")
T.wait(40)
T.press(1, "tractor")
T.wait(10)
T.assert(get().beam_queue ~= nil, "queued")
shot("06_beam_queue_waiting")
ap.trim_to(T, 1, get, spot, ap.beam_yaw(long, get().ship.yaw))
T.wait(10)
T.assert(get().tractor ~= nil or #get().hold > 1, "the queued find was pulled by itself")
shot("07_beam_queue_pulling")
-- the Unstable module has been eating Charge in here, and the HUD says why
T.wait(240)
T.assert(get().ship.charge < 100, "the Unstable module drained Charge inside the site")
shot("05_hud_unknown_effect")
print("gameplay tour done")
