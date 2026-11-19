-- SPDX-License-Identifier: MIT
-- Boot, rendering, touch and WebXR input paths, sounds, viewports; the same
-- move actions walk on foot and fly at the helm.
local T = saucer.test
local ap = require("sim.autopilot")
local avatar = require("sim.avatar")
local L = avatar.layout()
local get = function() return T.state().players[1] end

T.wait(5)
T.assert(T.state().tick == 5, "ticks advance")
T.assert(saucer.input.device_mode(1) == "kbm", "keyboard/mouse by default")
T.assert(get().mode == "wake" and get().panel.kind == "title", "wakes up in bed with the title card")

local function widget(name)
  for _, w in ipairs(saucer.input.touch_layout()) do if w.name == name then return w end end
end
local function tap(name, id)
  local w = widget(name)
  T.touch("down", id, w.x + w.w / 2, w.y + w.h / 2)
  T.wait(2)
  T.touch("up", id)
  T.wait(1)
end

-- touch: the Use button picks "Get up" on the title card
tap("use", 3)
T.assert(get().mode == "walk", "touch Use gets the player out of bed")
T.assert(saucer.input.device_mode(1) == "touch", "touch mode after a touch")
T.assert(ap.walk_to(T, 1, get, "dome"), "walked up to the dome deck")
T.assert(ap.look(T, 1, get, 0, 0), "facing the helm")

-- touch: push the virtual stick up -> the player walks forward under the dome
local z0 = get().body.pos[3]
local s0 = get().ship.pos[3]
T.touch("down", 7, 0.17, 0.72)
T.wait(1)
T.touch("move", 7, 0.17, 0.52)
T.wait(40)
T.touch("up", 7)
T.wait(1)
T.assert(get().body.pos[3] > z0 + 1, "touch stick walks forward")
T.assert(get().ship.pos[3] == s0, "walking does not fly the saucer")
T.assert(saucer.input.device_mode(1) == "touch", "touch mode after a touch")

-- touch-look-speed: a look swipe across half the short side in a quarter
-- second turns 90..120 degrees; the comfort setting scales it
local function swipe(id, dir)
  local lay = saucer.input.touch_layout()
  local sh = math.min(lay.css_w, lay.css_h)
  local y0 = get().body.yaw
  T.touch("down", id, 0.4, 0.25)
  T.wait(1)
  for i = 1, 15 do
    T.touch("move", id, 0.4 + dir * sh * 0.5 * i / 15 / lay.css_w, 0.25)
    T.wait(1)
  end
  T.touch("up", id)
  T.wait(1)
  return math.deg(saucer.math.wrap(y0 - get().body.yaw))
end
local deg = swipe(11, 1)
T.assert(deg >= 90 and deg <= 120, "half the short side turns 90..120 degrees (" .. deg .. ")")
T.assert(math.abs(swipe(12, -1) + deg) < 0.5, "and back the same")
saucer.xr.set_comfort({ look_sens = 0.5 })
local half = swipe(13, 1)
T.assert(math.abs(half - deg / 2) < 0.5, "the look speed setting scales the turn (" .. half .. ")")
swipe(14, -1)
saucer.xr.set_comfort({ look_sens = 1 })

-- walk to the helm and take it with the touch Use button
T.assert(ap.walk(T, 1, get, L.helm.stand, 0.3, 600), "walked to the helm")
tap("use", 9)
T.assert(get().mode == "helm", "touch Use takes the helm")
local z1 = get().ship.pos[3]
T.touch("down", 7, 0.17, 0.72)
T.wait(1)
T.touch("move", 7, 0.17, 0.52)
T.wait(60)
T.touch("up", 7)
T.wait(1)
T.assert(get().ship.pos[3] > z1 + 1, "at the helm the touch stick flies the saucer")

-- touch buttons: fold down to the Seat
local sounds = T.audio_count()
tap("shrink", 8)
T.wait(95)
T.assert(get().ship.size == 2, "touch shrink folds the Villa into the Seat")
T.assert(T.audio_count() > sounds, "size change plays a sound")

-- WebXR: a standing session; left stick forward flies, the size lever unfolds
T.xr({ available = 1, session = 2, head_fwd = { 0, 0, 1 }, controls = { stick_ly = -1 } })
local z2 = get().ship.pos[3]
T.wait(30)
T.assert(get().ship.pos[3] > z2 + 1, "XR stick flies forward")
T.assert(saucer.xr.session() == "standing", "XR session visible to mods")
T.xr({ controls = { stick_ly = 0, lever_up = 1 } })
T.wait(2)
T.xr({ controls = { lever_up = 0 } })
T.wait(115)
T.assert(get().ship.size == 1, "XR size lever unfolds the Villa")
-- left trigger: stand up; then walk where the head looks (turned to +x)
T.xr({ controls = { trigger_l = 1 } })
T.wait(2)
T.xr({ controls = { trigger_l = 0 } })
T.wait(1)
T.assert(get().mode == "walk", "XR Use stands up")
local x0 = get().body.pos[1]
T.xr({ head_fwd = { 1, 0, 0 }, controls = { stick_ly = -1 } })
T.wait(20)
T.xr({ controls = { stick_ly = 0 } })
T.assert(get().body.pos[1] > x0 + 0.5, "XR walking follows the head")
T.xr({ session = 0 })

-- split screen with more viewports than players renders without errors
T.viewports(2)
T.wait(4)
T.viewports(1)
T.press(1, "camera")
T.wait(2)
T.assert(get().cam == "chase", "camera toggles to chase")
T.screenshot("boot.png")
T.wait(2)
