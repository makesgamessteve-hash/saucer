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


-- add-huge-stations: a trader station is a kilometre-scale megastructure that hangs off its dock anchor
-- (the trader's `pos`) toward -x (sim/stationhull.lua). Place the anchor so the whole hull clears every
-- site, the vault and the arrival point: of 24 bearings x 3 distances x 3 heights round the sector's
-- origin, the hull's centre goes where its sphere has the most room. Pure; no rng. obstacles are
-- { x, y, z, r } spheres. -> anchor pos
M.STATION_BEARINGS = 24
M.STATION_DISTANCES = { 700, 950, 1200 }
M.STATION_HEIGHTS = { 0, 160, -160 }
function M.place_station(seed, sid, obstacles)
  local sh = require("sim.stationhull")
  local L = sh.get(sh.seed_of(seed, sid, 1), "port")
  local ctr, rad = L.info.centre, L.info.radius
  local best, best_score
  for k = 0, M.STATION_BEARINGS - 1 do
    local a = saucer.math.tau * k / M.STATION_BEARINGS
    for _, d in ipairs(M.STATION_DISTANCES) do
      for _, hy in ipairs(M.STATION_HEIGHTS) do
        local hx, hz = saucer.math.sin(a) * d, saucer.math.cos(a) * d
        local room = math.huge
        for _, o in ipairs(obstacles) do
          local dx, dy, dz = hx - o[1], hy - o[2], hz - o[3]
          room = math.min(room, saucer.math.sqrt(dx * dx + dy * dy + dz * dz) - o[4] - rad)
        end
        local score = math.min(room, 400) - 0.05 * d - math.abs(hy) * 0.1
        if not best_score or score > best_score + 1e-9 then
          best_score = score
          best = { hx - ctr[1], hy - ctr[2], hz - ctr[3] }
        end
      end
    end
  end
  return { best[1] // 1, best[2] // 1, best[3] // 1 }
end

-- a site's bounding sphere as an obstacle
local function site_ball(site)
  local ext = M.extent(site.kit)
  return { site.pos[1] + ext[1] / 2, site.pos[2] + ext[2] / 2, site.pos[3] + ext[3] / 2,
           0.5 * saucer.math.sqrt(ext[1] * ext[1] + ext[2] * ext[2] + ext[3] * ext[3]) }
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
  -- add-huge-stations: the trader's station is vast, so it takes the empty wedge of the sector
  local obstacles = { { 0, 0, -120, 260 }, { vault.pos[1], vault.pos[2], vault.pos[3], 80 } }
  for _, site in ipairs(sites) do obstacles[#obstacles + 1] = site_ball(site) end
  return { id = 1, sites = sites, trader = { pos = M.place_station(seed, 1, obstacles) }, vault = vault, arrival = { 0, 0, -120 } }
end

-- add-cities: some far sectors hold a body city (a planet, a moon or an asteroid) in addition to
-- their other sites, far out so its km-wide mass clears them. Own seed child: the other sites and
-- every sector that has no city come out exactly as before. -> kit id, rng (or nil)
M.CITY_CHANCE = 45
M.CITY_NEAR = 4 -- sectors 2..4
M.CITY_DISTANCE = 4600
M.OUTPOST_GAP = 420 -- m off the city's approach edge to its trader outpost
function M.city_of(seed, sid)
  if not sid or sid == 1 then return nil end
  local crng = saucer.rng.new(saucer.seed_child(seed, "city", sid))
  local roll, shift = crng:int(1, 100), crng:int(0, 2)
  -- the three nearest far sectors always hold one city each, one of every body, so every body is
  -- within a few folds of home in every universe; farther ones are a coin toss
  local near = sid <= M.CITY_NEAR
  if not near and roll > M.CITY_CHANCE then return nil end
  local bodies = require("sim.citygen").BODIES
  return "city_" .. bodies[(sid + (near and 0 or shift)) % #bodies + 1], crng
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
                 heart = (info and info.heart and i == 1) or nil, tutorial = false,
                 danger = info and info.danger or 2 }
  end
  local ckit, crng = M.city_of(seed, sid)
  if ckit then
    local ext = M.extent(ckit)
    local a = crng:float() * saucer.math.tau
    local d = M.CITY_DISTANCE + math.max(ext[1], ext[3]) // 2 - 1500 + crng:int(0, 300)
    local cy = crng:int(-200, 200)
    local ci = list[crng:int(1, #list)]
    sites[#sites + 1] = { id = #sites + 1, pos = { (saucer.math.sin(a) * d - ext[1] / 2) // 1, cy - ext[2] // 2,
                                                  (saucer.math.cos(a) * d - ext[3] / 2) // 1 },
                          seed = saucer.seed_child(seed, "site", sid * 100 + #sites + 1), kit = ckit, civ = ci, city = true, tutorial = false,
                          danger = info and info.danger or 2 }
  end
  -- add-huge-stations: the station takes the largest gap between the sites
  local obstacles = {}
  for _, site in ipairs(sites) do obstacles[#obstacles + 1] = site_ball(site) end
  local tp = M.place_station(seed, sid, obstacles)
  local out = { id = sid, sites = sites, trader = { pos = tp }, arrival = { tp[1] + 60, tp[2] + 20, tp[3] - 260 } }
  -- add-cities-2: a trader outpost hangs off the city's spaceport mouth, so a haul can be sold without the long
  -- flight back to the hub
  if ckit then
    local cs = sites[#sites]
    local ext = M.extent(ckit)
    out.traders = { out.trader, { pos = { cs.pos[1] + ext[1] // 2, cs.pos[2] + 150, cs.pos[3] - M.OUTPOST_GAP }, outpost = true } }
  end
  return out
end

return M
