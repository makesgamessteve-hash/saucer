-- SPDX-License-Identifier: MIT
-- Screenshot tour for milestone 4 (OpenSpec add-holodeck-home-life). Run from
-- the folder that should receive shots_m4/:
--   saucer --root REPO --seed 42 --windowed --script REPO/tools/shots/m4.lua
-- The holodeck, cooking, the bookshelf and the TV are used for real through
-- their panels. Staged: the decoded alien memory and the loot (spice, the
-- captain's log) are given directly instead of looting the vault first.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local holo = require("sim.holo")
local books = require("sim.books")
local kitchen = require("sim.kitchen")
local get = function() return T.state().players[1] end
local D = "shots_m4/"
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local function use() T.press(1, "use") T.wait(1) end
local function face(x, z, pitch)
  local b = get().body
  ap.look(T, 1, get, saucer.math.atan2(x - b.pos[1], z - b.pos[3]), pitch or 0, 240)
end
local function holo_face(x, z, pitch)
  local hg = function() return { mode = "walk", body = get().holo_run.body } end
  local b = get().holo_run.body
  ap.look(T, 1, hg, saucer.math.atan2(x - b.pos[1], z - b.pos[3]), pitch or 0, 240)
end
local function run(prefix)
  ap.walk_to_station(T, 1, get, "holodeck")
  use()
  ap.pick(T, 1, get, prefix)
  T.wait(10)
end
local function out()
  local a = holo.arch(holo.scene(T.state(), get(), get().holo_run).size)
  ap.holo_walk(T, 1, get, a[1], a[2] + 0.4)
  use()
end
local SHOTS = nil -- e.g. "02 03" while iterating
local function want(n) return not SHOTS or SHOTS:find(n, 1, true) end

T.wait(30)
ap.wake(T, 1, get)
-- staged loot
holo.unlock(get(), "memory")
kitchen.stock(get(), "velari_spice", 2)
books.add(get(), "velari_log")

-- 1. the holodeck room through its arch, from the engine room
if want("01") then
  ap.walk_to(T, 1, get, "holo_arch")
  ap.walk(T, 1, get, { 1.5, 0, -3.3 }, 0.2)
  face(8, -1.4, -0.02)
  T.wait(400)
  shot("01_holodeck_room")
end
-- 2. Sunset Beach, from the deck chair
if want("02") then
  run("Run Sunset Beach")
  ap.holo_walk(T, 1, get, -0.4, -1.2)
  holo_face(1.2, 6, 0.08)
  shot("02_program_beach")
  out()
end
-- 3. the Seat flight course, mid-run
if want("03") then
  run("Run Seat Flight Course")
  local sc = holo.scene(T.state(), get(), get().holo_run)
  local craft = function() return { ship = get().holo_run.craft } end
  for i = 1, 2 do local g = sc.gates[i] ap.fly(T, 1, craft, { g[1], g[2], g[3] }, 0.8, 900) end
  local g = sc.gates[3]
  for _ = 1, 30 do ap.hold(T, 1, (ap.steer(get().holo_run.craft, { g[1], g[2], g[3] }))) end
  shot("03_program_seat_course")
  use()
end
-- 4. the decoded alien place, at the memory
if want("04") then
  run("Run Resonant Memory")
  ap.holo_walk(T, 1, get, 0.8, -2.6)
  holo_face(0, 0.8, 0.18)
  shot("04_program_memory")
  ap.holo_walk(T, 1, get, 0.3, -1.4, 0.2)
  holo_face(0, 0.8, 0.35)
  use()
  T.wait(30)
  shot("05_memory_touched")
  out()
end
-- 6. cooking ember-spiced noodles at the stove
if want("06") then
  ap.walk_to_station(T, 1, get, "kitchen")
  use()
  ap.pick(T, 1, get, "Cook Ember-spiced noodles")
  T.wait(90)
  shot("06_cooking")
  T.wait(120)
end
-- 7. reading the captain's log at the bookshelf
if want("07") then
  ap.walk_to_station(T, 1, get, "books")
  use()
  ap.pick(T, 1, get, "Read Velari captain's log")
  T.wait(20)
  shot("07_bookshelf_reading")
  for _ = 1, 6 do if get().reading then use() end end
end
-- 8. the TV on the sofa
if want("08") then
  ap.walk_to_station(T, 1, get, "tv")
  use()
  ap.pick(T, 1, get, "Watch")
  T.wait(60)
  shot("08_tv")
end

