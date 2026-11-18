-- SPDX-License-Identifier: MIT
-- Saves, part 1 (run before saves_load.lua in the same user dir): one player
-- earns some credits, picks up a hold item, sleeps in the bed (seed plus
-- diffs) and the save file is checked for what it holds and does not hold.
local T = saucer.test
local ap = require("sim.autopilot")
local save = require("sim.save")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end

T.assert(ap.pick(T, 1, get, "Get up"), "got up")
get().credits = 420
get().hold[1] = { uid = 1, name = "Test Coil", value = 30, hot = true }
get().next_uid = 1
T.assert(ap.walk_to(T, 1, get, "bed"), "walked to the bed")
T.press(1, "use")
T.wait(1)
T.assert(ap.pick(T, 1, get, "Sleep"), "picked sleep")
T.assert(said("Game saved"), "sleeping saves")

local rec = save.read()
T.assert(rec and rec.format == 3 and rec.seed == 42, "the save is format 3 and holds the seed")
T.assert(#rec.players == 1 and rec.players[1].record_index == 0, "one record, record 0")
T.assert(next(rec.world.diff) == nil or rec.world.diff.d.clock, "the world diff holds only what changed")
T.assert(rec.sector == nil and rec.world.sector == nil, "no generated geometry in the save")
local mine = save.player(rec, 1)
T.assert(mine.credits == 420 and mine.hold[1].name == "Test Coil" and mine.hold[1].hot, "credits and the hot hold item are kept")
