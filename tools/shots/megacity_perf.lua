-- SPDX-License-Identifier: MIT
-- Megacity frame budget (OpenSpec add-alien-cities-2). The saucer cruises a loop out over the outer districts of a
-- body city for 900 drawn frames; prints the p50/p95/max wall time of a whole frame, of the megacity's own draw call
-- (view/citymega.lua: streaming, building, drawing) and of the sim's streaming (sim/citymega.lua sync).
--   xvfb-run -a saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/shots/megacity_perf.lua
--     [--script-arg planet|moon|asteroid]
-- (under xvfb the GPU is software: the frame figure is an upper bound, the Lua figures are the real CPU cost)
local T = saucer.test
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local ap = require("sim.autopilot")
local megav = require("view.citymega")
local mega = require("sim.citymega")
local BODY = (T.arg() ~= "" and T.arg()) or "planet"
local FRAMES = 900
local now = saucer.time.wall_ms
local draw_ms, sync_ms = {}, {}
local orig_draw, orig_sync = megav.draw, mega.sync
megav.draw = function(...)
  local t0 = now()
  local r = orig_draw(...)
  draw_ms[#draw_ms + 1] = now() - t0
  return r
end
mega.sync = function(...)
  local t0 = now()
  orig_sync(...)
  sync_ms[#sync_ms + 1] = now() - t0
end
local function p1() return T.state().players[1] end
T.wait(10)
ap.wake(T, 1, p1)
ap.take_helm(T, 1, p1)
local st = T.state()
for id = 2, #galaxy.generate(st.seed).sectors do
  if sector.city_of(st.seed, id) == "city_" .. BODY then game.enter_sector(st, id) break end
end
local site
for i, s in ipairs(st.sector.sites) do if s.city then site = i end end
local p = game.mega_plan(st, site)
-- a loop through four outer districts, low over their foundations
local route = {}
for k = 1, 4 do
  local d = p.districts[(k * 7) % #p.districts + 1]
  route[k] = { (d.box[1] + d.box[3]) / 2, p.frame.y + 260, (d.box[2] + d.box[4]) / 2 }
end
local frame_ms = {}
local s = p1().ship
local last = now()
for f = 1, FRAMES do
  local k = (f - 1) / FRAMES * #route
  local a, b = route[math.floor(k) % #route + 1], route[math.floor(k + 1) % #route + 1]
  local t = k - math.floor(k)
  s.pos = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
  s.vel, s.charge = { 0, 0, 0 }, 100
  s.yaw = saucer.math.atan2(b[1] - a[1], b[3] - a[3])
  T.wait(1)
  local t1 = now()
  frame_ms[#frame_ms + 1] = t1 - last
  last = t1
end
local function pct(list, q)
  local c = {}
  for i, x in ipairs(list) do c[i] = x end
  table.sort(c)
  if #c == 0 then return 0 end
  return c[math.max(1, math.ceil(#c * q))]
end
local function line(name, list)
  return string.format("%s p50 %.2f p95 %.2f max %.2f ms", name, pct(list, 0.5), pct(list, 0.95), pct(list, 1))
end
print(string.format("megaperf %s: %d frames, %d outer districts, built %d", BODY, FRAMES, #p.districts, megav.cache(p).built))
print("megaperf " .. line("frame", frame_ms))
print("megaperf " .. line("megacity draw", draw_ms))
print("megaperf " .. line("sim sync", sync_ms))
