-- SPDX-License-Identifier: MIT
-- Story screenshots (OpenSpec add-run-story). Run from the folder that should receive shots_story/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/story.lua
-- 1. a clue in its hall, 2. the beat: the clue read (log, lead), 3. the Story page at the holotable,
-- 4. the same page after the second clue.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local story = require("sim.story")
local tractor = require("sim.tractor")
local get = function() return T.state().players[1] end
local function shot(name) T.wait(4) T.screenshot("shots_story/" .. name .. ".png") T.wait(1) end

T.wait(10)
ap.wake(T, 1, get)
local st = T.state()
local ruin, origin = game.ruin(1), st.sector.sites[1].pos
local cand
for _, c in ipairs(tractor.candidates(st, get(), 1, ruin)) do if c.kind == "story" then cand = c end end
T.assert(cand, "a clue in the first derelict")
print("story:", T.state().story.title)
ap.take_helm(T, 1, get)
local ok, route = ap.enter(T, 1, get, ruin, origin, cand.room, nil)
T.assert(ok, "in the hall")
do -- stage the Villa a few metres off the clue, facing it
  local sh = get().ship
  sh.pos, sh.vel, sh.yaw, sh.pitch, sh.bank = { cand.pos[1], cand.pos[2] + 1, cand.pos[3] - 13 }, { 0, 0, 0 }, 0, 0, 0
  T.wait(30)
end
shot("01_clue_in_the_world")
T.assert(ap.beam_up(T, 1, get, cand), "beamed")
shot("02_story_beat")
if get().beam_console then ap.back_to_helm(T, 1, get) end
-- the second clue is read the same way by staging, so the page has two found
story.read(T.state(), 2, get(), game.ctx)
ap.leave(T, 1, get, route)
ap.take_helm(T, 1, get)
ap.resize(T, 1, get, 1)
ap.walk_to_station(T, 1, get, "holotable")
T.press(1, "use")
shot("03_codex_page")
