-- SPDX-License-Identifier: MIT
-- City generation (OpenSpec add-cities). A city is a hierarchy, all of it a pure function of the site seed:
--   city -> districts (concentric rings around a big centre, one landmark per special district)
--        -> lots (blocks: a tower, an enterable building, a plaza or nothing)
--        -> buildings (a stack of great halls joined by hatches, undercity levels below the street,
--           closets for the Seat, a spire on top) and tunnels under the streets between neighbours.
-- The result has the shape of a derelict (sim/ruin.lua): rooms, doors, walls, slots, solids and debris, so
-- physics, the beam, sentries, saves and the renderer treat it like any other site, plus `city`: the plan
-- (districts, landmarks, power couplings, gates) the map, the grid and the gravity rules read.
-- Three bodies share the generator and differ in their plan (kits/city_<body>.lua, field `city`):
--   planet   a concentric city of towers around a great centre, deep undercity, strong gravity
--   moon     a crater with a great dome and terraced canyon-wall districts, low gravity
--   asteroid a hollow carved rock: a shell with a mouth, two tiers of lots, a spin-gravity drum at the heart
local ruinm = require("sim.ruin")
local M = {}

M.BODIES = { "planet", "moon", "asteroid" }
M.LANDMARKS = { "spaceport", "reactor", "archive", "foundry", "garden", "palace" }
M.FILLER = { "market", "residential", "industrial" }
M.LABEL = {
  spaceport = "Spaceport", reactor = "Reactor Heart", archive = "Archive", foundry = "Foundry",
  garden = "Garden Arcology", palace = "Palace", market = "Market", residential = "Residential",
  industrial = "Industrial", drum = "Spin Drum", crater = "Crater Dome",
}
M.HALL = { 20, 7, 20 }     -- cells (4 m): a hall the Villa flies through
M.STEP = 7                 -- one level, in cells
M.DISTRICT = 3             -- lots per district side
M.MAX_ROOMS = 420          -- generation budget (rooms) per city

local function kit_of(id) return ruinm.kit_of(id) end

local function lot_origin(spec, gx, gz)
  return spec.margin + ((spec.ring or 0) + gx - 1) * (spec.lot + spec.street) + spec.street // 2,
         spec.approach + (gz - 1) * (spec.lot + spec.street)
end

-- per-civ look: architecture by the civ's shape, light colours by its glyph
M.PALETTES = { { 1.0, 0.82, 0.45 }, { 0.45, 0.95, 1.0 }, { 1.0, 0.5, 0.85 }, { 0.55, 1.0, 0.6 }, { 0.9, 0.95, 1.0 }, { 1.0, 0.55, 0.35 } }
M.SHAPES = { angular = "ziggurat", crystalline = "spire", organic = "dome", modular = "arcology" }
-- add-alien-cities (plan phase 10, design civs-and-relics §4.1, §4.3): a roster civ builds its towers in its massing's
-- form, and its ordinary districts take their character from what it valued (the landmarks stay as they are)
M.MASSING_FORMS = { ring = "crater", spine = "rib", cluster = "pods", hive = "hive", shell = "terrace", lattice = "lattice",
                    helix = "helix", organism = "lobed" }
M.ARCHETYPES = {
  knowledge = { label = "Archive Spires", form = "spire" },
  hoarding = { label = "Treasury Vaults", form = "vault" },
  faith = { label = "Cathedral Organs", form = "organ" },
  kinship = { label = "Brood Warrens", form = "hive" },
  conquest = { label = "Fortress Terraces", form = "ziggurat" },
  craft = { label = "Foundry Trenches", form = "slab" },
  harmony = { label = "Choir Bowls", form = "bowl" },
}
M.VALUES = { "knowledge", "hoarding", "faith", "kinship", "conquest", "craft", "harmony" }
M.OWN_VALUE = 60   -- % of a city's ordinary districts that carry its builders' own value (the rest: another one)
-- the share of a tower's height its first (full-footprint) tier fills: sky-bridges land on it
M.BASE_FRAC = { spire = 0.42, dome = 0.35, vault = 0.55, organ = 0.25, hive = 0.3, slab = 0.35, bowl = 0.12, lattice = 0.3,
                helix = 0.25, lobed = 0.3, pods = 0.2, terrace = 0.4, rib = 0.2, crater = 0.3 }
function M.style_of(civ)
  local glyph = civ and civ.glyph or 1
  local shape = civ and civ.shape or "angular"
  local n = #M.PALETTES
  local form = civ and civ.massing and M.MASSING_FORMS[civ.massing] or M.SHAPES[shape] or "ziggurat"
  return { shape = shape, form = form, window = M.PALETTES[glyph % n + 1], massing = civ and civ.massing or nil,
           value = civ and civ.axes and civ.axes.values or nil,
           accent = M.PALETTES[(glyph * 5 + 2) % n + 1], civ = civ and civ.id or nil }
end

