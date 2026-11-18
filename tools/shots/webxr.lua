-- SPDX-License-Identifier: MIT
-- Screenshot tour for the WebXR group (OpenSpec add-webxr-cockpit). Run from
-- the folder that should receive the shots (it writes shots/):
--   xvfb-run -a saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/webxr.lua
-- 1-3: the comfort settings on the flat screen (bed panel, the page, a changed setting);
-- 4-6: the same page in a mocked headset session, the size lever, a hand on it.
local T = saucer.test
-- joints reach the engine flipped (x and z negated, like the head): a left hand is at +x, forward is +z
local ap = require("sim.autopilot")
local D = "shots/"
local get = function() return T.state().players[1] end
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local function hand(ox, oy, oz, pose)
  local j = { wrist = { ox, oy, oz }, thumb = { ox - 0.04, oy, oz + 0.09 }, index = { ox - 0.02, oy, oz + 0.17 },
              middle = { ox, oy, oz + 0.18 }, ring = { ox + 0.02, oy, oz + 0.17 }, pinky = { ox + 0.04, oy, oz + 0.15 } }
  if pose == "pinch" then j.thumb = { j.index[1] + 0.01, j.index[2], j.index[3] } end
  return j
end

T.wait(10)
shot("01_title_card_has_comfort_settings")
T.assert(ap.pick(T, 1, get, "Comfort settings"), "opened the comfort settings")
shot("02_comfort_settings_flat")
T.assert(ap.pick(T, 1, get, "Snap angle"), "changed the snap angle")
T.assert(ap.pick(T, 1, get, "Vignette"), "changed the vignette")
T.assert(ap.pick(T, 1, get, "Turning"), "switched to smooth turning")
shot("03_comfort_settings_changed")

-- the same page inside a (mocked) headset: a headset renders at full resolution, one eye per half
saucer.render.settings({ width = 1280, height = 720 })
T.xr({ available = 1, session = 2, head_pos = { 0, 1.6, 0 }, head_fwd = { 0, 0, 1 }, mock_views = true, ipd = 0.064, fov = 120 })
shot("04_comfort_settings_in_xr")
T.assert(ap.pick(T, 1, get, "Back"), "back from the comfort settings")
T.wait(5)
T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.walk_to(T, 1, get, "helm"), "walked to the helm")
T.assert(ap.take_helm(T, 1, get), "took the helm")
T.xr({ joints = { left = hand(0.25, 1.4, 0.4), right = hand(-0.25, 1.4, 0.4) } })
shot("05_xr_cockpit_tracked_hands_and_lever")
local lx, ly, lz = table.unpack((saucer.xr.lever()))
local j = hand(0, 0, 0, "pinch")
local mx, my, mz = (j.thumb[1] + j.index[1]) / 2, j.index[2], j.index[3]
for _, v in pairs(j) do v[1], v[2], v[3] = v[1] + lx - mx, v[2] + ly - my, v[3] + lz - mz end
T.xr({ joints = { right = j } })
shot("06_xr_hand_on_the_size_lever")
T.xr({ joints = { left = false, right = false }, available = 0, session = 0 })
T.wait(2)
