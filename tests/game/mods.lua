-- SPDX-License-Identifier: MIT
-- Run with --mods-dir tests/fixtures/mods: load order, overrides, bad mods
-- reported (not fatal), and the instruction budget disabling a runaway mod.
local T = saucer.test
local by = {}
for _, m in ipairs(saucer.mods.list()) do by[m.id] = m end
T.assert(by.base and by.base.ok, "base loads")
T.assert(by.bigger_tractor.ok, "content mod loads")
T.assert(by.greedy.ok, "greedy loads (and gets cut off)")
T.assert(not by.bad_api.ok and by.bad_api.status:find("incompatible API"), "API mismatch reported: " .. by.bad_api.status)
T.assert(not by.needs_missing.ok and by.needs_missing.status:find("missing"), "missing dependency reported")
T.assert(not by.cycle_a.ok and by.cycle_a.status:find("cycle"), "cycle reported: " .. by.cycle_a.status)
T.assert(not by.old_dep.ok, "unsatisfied version reported")
T.assert(by.broken_manifest == nil or not by.broken_manifest.ok, "broken manifest skipped")
-- the data override wins over base
T.assert(require("sim.config").get(2).tractor_range == 30, "mod overrides saucer/configs.lua")
T.wait(5)
T.press(1, "use")
T.press(1, "shrink")
T.wait(40)
T.assert(T.state().bigger_tractor.changes == 1, "mod hook saw the size change event")
T.assert(T.state().players[1].ship.size == 2, "base game keeps running")
-- a data-only mod adds a holodeck program (holo/zen_garden.lua), no engine change
local holo = require("sim.holo")
local p = T.state().players[1]
T.assert(by.holo_garden and by.holo_garden.ok, "holodeck mod loads")
T.assert(holo.program("zen_garden") ~= nil, "the mod's program is discovered")
T.assert(holo.has(p, "zen_garden"), "a starter program from a mod is in the library")
local found = false
for _, r in ipairs(holo.rows(T.state(), p, { msg = function() end, fx = function() end })) do
  if r.text == "Run Zen Garden" then found = true end
end
T.assert(found, "the holodeck panel offers it")
T.assert(holo.start(T.state(), p, "zen_garden", nil, { msg = function() end, fx = function() end }), "and it runs")
T.wait(10)
T.assert(p.holo_run and p.holo_run.id == "zen_garden", "inside the mod's program")
