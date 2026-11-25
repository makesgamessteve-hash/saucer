-- SPDX-License-Identifier: MIT
-- add-run-story, slice 2: the first clue of the run's story, end to end. It lies in a great hall of the
-- tutorial derelict as a wreck log or mural: fly the Villa in, beam it up (it is read in place), see it
-- found for the party, filed on the bookshelf and its lead given, then sleep (save) and load: the
-- progress comes back, and the next clue is on offer at its own site.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local story = require("sim.story")
local tractor = require("sim.tractor")
local books = require("sim.books")
-- tune-sentry-economy: the tutorial's light Watcher bites harder now; this test is about something else
require("sim.autopilot").gentle_tutorial()
local get = function() return T.state().players[1] end
local function said(s)
  for _, x in ipairs(get().msgs or {}) do if x.text:find(s, 1, true) then return true end end
  return false
end

T.assert(ap.wake(T, 1, get), "got up")
local st = T.state()
local s = st.story
T.assert(story.active(st), "the story runs with the mystery")
local b1 = s.beats[1]
T.assert(b1.sector == 1 and b1.site == 1, "the first clue is in the tutorial derelict")
local ruin, origin = game.ruin(1), st.sector.sites[1].pos
local cand
for _, c in ipairs(tractor.candidates(st, get(), 1, ruin)) do if c.kind == "story" then cand = c end end
T.assert(cand ~= nil and cand.story == 1, "the first clue is a beam target at site 1")
T.assert(tractor.candidates(st, get(), 2, game.ruin(2))[1] == nil or tractor.candidates(st, get(), 2, game.ruin(2))[1].kind ~= "story",
  "the second clue is not on offer yet")

-- fly the Villa into its hall and beam it
T.assert(ap.take_helm(T, 1, get), "at the helm")
local ok, route = ap.enter(T, 1, get, ruin, origin, cand.room, nil)
T.assert(ok, "flew into the hall that holds the clue")
T.assert(ap.beam_up(T, 1, get, cand), "beamed the clue up")
if get().beam_console then ap.back_to_helm(T, 1, get) end
b1 = T.state().story.beats[1] -- (a restore replaces the tables)
st, s = T.state(), T.state().story
T.assert(b1.found_by == 1 and b1.tick > 0, "the clue is found, by player 1")
T.assert(said("STORY 1/" .. story.clue_count(s)), "the log says which clue it was")
T.assert(books.has(get(), "story:1") ~= nil, "it is on the bookshelf")
local page = books.resolve(st, "story:1")
T.assert(page.kind == "clue" and #page.pages >= 1, "and can be read there")
T.assert(#get().hold == 0 or get().hold[#get().hold].type ~= "story", "nothing rides in the hold: it is read in place")
T.assert(story.next_clue(s) == 2, "the next clue is now the one to find")
for _, c in ipairs(tractor.candidates(st, get(), 1, ruin)) do T.assert(c.kind ~= "story", "the found clue is gone from its hall") end
T.assert(ap.leave(T, 1, get, route), "back out of the derelict")
T.screenshot("story_clue_read.png")

-- sleep (saves), load: the progress is kept
T.assert(ap.take_helm(T, 1, get), "at the helm")
T.assert(ap.resize(T, 1, get, 1), "the Villa")
T.assert(ap.walk_to_station(T, 1, get, "bed"), "walked to the bed")
T.press(1, "use")
T.wait(1)
T.assert(ap.pick(T, 1, get, "Sleep until morning"), "slept")
T.wait(5)
b1 = T.state().story.beats[1]
T.assert(b1.found_by == 1, "still found after sleeping")
T.press(1, "use")
T.wait(1)
T.assert(ap.pick(T, 1, get, "Load saved game"), "loaded the save")
T.wait(5)
T.assert(T.state().story.beats[1].found_by == 1 and T.state().story.beats[1].tick == b1.tick, "the load put the progress back")
T.assert(story.next_clue(T.state().story) == 2, "and the next clue is still the second")
T.assert(books.has(T.state().players[1], "story:1") ~= nil, "with its page on the shelf")

-- the holotable: walk to it, use it, the Story page lists the clue and where the next one is
T.assert(ap.walk_to_station(T, 1, get, "holotable"), "walked to the holotable")
T.press(1, "use")
T.wait(1)
T.assert(get().panel and get().panel.kind == "story", "the Story page opened")
T.screenshot("story_codex.png")
T.assert(ap.pick(T, 1, get, "1 "), "opened the first clue from the page")
T.assert(get().reading and get().reading.id == "story:1", "and it reads again")
T.screenshot("story_codex_read.png")
