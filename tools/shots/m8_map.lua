-- SPDX-License-Identifier: MIT
-- Milestone 8 sector-map shot, solo so the map graphic has room beside the
-- rows (a split-screen view only lists them). Run like tools/shots/m8.lua.
local T = saucer.test
local ap = require("sim.autopilot")
local get = function() return T.state().players[1] end
T.wait(20)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
T.press(1, "map")
T.wait(3)
T.wait(2)
T.screenshot("shots_m8/02_sector_map.png")
T.wait(1)
