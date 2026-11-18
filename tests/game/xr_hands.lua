-- SPDX-License-Identifier: MIT
-- add-webxr-cockpit: hand tracking, the constant scale and haptics, end to end
-- through the engine with mocked WebXR poses (there is no headset in CI).
-- Tracked hands drive the same actions as the controllers: pinching the size
-- lever and moving it one detent is a Shrink (or a Grow) in that tick's
-- command frame, a fist is the grip (the map), a pinch is the left trigger
-- (Use). The pilot's eye never moves while the cockpit folds, the eyes stay
-- one IPD apart, and the fold gives exactly one haptic pulse.
local T = saucer.test
local ap = require("sim.autopilot")
local shipm = require("sim.ship")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end

local function hand(ox, oy, oz, pose)
  local j = { wrist = { ox, oy, oz }, thumb = { ox - 0.04, oy, oz + 0.09 }, index = { ox - 0.02, oy, oz + 0.17 },
              middle = { ox, oy, oz + 0.18 }, ring = { ox + 0.02, oy, oz + 0.17 }, pinky = { ox + 0.04, oy, oz + 0.15 } }
  if pose == "pinch" then j.thumb = { j.index[1] + 0.01, j.index[2], j.index[3] } end
  if pose == "fist" then
    for _, k in ipairs({ "middle", "ring", "pinky" }) do j[k] = { ox, oy, oz + 0.05 } end
  end
  return j
end
-- a pinching hand whose pinch point sits on (x, y, z)
local function pinch_at(x, y, z)
  local j = hand(0, 0, 0, "pinch")
  local mx, my, mz = (j.thumb[1] + j.index[1]) / 2, j.index[2], j.index[3]
  for _, v in pairs(j) do v[1], v[2], v[3] = v[1] + x - mx, v[2] + y - my, v[3] + z - mz end
  return j
end
local function lower(j, dy) for _, v in pairs(j) do v[2] = v[2] + dy end return j end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.walk_to(T, 1, get, "helm"), "walked to the helm")
T.assert(ap.take_helm(T, 1, get), "took the helm")
T.assert(get().ship.size == 1 and get().mode == "helm", "flying the Villa")
-- a headset: standing session, two eyes 64 mm apart, head at 1.6 m looking ahead
T.xr({ available = 1, session = 2, head_pos = { 0, 1.6, 0 }, head_fwd = { 0, 0, 1 }, mock_views = true, ipd = 0.064 })
T.wait(5)
local views = saucer.xr.session()
T.assert(views == "standing", "standing session")

local eye0 = shipm.eye_world(get().ship.pos, get().ship.yaw, 1)
local pulses0 = T.xr_haptics()

-- 1. grab the lever by hand and move it one detent toward "smaller"
local lx, ly, lz = table.unpack((saucer.xr.lever()))
local grip = pinch_at(lx, ly, lz)
T.xr({ joints = { right = grip } })
T.wait(2)
local _, held = saucer.xr.lever()
T.assert(held, "the pinch took the lever")
T.assert(get().ship.size == 1 and not get().ship.morph, "grabbing alone folds nothing")
T.xr({ joints = { right = lower(grip, -0.04) } })
T.wait(2)
T.assert(not get().ship.morph, "less than a detent folds nothing")
T.xr({ joints = { right = lower(grip, -0.05) } })
T.wait(2)
T.assert(get().ship.morph and get().ship.size == 2, "one detent down: the Villa folds into the Seat")
-- the fold: head height unchanged for the whole transition, one haptic pulse
local worst = 0
for _ = 1, 100 do
  T.wait(1)
  local eye = shipm.eye_world(get().ship.pos, get().ship.yaw, get().ship.size)
  worst = math.max(worst, vec.len(vec.sub(eye, eye0)))
end
T.assert(not get().ship.morph, "the fold finished")
T.assert(worst < 1e-6, "the pilot's eye stayed put through the fold: " .. worst)
T.assert(T.xr_haptics() == pulses0 + 1, "one haptic pulse for the fold, got " .. (T.xr_haptics() - pulses0))
T.xr({ joints = { right = false } })
T.wait(2)
T.assert(select(2, saucer.xr.lever()) == false, "letting go frees the lever")

-- 2. a fist is the right grip: the sector map
T.xr({ joints = { right = hand(0.3, 1.2, 0.3, "fist") } })
T.wait(3)
T.assert(get().panel and get().panel.kind == "map", "a fist opened the map: " .. tostring(get().panel and get().panel.kind))
T.xr({ joints = { right = hand(0.3, 1.2, 0.3) } })
T.wait(2)
T.assert(ap.pick(T, 1, get, "Close"), "closed the map")
T.xr({ joints = { right = false } })
T.wait(2)

-- 3. and back up one detent: Grow
T.xr({ joints = { left = pinch_at(lx, ly, lz) } })
T.wait(2)
T.assert(select(2, saucer.xr.lever()), "the left hand takes the lever too")
T.xr({ joints = { left = lower(pinch_at(lx, ly, lz), 0.09) } })
T.wait(2)
T.assert(get().ship.morph and get().ship.size == 1, "one detent up: the Seat unfolds")
for _ = 1, 120 do T.wait(1) end
T.assert(not get().ship.morph, "unfolded")
local eye1 = shipm.eye_world(get().ship.pos, get().ship.yaw, get().ship.size)
T.assert(vec.len(vec.sub(eye1, eye0)) < 1e-6, "back at the same eye")
T.xr({ joints = { left = false } })
T.wait(2)

-- 4. a pinch away from the lever is the left trigger: Use stands you up
T.xr({ joints = { left = hand(-0.3, 1.2, 0.3, "pinch") } })
T.wait(3)
T.assert(get().mode ~= "helm", "a pinch in the air is Use: stood up from the helm")
T.xr({ joints = { left = false }, available = 0, session = 0 })
T.wait(2)
print("xr hands ok at tick", T.state().tick)
