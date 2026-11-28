-- SPDX-License-Identifier: MIT
-- add-home-layout: before/after shots of the Villa with furniture moved.
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script this
-- Optional script-arg: a directory to write PNGs into (default shots_interior/p1).
local T = saucer.test
local ap = require("sim.autopilot")
local avatar = require("sim.avatar")
local layout = require("sim.layout")
local homeedit = require("sim.homeedit")
local decor = require("sim.decor")
local R = require("view.render")
local hud = require("view.hud")
local sm = saucer.math
local free
local show_hud = false
local orig_cam = R.camera
R.camera = function(p, xr) if free then return free end return orig_cam(p, xr) end
local orig_hud = hud.draw
hud.draw = function(...)
  if show_hud then return orig_hud(...) end
  return nil
end

local function p1() return T.state().players[1] end
local D = ((T.arg and T.arg()) or "shots_interior/p1")
if D:sub(-1) ~= "/" then D = D .. "/" end

local function world(p, lx, ly, lz)
  local e = avatar.rot(p.ship.yaw, { lx, ly, lz })
  return { p.ship.pos[1] + e[1], p.ship.pos[2] + e[2], p.ship.pos[3] + e[3] }
end

local function look_local(p, from, to, fov)
  local a, b = world(p, from[1], from[2], from[3]), world(p, to[1], to[2], to[3])
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  free = { pos = a, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)),
           fov = fov or 62, near = 0.15, far = 80 }
end

local function shot(name, wait)
  T.wait(wait or 36)
  T.screenshot(D .. name .. ".png")
  saucer.log.info("home_layout: " .. name)
  T.wait(1)
end

local ctx = { msg = function() end, fx = function() end }

T.wait(10)
ap.wake(T, 1, p1)
local p = p1()
-- park the Villa in open space so the dome looks out on the stars
p.ship.pos, p.ship.vel, p.ship.yaw, p.ship.pitch, p.ship.bank = { 0, 80, 0 }, { 0, 0, 0 }, 0, 0, 0
p.mode, p.panel = "walk", false
p.body = avatar.new(layout.base(), { -3.2, 0.6, 1.5 }, 3.5)
T.wait(4)

-- before: default living room, looking from the helm toward the sofa
look_local(p, { 0.6, 2.4, 5.4 }, { -5.6, 1.3, -0.4 }, 62)
shot("01_living_before")

-- before: kitchen and island
look_local(p, { 1.4, 2.3, 0.2 }, { 6.4, 1.3, -0.2 }, 62)
shot("02_kitchen_before")

-- rearrange: slide the sofa along the wall, shift the armchair, park a stool
local sofa = layout.home_pose("sofa")
layout.set_move(p, "sofa", { deck = 1, x = -5.2, z = 0.8, turn = 6, w = sofa.w, d = sofa.d })
local chair = layout.home_pose("armchair")
layout.set_move(p, "armchair", { deck = 1, x = -6.6, z = -3.2, turn = 12, w = chair.w, d = chair.d })
local plant = layout.home_pose("plant_lr")
layout.set_move(p, "plant_lr", { deck = 1, x = -2.6, z = 3.4, turn = 0, w = plant.w, d = plant.d })
local stool = layout.home_pose("stool_a")
layout.set_move(p, "stool_a", { deck = 1, x = 2.4, z = -2.6, turn = 3, w = stool.w, d = stool.d })
-- a bought lamp in the living room
decor.ensure(p).store.lamp = 1
decor.ensure(p).next_id = 1
p.decor.placed[#p.decor.placed + 1] = { id = 1, kind = "lamp", deck = 1, x = -3.2, z = 2.6, q = 0, turn = 0 }
p.decor.store.lamp = nil
T.wait(8)

look_local(p, { 0.6, 2.4, 5.4 }, { -5.6, 1.3, -0.4 }, 62)
shot("03_living_after")

look_local(p, { 1.4, 2.3, 0.2 }, { 6.4, 1.3, -0.2 }, 62)
shot("04_kitchen_after")

-- edit-mode ghost: carry a stool and hold a green box over the open living-room floor
p.body = avatar.new(layout.of(p), { -1.2, 0.6, 3.6 }, math.pi)
homeedit.enter(T.state(), p, ctx)
homeedit.pick_now(T.state(), p, ctx, { typ = "builtin", id = "stool_a" })
show_hud = true
look_local(p, { 0.8, 2.3, 5.4 }, { -2.4, 0.7, 1.2 }, 60)
shot("05_edit_ghost", 48)
show_hud = false

-- a close look at the sofa in its new place, from the holotable
look_local(p, { -4.6, 1.8, 1.6 }, { -7.4, 1.1, -0.2 }, 55)
shot("06_sofa_close")

saucer.log.info("home_layout: done")
