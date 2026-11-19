-- SPDX-License-Identifier: MIT
-- City frame budget (OpenSpec add-cities). Steps 900 drawn frames while the saucer cruises a loop through
-- the body city (or, for BODY "none", sits in the sector-1 clearing as the baseline). Run by
-- tools/shots/cities_perf.sh, which times the whole process; frame time = (run - baseline start-up) / frames.
local T = saucer.test
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local ap = require("sim.autopilot")
local vec = require("lib.vec")
local ruinm = require("sim.ruin")
local render = require("view.render")
-- OVERRIDES
local BODY = "planet"
local FRAMES = 900
local function p1() return T.state().players[1] end
T.wait(10)
ap.wake(T, 1, p1)
ap.take_helm(T, 1, p1)
local st = T.state()
local lod, chunks, culled, detail, litmax = 0, 0, 0, 0, 0
if BODY ~= "none" then
  for id = 2, #galaxy.generate(st.seed).sectors do
    if sector.city_of(st.seed, id) == "city_" .. BODY then game.enter_sector(st, id) break end
  end
  local site
  for i, s in ipairs(st.sector.sites) do if s.city then site = i end end
  local ruin = game.ruin(site)
  local kit = ruinm.kit_of(ruin.kit)
  local o = st.sector.sites[site].pos
  local ext = { kit.grid[1] * kit.cell, kit.grid[2] * kit.cell, kit.grid[3] * kit.cell }
  local port = ruin.city.districts[ruin.city.port]
  local s = p1().ship
  s.charge = 100
  -- a loop over the roofs at street-canyon height, round the whole city
  local route = {
    { o[1] + ext[1] / 2, port.pos[2] + 70, o[3] - 200 }, { o[1] + ext[1] * 0.2, port.pos[2] + 120, o[3] + ext[3] * 0.3 },
    { o[1] + ext[1] * 0.8, port.pos[2] + 120, o[3] + ext[3] * 0.5 }, { o[1] + ext[1] * 0.5, port.pos[2] + 200, o[3] + ext[3] * 0.8 },
  }
  local n = 0
  for f = 1, FRAMES do
    local k = (f - 1) / FRAMES * #route
    local a, b = route[math.floor(k) % #route + 1], route[math.floor(k + 1) % #route + 1]
    local t = k - math.floor(k)
    s.pos = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
    s.vel, s.charge = { 0, 0, 0 }, 100
    s.yaw = saucer.math.atan2(b[1] - a[1], b[3] - a[3])
    T.wait(1)
    local rs = render.stats
    if rs then lod, chunks, culled = lod + rs.lod, math.max(chunks, rs.chunks), culled + rs.culled; detail = math.max(detail, rs.detail); litmax = math.max(litmax, rs.lit or 0) end
    n = n + 1
  end
  print(string.format("perf %s: %d frames, max chunks drawn %d, max detail meshes %d, mean coarse %.1f, mean culled %.0f, max lit %d",
    BODY, n, chunks, detail, lod / n, culled / n, litmax))
else
  T.wait(FRAMES)
  print("perf none: " .. FRAMES .. " frames")
end