-- the value each ordinary district stands for: the builders' own for OWN_VALUE%, another for the rest (its own rng,
-- so the rest of the city is drawn exactly as before)
function M.archetypes(seed, districts, value)
  local rng = saucer.rng.new(saucer.seed_child(seed or 1, "archetype", 0))
  local own = M.ARCHETYPES[value or ""] and value or "craft"
  for _, d in ipairs(districts) do
    if not d.landmark and not d.drum and not d.crater then
      local v = own
      if rng:int(1, 100) > M.OWN_VALUE then v = M.VALUES[rng:int(1, #M.VALUES)] end
      d.value = v
      d.archetype = M.ARCHETYPES[v].label
      d.label = string.format("D%d %s", d.id, d.archetype)
    end
  end
  return districts
end

-- sky lanes: one between every district and its east and south neighbours, at cell height y
function M.lanes(dists, origin, kit, y)
  local by, out = {}, {}
  for _, d in ipairs(dists) do if d.dx then by[d.dz * 1000 + d.dx] = d end end
  for _, d in ipairs(dists) do
    for k = 1, 2 do
      local n = d.dx and by[k == 1 and (d.dz * 1000 + d.dx + 1) or ((d.dz + 1) * 1000 + d.dx)]
      if n then
        local wy = origin[2] + y * kit.cell
        out[#out + 1] = { a = { d.pos[1], wy, d.pos[3] }, b = { n.pos[1], wy, n.pos[3] }, from = d.id, to = n.id }
      end
    end
  end
  return out
end

-- the form of the tower on a lot: in a district with a value, every other tower in that value's form
function M.form_of(style, d, gx, gz)
  if d and d.value and (gx * 3 + gz) % 2 == 0 then return M.ARCHETYPES[d.value].form end
  return style.form
end
function M.base_height(form, h) return math.floor(h * (M.BASE_FRAC[form] or 0.3)) end

-- add-alien-cities: the civ-shaped forms (see M.tiers)
M.FORMS = {
  vault = { { 1, 1, 0, 0.55 }, { 0.84, 0.84, 0.55, 0.15 }, { 0.5, 0.5, 0.7, 0.06 } },
  organ = { { 1, 1, 0, 0.25 }, { 0.24, 0.24, 0.25, 0.75, -1, -1 }, { 0.24, 0.24, 0.25, 0.6, 1, -1 }, { 0.24, 0.24, 0.25, 0.45, 1, 1 },
            { 0.24, 0.24, 0.25, 0.68, -1, 1 } },
  hive = { { 1, 1, 0, 0.3 }, { 0.55, 0.55, 0.3, 0.22, -1, -1 }, { 0.55, 0.55, 0.45, 0.22, 1, 0 }, { 0.5, 0.5, 0.62, 0.22, 0, 1 },
           { 0.4, 0.4, 0.8, 0.2, -0.4, 0 } },
  slab = { { 1, 1, 0, 0.35 }, { 1, 0.4, 0.35, 0.15, 0, -1 }, { 0.2, 0.2, 0.35, 0.65, 1, 1 }, { 0.2, 0.2, 0.35, 0.5, -1, 1 } },
  bowl = { { 1, 1, 0, 0.12 }, { 0.4, 0.4, 0.12, 0.5 }, { 0.8, 0.8, 0.6, 0.12 }, { 1, 1, 0.72, 0.1 } },
  lattice = { { 1, 1, 0, 0.3 }, { 0.22, 0.22, 0.3, 0.62, -1, -1 }, { 0.22, 0.22, 0.3, 0.62, 1, -1 }, { 0.22, 0.22, 0.3, 0.62, 1, 1 },
              { 0.22, 0.22, 0.3, 0.62, -1, 1 }, { 1, 1, 0.92, 0.08 } },
  helix = { { 1, 1, 0, 0.25 }, { 0.3, 0.3, 0.25, 0.75 }, { 0.55, 0.55, 0.3, 0.12, -1, -1 }, { 0.55, 0.55, 0.45, 0.12, 1, -1 },
            { 0.55, 0.55, 0.6, 0.12, 1, 1 }, { 0.55, 0.55, 0.75, 0.12, -1, 1 } },
  lobed = { { 1, 1, 0, 0.3 }, { 0.8, 0.7, 0.3, 0.25, 0.3, -0.2 }, { 0.6, 0.75, 0.55, 0.2, -0.3, 0.3 }, { 0.4, 0.4, 0.75, 0.25, 0.2, 0 } },
  pods = { { 1, 1, 0, 0.2 }, { 0.45, 0.45, 0.2, 0.5, -1, -1 }, { 0.45, 0.45, 0.2, 0.8, 1, 0.2 }, { 0.4, 0.4, 0.2, 0.62, -0.2, 1 } },
  terrace = { { 1, 1, 0, 0.4 }, { 0.85, 0.85, 0.4, 0.15 }, { 0.7, 0.7, 0.55, 0.1 } },
  rib = { { 1, 1, 0, 0.2 }, { 0.35, 0.35, 0.2, 0.8 }, { 0.8, 0.3, 0.4, 0.05 }, { 0.8, 0.3, 0.6, 0.05 }, { 0.8, 0.3, 0.8, 0.05 } },
  crater = { { 1, 1, 0, 0.3 }, { 1, 0.2, 0.3, 0.3, 0, -1 }, { 1, 0.2, 0.3, 0.3, 0, 1 }, { 0.2, 1, 0.3, 0.3, -1, 0 },
             { 0.2, 1, 0.3, 0.3, 1, 0 } },
}

-- a tower's silhouette: stacked boxes { dx, dz, w, w2, dy, h } (cells, from the tower's footprint corner and base),
-- every box inside the footprint, so what you see is exactly what you hit
function M.tiers(form, w, w2, h, inverted)
  local out = {}
  local function add(frac_w, frac_w2, y0, hh, ox, oz)
    local ww, ww2 = math.max(4, math.floor(w * frac_w)), math.max(4, math.floor(w2 * frac_w2))
    out[#out + 1] = { dx = ((w - ww) // 2) + (ox or 0), dz = ((w2 - ww2) // 2) + (oz or 0), w = ww, w2 = ww2, dy = y0, h = math.max(2, hh) }
  end
  if form == "spire" then
    add(1, 1, 0, h * 0.42)
    add(0.62, 0.62, h * 0.42, h * 0.3)
    add(0.26, 0.26, h * 0.72, h * 0.28)
  elseif form == "dome" then
    local fr = { { 1, 0.35 }, { 0.88, 0.25 }, { 0.7, 0.2 }, { 0.48, 0.12 }, { 0.26, 0.08 } }
    local y = 0
    for _, f in ipairs(fr) do add(f[1], f[1], y, h * f[2]) y = y + h * f[2] end
  elseif form == "arcology" then
    add(0.5, 0.5, 0, h)
    add(1, 0.62, 0, h * 0.3)
    add(0.64, 1, h * 0.42, h * 0.2, w // 8, 0)
    add(0.8, 0.5, h * 0.72, h * 0.14, 0, w2 // 6)
  elseif M.FORMS[form] then
    -- add-alien-cities: { w frac, w2 frac, y0 frac, h frac, x slide, z slide } (a slide of -1..1 moves the box across
    -- the footprint's slack, so every box stays inside it); the first box is always the full footprint
    for _, b in ipairs(M.FORMS[form]) do
      local ww, ww2 = math.max(4, math.floor(w * b[1])), math.max(4, math.floor(w2 * b[2]))
      ww, ww2 = math.min(ww, w), math.min(ww2, w2)
      local sx, sz = (w - ww) // 2, (w2 - ww2) // 2
      local hh = math.floor(math.min(h, math.max(2, h * b[4])))   -- whole cells, so a hung tower flips exactly
      out[#out + 1] = { dx = sx + math.floor(sx * (b[5] or 0) + 0.5), dz = sz + math.floor(sz * (b[6] or 0) + 0.5), w = ww, w2 = ww2,
                        dy = math.min(math.floor(h * b[3]), math.floor(h) - hh), h = hh }
    end
  else -- ziggurat: four steps, each narrower
    local y = 0
    for i = 0, 3 do
      local f = 1 - i * 0.2
      add(f, f, y, h / 4)
      y = y + h / 4
    end
  end
  if inverted then -- hung from the ceiling: widest at the top
    local top = 0
    for _, t in ipairs(out) do top = math.max(top, t.dy + t.h) end
    for _, t in ipairs(out) do t.dy = top - t.dy - t.h end
  end
  for _, t in ipairs(out) do t.dy, t.h = math.floor(t.dy), math.floor(t.h) end
  return out
end

-- the cell extent (x, y, z) of a city kit's build volume
M.TRANSIT_BASE = 2000 -- ids of the mag-rail stretches (drawn like skyline districts)
M.SKY_BASE = 1000 -- ids of the outer skyline districts start above this (the core's are 1..n)

function M.extent_cells(kit)
  local s = kit.city
  local p = s.lot + s.street
  local R = s.ring or 0
  return { 2 * s.margin + (s.lots[1] + 2 * R) * p, kit.grid[2], s.approach + (s.lots[2] + R) * p + s.margin }
end

-- ------------------------------------------------------------------ the plan
-- a circular mask: lots in the corners of the bounding square are skyline, not core
function M.city_centre(spec)
  local nx, nz = spec.lots[1], spec.lots[2]
  return (nx + 1) / 2, (nz + 1) / 2, math.max(nx, nz) / 2 + 0.05
end

function M.lot_radius(spec, gx, gz)
  local cx, cz = M.city_centre(spec)
  local dx, dz = gx - cx, gz - cz
  return math.sqrt(dx * dx + dz * dz)
end

function M.in_disk(spec, gx, gz)
  local _, _, rad = M.city_centre(spec)
  return M.lot_radius(spec, gx, gz) <= rad
end

-- the circular footprint of the core plus its skyline, in world metres from origin, for the megacity's keep-out
function M.footprint(kit, origin)
  local spec = kit.city
  local cell = kit.cell
  origin = origin or { 0, 0, 0 }
  local cx, cz, rad = M.city_centre(spec)
  local R = spec.ring or 0
  local pitch = spec.lot + spec.street
  local x0 = spec.margin + (R + cx - 1) * pitch + spec.street // 2 + spec.lot / 2
  local z0 = spec.approach + (cz - 1) * pitch + spec.lot / 2
  return {
    x = origin[1] + x0 * cell,
    z = origin[3] + z0 * cell,
    r = (rad + R) * pitch * cell,
  }
end


-- ring bands and wedge counts: planet cities keep 16 districts, moon and
-- asteroid cities keep 9, matching the earlier 3x3-block counts.
local function ring_bands(spec)
  local nx, nz = spec.lots[1], spec.lots[2]
  local nd = ((nx + M.DISTRICT - 1) // M.DISTRICT) * ((nz + M.DISTRICT - 1) // M.DISTRICT)
  if nd >= 16 then
    return {
      { r = 2.35, n = 1, role = "core" },
      { r = 3.45, n = 3, role = "civic" },
      { r = 4.45, n = 4, role = "market" },
      { r = 5.35, n = 4, role = "residential" },
      { r = 99, n = 4, role = "industrial" },
    }
  end
  local scale = math.max(nx, nz) / 9
  return {
    { r = 1.85 * scale, n = 1, role = "core" },
    { r = 2.55 * scale, n = 2, role = "civic" },
    { r = 3.25 * scale, n = 2, role = "market" },
    { r = 3.95 * scale, n = 2, role = "residential" },
    { r = 99, n = 2, role = "industrial" },
  }
end

-- district index of a lot (concentric plan: needs the dmap from M.plan)
local function district_of(spec, gx, gz, dmap)
  if dmap then return dmap[gz * 1000 + gx] end
  local dx, dz = (gx - 1) // M.DISTRICT, (gz - 1) // M.DISTRICT
  local nd = (spec.lots[1] + M.DISTRICT - 1) // M.DISTRICT
  return dz * nd + dx + 1
end
M.district_of = district_of

function M.plan(rng, kit)
  local spec = kit.city
  local nx, nz = spec.lots[1], spec.lots[2]
  local cx, cz = M.city_centre(spec)
  local bands = ring_bands(spec)
  -- gather lots in the disk, bucketed by ring
  local buckets = {}
  for i = 1, #bands do buckets[i] = {} end
  for gz = 1, nz do
    for gx = 1, nx do
      if M.in_disk(spec, gx, gz) then
        local rad = M.lot_radius(spec, gx, gz)
        local bi = #bands
        for i, b in ipairs(bands) do
          if rad <= b.r then bi = i break end
        end
        local ang = saucer.math.atan2(gx - cx, gz - cz)
        buckets[bi][#buckets[bi] + 1] = { gx, gz, ang = ang, rad = rad }
      end
    end
  end
  -- if a ring came out empty, fold it into its neighbour so every district has lots
  for i = #buckets, 2, -1 do
    if #buckets[i] == 0 then
      bands[i - 1].n = bands[i - 1].n + bands[i].n
      bands[i].n = 0
    end
  end
  local districts, dmap = {}, {}
  local function add_district(lots, role, ring, wedge)
    table.sort(lots, function(a, b) if a.ang ~= b.ang then return a.ang < b.ang end return a.rad < b.rad end)
    local d = { id = #districts + 1, role = role, ring = ring, wedge = wedge or 1, lots = {} }
    local sx, sz = 0, 0
    for _, l in ipairs(lots) do
      d.lots[#d.lots + 1] = { l[1], l[2] }
      dmap[l[2] * 1000 + l[1]] = d.id
      sx, sz = sx + l[1], sz + l[2]
    end
    -- the centre lot is the one closest to the mean of the wedge
    local mx, mz = sx / #lots, sz / #lots
    local best, bd = 1, 1e9
    for i, l in ipairs(d.lots) do
      local dd = (l[1] - mx) * (l[1] - mx) + (l[2] - mz) * (l[2] - mz)
      if dd < bd then best, bd = i, dd end
    end
    d.center = d.lots[best]
    -- dx/dz keep a residual grid address (wedge, ring) for anything that still reads them
    d.dx, d.dz = d.wedge, d.ring
    districts[#districts + 1] = d
    return d
  end
  for i, b in ipairs(bands) do
    local pool = buckets[i]
    local n = b.n
    if n > 0 and #pool > 0 then
      if b.role == "core" or n == 1 then
        add_district(pool, b.role, i - 1, 1)
      else
        table.sort(pool, function(a, c) if a.ang ~= c.ang then return a.ang < c.ang end return a.rad < c.rad end)
        -- split the ring into n wedges as evenly as we can by count, in angle order
        local base, extra = #pool // n, #pool % n
        local k = 1
        for w = 1, n do
          local take = base + (w <= extra and 1 or 0)
          local slice = {}
          for _ = 1, take do
            slice[#slice + 1] = pool[k]
            k = k + 1
          end
          if #slice > 0 then add_district(slice, b.role, i - 1, w) end
        end
      end
    end
  end
  -- the spaceport is the district of the front-centre lot; the rest of the landmarks go by ring role
  local port_lot = { nx // 2 + 1, 1 }
  local pd = dmap[port_lot[2] * 1000 + port_lot[1]]
  if not pd then
    -- the front-centre lot is just outside the disk: use the nearest industrial lot
    local best, bd = nil, 1e9
    for _, d in ipairs(districts) do
      if d.role == "industrial" then
        for _, l in ipairs(d.lots) do
          local dd = (l[1] - port_lot[1]) ^ 2 + (l[2] - port_lot[2]) ^ 2
          if dd < bd then best, bd, port_lot = d.id, dd, { l[1], l[2] } end
        end
      end
    end
    pd = best or #districts
  end
  local function give(di, kind)
    for _, o in ipairs(districts) do
      if o.kind == kind and o ~= districts[di] then o.kind = districts[di].kind or "market" end
    end
    districts[di].kind = kind
  end
  -- default kind from the ring role, then place each landmark once
  for _, d in ipairs(districts) do
    d.kind = d.role == "core" and "palace" or (d.role == "civic" and "archive" or d.role)
  end
  give(pd, "spaceport")
  districts[pd].center = port_lot
  -- pick one district per remaining landmark, preferring a matching role
  local function pick_role(role, fallback)
    for _, d in ipairs(districts) do
      if d.id ~= pd and d.role == role and not d.landmark_set then return d end
    end
    for _, d in ipairs(districts) do
      if d.id ~= pd and (not fallback or d.role == fallback) and not d.landmark_set then return d end
    end
    for _, d in ipairs(districts) do
      if d.id ~= pd and not d.landmark_set then return d end
    end
  end
  local mid_gx, mid_gz = (nx + 1) // 2, (nz + 1) // 2 + 1
  local mid = dmap[mid_gz * 1000 + mid_gx] or (districts[1] and districts[1].id)
  local function place(kind, role, fallback)
    local d = pick_role(role, fallback)
    if d then give(d.id, kind) d.landmark_set = true end
  end
  if spec.body == "asteroid" and mid and mid ~= pd then
    give(mid, "reactor")
    districts[mid].drum = true
    districts[mid].landmark_set = true
  elseif spec.body == "moon" and mid and mid ~= pd then
    give(mid, "garden")
    districts[mid].crater = true
    districts[mid].landmark_set = true
  else
    place("palace", "core", "civic")
  end
  if not (spec.body == "asteroid") then place("reactor", "industrial", "market") end
  if not (spec.body == "moon") then place("garden", "civic", "residential") end
  place("archive", "civic", "market")
  place("foundry", "industrial", "market")
  if spec.body ~= "planet" then
    -- palace still needs a home when the core is the crater or the drum
    local has
    for _, d in ipairs(districts) do if d.kind == "palace" then has = true end end
    if not has then place("palace", "civic", "market") end
  end
  -- leftover districts keep their ring-role kind; each landmark kind appears once
  local marks = { spaceport = true, reactor = true, archive = true, foundry = true, garden = true, palace = true }
  local seen = {}
  for _, d in ipairs(districts) do
    if not d.kind or d.kind == "core" or d.kind == "civic" then
      d.kind = (d.role == "market" or d.role == "residential" or d.role == "industrial") and d.role or "market"
    end
    if marks[d.kind] then
      if seen[d.kind] then
        d.kind = (d.role == "market" or d.role == "residential" or d.role == "industrial") and d.role or "market"
      else
        seen[d.kind] = true
      end
    end
  end
  -- if a landmark is still missing, promote a leftover filler of a matching role
  local prefer = { palace = "core", archive = "civic", garden = "civic", foundry = "industrial", reactor = "industrial", spaceport = "industrial" }
  for _, kind in ipairs(M.LANDMARKS) do
    if not seen[kind] then
      local d = nil
      for _, o in ipairs(districts) do
        if not marks[o.kind] and o.role == prefer[kind] then d = o break end
      end
      if not d then
        for _, o in ipairs(districts) do
          if not marks[o.kind] then d = o break end
        end
      end
      if d then d.kind = kind seen[kind] = true end
    end
  end
  for _, d in ipairs(districts) do
    d.landmark = not not marks[d.kind]
    d.label = string.format("D%d %s", d.id, M.LABEL[d.drum and "drum" or d.crater and "crater" or d.kind])
    d.powered = d.kind == "spaceport"
    d.landmark_set = nil
  end
  return districts, pd, dmap
end

-- what stands on each lot: { type = tower|building|plaza|empty|landmark, y, d }
local function lot_level(spec, rng, gx, gz)
  if spec.body == "moon" then
    local over = gx - (spec.lots[1] - 4)
    return spec.ground + (over > 0 and over * spec.terrace or 0)
  elseif spec.body == "asteroid" then
    local t = spec.tiers[((gx + gz) % 2) + 1]
    if gz == 1 then t = spec.tiers[1] end
    return spec.ground + t
  end
  return spec.ground
end

local function pick_type(rng, mix)
  local r = rng:int(1, mix[1] + mix[2] + mix[3] + mix[4])
  if r <= mix[1] then return "tower" end
  r = r - mix[1]
  if r <= mix[2] then return "building" end
  r = r - mix[2]
  if r <= mix[3] then return "plaza" end
  return "empty"
end

-- ------------------------------------------------------------- build helpers
local function new_room(rooms, kind, class, cell, size, parent, extra)
  local r = { id = #rooms + 1, class = class, kind = kind, parent = parent, size = { size[1], size[2], size[3] },
              cell = { cell[1], cell[2], cell[3] }, inclass = class, faces = {} }
  for k, v in pairs(extra or {}) do r[k] = v end
  rooms[#rooms + 1] = r
  return r
end

local function overlap(a0, a1, b0, b1) return math.max(a0, b0), math.min(a1, b1) end

-- a hatch through the floor of `upper` and the ceiling of `lower` (stacked rooms)
local function hatch(doors, lower, upper)
  local x0, x1 = overlap(lower.cell[1], lower.cell[1] + lower.size[1], upper.cell[1], upper.cell[1] + upper.size[1])
  local z0, z1 = overlap(lower.cell[3], lower.cell[3] + lower.size[3], upper.cell[3], upper.cell[3] + upper.size[3])
  doors[#doors + 1] = { a = lower.id, b = upper.id, class = 4, axis = 2, sign = 1, lo = x0, hi = x1, lo3 = z0, hi3 = z1 }
  lower.faces["+y"], upper.faces["-y"] = true, true
end

-- a door between side-by-side rooms: `a`'s face (axis, sign) meets `b`
local function side_door(doors, a, b, axis, sign, class)
  local l = axis == 1 and 3 or 1
  local u0, u1 = overlap(a.cell[l], a.cell[l] + a.size[l], b.cell[l], b.cell[l] + b.size[l])
  local v0, v1 = overlap(a.cell[2], a.cell[2] + a.size[2], b.cell[2], b.cell[2] + b.size[2])
  doors[#doors + 1] = { a = a.id, b = b.id, class = class, axis = axis, sign = sign, lo = u0, hi = u1, vlo = v0, vhi = v1 }
  a.faces[ruinm.face_name(axis, sign)] = true
  b.faces[ruinm.face_name(axis, -sign)] = true
end

-- a door from open air into `r` through its face (axis, face_sign)
local function street_door(doors, r, axis, face_sign)
  local l = axis == 1 and 3 or 1
  doors[#doors + 1] = { a = 0, b = r.id, class = 4, axis = axis, sign = -face_sign, lo = r.cell[l], hi = r.cell[l] + r.size[l],
                        vlo = r.cell[2], vhi = r.cell[2] + r.size[2], street = true }
  r.faces[ruinm.face_name(axis, face_sign)] = true
end

local function world_box(cell, size, kit, origin)
  local mn, mx = {}, {}
  for k = 1, 3 do
    mn[k] = origin[k] + cell[k] * kit.cell
    mx[k] = mn[k] + size[k] * kit.cell
  end
  return mn, mx
end

-- the physics/render box that fills the hole of door d in room r (a closed gate)
local function gate_box(r, d, rooms, kit, origin)
  local axis = d.axis
  local fs = d.a == r.id and d.sign or -d.sign
  local holes = ruinm.face_holes(r, { d }, rooms, kit, origin, axis, fs)
  local h = holes[1]
  local mn, mx = ruinm.room_box(r, kit, origin)
  local t = kit.wall
  local a0 = fs < 0 and mn[axis] or mx[axis] - t
  local lo, hi = {}, {}
  lo[axis], hi[axis] = a0, a0 + t
  local l = axis == 1 and 3 or 1
  lo[l], hi[l] = h[1], h[2]
  lo[2], hi[2] = h[3], h[4]
  return { lo, hi }
end

-- --------------------------------------------------------------- generation
function M.generate(seed, kit, civ, origin)
  local spec = kit.city
  local rng = saucer.rng.new(seed)
  local districts, port, dmap = M.plan(rng, kit)
  local style0 = M.style_of(civ)
  M.archetypes(seed, districts, style0.value)
  local ext = M.extent_cells(kit)
  local rooms, doors, solids, debris = {}, {}, {}, {}
  local lots, bybuilding = {}, {}
  local gates, couplings = {}, {}
  local style = M.style_of(civ)
  local ceiling = kit.grid[2] - (spec.shell or 2) - 2
  local nx, nz = spec.lots[1], spec.lots[2]
  local ux, uz = M.HALL[1], M.HALL[3]
  local off = (spec.lot - ux) // 2

  -- mix of lot types by ring role (towers, buildings, plazas, empty)
  local MIX = {
    core = { 2, 1, 6, 1 },
    civic = { 2, 6, 2, 1 },
    market = { 2, 6, 2, 1 },
    residential = { 4, 3, 2, 1 },
    industrial = { 3, 3, 2, 2 },
    spaceport = spec.mix,
  }

  -- 1. the lots: type, level, stack (only lots inside the circular core)
  local plan = {}
  for gz = 1, nz do
    for gx = 1, nx do
      local di = dmap and dmap[gz * 1000 + gx]
      if di then
        local d = districts[di]
        local mix = MIX[d.role] or spec.mix
        local lot = { gx = gx, gz = gz, d = d.id, y = lot_level(spec, rng, gx, gz), type = pick_type(rng, mix) }
        lot.x0, lot.z0 = lot_origin(spec, gx, gz)
        if d.center[1] == gx and d.center[2] == gz then lot.type, lot.landmark = "building", d.kind end
        -- the very centre is a great plaza; a crown of tall towers rings it
        if d.role == "core" and not lot.landmark then
          if M.lot_radius(spec, gx, gz) < 1.2 then lot.type = "plaza" else lot.type = "tower" end
        end
        plan[#plan + 1] = lot
        lots[gz * 1000 + gx] = lot
      end
    end
  end
  -- the crater of a moon: nothing stands within `crater` lots of its dome
  if spec.crater then
    local mid_gx, mid_gz = (nx + 1) // 2, (nz + 1) // 2 + 1
    local cd = districts[(dmap and dmap[mid_gz * 1000 + mid_gx]) or 1]
    for _, lot in ipairs(plan) do
      local dx, dz = lot.gx - cd.center[1], lot.gz - cd.center[2]
      if dx * dx + dz * dz <= spec.crater * spec.crater and not lot.landmark then lot.type = "empty" end
    end
  end
  -- every special district other than the spaceport needs a plaza for its power coupling
  for _, d in ipairs(districts) do
    if d.kind ~= "spaceport" then
      local pick
      for _, l in ipairs(d.lots) do
        local lot = lots[l[2] * 1000 + l[1]]
        if lot.type == "plaza" then pick = lot break end
      end
      if not pick then
        for _, l in ipairs(d.lots) do
          local lot = lots[l[2] * 1000 + l[1]]
          if not lot.landmark and (not pick or lot.type == "empty") then pick = lot end
        end
        if pick then pick.type = "plaza" end
      end
      if pick then pick.coupling = d.id else d.powered = true end
    end
  end

  -- 2. buildings
  local function build(lot)
    local d = districts[lot.d]
    local landmark = lot.landmark
    local big = d.drum or d.crater
    local size = { ux, M.HALL[2], uz }
    local ox = off
    if d.drum then size, ox = { 28, 28, 28 }, 2 end
    if d.crater then size, ox = { 28, 10, 28 }, 2 end
    local umax = (landmark and spec.under[2] or rng:int(spec.under[1], spec.under[2]))
    local hmax = landmark and rng:int(1, 3) or rng:int(0, 2)
    if big then umax, hmax = (d.crater and 1 or 0), 0 end
    local base = { lot.x0 + ox, lot.y, lot.z0 + ox }
    if lot.hangar then base[3] = spec.approach end
    local stack = {}
    local function mk(level, kind)
      local cell = { base[1], base[2] + level * M.STEP, base[3] }
      local room = new_room(rooms, kind, 4, cell, size, 1, { district = d.id, lot = lot, level = level, calm = true })
      return room
    end
    local ground = mk(0, lot.hangar and "entrance" or "hall")
    stack[0] = ground
    -- cap the stack under the ceiling
    while hmax > 0 and base[2] + (hmax + 1) * M.STEP + 6 > ceiling do hmax = hmax - 1 end
    for k = 1, umax do
      local r = mk(-k, "hall")
      hatch(doors, r, stack[-k + 1])
      stack[-k] = r
    end
    for k = 1, hmax do
      local r = mk(k, "hall")
      hatch(doors, stack[k - 1], r)
      stack[k] = r
    end
    lot.stack, lot.umax, lot.hmax = stack, umax, hmax
    -- the street door
    if lot.hangar then
      street_door(doors, ground, 3, -1)
    else
      local faces = { { 3, -1 }, { 3, 1 }, { 1, -1 } }
      local f = faces[rng:int(1, #faces)]
      street_door(doors, ground, f[1], f[2])
    end
    if not lot.hangar then ground.street_door = doors[#doors] end
    -- a closet for the Seat off the top hall, on its +x face (tunnels run under the street, not here)
    local top = stack[hmax]
    if not big and rng:int(1, 100) <= 55 then
      local cl = new_room(rooms, "side", 1, { top.cell[1] + top.size[1], top.cell[2], top.cell[3] + 4 + rng:int(0, 6) }, { 4, 3, 6 },
        top.id, { district = d.id, lot = lot, calm = true })
      side_door(doors, top, cl, 1, 1, 1)
      lot.closet = cl
    end
    -- a spire on top: the skyline (never over a hatch: the top hall has none)
    local sp = rng:int(10, spec.tower[4] + 24)
    local top_y = top.cell[2] + top.size[2]
    sp = math.min(sp, ceiling - top_y)
    -- add-dock-land-eva: every third roof is left clear and marked as a landing pad (the rng draws above are unchanged)
    local padded = not big and not lot.hangar and sp >= 4 and (lot.gx + lot.gz) % 3 == 1
    if padded then
      local mn, mx = world_box({ top.cell[1], top_y, top.cell[3] }, { top.size[1], 0.3, top.size[3] }, kit, origin)
      solids[#solids + 1] = { mn, mx, kind = "pad", room = top.id }
      lot.pad = true
      sp = 0
    end
    if sp >= 4 and not big then
      local w = rng:int(8, 12)
      local cx = top.cell[1] + (top.size[1] - w) // 2
      local cz = top.cell[3] + (top.size[3] - w) // 2
      local mn, mx = world_box({ cx, top_y, cz }, { w, sp, w }, kit, origin)
      solids[#solids + 1] = { mn, mx, kind = "spire", room = top.id }
    end
    -- who is awake here: landmarks and a third of the other buildings keep a Watcher
    if landmark and landmark ~= "spaceport" then
      for _, r in pairs(stack) do r.calm = false end
    elseif not lot.hangar and rng:int(1, 100) <= 30 then
      ground.calm = false
    end
    bybuilding[#bybuilding + 1] = lot
    return ground
  end

  -- the spaceport hangar: room 1, its door on the -z face (the front-centre lot, or the port district's centre)
  local plot = lots[1 * 1000 + nx // 2 + 1]
  if not plot then
    local pd = districts[port]
    plot = pd and lots[pd.center[2] * 1000 + pd.center[1]]
  end
  plot.type, plot.landmark, plot.hangar = "building", "spaceport", true
  build(plot)
  for _, lot in ipairs(plan) do
    if lot ~= plot and lot.type == "building" and #rooms < M.MAX_ROOMS then build(lot) end
  end

  -- 3. tunnels under the streets between neighbouring buildings (at an undercity level both have)
  local function tunnel(a, b, axis)
    local k = math.min(a.umax, b.umax)
    if k < 1 then return end
    k = rng:int(1, k)
    local ra, rb = a.stack[-k], b.stack[-k]
    local lat = axis == 1 and 3 or 1
    local gap0 = ra.cell[axis] + ra.size[axis]
    local gap = rb.cell[axis] - gap0
    if gap < 4 then return end
    local cell = { 0, ra.cell[2], 0 }
    cell[axis], cell[lat] = gap0, ra.cell[lat] + 4
    local size = { 0, M.STEP, 0 }
    size[axis], size[lat] = gap, 12
    local t = new_room(rooms, "wing", 4, cell, size, ra.id, { district = ra.district, calm = true, tunnel = true })
    side_door(doors, ra, t, axis, 1, 4)
    side_door(doors, t, rb, axis, 1, 4)
    a.tunnels = (a.tunnels or 0) + 1
    t.ends = { ra.id, rb.id }
  end
  for _, lot in ipairs(plan) do
    if lot.stack and #rooms < M.MAX_ROOMS then
      local e = lots[lot.gz * 1000 + lot.gx + 1]
      if e and e.stack and rng:int(1, 100) <= 70 then tunnel(lot, e, 1) end
      local n = lots[(lot.gz + 1) * 1000 + lot.gx]
      if n and n.stack and rng:int(1, 100) <= 60 then tunnel(lot, n, 3) end
    end
  end

  -- 4. the rest of the skyline: towers, plaza platforms with their couplings, sky-bridges
  for _, lot in ipairs(plan) do
    local d = districts[lot.d]
    if lot.type == "tower" then
      local w, w2 = rng:int(spec.tower[1], spec.tower[2]), rng:int(spec.tower[1], spec.tower[2])
      local h0, h1 = spec.tower[3], spec.tower[4]
      local role = d.role
      local h
      if role == "core" then
        h = rng:int(math.max(h0, math.floor(h1 * 0.9)), math.floor(h1 * 1.25))
      elseif role == "civic" then
        h = rng:int(math.floor((h0 + h1) * 0.45), h1)
      elseif role == "market" then
        h = rng:int(h0, math.floor(h1 * 0.85))
      elseif role == "residential" then
        h = rng:int(h0, math.floor((h0 + h1) * 0.55))
      elseif role == "industrial" then
        h = rng:int(h0, math.floor(h1 * 0.7))
      else
        h = rng:int(h0, h1)
      end
      h = math.min(h, ceiling - lot.y)
      local cx = lot.x0 + (spec.lot - w) // 2
      local cz = lot.z0 + (spec.lot - w2) // 2
      -- asteroid towers alternate: standing on the floor or hung from the rock above
      local inverted = spec.body == "asteroid" and (lot.gx + lot.gz) % 2 == 0
      local y0 = inverted and (ceiling - h) or (lot.y - 3)
      local form = M.form_of(style, d, lot.gx, lot.gz)
      local tl = M.tiers(form, w, w2, h + 3, inverted)
      for k, t in ipairs(tl) do
        local mn, mx = world_box({ cx + t.dx, y0 + t.dy, cz + t.dz }, { t.w, t.h, t.w2 }, kit, origin)
        solids[#solids + 1] = { mn, mx, kind = "tower", room = 1, district = d.id, tier = k, form = form,
                                apex = k == #tl or nil }
      end
      lot.tower = { cx, cz, w, w2, M.base_height(form, h), inv = inverted, form = form }
    elseif lot.type == "plaza" then
      local w = spec.lot - 4
      local mn, mx = world_box({ lot.x0 + 2, lot.y - 2, lot.z0 + 2 }, { w, 2, w }, kit, origin)
      solids[#solids + 1] = { mn, mx, kind = "platform", room = 1, district = d.id }
      if lot.coupling then
        local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
        couplings[#couplings + 1] = { district = lot.coupling, pos = { cx, mx[2] + 1.4, cz }, lot = { lot.gx, lot.gz } }
        d.coupling = #couplings
      end
      -- a monument in the corner of every plaza
      local bm, bx = world_box({ lot.x0 + 3, lot.y, lot.z0 + 3 }, { 3, rng:int(3, 7), 3 }, kit, origin)
      solids[#solids + 1] = { bm, bx, kind = "monument", room = 1, district = d.id }
    end
  end
  -- 4b. the skyline: an outer ring of lots round and behind the core, towers and blocks only (no rooms, no
  -- doors, no slots): a few hundred cheap collision boxes that make the city run on for kilometres. Its own
  -- rng, so the core of a seed is the same with or without it.
  local sky, skyby = {}, {}
  local skyn = 0
  local R = spec.ring or 0
  if R > 0 then
    local rr = saucer.rng.new(saucer.seed_child(seed, "ring", 0))
    local ccx, ccz, crad = M.city_centre(spec)
    for gz = 1, nz + R do
      for gx = 1 - R, nx + R do
        local rad = math.sqrt((gx - ccx) * (gx - ccx) + (gz - ccz) * (gz - ccz))
        local playable = gx >= 1 and gx <= nx and gz >= 1 and gz <= nz and rad <= crad
        local in_ring = rad > crad and rad <= crad + R + 0.2
        local approach = gz < 1 and math.abs(gx - ccx) < 2.2
        if not playable and in_ring and not approach then
          local bx, bz = (gx - 1 + 3 * R) // M.DISTRICT, (gz - 1) // M.DISTRICT
          local key = bz * 1000 + bx
          local sd = skyby[key]
          if not sd then
            sd = { id = M.SKY_BASE + #sky + 1, n = 0, sx = 0, sz = 0, sy = 0 }
            sky[#sky + 1] = sd
            skyby[key] = sd
          end
          local x0, z0 = lot_origin(spec, gx, gz)
          local y = lot_level(spec, rr, gx, gz)
          local roll = rr:int(1, 100)
          local edge = math.max(1, rad - crad)
          local fall = 1 - 0.5 * (edge - 1) / R
          local w, w2, h
          if roll <= 55 then
            w, w2 = rr:int(spec.tower[1], spec.tower[2]), rr:int(spec.tower[1], spec.tower[2])
            h = rr:int(spec.tower[3], spec.tower[4])
          elseif roll <= 78 then
            w, w2 = rr:int(14, 22), rr:int(14, 22)
            h = rr:int(10, 36)
          end
          if w then
            h = math.max(10, math.min(math.floor(h * fall), ceiling - y))
            local cx, cz = x0 + (spec.lot - w) // 2, z0 + (spec.lot - w2) // 2
            local inverted = spec.body == "asteroid" and (gx + gz) % 2 == 0
            local y0 = inverted and (ceiling - h) or (y - 3)
            local tl = M.tiers(style.form, w, w2, h + 3, inverted)
            for k, t in ipairs(tl) do
              local mn, mx = world_box({ cx + t.dx, y0 + t.dy, cz + t.dz }, { t.w, t.h, t.w2 }, kit, origin)
              solids[#solids + 1] = { mn, mx, kind = "tower", room = 1, district = sd.id, tier = k, form = style.form,
                                      apex = k == #tl or nil, outer = true }
            end
            sd.n = sd.n + 1
            skyn = skyn + #tl
            sd.sx, sd.sz, sd.sy = sd.sx + x0 + spec.lot / 2, sd.sz + z0 + spec.lot / 2, sd.sy + y
          end
        end
      end
    end
  end

  -- sky-bridges between towers or buildings side by side that rise high enough
  local bridges = 0
  local bridge_list = {}
  if spec.body ~= "asteroid" then
    for _, lot in ipairs(plan) do
      local e = lots[lot.gz * 1000 + lot.gx + 1]
      local function top_of(l)
        if l.tower then return not l.tower.inv and (l.y + l.tower[5]) or nil end
        if l.stack then return l.stack[l.hmax].cell[2] + M.STEP end
      end
      if e and top_of(lot) and top_of(e) and rng:int(1, 100) <= 45 and bridges < 40 then
        local yb = math.min(top_of(lot), top_of(e)) - 3
        -- from this building's wall to the next one's (the tower base or the hall footprint)
        local x0 = lot.tower and (lot.tower[1] + lot.tower[3]) or (lot.x0 + off + ux)
        local gap = (e.tower and e.tower[1] or (e.x0 + off)) - x0
        if gap > 2 then
          local mn, mx = world_box({ x0, yb, lot.z0 + spec.lot // 2 - 3 }, { gap, 2, 6 }, kit, origin)
          solids[#solids + 1] = { mn, mx, kind = "bridge", room = 1, district = districts[lot.d].id, fall = 1 + #bridge_list % 5 }
          bridge_list[#bridge_list + 1] = #solids
          bridges = bridges + 1
        end
      end
    end
  end

  -- 4c. transit: mag-rail lines on pylons along the east-west streets and down the central avenue (trains
  -- are drawn, not simulated: a function of the tick), and a lift shaft at every plaza (four posts; the cabin
  -- is drawn). The decks and pylons are real boxes: you fly under them, over them or into them.
  local rails, lifts = {}, {}
  if spec.rails then
    local P = spec.lot + spec.street
    local top = (spec.ground or 0) + (spec.tiers and spec.tiers[2] or 0) + spec.rails.height
    local x_lo = spec.margin + 2 -- the whole width of the volume, core and ring
    local x_hi = ext[1] - spec.margin - 2
    for _, row in ipairs(spec.rails.rows) do
      local zc = spec.approach + (row - 1) * P - spec.street // 2 -- the street just before the row
      -- one deck box per pitch, a pylon at every join
      local x = x_lo
      local line = { axis = 1, y = top, c = zc, a = x_lo, b = x_hi }
      while x < x_hi do
        local x2 = math.min(x + P, x_hi)
        local mn, mx = world_box({ x, top, zc - 0.75 }, { x2 - x, 0.3, 1.5 }, kit, origin)
        solids[#solids + 1] = { mn, mx, kind = "rail", room = 1, district = M.TRANSIT_BASE + (x - x_lo) // (4 * P) + 20 * _, outer = true }
        local pm, px = world_box({ x2 - 0.45, (spec.ground or 0) - 3, zc - 0.45 }, { 0.9, top - (spec.ground or 0) + 3, 0.9 }, kit, origin)
        solids[#solids + 1] = { pm, px, kind = "pylon", room = 1, district = M.TRANSIT_BASE + (x - x_lo) // (4 * P) + 20 * _, outer = true }
        x = x2
      end
      rails[#rails + 1] = line
    end
    -- the central avenue: north-south, down the middle of the core
    local xc = spec.margin + (R + nx // 2) * P
    local z_lo, z_hi = spec.approach + 4, ext[3] - spec.margin - 2
    local z = z_lo
    while z < z_hi do
      local z2 = math.min(z + P, z_hi)
      local mn, mx = world_box({ xc - 0.75, top + 6, z }, { 1.5, 0.3, z2 - z }, kit, origin)
      solids[#solids + 1] = { mn, mx, kind = "rail", room = 1, district = M.TRANSIT_BASE + 900 + (z - z_lo) // (4 * P), outer = true }
      local pm, px = world_box({ xc - 0.45, (spec.ground or 0) - 3, z2 - 0.45 }, { 0.9, top + 6 - (spec.ground or 0) + 3, 0.9 }, kit, origin)
      solids[#solids + 1] = { pm, px, kind = "pylon", room = 1, district = M.TRANSIT_BASE + 900 + (z - z_lo) // (4 * P), outer = true }
      z = z2
    end
    rails[#rails + 1] = { axis = 3, y = top + 6, c = xc, a = z_lo, b = z_hi }
  end
  for _, lot in ipairs(plan) do
    if lot.type == "plaza" and spec.lifts then
      local d = districts[lot.d]
      local cx, cz = lot.x0 + spec.lot - 12, lot.z0 + spec.lot - 12
      local y0, y1 = lot.y, ceiling - 4
      for _, q in ipairs({ { 0, 0 }, { 2.5, 0 }, { 0, 2.5 }, { 2.5, 2.5 } }) do
        local mn, mx = world_box({ cx + q[1], y0, cz + q[2] }, { 0.5, y1 - y0, 0.5 }, kit, origin)
        solids[#solids + 1] = { mn, mx, kind = "liftpost", room = 1, district = d.id }
      end
      lifts[#lifts + 1] = { district = d.id, pos = { origin[1] + (cx + 1.5) * kit.cell, 0, origin[3] + (cz + 1.5) * kit.cell },
                            y0 = origin[2] + y0 * kit.cell, y1 = origin[2] + y1 * kit.cell, phase = #lifts * 0.37 }
    end
  end

  -- 5. the rock of an asteroid: a shell of slabs with a mouth in front of the spaceport
  if spec.shell then
    local t, S = spec.shell, ext
    local function slab(cell, size) local mn, mx = world_box(cell, size, kit, origin) solids[#solids + 1] = { mn, mx, kind = "rock", room = 1, global = true } end
    slab({ 0, 0, 0 }, { S[1], t, S[3] })
    slab({ 0, S[2] - t, 0 }, { S[1], t, S[3] })
    slab({ 0, t, 0 }, { t, S[2] - 2 * t, S[3] })
    slab({ S[1] - t, t, 0 }, { t, S[2] - 2 * t, S[3] })
    slab({ t, t, S[3] - t }, { S[1] - 2 * t, S[2] - 2 * t, t })
    -- front wall, round the mouth
    local mx0 = plot.x0 + off - 16
    local mx1 = plot.x0 + off + ux + 16
    local my0, my1 = plot.y - 8, plot.y + 24
    slab({ t, t, 0 }, { mx0 - t, S[2] - 2 * t, t })
    slab({ mx1, t, 0 }, { S[1] - t - mx1, S[2] - 2 * t, t })
    slab({ mx0, t, 0 }, { mx1 - mx0, my0 - t, t })
    slab({ mx0, my1, 0 }, { mx1 - mx0, S[2] - t - my1, t })
  end

  -- 6. slots, gates, validation
  local rng2 = saucer.rng.new(saucer.seed_child(seed, "slots", 0))
  local vault
  local rd = nil
  for _, d in ipairs(districts) do if d.kind == "reactor" then rd = d end end
  for _, lot in ipairs(bybuilding) do
    if rd and lot.d == rd.id and lot.landmark == "reactor" then
      vault = lot.stack[-lot.umax]
      if lot.umax == 0 then vault = lot.stack[lot.hmax] end
    end
  end
  if vault and vault.kind ~= "entrance" then
    vault.kind = "vault"
    vault.calm = false
  end
  local slots = ruinm.slots(rng2, rooms, kit, origin, seed)
  -- landmarks pay better: the foundry and the palace hold big salvage, the archive many small finds
  for _, s in ipairs(slots) do
    local r = rooms[s.room]
    local d = r.district and districts[r.district]
    if d then
      s.district = d.id
      if d.kind == "foundry" or d.kind == "palace" then s.tier = math.min(5, (s.tier or 1) + 1) end
      if d.kind == "palace" or d.kind == "reactor" then s.tier = math.min(5, (s.tier or 1) + 1) end
    end
  end
  local clues = {}
  for _, lot in ipairs(bybuilding) do
    local d = districts[lot.d]
    -- a landmark's ground hall always holds something worth the trip (the archive: two things)
    if lot.landmark and lot.landmark ~= "spaceport" then
      local g = lot.stack[0]
      local mn, mx = ruinm.room_box(g, kit, origin)
      local n = lot.landmark == "archive" and 2 or 1
      local have = 0
      for _, s in ipairs(slots) do if s.room == g.id then have = have + 1 end end
      for k = have + 1, n do
        slots[#slots + 1] = { id = #slots + 1, room = g.id, pos = { (mn[1] + mx[1]) / 2 + (k - 1.5) * 10, mn[2] + kit.wall + 1.5, (mn[3] + mx[3]) / 2 },
                              max_size = 3, tier = d.kind == "archive" and 2 or 3, seed = saucer.seed_child(seed, "slot", #slots + 1),
                              district = d.id }
      end
      -- add-cities-2: the archive's ground hall also holds a record, a clue that reads in place
      if lot.landmark == "archive" then
        clues[#clues + 1] = { district = d.id, room = g.id, pos = { (mn[1] + mx[1]) / 2, mn[2] + kit.wall + 2.5, (mn[3] + mx[3]) / 2 + 6 } }
      end
    end
  end

  -- gates: every street door and tunnel mouth of an unpowered district is shut until its coupling is restored
  for _, lot in ipairs(bybuilding) do
    local d = districts[lot.d]
    if not d.powered and lot.stack[0].street_door then
      gates[#gates + 1] = { id = #gates + 1, district = d.id, door = "street", room = lot.stack[0].id,
                            box = gate_box(lot.stack[0], lot.stack[0].street_door, rooms, kit, origin) }
    end
  end
  for _, r in ipairs(rooms) do
    if r.tunnel then
      -- the tunnel's mouth on the unpowered side
      for _, dd in ipairs(doors) do
        if dd.a == r.id then
          local into = rooms[dd.b]
          local d = districts[into.district]
          if not d.powered then
            gates[#gates + 1] = { id = #gates + 1, district = d.id, door = "tunnel", room = r.id,
                                  box = gate_box(r, dd, rooms, kit, origin) }
          end
        end
      end
    end
  end

  local walls = ruinm.walls(rooms, doors, kit, origin)
  debris = ruinm.debris(rng2, rooms, doors, kit, origin)
  local ok, reach = ruinm.validate(rooms, doors, slots)
  if not ok then return nil, reach end
  local city = { body = spec.body, districts = {}, couplings = couplings, gates = gates, port = port, stats = {}, style = style }
  for _, d in ipairs(districts) do
    local x0, z0, x1, z1 = 1e9, 1e9, -1e9, -1e9
    for _, l in ipairs(d.lots) do
      local q = lots[l[2] * 1000 + l[1]]
      x0, z0, x1, z1 = math.min(x0, q.x0 - spec.street // 2), math.min(z0, q.z0 - spec.street // 2), math.max(x1, q.x0 + spec.lot + spec.street // 2), math.max(z1, q.z0 + spec.lot + spec.street // 2)
    end
    d.box = { x0, z0, x1, z1 }
    local lot = lots[d.center[2] * 1000 + d.center[1]]
    local cx = origin[1] + (lot.x0 + spec.lot / 2) * kit.cell
    local cz = origin[3] + (lot.z0 + spec.lot / 2) * kit.cell
    city.districts[d.id] = { id = d.id, kind = d.kind, label = d.label, powered = d.powered, coupling = d.coupling,
                             pos = { cx, origin[2] + lot.y * kit.cell, cz }, drum = d.drum, crater = d.crater,
                             role = d.role, ring = d.ring, wedge = d.wedge,
                             value = d.value, archetype = d.archetype, dx = d.dx, dz = d.dz, box = d.box and { origin[1] + d.box[1] * kit.cell, origin[3] + d.box[2] * kit.cell, origin[1] + d.box[3] * kit.cell, origin[3] + d.box[4] * kit.cell } }
  end
  city.rails, city.lifts, city.bridges, city.clues = rails, lifts, bridge_list, clues
  -- add-alien-cities §4.3: sky lanes, the builders' flight corridors between neighbouring districts, high over the
  -- towers (drawn as light pulses travelling along them; nothing in the sim)
  city.lanes = M.lanes(city.districts, origin, kit, math.min(ceiling - 4, (spec.ground or 0) + spec.tower[4] + 6))
  city.skyline = {}
  for _, sd in ipairs(sky) do
    if sd.n > 0 then
      city.skyline[#city.skyline + 1] = { id = sd.id, towers = sd.n,
        pos = { origin[1] + sd.sx / sd.n * kit.cell, origin[2] + sd.sy / sd.n * kit.cell, origin[3] + sd.sz / sd.n * kit.cell } }
    end
  end
  city.stats = { rooms = #rooms, doors = #doors, walls = #walls, solids = #solids, slots = #slots, gates = #gates,
                 rails = #rails, lifts = #lifts, districts = #districts, skyline = #city.skyline, skyline_solids = skyn, buildings = #bybuilding, bridges = bridges }
  local tint = civ and civ.tint
  return { seed = seed, kit = kit.id, rooms = rooms, doors = doors, slots = slots, walls = walls, debris = debris, solids = solids,
           origin = origin, hash = ruinm.layout_hash(rooms, doors, solids), reach = reach, city = city, tint = tint }
end

return M
