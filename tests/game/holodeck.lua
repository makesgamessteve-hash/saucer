-- SPDX-License-Identifier: MIT
-- Milestone 4: holodeck and home life. Run the beach and the Seat flight
-- course on the holodeck, loot the tutorial vault (a data core, a log, alien
-- spice), decode the core at the lab, run the derelict replay and the decoded
-- alien memory, read the log on the bookshelf, get a hint from the TV, cook a
-- spiced meal for a buff, then buy a holodeck module at the trader and
-- install it. (A mod adding a program is tests/game/mods.lua.)
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local avatar = require("sim.avatar")
local holo = require("sim.holo")
local books = require("sim.books")
local buffs = require("sim.buffs")
local items = require("sim.items")
local L = avatar.layout()
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end
local function use()
  T.press(1, "use")
  T.wait(1)
end
local function to_arch_and_out()
  local a = holo.arch(holo.scene(T.state(), get(), get().holo_run).size)
  T.assert(ap.holo_walk(T, 1, get, a[1], a[2] + 0.4), "walked back to the exit arch")
  T.assert(holo.hint(T.state(), get()) == "USE: EXIT THE PROGRAM", "the arch hint")
  use()
  T.assert(not get().holo_run and avatar.room(L, get().body) == "Holodeck", "back in the holodeck room")
end
local function panel_at(node, kind)
  T.assert(ap.walk_to_station(T, 1, get, node), "walked to the " .. node)
  use()
  T.assert(get().panel and get().panel.kind == kind, "the " .. node .. " opens its panel")
