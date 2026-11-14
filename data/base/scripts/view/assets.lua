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
    local dome = kit.build("saucer", { diameter = c.diameter, height = c.height, part = "dome", config = c.id }, 1)
    cache.saucer[i] = { hull = hull, dome = dome }
  end
  -- the Villa's walkable interior and its glass dome (hull-local, see saucer/interior.lua)
  cache.interior = kit.build("interior", { part = "rooms" }, 1)
  cache.glass = kit.build("interior", { part = "glass" }, 1)
  cache.person = kit.build("person", {}, 1)
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
    if r.class >= (k.big or 4) then
      -- great halls: structural ribs down the walls and across the ceiling, glow strips
      local t = k.wall
      local holes = { [-1] = ruinm.face_holes(r, ruin.doors, ruin.rooms, k, origin, 1, -1),
                      [1] = ruinm.face_holes(r, ruin.doors, ruin.rooms, k, origin, 1, 1) }
      local z = mn[3] + 6
      while z < mx[3] - 4 do
        parts[#parts + 1] = { kind = "box", min = { mn[1] + t, mx[2] - t - 1.2, z - 0.6 },
                              max = { mx[1] - t, mx[2] - t, z + 0.6 }, color = { 0.42, 0.44, 0.5 }, uv = 0.5 }
        for _, side in ipairs({ -1, 1 }) do
          local clear = true
          for _, h in ipairs(holes[side]) do
            if z + 0.6 > h[1] - 1 and z - 0.6 < h[2] + 1 then clear = false end
          end
          if clear then
            local x0 = side < 0 and mn[1] + t or mx[1] - t - 1.2
            parts[#parts + 1] = { kind = "box", min = { x0, mn[2] + t, z - 0.6 }, max = { x0 + 1.2, mx[2] - t, z + 0.6 },
                                  color = { 0.42, 0.44, 0.5 }, uv = 0.5 }
            parts[#parts + 1] = { kind = "box", min = { x0 + (side < 0 and 1.2 or -0.1), mn[2] + 6, z - 0.15 },
                                  max = { x0 + (side < 0 and 1.3 or 0), mn[2] + 14, z + 0.15 },
                                  color = { 0.4, 1.0, 0.8 }, emissive = 1 }
          end
        end
        z = z + 8
      end
    end
    local g = kit.recipe("derelict_greeble", { w = mx[1] - mn[1], d = mx[3] - mn[3], top = mx[2] - mn[2] },
                         saucer.seed_child(ruin.seed, "greeble", r.id))
    for _, p in ipairs(kit.transform(g.parts, { pos = { cx, mn[2], cz } })) do parts[#parts + 1] = p end
  end
  m = saucer.mesh.build({ parts = parts })
  cache.ruin[ruin.hash] = m
  return m
end

return M
