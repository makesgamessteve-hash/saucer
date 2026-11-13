-- SPDX-License-Identifier: MIT
-- Boot, rendering, touch and WebXR input paths, sounds, viewports.
local T = saucer.test
local get = function() return T.state().players[1] end

T.wait(5)
T.assert(T.state().tick == 5, "ticks advance")
T.assert(saucer.input.device_mode(1) == "kbm", "keyboard/mouse by default")

-- touch: push the virtual stick up -> the saucer flies forward
local z0 = get().ship.pos[3]
T.touch("down", 7, 0.17, 0.72)
T.wait(1)
T.touch("move", 7, 0.17, 0.52)
T.wait(60)
T.touch("up", 7)
T.wait(1)
T.assert(get().ship.pos[3] > z0 + 1, "touch stick flies forward")
T.assert(saucer.input.device_mode(1) == "touch", "touch mode after a touch")

-- touch buttons: the shrink button
local layout = saucer.input.touch_layout()
local shrink
for _, w in ipairs(layout) do if w.name == "shrink" then shrink = w end end
local sounds = T.audio_count()
T.touch("down", 8, shrink.x + shrink.w / 2, shrink.y + shrink.h / 2)
T.wait(2)
T.touch("up", 8)
T.wait(40)
T.assert(get().ship.size == 2, "touch shrink button shrinks to the Cruiser")
T.assert(T.audio_count() > sounds, "size change plays a sound")

-- WebXR: a standing session; left stick forward flies, the size lever grows
T.xr({ available = 1, session = 2, head_fwd = { 0, 0, 1 }, controls = { stick_ly = -1 } })
local z1 = get().ship.pos[3]
T.wait(30)
T.assert(get().ship.pos[3] > z1 + 1, "XR stick flies forward")
T.assert(saucer.xr.session() == "standing", "XR session visible to mods")
T.xr({ controls = { stick_ly = 0, lever_up = 1 } })
T.wait(2)
T.xr({ controls = { lever_up = 0 } })
T.wait(70)
T.assert(get().ship.size == 1, "XR size lever grows back to the Villa")
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
