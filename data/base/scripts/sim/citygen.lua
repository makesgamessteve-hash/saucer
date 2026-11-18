-- SPDX-License-Identifier: MIT
-- City generation (OpenSpec add-cities). A city is a hierarchy, all of it a pure function of the site seed:
--   city -> districts (3 x 3 lots each, one landmark per special district)
--        -> lots (blocks: a tower, an enterable building, a plaza or nothing)
--        -> buildings (a stack of great halls joined by hatches, undercity levels below the street,
--           closets for the Seat, a spire on top) and tunnels under the streets between neighbours.
-- The result has the shape of a derelict (sim/ruin.lua): rooms, doors, walls, slots, solids and debris, so
-- physics, the beam, sentries, saves and the renderer treat it like any other site, plus `city`: the plan
-- (districts, landmarks, power couplings, gates) the map, the grid and the gravity rules read.
-- Three bodies share the generator and differ in their plan (kits/city_<body>.lua, field `city`):
--   planet   a horizon-wide grid of towers, deep undercity, strong gravity
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
  return spec.margin + (gx - 1) * (spec.lot + spec.street) + spec.street // 2,
         spec.approach + (gz - 1) * (spec.lot + spec.street)
end

-- the cell extent (x, y, z) of a city kit's build volume
function M.extent_cells(kit)
  local s = kit.city
  local p = s.lot + s.street
  return { 2 * s.margin + s.lots[1] * p, kit.grid[2], s.approach + s.lots[2] * p + s.margin }
end

-- ------------------------------------------------------------------ the plan
-- district index of a lot and the number of districts
local function district_of(spec, gx, gz)
  local dx, dz = (gx - 1) // M.DISTRICT, (gz - 1) // M.DISTRICT
  local nd = (spec.lots[1] + M.DISTRICT - 1) // M.DISTRICT
  return dz * nd + dx + 1
end
M.district_of = district_of

