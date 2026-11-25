-- SPDX-License-Identifier: MIT
-- add-material-system 5.2: the material showcase sheet. In the relic slice's first hall, rows of spheres and slabs in
-- three made-up civs' materials (one per shot: crystals that sparkle, brushed and liquid metals, organics), lit by the
-- hall's lamps. Run from the folder that should receive shots_materials/:
--   saucer --root REPO --seed 42 --relic-slice --windowed --width 1280 --height 720 --script REPO/tools/shots/material_sheet.lua
local T = saucer.test
local D = "shots_materials/"
local relic = require("sim.relic")
local game = require("sim.game")
local ruinm = require("sim.ruin")
local R = require("view.render")
local relicv = require("view.relic")
local phen = require("view.phenomena")
local civs = require("sim.civs")
local matv = require("view.materials")
local sm = saucer.math
require("view.hud").draw = function() end
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
local function look_at(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  free = { pos = from, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov = fov or 60, near = 0.3,
           far = 9000 }
end

T.wait(20)
local i = relic.site_index(T.state())
T.assert(i ~= nil, "run with --relic-slice")
local site = T.state().sector.sites[i]
local r = game.ruin(i)
local kit = ruinm.kit_of(r.kit)
relicv.BUILDS = 1000
local mn, mx = ruinm.room_box(r.rooms[r.relic.halls[1]], kit, site.pos)
local c = { (mn[1] + mx[1]) / 2, mn[2] + kit.wall, (mn[3] + mx[3]) / 2 }
local S = matv.SLOT
-- the sheet: five objects a row, slot by slot (dominant, accent, rare, ring, decay)
local sheet = saucer.mesh.build({ parts = (function()
  local parts = {}
  local slots = { S.dominant, S.accent, S.rare, S.ring, S.decay }
  for k, slot in ipairs(slots) do
    local x = (k - 3) * 7
    parts[#parts + 1] = { kind = "sphere", c = { x, 5.5, 0 }, r = 2.6, h = 2.6, seg = 28, rings = 16, color = { 0.7, 0.7, 0.7 }, mat = slot }
    parts[#parts + 1] = { kind = "box", min = { x - 2.6, 0.5, -1.2 }, max = { x + 2.6, 1.7, 1.2 }, color = { 0.7, 0.7, 0.7 }, mat = slot }
  end
  return parts
end)() })
local draw = phen.draw
phen.draw = function(v, A, ruin, show, cam, t, opts)
  v:mesh(sheet, { pos = { c[1], c[2], c[3] + 20 }, palette = opts.palette })
  return draw(v, A, ruin, show, cam, t, opts)
end
local base = civs.vyrr()
local function civ(id, dom, acc, rare, ring, decay)
  local m = { dominant = { id = dom }, accent = { id = acc }, rare = { id = rare },
              signature = { rule = "INLAY", ring = ring }, decay = { decay } }
  return setmetatable({ id = id, materials = m, fate = "plague" }, { __index = base })
end
local sheets = {
  civ("sheet_crystal", "quartz", "silver", "rose_quartz", "obsidian", "amber"),
  civ("sheet_metal", "titanium_blue", "mercury", "gold", "bronze_ox", "iron_rust"),
  civ("sheet_organic", "nacre", "black_chrome", "amethyst", "coral", "flesh_necrotic"),
}
local p = T.state().players[1]
p.ship.pos = { c[1], c[2] + 3, c[3] - 10 }
for _, s in ipairs(sheets) do
  relicv.set_style(s)
  saucer.log.info("material sheet: " .. s.id)
  look_at({ c[1] + 2, c[2] + 6, c[3] + 1 }, { c[1], c[2] + 4, c[3] + 20 }, 66)
  T.wait(30)
  T.screenshot(D .. s.id .. ".png")
  T.wait(13)
  T.screenshot(D .. s.id .. "_b.png")
  T.wait(3) -- the screenshot is written on a later frame: keep this style until it is
end
relicv.set_style(nil)
free = nil
