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


-- add-huge-stations, add-alien-stations: a trader station is a multi-kilometre alien megastructure that grows
-- off its dock anchor (the trader's `pos`) toward -x (sim/stationhull.lua). Place the anchor so the hull's box
-- clears every site, the vault and the arrival point by a margin: of 24 bearings x 6 distances x 5 heights round
-- the sector's origin, the anchor goes as near the origin as it can while the box has room, and where the way in
-- from the arrival point to the hangar mouth does not cross the hull. Pure; no rng. obstacles are { x, y, z, r }
-- spheres. -> anchor pos
M.STATION_BEARINGS = 24
M.STATION_DISTANCES = { 700, 1000, 1350, 1750, 2200, 2700 }
M.STATION_HEIGHTS = { 0, 250, -250, 550, -550 }
M.STATION_ROOM = 120     -- m of clear space between the hull's box and any obstacle
local placed, placed_order = {}, {}
function M.place_station(seed, sid, obstacles)
  -- the same sector is generated again and again (loads, tests): the answer is a pure function of its inputs
  local key = { tostring(seed), tostring(sid) }
  for _, o in ipairs(obstacles) do key[#key + 1] = string.format("%.2f,%.2f,%.2f,%.2f", o[1], o[2], o[3], o[4]) end
  key = table.concat(key, ";")
  local hit = placed[key]
  if not hit then
    hit = M.place_station_uncached(seed, sid, obstacles)
    placed[key] = hit
    placed_order[#placed_order + 1] = key
    if #placed_order > 64 then placed[table.remove(placed_order, 1)] = nil end
  end
  return { hit[1], hit[2], hit[3] }
end

-- distance from a point to a box (0 inside)
local function box_gap(p, lo, hi)
  local s = 0
  for k = 1, 3 do
    local d = math.max(lo[k] - p[k], 0, p[k] - hi[k])
    s = s + d * d
  end
  return saucer.math.sqrt(s)
end
M.box_gap = box_gap

-- does the segment a-b pass through the box? (slab test)
local function seg_hits_box(a, b, lo, hi)
  local t0, t1 = 0, 1
  for k = 1, 3 do
    local d = b[k] - a[k]
    if math.abs(d) < 1e-9 then
      if a[k] < lo[k] or a[k] > hi[k] then return false end
    else
      local u, v = (lo[k] - a[k]) / d, (hi[k] - a[k]) / d
      if u > v then u, v = v, u end
      t0, t1 = math.max(t0, u), math.min(t1, v)
      if t0 > t1 then return false end
    end
  end
  return true
end
M.seg_hits_box = seg_hits_box

-- the station of sector sid's main trader: its family follows the walk-in seed (sim/stationgen.lua)
function M.station_family(seed, sid)
  local sg = require("sim.stationgen")
  return require("sim.stationhull").family_of(sg.seed_of(seed, sid, 1))
end

local spots_cache
function M.station_spots(T)
  if spots_cache then return spots_cache end
  local sin, cos, sqrt = saucer.math.sin, saucer.math.cos, saucer.math.sqrt
  local out = {}
  for k = 0, M.STATION_BEARINGS - 1 do
    local a = saucer.math.tau * k / M.STATION_BEARINGS
    local sa, ca = sin(a), cos(a)
    for _, d in ipairs(M.STATION_DISTANCES) do
      for _, hy in ipairs(M.STATION_HEIGHTS) do
        local p = { sa * d, hy, ca * d }
        local mouth = { p[1] + T.mouth_x, p[2] + T.floor_y + T.height / 2, p[3] }
        out[#out + 1] = { p = p, mouth = mouth, i = #out + 1,
                          near = sqrt(mouth[1] * mouth[1] + mouth[2] * mouth[2] + mouth[3] * mouth[3]) + math.abs(hy) * 0.5 }
      end
    end
  end
  table.sort(out, function(u, w) if u.near ~= w.near then return u.near < w.near end return u.i < w.i end)
  spots_cache = out
  return out
end

function M.place_station_uncached(seed, sid, obstacles, from)
  local sh = require("sim.stationhull")
  -- (the station's box alone: building the whole layout for every sector would be slow)
  local _, _, lo, hi = sh.envelope(sh.seed_of(seed, sid, 1), "port", M.station_family(seed, sid))
  local T = require("sim.dock").tune()
  -- the hull's box without the cell and its approach (the way in ends at the mouth)
  local body_hi = { T.back_x - 10, hi[2], hi[3] }
  from = from or { 0, 0, -120 }
  local best, best_score, best_i
  -- every spot, nearest first (the order and the bearings, distances and heights are fixed, so made once);
  -- a spot whose best possible score cannot beat the best so far ends the search (ties go to the earlier
  -- spot in bearing, distance, height order, as a plain sweep would pick)
  local spots = M.station_spots(T)
  for _, sp in ipairs(spots) do
    if best_score and sp.near - 80 > best_score then break end
    local p = sp.p
    local blo, bhi = { p[1] + lo[1], p[2] + lo[2], p[3] + lo[3] }, { p[1] + hi[1], p[2] + hi[2], p[3] + hi[3] }
    local room = math.huge
    for _, o in ipairs(obstacles) do
      local r = box_gap(o, blo, bhi) - o[4]
      if r < room then room = r end
      if room < M.STATION_ROOM then break end
    end
    if room >= M.STATION_ROOM then
      local blocked = seg_hits_box(from, sp.mouth, blo, { p[1] + body_hi[1], p[2] + body_hi[2], p[3] + body_hi[3] })
      local score = sp.near + (blocked and 2000 or 0) - math.min(room, 400) * 0.2
      if not best_score or score < best_score or (score == best_score and sp.i < best_i) then
        best, best_score, best_i = p, score, sp.i
      end
    end
  end
  -- (nothing fits: the farthest, highest spot; the hull may brush an obstacle)
  best = best or { 0, M.STATION_HEIGHTS[4] + hi[2] - lo[2], M.STATION_DISTANCES[#M.STATION_DISTANCES] }
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
  -- add-relic-stations (plan phase 8): some far sectors hold a relic, placed last so every other site, the city and
  -- the station come out exactly as before
  local rs = M.relic_site(seed, sid, info, sites, obstacles, tp)
  if rs then sites[#sites + 1] = rs end
  return out
end

-- add-relic-stations §8.4: relics are a site kind of far sectors. Sector RELIC_FIRST always holds one (a few folds
-- from home in every universe), farther ones RELIC_CHANCE in 100; never the home sector or the Heart's. Its civ is
-- one of the sector's own; it sits RELIC_DISTANCE out, its whole build box at least RELIC_MARGIN from every other
-- site, the city and the trader station. Own seed child, so a sector without a relic is unchanged. -> civ index, rng
M.RELIC_FIRST = 3
M.RELIC_CHANCE = 35
M.RELIC_DISTANCE = 3600
M.RELIC_MARGIN = 120
M.RELIC_TRIES = 16
function M.relic_of(seed, sid, info)
  if not sid or sid == 1 or (info and info.heart) then return nil end
  local rng = saucer.rng.new(saucer.seed_child(seed, "relic", sid))
  local roll = rng:int(1, 100)
  if sid < M.RELIC_FIRST then return nil end
  if sid > M.RELIC_FIRST and roll > M.RELIC_CHANCE then return nil end
  local list = info and info.civs or { 1 }
  return list[rng:int(1, #list)], rng
end

-- the build box a relic of this civ may fill (a styled relic gets the archetypes' larger grid), in meters
function M.relic_extent(civ)
  local kit = data.load("kits/relic.lua")
  local g = kit.grid
  if require("sim.relicgen").archetype(civ) then g = data.load("civs/dungeons.lua").grid end
  return { g[1] * kit.cell, g[2] * kit.cell, g[3] * kit.cell }
end

function M.relic_site(seed, sid, info, sites, obstacles, tp)
  local ci, rng = M.relic_of(seed, sid, info)
  if not ci then return nil end
  local civ = require("sim.civs").get(seed, ci)
  local ext = M.relic_extent(civ)
  local obs = {}
  for _, o in ipairs(obstacles) do obs[#obs + 1] = o end
  -- the trader station's hull, as a ball round its box
  local sh = require("sim.stationhull")
  local _, _, lo, hi = sh.envelope(sh.seed_of(seed, sid, 1), "port", M.station_family(seed, sid))
  local sc, sr = {}, 0
  for k = 1, 3 do
    sc[k] = tp[k] + (lo[k] + hi[k]) / 2
    sr = sr + ((hi[k] - lo[k]) / 2) ^ 2
  end
  obs[#obs + 1] = { sc[1], sc[2], sc[3], saucer.math.sqrt(sr) }
  for _, s in ipairs(sites) do
    if s.city then obs[#obs + 1] = site_ball(s) end
  end
  local turn = rng:float() * saucer.math.tau
  local d0 = M.RELIC_DISTANCE + math.max(ext[1], ext[3]) // 2
  local pos
  for t = 0, M.RELIC_TRIES - 1 do
    local a = turn + saucer.math.tau * (t % 8) / 8
    local d = d0 + (t // 8) * 1500
    local cy = rng:int(-300, 300)
    local p = { (saucer.math.sin(a) * d - ext[1] / 2) // 1, cy - ext[2] // 2, (saucer.math.cos(a) * d - ext[3] / 2) // 1 }
    local blo, bhi = p, { p[1] + ext[1], p[2] + ext[2], p[3] + ext[3] }
    local ok = true
    for _, o in ipairs(obs) do
      if box_gap(o, blo, bhi) - o[4] < M.RELIC_MARGIN then
        ok = false
        break
      end
    end
    if ok then
      pos = p
      break
    end
  end
  -- (nothing fits: far beyond everything, on the first bearing)
  pos = pos or { (saucer.math.sin(turn) * (d0 + 4000) - ext[1] / 2) // 1, -ext[2] // 2,
                 (saucer.math.cos(turn) * (d0 + 4000) - ext[3] / 2) // 1 }
  local id = #sites + 1
  return { id = id, pos = pos, seed = saucer.seed_child(seed, "relic_site", sid), kit = "relic", civ = ci, relic = true,
           tutorial = false, danger = info and info.danger or 2 }
end

return M
