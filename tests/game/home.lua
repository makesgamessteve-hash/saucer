-- SPDX-License-Identifier: MIT
-- Milestone 2: living in the Villa. Wake up to the title card, walk through a
-- sliding door, cook in the kitchen, check the engine and the lab bench,
-- sleep in the bed (which saves), then wander off and load the save back.
local T = saucer.test
local ap = require("sim.autopilot")
local avatar = require("sim.avatar")
local home = require("sim.home")
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

-- wake-up title card
T.assert(get().mode == "wake" and get().panel.kind == "title", "wakes up to the title card")
T.assert(said("wake up"), "wake-up message")
T.assert(ap.pick(T, 1, get, "Get up"), "picked Get up")
T.assert(get().mode == "walk" and not get().panel, "standing beside the bed")
T.assert(avatar.room(L, get().body) == "Bedroom", "in the bedroom")

-- the bedroom door is closed until someone walks up to it, and is solid while closed
T.assert(get().doors[1] == 0, "bedroom door closed")
T.assert(#home.solids(L, get()) == #L.doors, "closed doors are solid")
T.assert(ap.walk_to(T, 1, get, "bed_door_n"), "walked to the bedroom door")
T.wait(20)
T.assert(get().doors[1] == 1, "the door slid open")
T.assert(#home.solids(L, get()) == #L.doors - 1, "an open door can be walked through")
T.assert(ap.walk_to(T, 1, get, "engine"), "walked through it to the engine room")
T.assert(avatar.room(L, get().body) == "Engine room", "in the engine room")
T.wait(150)
T.assert(get().doors[1] == 0, "the door closed behind")

-- fix-bedroom-door: stand and dither on the door's trigger edge (as a thumb on a touch
-- stick does): the leaf must open once and stay put, never jitter or flap
do
  local reach = L.doors[1].reach
  local cx, cz = home.door_center(L.doors[1])
  T.assert(ap.walk(T, 1, get, { cx, L.decks[2].floor, cz - reach - 0.4 }, 0.1, 600), "walked to the door's trigger edge")
  -- face the door (yaw 0 looks along +z) and creep up until it just triggers
  for _ = 1, 200 do
    local b = get().body
    if math.abs(saucer.math.wrap(b.yaw)) < 0.01 then break end
    ap.hold(T, 1, { turn = (saucer.math.wrap(b.yaw) > 0) and 0.3 or -0.3 })
  end
  T.assert(get().door_goal == nil or get().door_goal[1] == 0, "the door waits while the body is outside its reach")
  for _ = 1, 600 do
    if get().door_goal and get().door_goal[1] == 1 then break end
    ap.hold(T, 1, { move_z = 0.1 })
  end
  T.assert(get().door_goal and get().door_goal[1] == 1, "creeping up triggers the door at its reach")
  local turns, dir, last, solid_flips, solid = 0, 0, get().doors[1], 0, nil
  local function sample()
    local d = get().doors[1]
    local nd = d > last and 1 or d < last and -1 or 0
    if nd ~= 0 and dir ~= 0 and nd ~= dir then turns = turns + 1 end
    if nd ~= 0 then dir = nd end
    last = d
    local s = d < L.door_solid_below
    if solid ~= nil and s ~= solid then solid_flips = solid_flips + 1 end
    solid = s
  end
  for i = 1, 600 do
    -- creep in and out across the open radius: about 5 mm per tick, 3 ticks each way
    local fwd = ((i // 3) % 2 == 0) and 0.1 or -0.1
    if i > 300 then fwd = 0 end
    ap.hold(T, 1, { move_z = fwd })
    sample()
  end
  T.assert(get().doors[1] == 1, "the door is open for the body on its edge")
  print("door at the edge: direction reversals", turns, "solid flips", solid_flips, "open", get().doors[1])
  T.assert(turns <= 2, "the door did not flap at the trigger edge")
  T.assert(solid_flips <= 2, "the door's collision did not flap either")
  T.assert(get().doors[1] == 1 or get().doors[1] == 0, "the leaf rests fully open or shut")
  for _ = 1, 60 do T.wait(1); T.assert(get().doors[1] == last, "a body standing still leaves the door where it is") end
end

-- engine console
T.assert(ap.walk_to(T, 1, get, "engine"), "back to the engine console")
use()
T.assert(said("Fold engine: Charge"), "engine console reads out Charge")

-- kitchen: cook a meal, Charge recharges faster for a while
T.assert(ap.walk_to(T, 1, get, "kitchen"), "walked up to the kitchen")
use()
T.assert(get().panel and get().panel.kind == "kitchen", "the stove opens the galley")
T.assert(ap.pick(T, 1, get, "Cook Quick snack"), "picked a quick snack")
T.assert(get().cooking, "cooking at the stove")
T.wait(200)
T.assert(said("quick meal") and home.fed(T.state(), get()), "cooked a meal, well fed")
T.assert(home.regen_factor(T.state(), get()) > 1, "faster regen while fed")

-- lab bench and trade terminal are places to go
T.assert(ap.walk_to(T, 1, get, "lab"), "walked to the lab bench")
use()
T.assert(get().panel and get().panel.kind == "lab", "the lab bench opens its panel")
T.assert(ap.pick(T, 1, get, "Close"), "closed the lab panel")
T.assert(ap.walk_to(T, 1, get, "trade"), "walked to the trade terminal")
use()
T.assert(said("No trader in range"), "trade terminal needs a trader")

-- bed: sleep until morning, which refills Charge and saves the game
T.assert(ap.walk_to(T, 1, get, "bed"), "walked back down to the bed")
use()
T.assert(get().panel and get().panel.kind == "bed", "bed panel open")
T.assert(ap.pick(T, 1, get, "Close"), "closed it")
T.assert(not get().panel, "closed")
use()
T.assert(ap.pick(T, 1, get, "Sleep"), "picked sleep")
T.assert(said("Game saved"), "sleeping saves")
local saved_tick = T.state().tick
local saved_pos = { get().body.pos[1], get().body.pos[2], get().body.pos[3] }
T.assert(get().sleeps == 1, "slept once")

-- wander off, then load the save from the bed
T.assert(ap.walk_to(T, 1, get, "engine"), "walked away")
T.assert(ap.walk_to(T, 1, get, "bed"), "and back")
use()
T.assert(ap.pick(T, 1, get, "Load"), "picked load")
T.assert(said("Loaded the save"), "loaded")
T.assert(T.state().tick == saved_tick, "the clock is back at the save")
for k = 1, 3 do T.assert(math.abs(get().body.pos[k] - saved_pos[k]) < 1e-9, "body back where it slept") end
T.assert(get().sleeps == 1 and get().mode == "walk", "player record restored")
T.wait(10)
T.assert(T.state().tick == saved_tick + 10, "the sim runs on after loading")
