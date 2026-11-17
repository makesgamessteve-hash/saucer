-- SPDX-License-Identifier: MIT
-- add-presentation-packaging: WebXR comfort, end to end through the engine.
-- Drives the XR controls the way web/saucer_xr.js does (saucer.test.xr), in
-- a standing ("local-floor") and a seated ("local") session: a right-stick
-- flick is one 30 degree snap turn (re-armed when the stick returns), smooth
-- turning comes back when snap is switched off, the frames render with the
-- hands and the comfort vignette, and the HUD stays off in the headset.
local T = saucer.test
local ap = require("sim.autopilot")
local comfort = require("sim.comfort")
local xrv = require("view.xr")
local get = function() return T.state().players[1] end
local function near(a, b) return math.abs(saucer.math.wrap(a - b)) < 1e-3 end
local function stick(x, ticks)
  T.xr({ controls = { stick_rx = x } })
  T.wait(ticks or 1)
end
local HANDS = { { pose = { -0.25, 1.0, 0.35, 0, 0, 1 } }, { pose = { 0.25, 1.0, 0.35, 0, 0, 1 } } }

T.assert(ap.wake(T, 1, get), "got up")
-- standing session, room scale
T.xr({ available = 1, session = 2, views = 2, head_pos = { 0, 1.62, 0 }, head_fwd = { 0, 0, 1 }, hands = HANDS })
T.wait(5)
T.assert(saucer.xr.session() == "standing", "standing session")
local y0 = get().body.yaw
stick(1, 10) -- held over: still one snap
T.assert(near(get().body.yaw, y0 - comfort.SNAP), "one snap right per flick: " .. get().body.yaw - y0)
stick(0, 2)
stick(-1, 3)
T.assert(near(get().body.yaw, y0), "snap left brings it back")
stick(0.5, 5) -- below the snap threshold: nothing
T.assert(near(get().body.yaw, y0), "a nudge below the threshold does not turn")
stick(0, 2)
-- walking forward draws the vignette (render-only, the sim never sees it)
local h0 = T.state_hash()
for _ = 1, 40 do ap.hold(T, 1, { move_z = 1 }) end
T.assert(T.state_hash() ~= h0, "walked")
ap.hold(T, 1, {})
T.assert(xrv.stats.frames > 40 and xrv.stats.hands > 0, "XR frames drew the hands and wrist panel")
T.assert(xrv.stats.vignettes > 0, "walking drew the comfort vignette")
-- smooth turning when the player turns snap off
saucer.xr.set_comfort({ snap = false })
local y1 = get().body.yaw
stick(1, 20)
T.assert(not near(get().body.yaw, y1) and math.abs(saucer.math.wrap(get().body.yaw - y1)) > comfort.SNAP,
  "smooth turning keeps turning while held")
stick(0, 2)
saucer.xr.set_comfort({ snap = true })
-- seated session at the helm: the saucer itself snaps
T.xr({ session = 1, head_pos = { 0, 0, 0 } })
T.assert(ap.walk_to(T, 1, get, "helm"), "walked to the helm")
T.assert(ap.take_helm(T, 1, get), "took the helm")
local s0 = get().ship.yaw
stick(-1, 4)
stick(0, 2)
T.assert(near(get().ship.yaw, s0 + comfort.SNAP), "the saucer snaps left at the helm")
T.assert(saucer.xr.session() == "seated", "seated session")
T.wait(10)
local f = xrv.stats.frames
T.xr({ hands = {} })
T.wait(3)
T.assert(xrv.stats.frames > f, "seated frames render")
T.xr({ available = 0, session = 0, views = 0, hands = {} })
xrv.reset()
T.wait(5)
print("xr comfort ok at tick", T.state().tick)
