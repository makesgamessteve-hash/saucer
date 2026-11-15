-- SPDX-License-Identifier: MIT
-- Sector generation (true 3D): a starship derelict near the start, an alien
-- station and a floating city further out, spread around the trader in every
-- direction (above and below too), plus the Resonant vault in open space.
-- Sites are huge (hundreds of meters a side), so they sit 1.3-1.6 km apart.
local data = require("lib.data")
local M = {}

M.SITES = 3
M.KITS = { "starship", "station", "city" }

-- size of a kit's build volume in meters
function M.extent(kit_id)
  local k = data.load("kits/" .. kit_id .. ".lua")
  local g = k.grid or { 64, 48, 96 }
  return { g[1] * k.cell, g[2] * k.cell, g[3] * k.cell }, k
end

function M.generate(seed)
  local rng = saucer.rng.new(saucer.seed_child(seed, "sector", 0))
  local civs = data.load("civs/civs.lua")
  local sites = {}
  for i = 1, M.SITES do
    local kit = M.KITS[(i - 1) % #M.KITS + 1]
    local ext, k = M.extent(kit)
    local pos
    if i == 1 then
      -- the tutorial derelict: its hangar door faces you, at your altitude, ~130 m ahead.
      -- (the entrance sits mid-height of the build volume, see sim/ruin.lua)
      local g = k.grid
      local floor = ((g[2] - k.rooms[4][2]) // 2) * k.cell
      pos = { rng:int(-20, 20) - ext[1] // 2, -(floor + k.wall + k.doors[4][2] / 2) // 1, 150 + rng:int(0, 30) }
    else
      local a = saucer.math.tau * (i - 1) / M.SITES + rng:float() * 0.5
      local d = 1300 + rng:int(0, 300)
      local cy = rng:int(-220, 220)
      -- origin is the corner of the build volume, centred on the chosen point
      pos = { (saucer.math.sin(a) * d - ext[1] / 2) // 1, cy - ext[2] // 2, (saucer.math.cos(a) * d - ext[3] / 2) // 1 }
    end
    sites[i] = { id = i, pos = pos, seed = saucer.seed_child(seed, "site", i), kit = kit, civ = rng:int(1, #civs) }
    -- the first derelict is the tutorial: a Velari hulk whose hangar takes the whole Villa
    if i == 1 then sites[i].civ = 1 end
  end
  -- milestone 3: the Resonant vault of the mystery waits in open space, in the
  -- empty wedge beside the tutorial derelict, above or below your start level
  local va = 0.8 + rng:float() * 0.6
  local vd = 620 + rng:int(0, 120)
  local vault = { pos = { saucer.math.sin(va) * vd // 1, rng:int(-120, 120), saucer.math.cos(va) * vd // 1 } }
  return { sites = sites, trader = { pos = { -260, 30, -140 } }, vault = vault }
end

return M
