-- SPDX-License-Identifier: MIT
-- Saves, part 2 (run with --local-players 2 after saves_write.lua): the
-- single-player save is loaded from the title card of a two-player game.
-- Record 0 comes back unchanged and record 1 starts with a starter saucer.
local T = saucer.test
local ap = require("sim.autopilot")
local get = function(i) return T.state().players[i or 1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end

T.assert(#T.state().players == 2, "two local players")
T.assert(get().panel and get().panel.kind == "title", "the title card is up")
T.assert(ap.pick(T, 1, get, "Load"), "picked Load saved game")
T.assert(said("Loaded the save"), "loaded")
T.assert(#T.state().players == 2, "still two players")
T.assert(get(1).record_index == 0 and get(1).credits == 420, "record 0 keeps its credits")
T.assert(get(1).hold[1] and get(1).hold[1].name == "Test Coil" and get(1).hold[1].hot, "and its hot hold item")
T.assert(get(2).record_index == 1 and get(2).credits == 0 and #get(2).hold == 0, "record 1 is new and empty")
T.assert(get(2).ship.size == 1 and get(2).mode == "wake", "with a starter saucer, waking up")
T.wait(30)
T.assert(get(1).credits == 420, "the sim runs on")
