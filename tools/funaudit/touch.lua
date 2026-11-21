-- SPDX-License-Identifier: MIT
-- Fun audit, mobile web proxy (headless): touch layout sizes per resolution,
-- touch Use latency and look-drag turn gain. Prints FUNT lines.
local T = saucer.test
local ap = require("sim.autopilot")
local get = function() return T.state().players[1] end
T.wait(5)
local function widget(name)
  for _, w in ipairs(saucer.input.touch_layout()) do if w.name == name then return w end end
end
-- touch Use on the title card: ticks until mode changes
local w = widget("use")
local t0 = T.state().tick
T.touch("down", 3, w.x + w.w / 2, w.y + w.h / 2)
local lat
for i = 1, 30 do T.wait(1) if get().mode ~= "wake" then lat = T.state().tick - t0 break end end
T.touch("up", 3) T.wait(1)
print(string.format("FUNT use_latency_ticks %s", tostring(lat)))
for _, r in ipairs({ { 568, 320 }, { 640, 360 }, { 667, 375 }, { 844, 390 }, { 1280, 720 }, { 1920, 1080 } }) do
  local hw, hh = T.touch_metrics({ w = r[1], h = r[2] })
  local L = saucer.input.touch_layout()
  local minpx, n, over = 1e9, 0, 0
  for i, a in ipairs(L) do
    if a.kind ~= "stick" and a.kind ~= "look" and a.w and a.w < 0.5 then
      local px = math.min(a.w * r[1], a.h * r[2])
      minpx = math.min(minpx, px); n = n + 1
      for j = i + 1, #L do
        local b = L[j]
        if b.w and b.w < 0.5 and a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then over = over + 1 end
      end
    end
  end
  print(string.format("FUNT layout %dx%d hud %dx%d buttons %d min_side_px %.0f overlaps %d", r[1], r[2], hw, hh, n, minpx, over))
end
T.touch_metrics({ w = 640, h = 360 })
-- look drag: 10% of the screen width over 10 ticks, measure yaw change on foot
local y0 = get().body.yaw
T.touch("down", 8, 0.70, 0.40) T.wait(1)
local first
for i = 1, 10 do
  T.touch("move", 8, 0.70 + 0.01 * i, 0.40) T.wait(1)
  if not first and math.abs(get().body.yaw - y0) > 1e-4 then first = i end
end
T.touch("up", 8) T.wait(2)
local d = math.abs(get().body.yaw - y0)
print(string.format("FUNT look_drag 10%%width yaw_deg %.1f first_response_tick %s", d * 180 / math.pi, tostring(first)))