end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(#books.ensure(get()) == 1, "the shelf starts with the owner's manual")

-- 1. the holodeck room: run Sunset Beach and lie back in the deck chair
panel_at("holodeck", "holodeck")
T.assert(avatar.room(L, get().body) == "Engine room", "the panel is on the engine-room side of the arch")
T.assert(require("sim.panel").find(T.state(), get(), "Run Resonant Memory") == nil, "loot programs start locked")
T.assert(ap.pick(T, 1, get, "Run Sunset Beach"), "ran Sunset Beach")
T.assert(get().holo_run and get().holo_run.id == "beach", "inside the beach program")
T.assert(ap.holo_walk(T, 1, get, 0.6, 0.2), "walked to the deck chair")
T.assert(holo.hint(T.state(), get()):find("DECK CHAIR", 1, true), "the chair hint")
use()
T.assert(buffs.active(T.state(), get(), "calm"), "Calm from the beach")
to_arch_and_out()

-- 2. the Seat flight course: fly every ring, the first clear pays a bonus
local c0 = get().credits or 0
panel_at("holodeck", "holodeck")
T.assert(ap.pick(T, 1, get, "Run Seat Flight Course"), "ran the flight course")
T.assert(get().holo_run.craft, "sitting in a simulated Seat")
T.assert(ap.holo_course(T, 1, get), "flew the whole course")
T.assert(said("Course clear"), "course clear message")
T.assert(get().credits == c0 + 25, "the training bonus")
T.assert(get().holo.best.seat_course, "best time saved")
use()
T.assert(not get().holo_run, "Use ends the flight run")

-- 3. loot the tutorial vault: a data core, a captain's log and alien spice
T.assert(ap.take_helm(T, 1, get), "took the helm")
local st = T.state()
local origin, ruin = st.sector.sites[1].pos, game.ruin(1)
local vault
for _, r in ipairs(ruin.rooms) do if r.kind == "vault" then vault = r end end
local ok, route = ap.enter(T, 1, get, ruin, origin, vault.id)
T.assert(ok, "flew into the vault")
local door = ap.door_center(ap.door_of(ruin, vault.id), ruin.rooms, require("sim.ruin").kit_of(ruin.kit), origin)
local got = ap.grab(T, 1, get, 1, ruin, vault.id, door)
local core
for _, it in ipairs(get().hold) do if it.home and it.home.kind == "program" then core = it end end
T.assert(core and items.label(core) == "Data core (undecoded)", "a data core in the hold (" .. got .. " grabbed)")
T.assert(ap.leave(T, 1, get, route), "flew back out")
T.assert(books.has(get(), "velari_log"), "banking shelved the captain's log")
T.assert((get().pantry.velari_spice or 0) >= 1, "and stocked the Velari spice")
T.assert(get().trails["1"] and #get().trails["1"].pts > 2, "the route was recorded for the replay")

-- 4. decode the data core at the lab bench
panel_at("lab", "lab")
T.assert(ap.pick(T, 1, get, "Decode Data core"), "queued the core")
T.assert(ap.pick(T, 1, get, "Close"), "closed the lab")
T.assert(ap.wait_until(T, 1, function() return holo.has(get(), "memory") end, 60 * 40), "decoded: Resonant Memory")

-- 5. two more programs: the derelict replay and the alien memory
panel_at("holodeck", "holodeck")
T.assert(ap.pick(T, 1, get, "Run Derelict Replay: site 1"), "ran the replay of site 1")
local sz = holo.scene(T.state(), get(), get().holo_run).size
T.assert(ap.holo_walk(T, 1, get, 0, -math.min(2.6, sz * 0.4) - 0.2), "walked up to the plinth")
use()
T.assert(said("Replay"), "the replay log reads out")
to_arch_and_out()
panel_at("holodeck", "holodeck")
T.assert(ap.pick(T, 1, get, "Run Resonant Memory"), "ran the decoded memory")
local spot
for _, s in ipairs(holo.scene(T.state(), get(), get().holo_run).spots) do if s.id == "memory" then spot = s end end
T.assert(ap.holo_walk(T, 1, get, spot.at[1], spot.at[2] - 0.6), "walked to the obelisk")
use()
T.assert(books.has(get(), "memory"), "the memory is on the shelf")
local lead = books.next_echo_site(T.state().mystery)
T.assert(lead and get().leads[tostring(lead)], "the memory points at site " .. tostring(lead))
to_arch_and_out()

-- 6. read the found log on the bookshelf
panel_at("books", "books")
T.assert(ap.pick(T, 1, get, "Read Velari captain's log"), "opened the captain's log")
T.assert(get().reading and get().reading.id == "velari_log", "reading")
for _ = 1, 6 do if get().reading then use() end end
T.assert(not get().reading, "read to the end and closed it")
T.assert(said("A lead"), "the clue gave a lead")

-- 7. the TV picks up the nearest station and gives a hint
panel_at("tv", "tv")
T.assert(ap.pick(T, 1, get, "Watch"), "switched on the TV")
T.assert(get().tv and get().last_hint, "a hint from the TV: " .. tostring(get().last_hint))
T.wait(30)
ap.hold(T, 1, { move_z = 1 })
T.wait(2)
T.assert(not get().tv, "got up from the sofa")

-- 8. cook spiced noodles from trader noodles and alien spice
panel_at("kitchen", "kitchen")
T.assert(ap.pick(T, 1, get, "Cook Ember-spiced noodles"), "cooking the spiced noodles")
T.assert(ap.wait_until(T, 1, function() return not get().cooking end, 400), "the meal is ready")
T.assert(buffs.active(T.state(), get(), "keen") and buffs.active(T.state(), get(), "fed"), "keen and well fed")

-- 9. buy a holodeck module at the trader and install it
T.assert(ap.take_helm(T, 1, get), "back at the helm")
local tp = st.sector.trader.pos
T.assert(ap.travel(T, 1, get, { tp[1] + 50, tp[2], tp[3] + 50 }, 6, 6000), "flew to the trader")
T.assert(get().docked == 1, "docked")
panel_at("trade", "trade")
for _ = 1, 8 do
  if (get().credits or 0) >= 70 then break end
  local sold = false
  for _, it in ipairs(get().hold) do
    if items.sellable(it) and not sold then sold = ap.pick(T, 1, get, "Sell " .. items.label(it)) end
  end
  if not sold then break end
end
T.assert((get().credits or 0) >= 70, "afford the emitter array (" .. tostring(get().credits) .. " c)")
T.assert(ap.pick(T, 1, get, "Buy Holo emitter array"), "bought the emitter array")
T.assert(ap.pick(T, 1, get, "Close"), "closed the terminal")
panel_at("holodeck", "holodeck")
T.assert(ap.pick(T, 1, get, "Install Holo emitter array"), "installed it")
T.assert(holo.level(get(), "size") == 10, "the holodeck has more space")
T.assert(ap.pick(T, 1, get, "Close"), "closed the holodeck panel")
print(string.format("holodeck: runs %d best %.1f s shelf %d meals %d credits %d", get().holo.runs,
  get().holo.best.seat_course, #get().shelf, get().meals or 0, get().credits or 0))