function M.plan(rng, kit)
  local spec = kit.city
  local nx, nz = spec.lots[1], spec.lots[2]
  local nd = (nx + M.DISTRICT - 1) // M.DISTRICT
  local ndz = (nz + M.DISTRICT - 1) // M.DISTRICT
  local districts = {}
  for dz = 1, ndz do
    for dx = 1, nd do
      local gx0, gz0 = (dx - 1) * M.DISTRICT + 1, (dz - 1) * M.DISTRICT + 1
      local d = { id = #districts + 1, dx = dx, dz = dz, lots = {} }
      for gz = gz0, math.min(gz0 + M.DISTRICT - 1, nz) do
        for gx = gx0, math.min(gx0 + M.DISTRICT - 1, nx) do d.lots[#d.lots + 1] = { gx, gz } end
      end
      d.center = d.lots[(#d.lots + 1) // 2]
      districts[#districts + 1] = d
    end
  end
  -- the spaceport is the district of the front-centre lot; the rest of the landmarks go to random districts
  local port_lot = { nx // 2 + 1, 1 }
  local pd = district_of(spec, port_lot[1], port_lot[2])
  local order = {}
  for i = 1, #districts do if i ~= pd then order[#order + 1] = i end end
  for k = #order, 2, -1 do
    local j = rng:int(1, k)
    order[k], order[j] = order[j], order[k]
  end
  districts[pd].kind = "spaceport"
  districts[pd].center = port_lot
  local marks = { "reactor", "archive", "foundry", "garden", "palace" }
  for i, di in ipairs(order) do
    districts[di].kind = marks[i] or M.FILLER[rng:int(1, #M.FILLER)]
  end
  -- body-specific heart: the drum of an asteroid, the crater dome of a moon
  local mid = district_of(spec, (nx + 1) // 2, (nz + 1) // 2 + 1)
  if spec.body == "asteroid" and mid ~= pd then districts[mid].kind, districts[mid].drum = "reactor", true end
  if spec.body == "moon" and mid ~= pd then districts[mid].kind, districts[mid].crater = "garden", true end
  for _, d in ipairs(districts) do
    d.landmark = d.kind == "spaceport" or d.kind == "reactor" or d.kind == "archive" or d.kind == "foundry"
      or d.kind == "garden" or d.kind == "palace"
    d.label = string.format("D%d %s", d.id, M.LABEL[d.drum and "drum" or d.crater and "crater" or d.kind])
    d.powered = d.kind == "spaceport"
  end
  return districts, pd
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
  local districts, port = M.plan(rng, kit)
  local ext = M.extent_cells(kit)
  local rooms, doors, solids, debris = {}, {}, {}, {}
  local lots, bybuilding = {}, {}
  local gates, couplings = {}, {}
  local ceiling = kit.grid[2] - (spec.shell or 2) - 2
  local nx, nz = spec.lots[1], spec.lots[2]
  local ux, uz = M.HALL[1], M.HALL[3]
  local off = (spec.lot - ux) // 2

  -- 1. the lots: type, level, stack
  local plan = {}
  for gz = 1, nz do
    for gx = 1, nx do
      local d = districts[district_of(spec, gx, gz)]
      local lot = { gx = gx, gz = gz, d = d.id, y = lot_level(spec, rng, gx, gz), type = pick_type(rng, spec.mix) }
      lot.x0, lot.z0 = lot_origin(spec, gx, gz)
      if d.center[1] == gx and d.center[2] == gz then lot.type, lot.landmark = "building", d.kind end
      plan[#plan + 1] = lot
      lots[gz * 1000 + gx] = lot
    end
  end
  -- the crater of a moon: nothing stands within `crater` lots of its dome
  if spec.crater then
    local cd = districts[district_of(spec, (nx + 1) // 2, (nz + 1) // 2 + 1)]
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

  -- the front-centre lot holds the spaceport hangar: room 1, its door on the -z face
  local plot = lots[1 * 1000 + nx // 2 + 1]
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
      local h = rng:int(spec.tower[3], spec.tower[4])
      h = math.min(h, ceiling - lot.y)
      local cx = lot.x0 + (spec.lot - w) // 2
      local cz = lot.z0 + (spec.lot - w2) // 2
      local mn, mx = world_box({ cx, lot.y - 3, cz }, { w, h + 3, w2 }, kit, origin)
      solids[#solids + 1] = { mn, mx, kind = "tower", room = 1 }
      lot.tower = { cx, cz, w, w2, h }
    elseif lot.type == "plaza" then
      local w = spec.lot - 4
      local mn, mx = world_box({ lot.x0 + 2, lot.y - 2, lot.z0 + 2 }, { w, 2, w }, kit, origin)
      solids[#solids + 1] = { mn, mx, kind = "platform", room = 1 }
      if lot.coupling then
        local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
        couplings[#couplings + 1] = { district = lot.coupling, pos = { cx, mx[2] + 1.4, cz }, lot = { lot.gx, lot.gz } }
        d.coupling = #couplings
      end
      -- a monument in the corner of every plaza
      local bm, bx = world_box({ lot.x0 + 3, lot.y, lot.z0 + 3 }, { 3, rng:int(3, 7), 3 }, kit, origin)
      solids[#solids + 1] = { bm, bx, kind = "monument", room = 1 }
    end
  end
  -- sky-bridges between towers or buildings side by side that rise high enough
  local bridges = 0
  if spec.body ~= "asteroid" then
    for _, lot in ipairs(plan) do
      local e = lots[lot.gz * 1000 + lot.gx + 1]
      local function top_of(l)
        if l.tower then return l.y + l.tower[5] end
        if l.stack then return l.stack[l.hmax].cell[2] + M.STEP end
      end
      if e and top_of(lot) and top_of(e) and rng:int(1, 100) <= 45 and bridges < 40 then
        local yb = math.min(top_of(lot), top_of(e)) - 3
        local x0 = lot.x0 + spec.lot - 2
        local gap = e.x0 + 2 - x0
        local mn, mx = world_box({ x0, yb, lot.z0 + spec.lot // 2 - 3 }, { gap, 2, 6 }, kit, origin)
        solids[#solids + 1] = { mn, mx, kind = "bridge", room = 1 }
        bridges = bridges + 1
      end
    end
  end

  -- 5. the rock of an asteroid: a shell of slabs with a mouth in front of the spaceport
  if spec.shell then
    local t, S = spec.shell, ext
    local function slab(cell, size) local mn, mx = world_box(cell, size, kit, origin) solids[#solids + 1] = { mn, mx, kind = "rock", room = 1 } end
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
  local city = { body = spec.body, districts = {}, couplings = couplings, gates = gates, port = port, stats = {} }
  for _, d in ipairs(districts) do
    local lot = lots[d.center[2] * 1000 + d.center[1]]
    local cx = origin[1] + (lot.x0 + spec.lot / 2) * kit.cell
    local cz = origin[3] + (lot.z0 + spec.lot / 2) * kit.cell
    city.districts[d.id] = { id = d.id, kind = d.kind, label = d.label, powered = d.powered, coupling = d.coupling,
                             pos = { cx, origin[2] + lot.y * kit.cell, cz }, drum = d.drum, crater = d.crater }
  end
  city.stats = { rooms = #rooms, doors = #doors, walls = #walls, solids = #solids, slots = #slots, gates = #gates,
                 districts = #districts, buildings = #bybuilding, bridges = bridges }
  local tint = civ and civ.tint
  return { seed = seed, kit = kit.id, rooms = rooms, doors = doors, slots = slots, walls = walls, debris = debris, solids = solids,
           origin = origin, hash = ruinm.layout_hash(rooms, doors, solids), reach = reach, city = city, tint = tint }
end

return M
