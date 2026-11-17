-- SPDX-License-Identifier: MIT
-- Sector generation (true 3D): a starship derelict near the start, an alien
-- station and a floating city further out, spread around the trader in every
-- direction (above and below too), plus the Resonant vault in open space.
-- Sites are huge (hundreds of meters a side), so they sit 1.3-1.6 km apart.
local data = require("lib.data")
local M = {}

M.SITES = 3
M.KITS = { "starship", "station", "city" }
-- add-wider-dark: every kit a far sector may use (the hive is the newest)
M.ALL_KITS = { "starship", "station", "city", "hive" }

-- size of a kit's build volume in meters
function M.extent(kit_id)
  local k = data.load("kits/" .. kit_id .. ".lua")
  local g = k.grid or { 64, 48, 96 }
  return { g[1] * k.cell, g[2] * k.cell, g[3] * k.cell }, k
end

-- generate(seed, sid, info): the home sector (sid 1, the milestone 3 layout,
-- unchanged) or a far sector from the galaxy (sim/galaxy.lua)
function M.generate(seed, sid, info)
  if sid and sid ~= 1 then return M.far(seed, sid, info) end
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
    if i == 1 then
      sites[i].civ = 1
      sites[i].tutorial = true -- unguarded (sim/sentry.lua)
    end
  end
  -- milestone 3: the Resonant vault of the mystery waits in open space, in the
  -- empty wedge beside the tutorial derelict, above or below your start level
  local va = 0.8 + rng:float() * 0.6
  local vd = 620 + rng:int(0, 120)
  local vault = { pos = { saucer.math.sin(va) * vd // 1, rng:int(-120, 120), saucer.math.cos(va) * vd // 1 } }
  return { id = 1, sites = sites, trader = { pos = { -260, 30, -140 } }, vault = vault, arrival = { 0, 0, -120 } }
end

-- add-wider-dark: a far sector. 3-4 sites (4 in the Heart sector: the Heart
-- site is its first) drawn from the sector's civs, each site in a kit its
-- civ builds, spread round the trader in every direction. info is the
-- galaxy entry: { civs = { universe civ indices }, danger, heart }.
function M.far(seed, sid, info)
  local civs = require("sim.civs")
  local rng = saucer.rng.new(saucer.seed_child(seed, "sector", sid))
  local list = info and info.civs or { 1 }
  local n = info and info.heart and 4 or rng:int(3, 4)
  local sites = {}
  local turn = rng:float() * saucer.math.tau
  for i = 1, n do
    local ci = list[(i - 1) % #list + 1]
    local civ = civs.get(seed, ci)
    local ks = civ.kits or M.KITS
    local kit = ks[rng:int(1, math.min(2, #ks))]
    if info and info.heart and i == 1 then kit = ks[1] end
    local ext = M.extent(kit)
    local a = turn + saucer.math.tau * (i - 1) / n + rng:float() * 0.4
    local d = 1250 + rng:int(0, 350)
    local cy = rng:int(-260, 260)
    if info and info.heart and i == 1 then d, cy = 1100, 0 end
    local pos = { (saucer.math.sin(a) * d - ext[1] / 2) // 1, cy - ext[2] // 2, (saucer.math.cos(a) * d - ext[3] / 2) // 1 }
    sites[i] = { id = i, pos = pos, seed = saucer.seed_child(seed, "site", sid * 100 + i), kit = kit, civ = ci,
                 heart = (info and info.heart and i == 1) or nil }
  end
  local tp = { rng:int(-200, 200), rng:int(-60, 60), rng:int(-200, 200) }
  return { id = sid, sites = sites, trader = { pos = tp }, arrival = { tp[1] + 60, tp[2] + 20, tp[3] - 260 } }
end

return M
