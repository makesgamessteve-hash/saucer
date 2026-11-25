-- SPDX-License-Identifier: MIT
-- add-material-system golden shots. Run from the folder that should receive shots_materials/:
--   with --relic-slice: the reference scene (a Vyrr trunk, its ribs, cushions and spines, and the Core's idol),
--     once with materials full and once off -> shots_materials/relic_trunk_{full,off}.png, relic_core_{full,off}.png;
--     then the heart and the idol with and without glow sprites -> shots_materials/glow_{heart,idol}_{on,off}.png
--   without it: the legacy scene (seed 42 at tick 120, the default view) -> shots_materials/legacy.png; run the
--     same script with a build from before the material system to get the reference (it needs no new API)
-- tools/shots/golden_compare.py compares them with tests/golden/ (tools/shots/materials.sh runs it all).
local T = saucer.test
local D = "shots_materials/"
local has, relic = pcall(require, "sim.relic")
if not has then relic = nil end
local i = relic and relic.site_index(T.state()) or nil
if not i then
  T.wait(120)
  T.screenshot(D .. "legacy.png")
  return
end
local ap = require("sim.autopilot")
local game = require("sim.game")
local ruinm = require("sim.ruin")
local R = require("view.render")
local hud = require("view.hud")
local sm = saucer.math
local get = function() return T.state().players[1] end
hud.draw = function() end
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
local function look_at(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  free = { pos = from, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov = fov or 70, near = 0.3, far = 9000 }
end
T.wait(20)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
local site = T.state().sector.sites[i]
local r = game.ruin(i)
local kit = ruinm.kit_of(r.kit)
local s = get().ship
s.pos, s.vel = { site.pos[1], site.pos[2] - 300, site.pos[3] }, { 0, 0, 0 } -- out of frame
local function pair(name)
  for _, m in ipairs({ "full", "off" }) do
    saucer.render.settings({ materials = m })
    T.wait(2)
    T.screenshot(D .. name .. "_" .. m .. ".png")
    T.wait(2)
  end
end
local t = r.rooms[r.relic.trunks[1]]
local mn, mx = ruinm.room_box(t, kit, site.pos)
local c = { (mn[1] + mx[1]) / 2, mn[2] + kit.wall, (mn[3] + mx[3]) / 2 }
look_at({ c[1] + 9, c[2] + 14, mn[3] + 6 }, { c[1] - 6, c[2] + 9, c[3] + 30 }, 72)
pair("relic_trunk")
local idol
for _, sl in ipairs(r.slots) do if sl.idol then idol = sl end end
look_at({ idol.pos[1] + 16, idol.pos[2] + 5, idol.pos[3] - 18 }, { idol.pos[1] - 4, idol.pos[2] + 1, idol.pos[3] + 6 }, 74)
pair("relic_core")
saucer.render.settings({ materials = "full" })
-- fix-glow: the glow sprites only ever add light (they once drew as dark blocky balls round the lamps, the idol and
-- the engine). The heart and the idol with and without them, at one frozen render time, so only the sprites differ
-- -> shots_materials/glow_{heart,idol}_{on,off}.png; golden_compare.py --brighter checks them
local relicv = require("view.relic")
local A = require("view.assets").init()
local draw0, noglow, patched = relicv.draw, false, false
relicv.draw = function(v, a, state, cam, xr)
  if not patched then
    local m = getmetatable(v).methods
    local bb = m.billboard
    m.billboard = function(self, tex, ...) if noglow and tex == A.tex.glow then return end return bb(self, tex, ...) end
    patched = true
  end
  return draw0(v, a, state, cam, xr, 10.0)
end
local function glow_pair(name)
  for _, g in ipairs({ "on", "off" }) do
    noglow = g == "off"
    T.wait(3)
    T.screenshot(D .. "glow_" .. name .. "_" .. g .. ".png")
    T.wait(1)
  end
  noglow = false
end
local core = r.rooms[r.relic.core]
local cmn, cmx = ruinm.room_box(core, kit, site.pos)
local cc = { (cmn[1] + cmx[1]) / 2, cmn[2] + kit.wall, (cmn[3] + cmx[3]) / 2 }
look_at({ cc[1] - 40, cc[2] + 30, cmn[3] + 8 }, { cc[1], cc[2] + 40, cc[3] }, 84)
glow_pair("heart")
look_at({ idol.pos[1] + 16, idol.pos[2] + 5, idol.pos[3] - 18 }, { idol.pos[1] - 4, idol.pos[2] + 1, idol.pos[3] + 6 }, 74)
glow_pair("idol")
relicv.draw = draw0
