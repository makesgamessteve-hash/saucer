-- SPDX-License-Identifier: MIT
-- Screenshot tour for the decluttered touch controls (OpenSpec
-- declutter-touch-controls): the idle helm (Use, Boost, the stick, the lift,
-- the tray button), the beam's context button with loot lined up, and the
-- tray open. Run (touch layout in CSS px = the window) from the folder that
-- should receive shots_declutter/:
--   saucer --root REPO --seed 42 --windowed --fill --width 568 --height 320 --script REPO/tools/shots/declutter.lua
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local tractor = require("sim.tractor")
local get = function() return T.state().players[1] end
local function size()
  local l = saucer.input.touch_layout()
  return l.css_w, l.css_h
end
local function shot(name)
  T.wait(3)
  local W, H = size()
  T.screenshot(string.format("shots_declutter/%dx%d_%s.png", math.floor(W + 0.5), math.floor(H + 0.5), name))
  T.wait(1)
end
-- a short look drag at the top of the view puts the HUD into touch mode
local function touch_mode()
  T.touch("down", 900, 0.5, 0.12)
  T.wait(1)
  T.touch("move", 900, 0.5 + 1 / size(), 0.12)
  T.wait(1)
  T.touch("up", 900)
  T.wait(2)
end
local function tap(name)
  for _, w in ipairs(saucer.input.touch_layout()) do
    if w.name == name and w.group ~= "tray" then
      T.touch("down", 901, w.x + w.w / 2, w.y + w.h / 2)
      T.wait(2)
      T.touch("up", 901)
      return true
    end
  end
end

local st = T.state()
local ruin = game.ruin(1)
local origin = st.sector.sites[1].pos
T.wait(30)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
touch_mode()
T.wait(30)
shot("01_idle_helm")
-- fly into the first great hall and hover over the long scrap, keel along it
local long, vault
for _, c in ipairs(tractor.candidates(st, get(), 1, ruin)) do
  if c.axis and ruin.rooms[c.room].class >= 4 and not long then long = c end
end
for _, r in ipairs(ruin.rooms) do if r.kind == "vault" then vault = r end end
local vroute = ap.route(ruin, origin, vault.id)
local hi
for i, id in ipairs(ap.chain(ruin, vault.id)) do if id == long.room then hi = i end end
local to_hall = {}
for i = 1, 3 * hi do to_hall[#to_hall + 1] = vroute[i] end
ap.follow(T, 1, get, to_hall, 1500)
ap.hover_over(T, 1, get, long)
ap.look(T, 1, get, get().ship.yaw, -0.6, 240)
touch_mode()
local _, heading = game.viewpoint(get())
local tg = tractor.scan(T.state(), get(), get().site, ruin, heading)
print("declutter: target " .. tostring(tg and tg.status))
T.wait(4) -- the context button's 150 ms fade-in
shot("02_context_beam")
tap("more")
T.wait(12)
shot("03_tray_open")
tap("more")
T.wait(5)
