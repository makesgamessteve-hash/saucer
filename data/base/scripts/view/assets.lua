-- SPDX-License-Identifier: MIT
-- Render-side asset cache: meshes built from recipes, textures and palettes
-- loaded through the VFS. Nothing here is simulation state.
local kit = require("lib.meshkit")
local configs = require("sim.config")
local ruinm = require("sim.ruin")
local M = {}

local cache = { saucer = {}, ruin = {} }
M.cache = cache

function M.palette(name) return saucer.render.palette(name) end
function M.texture(path) return saucer.render.texture(path) end

function M.init()
  if cache.ready then return cache end
  cache.pal = {
    base = M.palette("authored/palettes/base.png"),
  }
  cache.tex = {
    hull = M.texture("generated/textures/hull_plating.png"),
    nebula = M.texture("generated/textures/nebula.png"),
    loot = M.texture("authored/sprites/loot.png"),
    echo = M.texture("authored/sprites/echo.png"),
    beam = M.texture("authored/sprites/beam.png"),
  }
  cache.stars = saucer.mesh.build({ parts = { { kind = "stars", count = 1400, r = 900, size = 2.2, seed = 7 } } })
  cache.station = kit.build("station", {}, 11)
  cache.cache_mesh = kit.build("loot_cache", { size = 1 }, 1)
  for i, c in ipairs(configs.all()) do
    local hull = kit.build("saucer", { diameter = c.diameter, height = c.height, part = "hull", config = c.id }, 1)
    local dome = kit.build("saucer", { diameter = c.diameter, height = c.height, part = "dome" }, 1)
    cache.saucer[i] = { hull = hull, dome = dome }
  end
  cache.ready = true
  return cache
end

-- one mesh per generated derelict (keyed by its layout hash)
function M.ruin_mesh(ruin, origin)
  local m = cache.ruin[ruin.hash]
  if m then return m end
  local k = ruinm.kit_of(ruin.kit)
  local parts = {}
  for _, b in ipairs(ruin.walls) do
    parts[#parts + 1] = { kind = "box", min = b[1], max = b[2], color = k.color, uv = 0.25 }
  end
  for _, b in ipairs(ruin.debris) do
    parts[#parts + 1] = { kind = "box", min = b[1], max = b[2], color = { 0.55, 0.45, 0.32 }, uv = 0.5 }
  end
  for _, r in ipairs(ruin.rooms) do
    local mn, mx = ruinm.room_box(r, k, origin)
    local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
    -- ceiling light strip
    parts[#parts + 1] = { kind = "box", min = { cx - 0.3, mx[2] - k.wall - 0.12, mn[3] + 1 },
                          max = { cx + 0.3, mx[2] - k.wall, mx[3] - 1 }, color = { 0.4, 1.0, 0.8 }, emissive = 1 }
    local g = kit.recipe("derelict_greeble", { w = mx[1] - mn[1], d = mx[3] - mn[3], top = mx[2] - mn[2] },
                         saucer.seed_child(ruin.seed, "greeble", r.id))
    for _, p in ipairs(kit.transform(g.parts, { pos = { cx, mn[2], cz } })) do parts[#parts + 1] = p end
  end
  m = saucer.mesh.build({ parts = parts })
  cache.ruin[ruin.hash] = m
  return m
end

return M
