-- SPDX-License-Identifier: MIT
-- add-alien-cities-2 (plan phase 10 part 2, design civs-and-relics §4.2, §4.4): the megacity round a city's core.
-- The core (sim/citygen.lua) stays the downtown; round it a ring of outer districts fills a 21 km square footprint, each
-- district a block of civ-shaped megaforms up to 1.5 km tall (one per city up to 2.8 km) between canyon avenues,
-- joined by strata decks. Nothing here is saved: the plan and every district are pure functions of the city's seed.
--
-- Streaming (deterministic): a district is solid only while a player's ship is within ACTIVE m of it (at most
-- PER_PLAYER per player and MAX_ACTIVE in all, nearest first). One that has not been built when it is needed is built
-- there and then; the view may build districts ahead of time (view/citymega.lua), which only fills the same cache.
local citygen = require("sim.citygen")
local ruinm = require("sim.ruin")

local M = {}

M.CELL = 3000              -- m, one outer district's square (avenues come off it)
M.SPAN = { planet = { 16000, 20000 }, moon = { 15500, 19000 }, asteroid = { 15500, 18000 } }
M.DISTRICTS = 48           -- at most this many districts in a city, core and ring together
M.BASE_ID = 3000           -- outer district ids (the core's are 1..n, skyline 1000+, transit 2000+)
M.AVENUE = { 80, 220 }     -- m, the canyon between two districts
M.PAD = 300                -- m kept clear round the core, every other site, the stations and the arrival point
M.CORRIDOR = 700           -- m, half the width of the clear approach in front of the spaceport
M.ORGAN_H = { 180, 900 }   -- m, an ordinary megaform's height over the street
M.CROWN_H = { 900, 1500 }  -- m, a crown megaform (CROWN in 100 of them)
M.CROWN = 18
M.MEGAFORM_H = { 2000, 2800 } -- m, the city's one tallest form
M.SNAP = 4                 -- m, the cell every tier is rounded to
M.ACTIVE = 1500            -- m from a ship to a district's box: inside this the district is solid
M.KEEP = 1750              -- m: an active district stays solid until the ship is this far
M.PER_PLAYER = 9
M.MAX_ACTIVE = 16

local floor, max, min = math.floor, math.max, math.min

-- the core's frame: centre (x, z), street level y, extent (m), kit
function M.frame(r)
  local kit = ruinm.kit_of(r.kit)
  local e = citygen.extent_cells(kit)
  local o = r.origin
  local ext = { e[1] * kit.cell, e[2] * kit.cell, e[3] * kit.cell }
  return { cx = o[1] + ext[1] / 2, cz = o[3] + ext[3] / 2, y = o[2] + (kit.city.ground or 0) * kit.cell, ext = ext,
           origin = o, kit = kit, body = kit.city.body }
end

-- distance in the ground plane from (x, z) to the rectangle b = { x0, z0, x1, z1 }
local function rect_dist(b, x, z)
  local dx = max(b[1] - x, 0, x - b[3])
  local dz = max(b[2] - z, 0, z - b[4])
  return saucer.math.sqrt(dx * dx + dz * dz)
end
M.rect_dist = rect_dist
local function rects_meet(a, b, pad)
  return a[1] < b[3] + pad and b[1] < a[3] + pad and a[2] < b[4] + pad and b[2] < a[4] + pad
end

-- the balls the ring keeps clear of: every other site, every station, the arrival point -> { x, z, r }
function M.obstacles(sector, i, station_ball)
  local out = {}
  for j, s in ipairs(sector.sites or {}) do
    if j ~= i then
      local ext = require("sim.sector").extent(s.kit)
      local rr = 0.5 * saucer.math.sqrt(ext[1] * ext[1] + ext[2] * ext[2] + ext[3] * ext[3])
      out[#out + 1] = { s.pos[1] + ext[1] / 2, s.pos[3] + ext[3] / 2, rr }
    end
  end
  local list = sector.traders or (sector.trader and { sector.trader }) or {}
  for idx, tr in ipairs(list) do
    local c, rr = nil, 1400
    if station_ball then c, rr = station_ball(idx) end
    c = c or tr.pos
    out[#out + 1] = { c[1], c[3], rr }
  end
  if sector.arrival then out[#out + 1] = { sector.arrival[1], sector.arrival[3], 400 } end
  return out
end

-- the outer districts' plan for city ruin r (site i of sector) -> { frame, districts = { ... } }. Pure; cheap
-- (footprints and heights only: M.build fills in the tiers)
function M.plan(r, sector, i, station_ball)
  local fr = M.frame(r)
  local rng = saucer.rng.new(saucer.seed_child(r.seed, "mega", 0))
  local span = M.SPAN[fr.body] or M.SPAN.planet
  local want = rng:int(span[1], span[2])
  local half = math.ceil((want / M.CELL - 1) / 2)
  local core = { fr.origin[1] - M.PAD, fr.origin[3] - M.PAD, fr.origin[1] + fr.ext[1] + M.PAD, fr.origin[3] + fr.ext[3] + M.PAD }
  -- the way in: the spaceport is on the core's -z face; keep a corridor in front of it, and keep the whole ring off
  -- the side of the core that faces the sector's heart (where the other sites, the station and the arrival are)
  local lane = { fr.cx - M.CORRIDOR, -1e9, fr.cx + M.CORRIDOR, fr.origin[3] }
  local heart = saucer.math.sqrt(fr.cx * fr.cx + fr.cz * fr.cz) - max(fr.ext[1], fr.ext[3]) / 2 - M.PAD
  local obs = M.obstacles(sector or {}, i, station_ball)
  local cells = {}
  for iz = -half, half do
    for ix = -half, half do
      local x0, z0 = fr.cx + (ix - 0.5) * M.CELL, fr.cz + (iz - 0.5) * M.CELL
      local b = { x0, z0, x0 + M.CELL, z0 + M.CELL }
      local ok = not rects_meet(b, core, 0) and not rects_meet(b, lane, 0) and rect_dist(b, 0, 0) > heart
      for _, o in ipairs(obs) do
        if ok and rect_dist(b, o[1], o[2]) < o[3] + M.PAD then ok = false end
      end
      if ok then
        local mx, mz = x0 + M.CELL / 2 - fr.cx, z0 + M.CELL / 2 - fr.cz
        cells[#cells + 1] = { ix = ix, iz = iz, box = b, far = mx * mx + mz * mz }
      end
    end
  end
  -- too many: the farthest go (ties by grid order, so the cut is the same everywhere)
  local room = M.DISTRICTS - #((r.city and r.city.districts) or {})
  if #cells > room then
    local order = {}
    for k, c in ipairs(cells) do order[k] = c end
    table.sort(order, function(a, b) if a.far ~= b.far then return a.far < b.far end return (a.iz * 1000 + a.ix) < (b.iz * 1000 + b.ix) end)
    local keep = {}
    for k = 1, max(room, 0) do keep[order[k]] = true end
    local kept = {}
    for _, c in ipairs(cells) do if keep[c] then kept[#kept + 1] = c end end
    cells = kept
  end
  local style = (r.city and r.city.style) or citygen.style_of(nil)
  local out = { frame = fr, districts = {}, seed = r.seed, style = style, span = (2 * half + 1) * M.CELL }
  local tallest, best = nil, -1
  for k, c in ipairs(cells) do
    local d = M.plan_district(r.seed, k, c, fr, style)
    out.districts[k] = d
    -- the megaform stands in the district farthest from the sector's heart
    local mx, mz = (c.box[1] + c.box[3]) / 2, (c.box[2] + c.box[4]) / 2
    local far = mx * mx + mz * mz
    if far > best then tallest, best = d, far end
  end
  if tallest then
    local drng = saucer.rng.new(saucer.seed_child(r.seed, "megaform", 0))
    local o = tallest.organs[(#tallest.organs + 1) // 2]
    if o then
      local w = min(600, floor(tallest.lot * 0.9 / M.SNAP) * M.SNAP)
      o.x0, o.z0 = o.lx + floor((tallest.lot - w) / 2), o.lz + floor((tallest.lot - w) / 2)
      o.w, o.w2, o.h, o.form, o.megaform = w, w, drng:int(M.MEGAFORM_H[1], M.MEGAFORM_H[2]), style.form, true
      tallest.megaform = true
      tallest.top = max(tallest.top, o.h)
    end
  end
  return out
end

-- one outer district's plan: its value, its megaforms' footprints and heights, its decks
function M.plan_district(seed, k, c, fr, style)
  local rng = saucer.rng.new(saucer.seed_child(seed, "megadist", k))
  local own = citygen.ARCHETYPES[style.value or ""] and style.value or "craft"
  local value = own
  if rng:int(1, 100) > citygen.OWN_VALUE then value = citygen.VALUES[rng:int(1, #citygen.VALUES)] end
  local av = rng:int(M.AVENUE[1], M.AVENUE[2])
  local b = { c.box[1] + av / 2, c.box[2] + av / 2, c.box[3] - av / 2, c.box[4] - av / 2 }
  local g = rng:int(3, 4)
  local lot = floor((b[3] - b[1]) / g)
  local d = { id = M.BASE_ID + k, k = k, ix = c.ix, iz = c.iz, box = b, cell = c.box, value = value, archetype = citygen.ARCHETYPES[value].label,
              lot = lot, g = g, organs = {}, decks = {}, y = fr.y, body = fr.body, top = 0 }
  d.label = string.format("D%d %s", d.id, d.archetype)
  local grid = {}
  for gz = 1, g do
    for gx = 1, g do
      local lx, lz = b[1] + (gx - 1) * lot, b[2] + (gz - 1) * lot
      if rng:int(1, 100) <= 82 then
        local w = floor(lot * rng:int(45, 80) / 100 / M.SNAP) * M.SNAP
        local w2 = floor(lot * rng:int(45, 80) / 100 / M.SNAP) * M.SNAP
        local h = rng:int(1, 100) <= M.CROWN and rng:int(M.CROWN_H[1], M.CROWN_H[2]) or rng:int(M.ORGAN_H[1], M.ORGAN_H[2])
        local jx, jz = rng:int(0, lot - w), rng:int(0, lot - w2)
        local form = citygen.form_of(style, d, gx, gz)
        local o = { gx = gx, gz = gz, lx = lx, lz = lz, x0 = lx + jx, z0 = lz + jz, w = w, w2 = w2, h = h, form = form }
        d.organs[#d.organs + 1] = o
        grid[gz * 10 + gx] = o
        d.top = max(d.top, h)
      end
    end
  end
  -- strata decks: a slab between two neighbours in a row, a third of the way up the lower one
  local n = rng:int(1, 3)
  for _ = 1, n do
    local gz, gx = rng:int(1, g), rng:int(1, g - 1)
    local a, e = grid[gz * 10 + gx], grid[gz * 10 + gx + 1]
    if a and e and e.x0 > a.x0 + a.w then
      local z0, z1 = max(a.z0, e.z0), min(a.z0 + a.w2, e.z0 + e.w2)
      if z1 - z0 >= 40 then
        local low = min(a.h, e.h)
        local yy = floor(low * rng:int(25, 45) / 100 / M.SNAP) * M.SNAP
        local wz = min(z1 - z0, rng:int(30, 80))
        local zm = floor((z0 + z1 - wz) / 2)
        d.decks[#d.decks + 1] = { a.x0 + a.w, yy, zm, e.x0, yy + 8, zm + wz }
      end
    end
  end
  return d
end

-- the solids of one outer district (world { min, max } boxes): a foundation under its whole cell (the avenues' floor
-- too), each megaform's tiers, the decks. Pure.
function M.build(d)
  local out = {}
  local y = d.y
  local b = d.cell
  local slab = d.body == "asteroid" and 40 or 6
  out[1] = { { b[1], y - slab, b[2] }, { b[3], y, b[4] } }
  local s = M.SNAP
  for _, o in ipairs(d.organs) do
    local wc, w2c, hc = o.w // s, o.w2 // s, o.h // s
    for _, t in ipairs(citygen.tiers(o.form, wc, w2c, hc)) do
      local x0, z0, y0 = o.x0 + t.dx * s, o.z0 + t.dz * s, y + t.dy * s
      out[#out + 1] = { { x0, y0, z0 }, { x0 + t.w * s, y0 + t.h * s, z0 + t.w2 * s } }
    end
  end
  for _, k in ipairs(d.decks) do out[#out + 1] = { { k[1], y + k[2], k[3] }, { k[4], y + k[5], k[6] } } end
  return out
end

-- ------------------------------------------------------------ the cache and the active set (derived, never saved)
local plans = setmetatable({}, { __mode = "k" })  -- ruin -> plan
local built = {}                                  -- seed .. ":" .. k -> solids
local live = {}                                   -- site index -> { [k] = { box ids } }
M.stats = { built = 0, sync_built = 0 }

function M.get_plan(r, sector, i, station_ball)
  if not r or not r.city then return nil end
  local p = plans[r]
  if not p then
    p = M.plan(r, sector, i, station_ball)
    plans[r] = p
  end
  return p
end

-- the solids of district d of plan p (built once, cached)
function M.solids(p, d)
  local key = p.seed .. ":" .. d.k
  local s = built[key]
  if not s then
    s = M.build(d)
    built[key] = s
    M.stats.built = M.stats.built + 1
  end
  return s
end
function M.is_built(p, d) return built[p.seed .. ":" .. d.k] ~= nil end

-- forget every live box (the physics world was cleared): the next sync adds them again
function M.reset()
  live = {}
end
function M.live(i) return live[i] or {} end
function M.clear_cache() built = {} end

-- the districts that should be solid at site i: per player its PER_PLAYER nearest within reach (an already live one
-- within KEEP), then the MAX_ACTIVE nearest of those -> sorted list of district indices
function M.wanted(p, positions, now)
  local best = {}
  for _, pos in ipairs(positions) do
    local near = {}
    for k, d in ipairs(p.districts) do
      local dist = rect_dist(d.box, pos[1], pos[3])
      local top = p.frame.y + d.top
      if pos[2] > top then dist = max(dist, pos[2] - top) end
      if pos[2] < p.frame.y - 60 then dist = max(dist, p.frame.y - 60 - pos[2]) end
      local reach = (now and now[k]) and M.KEEP or M.ACTIVE
      if dist <= reach then near[#near + 1] = { k = k, dist = dist } end
    end
    table.sort(near, function(a, b) if a.dist ~= b.dist then return a.dist < b.dist end return a.k < b.k end)
    for n = 1, min(#near, M.PER_PLAYER) do
      local e = near[n]
      if not best[e.k] or e.dist < best[e.k] then best[e.k] = e.dist end
    end
  end
  local list = {}
  for k, dist in pairs(best) do list[#list + 1] = { k = k, dist = dist } end
  table.sort(list, function(a, b) if a.dist ~= b.dist then return a.dist < b.dist end return a.k < b.k end)
  local out = {}
  for n = 1, min(#list, M.MAX_ACTIVE) do out[#out + 1] = list[n].k end
  table.sort(out)
  return out
end

-- make the live set of every city in the sector match the players' positions (game.step, game.rebuild)
function M.sync(state, ruin_of, station_ball)
  local positions = {}
  for _, pl in ipairs(state.players or {}) do positions[#positions + 1] = pl.ship.pos end
  for i, site in ipairs(state.sector.sites) do
    local r = ruin_of(i)
    if site.city and r and r.city then
      local p = M.get_plan(r, state.sector, i, station_ball)
      local now = live[i] or {}
      live[i] = now
      local want = {}
      for _, k in ipairs(M.wanted(p, positions, now)) do want[k] = true end
      -- drop first (the ids at the end of the physics list are freed), then add in district order
      local drop = {}
      for k in pairs(now) do if not want[k] then drop[#drop + 1] = k end end
      table.sort(drop, function(a, b) return a > b end)
      for _, k in ipairs(drop) do
        local ids = now[k]
        for n = #ids, 1, -1 do saucer.physics.remove(ids[n]) end
        now[k] = nil
      end
      for k = 1, #p.districts do
        if want[k] and not now[k] then
          local d = p.districts[k]
          if not M.is_built(p, d) then M.stats.sync_built = M.stats.sync_built + 1 end
          local ids = {}
          for _, b in ipairs(M.solids(p, d)) do ids[#ids + 1] = saucer.physics.add_box(b[1], b[2], 1) end
          now[k] = ids
        end
      end
    end
  end
end

-- the outer district within pad m of pos (in the ground plane, up to its top plus pad), or nil
function M.near_district(p, pos, pad)
  for _, d in ipairs(p and p.districts or {}) do
    if rect_dist(d.box, pos[1], pos[3]) <= pad and pos[2] <= p.frame.y + d.top + pad then return d end
  end
  return nil
end

-- the outer district that holds (x, z) at plan p, or nil
function M.district_at(p, x, z)
  for _, d in ipairs(p and p.districts or {}) do
    local b = d.box
    if x >= b[1] and x <= b[3] and z >= b[2] and z <= b[4] then return d end
  end
  return nil
end

return M
