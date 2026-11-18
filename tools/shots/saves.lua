-- SPDX-License-Identifier: MIT
-- Screenshot tour for the Saves group (OpenSpec add-save-system). Run from the
-- folder that should receive the shots (it writes shots/):
--   xvfb-run -a saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --local-players 2
--          --viewports 2 --script REPO/tools/shots/saves.lua
-- A one-player universe with some credits is saved (seed plus diffs), then
-- player 1 loads it from the title card of a two-player game: record 0 comes
-- back, record 1 starts with a starter saucer.
local T = saucer.test
local game = require("sim.game")
local save = require("sim.save")
local ap = require("sim.autopilot")
local D = "shots/"
local p1 = function() return T.state().players[1] end
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end

T.wait(10)
-- the single-player universe being saved (built apart from the running game)
local one = {}
game.init(one, { seed = 42, players = 1 })
one.players[1].credits = 1234
one.players[1].sleeps = 3
one.players[1].mode, one.players[1].panel = "walk", false
local rec = save.record(one)
print(string.format("save: %s; world diff keys %d, player diff values %d", save.summary(rec),
  require("sim.diff").size(rec.world.diff), require("sim.diff").size(rec.players[1].diff)))
T.assert(saucer.save.write(save.SLOT, rec), "wrote the save")

shot("01_title_card_two_players")
T.assert(ap.pick(T, 1, p1, "Load"), "picked Load saved game")
T.wait(30)
shot("02_loaded_record0_and_new_record1")
