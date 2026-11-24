-- SPDX-License-Identifier: MIT
-- Walkable trader-station interiors (OpenSpec add-pocket-station-visits).
-- generate(seed) lays out one deck from the station kit's `walk` section
-- (kits/station.lua): a concourse spine with the arrival hangar at its start,
-- a market hall of stalls, a bar down a narrow passage and a second hangar
-- (at the far end, or off a side passage). Everything is axis-aligned boxes
-- on a flat floor (y = 0) in station-local meters, so walking collides in 2D
-- like the Villa's decks. Pure and deterministic: the same seed gives the
-- same layout (and hash) on every platform. Derived data, never saved.
local data = require("lib.data")
local sm = saucer.math
local M = {}

M.WALL = 0.3        -- wall slab thickness (centred on the box faces)
M.DOOR_DEPTH = 0.8  -- how far a doorway's walk box reaches into each side
M.BODY_R = 0.3

function M.kit() return data.load("kits/station.lua") end
function M.folk() return data.load("station/folk.lua") end

local function rint(rng, r)
  if type(r) == "number" then return r end
  return rng:int(r[1], r[2])
end

local function area(L, kind, name, x0, z0, x1, z1, h)
  local a = { id = #L.areas + 1, kind = kind, name = name, box = { x0, z0, x1, z1 }, h = h }
  L.areas[a.id] = a
  return a
end

-- a doorway between areas a and b in the wall plane axis = at (axis 1: a
-- plane of constant x, axis 3: constant z), open over [lo, hi] on the other axis
local function door(L, a, b, axis, at, lo, hi, h)
  local d = { id = #L.doors + 1, a = a.id, b = b.id, axis = axis, at = at, lo = lo, hi = hi, h = h }
  L.doors[d.id] = d
  return d
end

function M.door_box(d)
  local e = M.DOOR_DEPTH
  if d.axis == 1 then return { d.at - e, d.lo, d.at + e, d.hi } end
  return { d.lo, d.at - e, d.hi, d.at + e }
end

function M.door_center(d)
  if d.axis == 1 then return { d.at, (d.lo + d.hi) / 2 } end
  return { (d.lo + d.hi) / 2, d.at }
end

function M.center(a)
  local b = a.box
  return { (b[1] + b[3]) / 2, (b[2] + b[4]) / 2 }
end

local function solid_box(L, x0, z0, x1, z1, h, extra)
  local s = { kind = "box", box = { math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1) }, h = h }
  for k, v in pairs(extra or {}) do s[k] = v end
  L.solids[#L.solids + 1] = s
  return s
end

local function solid_circle(L, x, z, r, h, extra)
  local s = { kind = "circle", c = { x, z }, r = r, h = h }
  for k, v in pairs(extra or {}) do s[k] = v end
  L.solids[#L.solids + 1] = s
  return s
end

local function prop(L, kind, t)
  t.kind = kind
  L.props[#L.props + 1] = t
  return t
end

local function species_of(folk, id)
  for i, s in ipairs(folk.species) do
    if s.id == id then return i end
  end
  return 1
end

-- a crowd species index that is never the thief's
local function crowd(folk, rng)
  local n = 0
  for _, s in ipairs(folk.species) do if not s.thief then n = n + 1 end end
  local k = rng:int(1, n)
  for i, s in ipairs(folk.species) do
    if not s.thief then
      k = k - 1
      if k == 0 then return i end
    end
  end
  return 1
end

-- a hangar: pad in the middle, crates and fuel tanks along the side walls,
-- open to space on its `mouth` face (axis, sign)
local function furnish_hangar(L, a, rng, mouth_axis, mouth_sign)
  local b = a.box
  local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
  a.pad = { cx, cz }
  a.mouth = { axis = mouth_axis, sign = mouth_sign }
  prop(L, "pad", { at = { cx, cz }, r = 13.5 })
  prop(L, "gantry", { at = { cx, cz }, axis = mouth_axis, len = (mouth_axis == 1) and (b[3] - b[1]) or (b[4] - b[2]),
                      y = a.h - 2.5 })
  -- the side walls run along the mouth axis; stack cargo against them
  local along = mouth_axis
  local across = mouth_axis == 1 and 3 or 1
  local lo_a, hi_a = b[along == 1 and 1 or 2], b[along == 1 and 3 or 4]
  local lo_c, hi_c = b[across == 1 and 1 or 2], b[across == 1 and 3 or 4]
  for _, side in ipairs({ -1, 1 }) do
    local wall = side < 0 and lo_c or hi_c
    local n = rng:int(2, 4)
    for k = 1, n do
      local t = (k - 0.5) / n
      local u = lo_a + 6 + (hi_a - lo_a - 12) * t + rng:int(-1, 1)
      local s = 1.4 + rng:int(0, 4) * 0.25
      local v = wall - side * (s / 2 + 0.6)
      local x, z = u, v
      if along == 3 then x, z = v, u end
      local stack = rng:int(1, 3)
      solid_box(L, x - s / 2, z - s / 2, x + s / 2, z + s / 2, s * stack, { look = "crate", stack = stack,
                tint = rng:int(1, 3) })
    end
    -- a fuel tank in the corner by the inner wall
    local u = mouth_sign > 0 and (lo_a + 2.2) or (hi_a - 2.2)
    local v = wall - side * 2.2
    local x, z = u, v
    if along == 3 then x, z = v, u end
    solid_circle(L, x, z, 1.3, 5.0, { look = "tank" })
  end
end

-- market stalls in two rows along the walls that run away from the door,
-- keepers behind their counters, customers' spots in front
local function furnish_market(L, a, rng, folk, door_x)
  local b = a.box
  local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
  local far = door_x < cx and b[3] or b[1]
  local n = rint(rng, M.kit().walk.market.stalls)
  -- vendors: everyone marked `always`, then a shuffled pick of the rest
  local pool, picked = {}, {}
  for _, v in ipairs(folk.vendors) do
    if v.always then picked[#picked + 1] = v else pool[#pool + 1] = v end
  end
  while #picked < n and #pool > 0 do picked[#picked + 1] = table.remove(pool, rng:int(1, #pool)) end
  -- deterministic shuffle of the stall order
  for i = #picked, 2, -1 do
    local j = rng:int(1, i)
    picked[i], picked[j] = picked[j], picked[i]
  end
  local rows = { { wall = b[2], dir = 1 }, { wall = b[4], dir = -1 } }
  local per = { (#picked + 1) // 2, #picked // 2 }
  local x_lo, x_hi = math.min(door_x, far), math.max(door_x, far)
  local k = 0
  for r, row in ipairs(rows) do
    for i = 1, per[r] do
      k = k + 1
      local v = picked[k]
      local t = (i - 0.5) / per[r]
      local sx = x_lo + 4 + (x_hi - x_lo - 7) * t
      if door_x > cx then sx = x_hi - 4 - (x_hi - x_lo - 7) * t end
      local cz0 = row.wall + row.dir * 1.6
      local cz1 = cz0 + row.dir * 1.0
      solid_box(L, sx - 1.6, cz0, sx + 1.6, cz1, 1.05, { look = "counter", color = v.color })
      local stall = { id = #L.stalls + 1, vendor = v.id, name = v.name, area = a.id,
                      keeper = { sx, row.wall + row.dir * 0.85 }, yaw = row.dir > 0 and 0 or sm.pi,
                      spot = { sx, cz1 + row.dir * 1.7 }, species = species_of(folk, v.species), color = v.color }
      L.stalls[stall.id] = stall
      prop(L, "awning", { at = { sx, (cz0 + cz1) / 2 }, w = 3.6, dir = row.dir, color = v.color })
      prop(L, "goods", { at = { sx, (cz0 + cz1) / 2 }, w = 3.0, dir = row.dir, seed = rng:int(1, 9999), color = v.color })
    end
  end
  prop(L, "holosign", { at = { cx, cz }, y = a.h - 3.5, color = { 1, 0.75, 0.3 } })
  for _ = 1, 2 do
    local ox = (rng:int(0, 1) * 2 - 1) * 3.5
    prop(L, "planter", { at = { cx + ox, cz + (rng:int(0, 1) * 2 - 1) * 3.0 }, r = 0.7 })
  end
  a.aisle = { cx, cz }
end

-- the bar: a counter by the far wall with the bartender (also the fence),
-- stools, tables with patrons and a neon strip
local function furnish_bar(L, a, rng, folk, door_x)
  local b = a.box
  local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
  local dir = door_x < cx and 1 or -1       -- from the door towards the counter
  local wall = dir > 0 and b[3] or b[1]
  local half = (b[4] - b[2]) * 0.3
  local c0 = wall - dir * 1.8
  local c1 = c0 - dir * 0.9
  solid_box(L, c0, cz - half, c1, cz + half, 1.1, { look = "bar_counter" })
  L.bar = { area = a.id, keeper = { wall - dir * 0.9, cz }, yaw = dir > 0 and -sm.pi / 2 or sm.pi / 2,
            spot = { c1 - dir * 1.1, cz }, species = crowd(folk, rng), patrons = {} }
  prop(L, "shelf", { at = { wall - dir * 0.25, cz }, len = half * 2, dir = dir })
  prop(L, "neon", { at = { wall - dir * 0.2, cz }, len = half * 2.2, y = a.h - 0.8, dir = dir })
  for i = -1, 1, 2 do
    prop(L, "stool", { at = { c1 - dir * 0.55, cz + i * half * 0.6 } })
    L.bar.patrons[#L.bar.patrons + 1] = { pos = { c1 - dir * 0.55, cz + i * half * 0.6 }, yaw = dir > 0 and sm.pi / 2 or -sm.pi / 2,
      species = crowd(folk, rng), line = rng:int(1, #folk.chatter), seated = true }
  end
  local nt = rint(rng, M.kit().walk.bar.tables)
  for k = 1, nt do
    local side = k % 2 == 0 and 1 or -1
    local tx = b[1] + (b[3] - b[1]) * (0.25 + 0.25 * ((k - 1) // 2))
    if dir < 0 then tx = b[3] - (tx - b[1]) end
    local tz = cz + side * math.max(2.6, (b[4] - b[2]) / 2 - 2.0)
    solid_circle(L, tx, tz, 0.65, 0.8, { look = "table" })
    L.bar.patrons[#L.bar.patrons + 1] = { pos = { tx, tz + side * 0.95 }, yaw = side > 0 and sm.pi or 0,
      species = crowd(folk, rng), line = rng:int(1, #folk.chatter), seated = true }
    if rng:int(0, 1) == 1 then
      L.bar.patrons[#L.bar.patrons + 1] = { pos = { tx + 0.95, tz }, yaw = -sm.pi / 2, species = crowd(folk, rng),
        line = rng:int(1, #folk.chatter), seated = true }
    end
    prop(L, "lamp", { at = { tx, tz }, y = a.h - 0.6 })
  end
  a.aisle = { cx, cz }
end

-- ---------------------------------------------------------------------------------------------------
-- add-huge-stations: the dressing of the walk-in path. A child rng (the layout's own stream is untouched):
-- the arrival and far hangars get ceiling cranes on rails, fuel lines and hose reels, floor lanes, wall
-- cradles with parked craft, a catwalk with a control booth and a lit bay sign; the concourse gets
-- vending machines, kiosks, ad panels, benches, banners, drones and skylights; the market and the bar a
-- few banners. Mostly props (no collision); machines and kiosks are solid, clear of every doorway.
-- ---------------------------------------------------------------------------------------------------
local function near_door(L, axis, side_at, z, pad)
  for _, d in ipairs(L.doors) do
    if d.axis == axis and math.abs(d.at - side_at) < 0.5 and z > d.lo - pad and z < d.hi + pad then return true end
  end
  return false
end

local AD_COLORS = { { 1.0, 0.45, 0.2 }, { 0.3, 0.85, 1.0 }, { 0.95, 0.85, 0.25 }, { 0.85, 0.35, 0.9 }, { 0.4, 1.0, 0.55 } }

local function dress_spine(L, a, rng)
  local b = a.box
  local sw = (b[3] - b[1]) / 2
  local len = b[4]
  for _, side in ipairs({ -1, 1 }) do
    local wall = side * sw
    local z = 3.0
    while z < len - 2.5 do
      if not near_door(L, 1, wall, z, 2.6) and not near_door(L, 1, wall, z + 1.6, 2.6) then
        local k = rng:int(1, 6)
        if k == 1 then
          solid_box(L, math.min(wall, wall - side * 0.9), z - 0.45, math.max(wall, wall - side * 0.9), z + 0.45, 1.9,
                    { look = "vending", color = AD_COLORS[rng:int(1, #AD_COLORS)], face = -side })
          z = z + 2.2
        elseif k == 2 then
          prop(L, "ad_panel", { at = { wall - side * 0.12, z }, face = -side, w = 3.0, color = AD_COLORS[rng:int(1, #AD_COLORS)],
                                seed = rng:int(1, 999) })
          z = z + 4.2
        elseif k == 3 then
          solid_circle(L, wall - side * 1.1, z, 0.42, 1.5, { look = "kiosk", color = AD_COLORS[rng:int(1, #AD_COLORS)], face = -side })
          z = z + 2.6
        elseif k == 4 then
          prop(L, "bench", { at = { wall - side * 0.55, z }, len = 2.2, side = side })
          z = z + 3.0
        elseif k == 5 then
          prop(L, "planter", { at = { wall - side * 0.9, z }, r = 0.6 })
          z = z + 2.0
        else
          z = z + 2.4
        end
      else
        z = z + 1.2
      end
    end
  end
  -- banners hanging from the ceiling along the middle, skylights between them
  local z = 5.0
  while z < len - 3 do
    local c = AD_COLORS[rng:int(1, #AD_COLORS)]
    prop(L, "banner", { at = { (rng:int(0, 1) * 2 - 1) * (sw * 0.45), z }, y = a.h, color = c, axis = 3 })
    prop(L, "skylight", { at = { 0, z + 3.5 }, y = a.h, w = sw * 1.0 })
    z = z + 7.0
  end
  -- two maintenance drones hover mid-concourse
  for _ = 1, 2 do
    prop(L, "drone", { at = { rng:int(-2, 2), 3 + rng:int(0, math.max(1, math.floor(len - 6))) }, y = 4.2 + rng:int(0, 8) * 0.1,
                       phase = rng:int(0, 999) / 1000 })
  end
end

local function dress_hangar(L, a, rng, num)
  local b = a.box
  local m = a.mouth
  local along, across = m.axis, m.axis == 1 and 3 or 1
  local lo_a, hi_a = b[along == 1 and 1 or 2], b[along == 1 and 3 or 4]
  local lo_c, hi_c = b[across == 1 and 1 or 2], b[across == 1 and 3 or 4]
  local function xz(u, v) if along == 1 then return { u, v } else return { v, u } end end
  -- two ceiling cranes on rails; the hooks hang at their own height
  for k = 1, 2 do
    local u = lo_a + (hi_a - lo_a) * (k == 1 and 0.3 or 0.7) + rng:int(-2, 2)
    prop(L, "rail_crane", { at = xz(u, (lo_c + hi_c) / 2), axis = along, y = a.h, span = hi_c - lo_c, hook = rng:int(4, 12) / 10,
                            along = { lo_a, hi_a } })
  end
  -- fuel lines on the floor along both walls, a hose reel on each
  for _, side in ipairs({ -1, 1 }) do
    local v = (side < 0 and lo_c or hi_c) - side * 3.6
    prop(L, "fuelline", { at = xz((lo_a + hi_a) / 2, v), axis = along, len = hi_a - lo_a - 6, side = side })
    prop(L, "hose_reel", { at = xz(lo_a + 4 + rng:int(0, 3), (side < 0 and lo_c or hi_c) - side * 0.9), axis = along, side = side })
  end
  -- floor lanes: lit guide lines from the door toward the pad
  prop(L, "lane", { at = xz(a.pad and (along == 1 and a.pad[1] or a.pad[2]) or (lo_a + hi_a) / 2, (lo_c + hi_c) / 2), axis = along,
                    from = lo_a + 1, to = hi_a - 1, mouth = m.sign })
  -- two wall cradles with parked craft, high above the crates
  for k, side in ipairs({ -1, 1 }) do
    local u = lo_a + (hi_a - lo_a) * (0.35 + 0.3 * rng:int(0, 1))
    local v = (side < 0 and lo_c or hi_c) - side * 1.3
    prop(L, "wall_ship", { at = xz(u, v), axis = along, side = side, y = a.h * 0.46, yaw = rng:int(0, 1) == 0 and 0 or sm.pi,
                           color = rng:int(0, 1) == 0 and { 0.62, 0.64, 0.7 } or { 0.7, 0.5, 0.32 }, empty = (k == 2 and rng:int(0, 2) == 0) })
  end
  -- a catwalk along one wall, with a control booth at its end
  local side = rng:int(0, 1) * 2 - 1
  local v = (side < 0 and lo_c or hi_c) - side * 0.9
  prop(L, "catwalk", { at = xz((lo_a + hi_a) / 2, v), axis = along, side = side, len = (hi_a - lo_a) - 8, y = a.h * 0.38 })
  prop(L, "booth", { at = xz(hi_a - 5 - (hi_a - lo_a) * 0.0, (side < 0 and lo_c or hi_c) - side * 2.2), axis = along, side = side, y = a.h * 0.38 })
  -- the bay's number, lit, high on the wall facing the pad
  prop(L, "bay_sign", { at = xz(m.sign > 0 and lo_a or hi_a, (lo_c + hi_c) / 2), axis = along, face = m.sign, y = a.h * 0.62, text = string.format("%02d", num), });
  -- tool carts by the door side
  for _ = 1, 2 do
    local u = (m.sign > 0 and lo_a or hi_a) - m.sign * 0
    u = u + (m.sign > 0 and 1 or -1) * rng:int(2, 4)
    local v2 = (rng:int(0, 1) == 0 and lo_c or hi_c) + (rng:int(0, 1) == 0 and 1 or -1) * 5
    v2 = math.max(lo_c + 4.5, math.min(hi_c - 4.5, (lo_c + hi_c) / 2 + rng:int(-12, 12)))
    prop(L, "cart", { at = xz(u, v2), yaw = rng:float() * sm.tau })
  end
end

local function dress_room(L, a, rng)
  local b = a.box
  local n = a.kind == "market" and 3 or 2
  for _ = 1, n do
    prop(L, "banner", { at = { rng:int(math.floor(b[1] + 2), math.floor(b[3] - 2)), rng:int(math.floor(b[2] + 2), math.floor(b[4] - 2)) },
                        y = a.h, color = AD_COLORS[rng:int(1, #AD_COLORS)], axis = rng:int(0, 1) * 2 + 1 })
  end
end

-- the lit number of a trader station's hangar bay (1 = the arrival hangar, whose number is also over the
-- mouth outside, sim/stationhull.lua)
function M.bay_number(seed, bay)
  if (bay or 1) == 1 then return seed % 17 + 1 end
  return (seed // 17) % 23 + 1
end

-- the dressing of a finished layout; its own stream, so the layout above is the same with or without it
function M.dress(L, seed)
  local rng = saucer.rng.new(saucer.seed_child(seed, "dress", 1))
  for _, a in ipairs(L.areas) do
    if a.kind == "hangar" and a.mouth then dress_hangar(L, a, rng, M.bay_number(seed, a.bay))
    elseif a.name == "Concourse" then dress_spine(L, a, rng)
    elseif a.kind == "market" or a.kind == "bar" then dress_room(L, a, rng) end
  end
end


-- ---------------------------------------------------------------------------------------------------
-- add-alien-stations: the alien wing. Off the market's far wall a chain of passages (straight or doglegged,
-- angled ribs inside) and chambers grows, branching now and then: atriums with growth pillars, brood halls
-- of cocoon racks, glowing gardens, glyph shrines with a floating monolith, and vertical shafts with ledges
-- climbing the walls. Named and coloured by the station's family. Its own rng stream, after the rest of the
-- layout, so the concourse, the market, the bar and the hangars are as they were. Everything stays on the one
-- walkable floor; the routes from each chamber's middle to its doorways are kept clear.
-- ---------------------------------------------------------------------------------------------------
M.LOOKS = { "atrium", "shaft", "brood", "garden", "shrine" }

local function overlaps(L, b, extra)
  local m = 0.01
  for _, a in ipairs(L.areas) do
    local o = a.box
    if b[1] < o[3] - m and b[3] > o[1] + m and b[2] < o[4] - m and b[4] > o[2] + m then return true end
  end
  for _, o in ipairs(extra) do
    if b[1] < o[3] - m and b[3] > o[1] + m and b[2] < o[4] - m and b[4] > o[2] + m then return true end
  end
  return false
end

-- a box `len` out of face (axis, sign) of box b, `half` wide about u on the other axis -> box, the face's plane
local function out_box(b, axis, sign, u, len, half)
  if axis == 1 then
    local f = sign > 0 and b[3] or b[1]
    return { math.min(f, f + sign * len), u - half, math.max(f, f + sign * len), u + half }, f
  end
  local f = sign > 0 and b[4] or b[2]
  return { u - half, math.min(f, f + sign * len), u + half, math.max(f, f + sign * len) }, f
end

-- the span of box b along the axis that is not `axis`
local function span(b, axis)
  if axis == 1 then return b[2], b[4] end
  return b[1], b[3]
end

-- the space beyond every hangar's mouth stays open (you see space through it)
local function mouth_zones(L)
  local out = {}
  for _, a in ipairs(L.areas) do
    if a.kind == "hangar" and a.mouth then
      local b = a.box
      local zb = out_box(b, a.mouth.axis, a.mouth.sign, (a.mouth.axis == 1) and (b[2] + b[4]) / 2 or (b[1] + b[3]) / 2, 400,
                         ((a.mouth.axis == 1) and (b[4] - b[2]) or (b[3] - b[1])) / 2 + 40)
      out[#out + 1] = zb
    end
  end
  return out
end

-- distance from p to the segment a-b (2D)
local function seg_dist(p, a, b)
  local dx, dz = b[1] - a[1], b[2] - a[2]
  local l2 = dx * dx + dz * dz
  local t = l2 > 0 and math.max(0, math.min(1, ((p[1] - a[1]) * dx + (p[2] - a[2]) * dz) / l2)) or 0
  local ex, ez = p[1] - (a[1] + dx * t), p[2] - (a[2] + dz * t)
  return sm.sqrt(ex * ex + ez * ez)
end

-- is (x, z) at least r clear of the walks from the chamber's middle to its doorways (and of the walls)?
local function off_paths(L, a, x, z, r)
  local b = a.box
  if x < b[1] + r + 0.4 or x > b[3] - r - 0.4 or z < b[2] + r + 0.4 or z > b[4] - r - 0.4 then return false end
  local c = M.center(a)
  for _, d in ipairs(L.doors) do
    if d.a == a.id or d.b == a.id then
      if seg_dist({ x, z }, c, M.door_center(d)) < r + 1.6 then return false end
      local db = M.door_box(d)
      if x > db[1] - r - 1.5 and x < db[3] + r + 1.5 and z > db[2] - r - 1.5 and z < db[4] + r + 1.5 then return false end
    end
  end
  for _, s in ipairs(L.solids) do
    if s.kind == "circle" then
      local dx, dz = x - s.c[1], z - s.c[2]
      if dx * dx + dz * dz < (r + s.r + 0.8) * (r + s.r + 0.8) then return false end
    end
  end
  return true
end
M.off_paths = off_paths

-- fill a chamber by its look (props for the view, a few solids)
local function furnish_chamber(L, a, rng, W)
  local b = a.box
  local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
  local sx, sz = b[3] - b[1], b[4] - b[2]
  local look = a.alien
  local function try_circle(n, r0, r1, h, extra, ring)
    local placed = 0
    for _ = 1, n * 6 do
      if placed >= n then break end
      local x, z
      if ring then
        local ang = rng:float() * sm.tau
        x, z = cx + sm.sin(ang) * sx * ring, cz + sm.cos(ang) * sz * ring
      else
        x, z = b[1] + rng:float() * sx, b[2] + rng:float() * sz
      end
      local r = r0 + (r1 - r0) * rng:float()
      if off_paths(L, a, x, z, r) then
        local t = {}
        for k, v in pairs(extra) do t[k] = v end
        t.seed = rng:int(1, 9999)
        solid_circle(L, x, z, r, h or a.h, t)
        placed = placed + 1
      end
    end
    return placed
  end
  -- ribs arch over every chamber, slightly askew; a glowing pool or floor pattern in the middle
  prop(L, "ribs", { at = { cx, cz }, box = { b[1], b[2], b[3], b[4] }, h = a.h, skew = (rng:float() - 0.5) * 0.5,
                    step = 3 + rng:int(0, 2), axis = sx >= sz and 1 or 3 })
  if look == "atrium" then
    try_circle(rng:int(5, 8), 0.7, 1.5, a.h, { look = "growth" }, 0.33)
    prop(L, "pool", { at = { cx, cz }, r = math.min(sx, sz) * 0.16 })
    for _ = 1, rng:int(2, 4) do
      prop(L, "orbiter", { at = { cx + (rng:float() - 0.5) * sx * 0.4, cz + (rng:float() - 0.5) * sz * 0.4 }, y = a.h * (0.45 + rng:float() * 0.35),
                           r = 0.6 + rng:float() * 0.8, phase = rng:int(0, 999) / 1000 })
    end
  elseif look == "shaft" then
    local levels = math.floor(a.h / 9)
    for k = 1, levels do prop(L, "ledge", { box = { b[1], b[2], b[3], b[4] }, y = k * 9 - 0.5, w = 1.6, gap = rng:int(0, 3) }) end
    prop(L, "monolith", { at = { cx, cz }, y = 8 + rng:float() * 4, h = a.h * 0.45, w = 1.4, yaw = rng:float() * sm.pi, spin = true })
    try_circle(rng:int(2, 4), 0.5, 0.9, 1.6, { look = "pod" })
  elseif look == "brood" then
    -- cocoon racks along the two long walls, broken at the doorways
    local long = sx >= sz and 1 or 3
    local lo, hi = span(b, long == 1 and 3 or 1)   -- along the long walls
    for _, side in ipairs({ -1, 1 }) do
      local wall = long == 1 and (side < 0 and b[2] or b[4]) or (side < 0 and b[1] or b[3])
      local u = lo + 1.5
      while u < hi - 2.5 do
        local len = 2.2
        local x0, z0, x1, z1
        if long == 1 then x0, x1, z0, z1 = u, u + len, wall - side * 0.1, wall - side * 1.3
        else x0, x1, z0, z1 = wall - side * 0.1, wall - side * 1.3, u, u + len end
        local mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
        if off_paths(L, a, mx, mz, 1.1) then
          solid_box(L, x0, z0, x1, z1, math.min(a.h - 1, 5.5), { look = "rack", n = rng:int(2, 4), seed = rng:int(1, 9999) })
        end
        u = u + len + 0.6
      end
    end
    try_circle(rng:int(2, 3), 0.8, 1.1, 2.2, { look = "egg" }, 0.2)
  elseif look == "garden" then
    try_circle(rng:int(9, 14), 0.35, 0.8, 1.2 + rng:float() * 1.5, { look = "plant" })
    prop(L, "pool", { at = { cx, cz }, r = math.min(sx, sz) * 0.12 })
  else
    -- shrine: a floating monolith over a low altar at the far side, glyph walls all round
    local far_ok = false
    for _ = 1, 8 do
      local x, z = cx + (rng:float() - 0.5) * sx * 0.5, cz + (rng:float() - 0.5) * sz * 0.5
      if off_paths(L, a, x, z, 1.3) then
        solid_box(L, x - 1.2, z - 1.2, x + 1.2, z + 1.2, 0.9, { look = "altar" })
        prop(L, "monolith", { at = { x, z }, y = 2.2, h = math.min(a.h - 3, 7), w = 1.1, yaw = rng:float() * sm.pi })
        far_ok = true
        break
      end
    end
    if not far_ok then prop(L, "monolith", { at = { cx, cz }, y = a.h * 0.5, h = a.h * 0.3, w = 0.9, yaw = 0 }) end
    prop(L, "glyphwall", { box = { b[1], b[2], b[3], b[4] }, h = a.h, seed = rng:int(1, 9999) })
    try_circle(rng:int(2, 4), 0.4, 0.6, 2.4, { look = "brazier" }, 0.4)
  end
end

function M.alien_wing(L, seed)
  local W = M.kit().walk.alien
  local c = L.cell
  local fam = L.family
  local names = W.names[fam] or W.names.coral
  local rng = saucer.rng.new(saucer.seed_child(seed, "alien", 1))
  local market
  for _, a in ipairs(L.areas) do if a.kind == "market" then market = a end end
  local zones = mouth_zones(L)
  -- where the wing starts: the market's wall away from the concourse
  local mb = market.box
  local msign = (mb[1] + mb[3]) / 2 > 0 and 1 or -1
  local heads = { { area = market, axis = 1, sign = msign, u = (mb[2] + mb[4]) / 2, fixed = true } }
  local want = rint(rng, W.chambers)
  local pw = W.passage_w * c / 2
  local made = 0
  local looks_left = {}
  for i, lk in ipairs(M.LOOKS) do looks_left[i] = lk end
  for _ = 1, want * 6 do
    if made >= want then break end
    -- the newest chamber grows on most of the time; now and then an older one branches
    local hd = heads[#heads]
    if #heads > 2 and rng:int(0, 99) < 30 then hd = heads[rng:int(2, #heads)] end
    local axis, sign, u = hd.axis, hd.sign, hd.u
    if not hd.fixed then
      local dirs = { { 1, 1 }, { 1, -1 }, { 3, 1 }, { 3, -1 } }
      local d = dirs[rng:int(1, 4)]
      axis, sign = d[1], d[2]
      local lo, hi = span(hd.area.box, axis)
      if hi - lo < 2 * pw + 2 then axis = nil else u = lo + pw + 1 + rng:float() * (hi - lo - 2 * pw - 2) end
    end
    if axis then
      -- the passage: straight, or a dogleg with a sideways leg
      local plen = rint(rng, W.passage) * c
      local boxes = {}
      local p1, f1 = out_box(hd.area.box, axis, sign, u, plen, pw)
      boxes[1] = { box = p1, axis = axis, at = f1, lo = u - pw, hi = u + pw }
      local end_axis, end_sign, end_u, last = axis, sign, u, p1
      if rng:int(0, 99) < 45 then
        local turn = rng:int(0, 1) * 2 - 1
        local ax2 = axis == 1 and 3 or 1
        -- the leg leaves from the side of the first part's far end
        local lo1, hi1 = (axis == 1) and p1[1] or p1[2], (axis == 1) and p1[3] or p1[4]
        local u2 = sign > 0 and (hi1 - pw) or (lo1 + pw)
        local p2, f2 = out_box(p1, ax2, turn, u2, rint(rng, W.passage) * c, pw)
        boxes[2] = { box = p2, axis = ax2, at = f2, lo = u2 - pw, hi = u2 + pw }
        end_axis, end_sign, end_u, last = ax2, turn, u2, p2
      end
      local look = looks_left[rng:int(1, #looks_left)]
      local wcells, dcells = rint(rng, W.size), rint(rng, W.size)
      local h = look == "shaft" and rint(rng, W.shaft_h) or rint(rng, W.hall_h)
      if look == "shaft" then wcells, dcells = math.max(5, wcells - 3), math.max(5, dcells - 3) end
      local half = wcells * c / 2
      local shift = (rng:float() - 0.5) * 2 * math.max(0, half - pw - 2)
      local ch, fc = out_box(last, end_axis, end_sign, end_u + shift, dcells * c, half)
      local ok = not overlaps(L, ch, zones)
      for _, pb in ipairs(boxes) do ok = ok and not overlaps(L, pb.box, zones) end
      -- (the chamber must not swallow the passage's own first part)
      if ok and #boxes == 2 then
        local q = boxes[1].box
        if ch[1] < q[3] - 0.01 and ch[3] > q[1] + 0.01 and ch[2] < q[4] - 0.01 and ch[4] > q[2] + 0.01 then ok = false end
      end
      if ok then
        local prev = hd.area
        for k, pb in ipairs(boxes) do
          local pa = area(L, "corridor", names.passage, pb.box[1], pb.box[2], pb.box[3], pb.box[4], W.passage_h)
          pa.alien = "passage"
          pa.wing = true
          door(L, prev, pa, pb.axis, pb.at, pb.lo, pb.hi, math.min(L.door_h, W.passage_h - 0.4))
          pa.door_at = M.door_center(L.doors[#L.doors])
          prev = pa
          if k == 1 then hd.fixed = nil end
        end
        local a = area(L, "chamber", names[look], ch[1], ch[2], ch[3], ch[4], h)
        a.alien = look
        a.wing = true
        door(L, prev, a, end_axis, fc, end_u - pw, end_u + pw, math.min(L.door_h + 1, W.passage_h - 0.4))
        a.door_at = M.door_center(L.doors[#L.doors])
        heads[#heads + 1] = { area = a }
        made = made + 1
        -- every look once before any repeats
        for i, lk in ipairs(looks_left) do if lk == look then table.remove(looks_left, i) break end end
        if #looks_left == 0 then for i, lk in ipairs(M.LOOKS) do looks_left[i] = lk end end
      end
    end
  end
  -- furnish once every doorway is in place (the clear routes know all of them)
  for _, a in ipairs(L.areas) do
    if a.kind == "chamber" then furnish_chamber(L, a, rng, W) end
    if a.wing and a.kind == "corridor" then
      prop(L, "ribs", { at = M.center(a), box = { a.box[1], a.box[2], a.box[3], a.box[4] }, h = a.h, skew = (rng:float() - 0.5) * 0.7,
                        step = 2, axis = (a.box[3] - a.box[1]) >= (a.box[4] - a.box[2]) and 1 or 3 })
    end
  end
  L.wing = made
end

-- generate(seed, family) -> layout (family: sim/stationhull.lua's, from the seed when not given)
function M.generate(seed, family)
  local K = M.kit().walk
  local folk = M.folk()
  local c = K.cell
  local rng = saucer.rng.new(seed)
  local L = { seed = seed, cell = c, areas = {}, doors = {}, solids = {}, props = {}, stalls = {}, walkers = {},
              door_h = K.door_h, pad_y = K.pad_y, family = family or require("sim.stationhull").family_of(seed) }
  local sw = K.spine.w * c / 2
  -- the arrival hangar and the spine
  local h1w, h1d = rint(rng, K.hangar.w), rint(rng, K.hangar.d)
  local hangar1 = area(L, "hangar", "Arrival hangar", -h1w * c / 2, -h1d * c, h1w * c / 2, 0, K.hangar.h)
  hangar1.bay = 1
  -- side slots: market (direct), bar (down a passage), maybe the second hangar
  local ms = rng:int(0, 1) * 2 - 1
  local bs = rng:int(0, 1) * 2 - 1
  local h2_end = rng:int(0, 1) == 0
  local items = {
    { kind = "market", side = ms, w = rint(rng, K.market.w), d = rint(rng, K.market.d) },
    { kind = "bar", side = bs, w = rint(rng, K.bar.w), d = rint(rng, K.bar.d), pass = rint(rng, K.passage.len) },
  }
  local h2w, h2d = rint(rng, K.hangar.w), rint(rng, K.hangar.d)
  if not h2_end then
    items[#items + 1] = { kind = "hangar", side = -ms, w = h2d, d = h2w, pass = rint(rng, K.passage.len) }
  end
  local cursor = { [-1] = c, [1] = c }
  for _, it in ipairs(items) do
    it.z0 = cursor[it.side] + rng:int(0, 1) * c
    it.z1 = it.z0 + it.d * c
    cursor[it.side] = it.z1 + c
  end
  local len = math.max(rint(rng, K.spine.len), (math.max(cursor[-1], cursor[1]) + c - 1) // c)
  local spine = area(L, "corridor", "Concourse", -sw, 0, sw, len * c, K.spine.h)
  door(L, hangar1, spine, 3, 0, -sw, sw, K.door_h)
  furnish_hangar(L, hangar1, rng, 3, -1)
  hangar1.door_at = { 0, 0 }
  -- the areas along the spine
  for _, it in ipairs(items) do
    local s = it.side
    local wall = s * sw
    local zc = (it.z0 + it.z1) / 2
    if it.kind == "market" then
      local x0, x1 = wall, wall + s * it.w * c
      local a = area(L, "market", "Market", math.min(x0, x1), it.z0, math.max(x0, x1), it.z1, K.market.h)
      door(L, spine, a, 1, wall, zc - c, zc + c, K.door_h)
      furnish_market(L, a, rng, folk, wall)
      a.door_at = { wall, zc }
    else
      local pw = (it.kind == "bar" and K.passage.w or 2) * c / 2
      local p0, p1 = wall, wall + s * it.pass * c
      local ph = it.kind == "bar" and K.passage.h or K.spine.h
      local pas = area(L, "corridor", it.kind == "bar" and "Bar passage" or "Hangar passage", math.min(p0, p1), zc - pw,
        math.max(p0, p1), zc + pw, ph)
      local dh = math.min(K.door_h, ph - 0.4)
      door(L, spine, pas, 1, wall, zc - pw, zc + pw, dh)
      local x0, x1 = p1, p1 + s * it.w * c
      local a
      if it.kind == "bar" then
        a = area(L, "bar", "The Drift bar", math.min(x0, x1), it.z0, math.max(x0, x1), it.z1, K.bar.h)
        door(L, pas, a, 1, p1, zc - pw, zc + pw, dh)
        furnish_bar(L, a, rng, folk, p1)
      else
        a = area(L, "hangar", "Far hangar", math.min(x0, x1), it.z0, math.max(x0, x1), it.z1, K.hangar.h)
        a.bay = 2
        door(L, pas, a, 1, p1, zc - pw, zc + pw, dh)
        furnish_hangar(L, a, rng, 1, s)
      end
      a.door_at = { p1, zc }
      pas.door_at = { wall, zc }
    end
  end
  if h2_end then
    local a = area(L, "hangar", "Far hangar", -h2w * c / 2, len * c, h2w * c / 2, len * c + h2d * c, K.hangar.h)
    a.bay = 2
    door(L, spine, a, 3, len * c, -sw, sw, K.door_h)
    furnish_hangar(L, a, rng, 3, 1)
    a.door_at = { 0, len * c }
  end
  -- concourse pillars wherever no doorway is near, benches between them
  for z = c, len * c - c, 2 * c do
    for _, s in ipairs({ -1, 1 }) do
      local near = false
      for _, d in ipairs(L.doors) do
        if d.axis == 1 and d.at * s > 0 and z > d.lo - 3 and z < d.hi + 3 then near = true end
      end
      if not near then solid_circle(L, s * (sw - 0.6), z, 0.35, K.spine.h, { look = "pillar" }) end
    end
  end
  -- people strolling up and down the concourse
  for k = 1, rint(rng, K.walkers) do
    L.walkers[k] = { x = (rng:int(0, 8) - 4) * 0.4, z0 = 3 + rng:int(0, 3), z1 = len * c - 3 - rng:int(0, 3),
                     speed = 0.8 + rng:int(0, 5) * 0.1, phase = rng:int(0, 999) / 1000, species = crowd(folk, rng) }
  end
  -- the pickpocket loiters in the market or the bar
  local haunt
  local want = rng:int(0, 1) == 0 and "market" or "bar"
  for _, a in ipairs(L.areas) do
    if a.kind == want and not haunt then haunt = a end
  end
  haunt = haunt or spine
  L.thief = { home = { haunt.aisle and haunt.aisle[1] or M.center(haunt)[1], (haunt.aisle or M.center(haunt))[2] },
              area = haunt.id, species = species_of(folk, "hooded") }
  for _, s in ipairs(folk.species) do if s.thief then L.thief.species = species_of(folk, s.id) end end
  L.spawn = { pos = { 0, 0, -6 }, yaw = sm.pi }
  L.spine_len = len * c
  M.alien_wing(L, seed)
  M.dress(L, seed)
  M.build_nav(L)
  L.hash = M.hash(L)
  return L
end

-- the walk graph: area centres, doorway centres and concourse stops
function M.build_nav(L)
  local nodes, links = {}, {}
  local function node(x, z, a)
    nodes[#nodes + 1] = { x, z, area = a }
    return #nodes
  end
  local spine
  for _, a in ipairs(L.areas) do if a.name == "Concourse" then spine = a end end
  local last = L.spine_len
  local end_door = false
  -- (only the concourse's own doorways make stops on it: the alien wing's doors are elsewhere)
  local function on_spine(d) return d.a == spine.id or d.b == spine.id end
  for _, d in ipairs(L.doors) do if d.axis == 3 and d.at == last and on_spine(d) then end_door = true end end
  if not end_door then last = last - 1.5 end
  local stops = { [0] = true, [last] = true }
  for _, d in ipairs(L.doors) do
    if d.axis == 1 and on_spine(d) then stops[(d.lo + d.hi) / 2] = true end
  end
  local zs = {}
  for z in pairs(stops) do zs[#zs + 1] = z end
  table.sort(zs)
  local spine_node = {}
  local prev
  for _, z in ipairs(zs) do
    local n = node(0, z, spine.id)
    spine_node[z] = n
    if prev then links[#links + 1] = { prev, n } end
    prev = n
  end
  local area_node = {}
  for _, a in ipairs(L.areas) do
    if a ~= spine then
      local q = a.aisle or M.center(a)
      area_node[a.id] = node(q[1], q[2], a.id)
    end
  end
  area_node[spine.id] = spine_node[0]
  for _, d in ipairs(L.doors) do
    local dc = M.door_center(d)
    local dn = node(dc[1], dc[2], d.b)
    local A, B = L.areas[d.a], L.areas[d.b]
    local an = area_node[A.id]
    if A == spine then an = spine_node[d.axis == 1 and dc[2] or d.at] end
    links[#links + 1] = { an, dn }
    links[#links + 1] = { dn, area_node[B.id] }
  end
  L.nav = { nodes = nodes, links = links }
  local adj = {}
  for i = 1, #nodes do adj[i] = {} end
  for _, l in ipairs(links) do
    if l[1] ~= l[2] then
      table.insert(adj[l[1]], l[2])
      table.insert(adj[l[2]], l[1])
    end
  end
  L.nav.adj = adj
end

function M.hash(L)
  local parts = {}
  for _, a in ipairs(L.areas) do
    local b = a.box
    parts[#parts + 1] = string.format("%s:%.1f,%.1f,%.1f,%.1f,%.1f", a.kind, b[1], b[2], b[3], b[4], a.h)
  end
  for _, s in ipairs(L.solids) do
    if s.kind == "box" then parts[#parts + 1] = string.format("b%.2f,%.2f,%.2f,%.2f", s.box[1], s.box[2], s.box[3], s.box[4])
    else parts[#parts + 1] = string.format("c%.2f,%.2f,%.2f", s.c[1], s.c[2], s.r) end
  end
  for _, st in ipairs(L.stalls) do parts[#parts + 1] = st.vendor end
  return string.format("%016x", saucer.hash64(table.concat(parts, ";"), 1))
end

local cache = {}
function M.get(seed, family)
  local key = tostring(seed) .. ":" .. tostring(family)
  local L = cache[key]
  if not L then
    L = M.generate(seed, family)
    cache[key] = L
  end
  return L
end

-- the walk-in seed of sector sid's trader idx (the home sector's are the old ones; far sectors' differ, so their
-- stations' families and wings do too)
function M.seed_of(seed, sid, idx)
  if (sid or 1) == 1 then return saucer.seed_child(seed or 0, "station", idx or 1) end
  return saucer.seed_child(seed or 0, "station", sid * 16 + (idx or 1))
end

function M.seed_for(state, trader_idx)
  return M.seed_of(state.seed, state.sector and state.sector.id or 1, trader_idx)
end

local function inside(b, x, z, r)
  return x >= b[1] + r and x <= b[3] - r and z >= b[2] + r and z <= b[4] - r
end

-- the area a point is in (doorways count as the area they lead into), or nil
function M.area_at(L, x, z)
  for _, a in ipairs(L.areas) do
    if inside(a.box, x, z, 0) then return a end
  end
  for _, d in ipairs(L.doors) do
    if inside(M.door_box(d), x, z, 0) then return L.areas[d.b] end
  end
  return nil
end

local function hit_solid(s, x, z, r)
  if s.kind == "circle" then
    local dx, dz = x - s.c[1], z - s.c[2]
    local rr = s.r + r
    return dx * dx + dz * dz < rr * rr
  end
  local b = s.box
  local cx = math.max(b[1], math.min(x, b[3]))
  local cz = math.max(b[2], math.min(z, b[4]))
  local dx, dz = x - cx, z - cz
  return dx * dx + dz * dz < r * r
end

-- the layout's solids bucketed by SOLID_CELL squares (built on first use, kept on the cached layout; a
-- solid sits in every square its footprint touches)
local SOLID_CELL = 4
local function solid_grid(L)
  if L.solid_grid and L.solid_grid.n == #L.solids then return L.solid_grid.cells end
  local cells = {}
  for _, s in ipairs(L.solids) do
    local x0, z0, x1, z1
    if s.kind == "circle" then x0, z0, x1, z1 = s.c[1] - s.r, s.c[2] - s.r, s.c[1] + s.r, s.c[2] + s.r
    else x0, z0, x1, z1 = s.box[1], s.box[2], s.box[3], s.box[4] end
    for gx = math.floor(x0 / SOLID_CELL), math.floor(x1 / SOLID_CELL) do
      for gz = math.floor(z0 / SOLID_CELL), math.floor(z1 / SOLID_CELL) do
        local k = gx * 65536 + gz
        local c = cells[k]
        if not c then c = {} cells[k] = c end
        c[#c + 1] = s
      end
    end
  end
  L.solid_grid = { n = #L.solids, cells = cells }
  return cells
end

-- can a body of radius r stand at (x, z)?
function M.free(L, x, z, r)
  r = r or M.BODY_R
  local ok = false
  for _, a in ipairs(L.areas) do
    if inside(a.box, x, z, r) then ok = true break end
  end
  if not ok then
    for _, d in ipairs(L.doors) do
      if inside(M.door_box(d), x, z, r) then ok = true break end
    end
  end
  if not ok then return false end
  -- (the solids are looked up in a coarse grid: the bigger stations have a lot of furniture)
  local g = solid_grid(L)
  local G = SOLID_CELL
  for gx = math.floor((x - r) / G), math.floor((x + r) / G) do
    for gz = math.floor((z - r) / G), math.floor((z + r) / G) do
      local cell = g[gx * 65536 + gz]
      if cell then
        for _, s in ipairs(cell) do
          if hit_solid(s, x, z, r) then return false end
        end
      end
    end
  end
  return true
end

-- is the straight walk from a to b clear?
function M.clear(L, a, b, r)
  local dx, dz = b[1] - a[1], b[2] - a[2]
  local d = sm.sqrt(dx * dx + dz * dz)
  local n = math.max(1, math.ceil(d / 0.25))
  for i = 0, n do
    local t = i / n
    if not M.free(L, a[1] + dx * t, a[2] + dz * t, r) then return false end
  end
  return true
end

-- the nav node nearest to p that p can walk to in a straight line
function M.nearest(L, p, r)
  -- nearest first (ties to the lower id), so the first clear one is the answer
  local order = {}
  for i, q in ipairs(L.nav.nodes) do
    local dx, dz = q[1] - p[1], q[2] - p[2]
    order[i] = { dx * dx + dz * dz, i }
  end
  table.sort(order, function(u, w) if u[1] ~= w[1] then return u[1] < w[1] end return u[2] < w[2] end)
  for _, o in ipairs(order) do
    if M.clear(L, p, L.nav.nodes[o[2]], r) then return o[2] end
  end
  return nil
end

-- fewest-links node path between nav nodes -> list of node ids
function M.node_path(L, from, to)
  if not from or not to then return nil end
  local prev, queue, head = { [from] = from }, { from }, 1
  while head <= #queue do
    local n = queue[head]
    head = head + 1
    if n == to then break end
    for _, m in ipairs(L.nav.adj[n]) do
      if not prev[m] then
        prev[m] = n
        queue[#queue + 1] = m
      end
    end
  end
  if not prev[to] then return nil end
  local path, n = {}, to
  while n ~= from do
    table.insert(path, 1, n)
    n = prev[n]
  end
  table.insert(path, 1, from)
  return path
end

-- route(L, a, b) -> list of {x, z} points from a to b: straight when clear,
-- otherwise via the walk graph
function M.route(L, a, b, r)
  if M.clear(L, a, b, r) then return { { b[1], b[2] } } end
  local na, nb = M.nearest(L, a, r), M.nearest(L, b, r)
  local path = M.node_path(L, na, nb)
  if not path then return { { b[1], b[2] } } end
  local out = {}
  for _, n in ipairs(path) do
    local q = L.nav.nodes[n]
    out[#out + 1] = { q[1], q[2] }
  end
  out[#out + 1] = { b[1], b[2] }
  -- skip leading points we can already see past
  while #out > 1 and M.clear(L, a, out[2], r) do table.remove(out, 1) end
  return out
end

-- the hangar areas in order of their bay number
function M.hangars(L)
  local out = {}
  for _, a in ipairs(L.areas) do if a.kind == "hangar" then out[a.bay] = a end end
  return out
end

-- where a concourse stroller is at sim tick `tick` -> x, z, yaw
function M.walker_at(w, tick)
  local span = math.max(1, w.z1 - w.z0)
  local period = 2 * span / w.speed
  local t = ((tick / 60) / period + w.phase) % 1
  local f = t < 0.5 and t * 2 or (1 - t) * 2
  return w.x, w.z0 + span * f, t < 0.5 and 0 or sm.pi
end

return M
