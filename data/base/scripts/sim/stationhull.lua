-- SPDX-License-Identifier: MIT
-- The outside of a trader station (OpenSpec add-huge-stations, add-alien-stations).
--
-- generate(seed, class, bay_no, mesh, family) lays out a multi-kilometre alien megastructure in "anchor"
-- meters: the origin is the trader's `pos`, the dock anchor, and the hangar cell of sim/dock.lua sits at its +x
-- end, so the station grows off the cell's back wall toward -x: a stem studded with docking pods, floating
-- glyph monoliths and cocoons, then the family's body:
--   coral    (Reef)     a coral trunk with chitin plates, tendrils ending in glowing polyps, habitat bulbs,
--                       a halo of drifting spores
--   crystal  (Lattice)  a cut-crystal core in a lattice of nodes and struts, great shards, a splinter halo
--   spiral   (Helix)    a horn, a nautilus of chambers and lopsided flaring helices turning round it
--   shells   (Gyre)     a great orb in nested shells turning on tilted axes, standing stones, a tail of orbs
-- The hangar cell is one small bay among many.
--
-- The result is plain data, a pure function of (seed, class, family, the dock tune and the kit): the same on
-- every platform, never saved. Mesh parts come in layers (view/stationhull.lua turns each into one mesh):
--   core    the standing hull: stem, body, pods, the hangar cell's shell
--   detail  its plates, pores, glyphs, irises, conduits and the hangar's dressing (drawn near)
--   ring    the spinning layer (halos, helices, shells) turning about the x axis through `spin_pos`
--   ringd   its lit nodes (drawn near)
--   far     one cheap silhouette of everything (drawn from afar)
-- plus `solids` (boxes for the physics world; the spinning layer has none), `lights` and `far_bay`, where the
-- far hangar's pod opens.
local data = require("lib.data")
local sm = saucer.math
local M = {}

local PI, TAU = sm.pi, sm.tau
function M.kit() return data.load("station/hull.lua") end

local function rint(rng, r)
  if type(r) == "number" then return r end
  return rng:int(r[1], r[2])
end

local function rfloat(rng, lo, hi) return lo + (hi - lo) * rng:float() end
local function shade(c, f) return { c[1] * f, c[2] * f, c[3] * f } end

-- seven-row 3x5 digits for the bay numbers over the mouths
local DIGITS = {
  ["0"] = { "111", "101", "101", "101", "111" }, ["1"] = { "010", "110", "010", "010", "111" },
  ["2"] = { "111", "001", "111", "100", "111" }, ["3"] = { "111", "001", "111", "001", "111" },
  ["4"] = { "101", "101", "111", "001", "001" }, ["5"] = { "111", "100", "111", "001", "111" },
  ["6"] = { "111", "100", "111", "101", "111" }, ["7"] = { "111", "001", "010", "010", "010" },
  ["8"] = { "111", "101", "111", "101", "111" }, ["9"] = { "111", "101", "111", "001", "111" },
}

-- ---------------------------------------------------------------------------------------------------
-- the builder: a context with the layers, a counter per layer and primitive helpers. y is relative to the
-- station's axis (AY above the anchor) unless a helper says it is spinning (then it is about the axis).
-- ---------------------------------------------------------------------------------------------------
-- the families of the kit by id, and the one a seed picks
function M.families() return M.kit().families end
function M.family(id)
  for _, f in ipairs(M.kit().families) do
    if f.id == id then return f end
  end
  error("unknown station family " .. tostring(id))
end
function M.family_of(seed)
  local fams = M.kit().families
  return fams[saucer.seed_child(seed or 0, "family", 1) % #fams + 1].id
end

local function new_ctx(seed, class, mesh, family)
  local H = M.kit()
  local K = H.classes[class]
  if not K then error("unknown station class " .. tostring(class)) end
  local T = data.load("saucer/dock.lua")
  local c = {
    H = H, K = K, T = T, class = class, seed = seed, s = K.scale or 1,
    AY = T.floor_y + T.height / 2,
    parts = { core = {}, detail = {}, ring = {}, ringd = {}, far = {} },
    solids = {}, spin = {}, lights = {}, mesh = mesh,
    fam = M.family(family or M.family_of(seed)),
    rng = saucer.rng.new(saucer.seed_child(seed, "hull", 1)),
    drng = saucer.rng.new(saucer.seed_child(seed, "hull", 2)),
    mrng = saucer.rng.new(saucer.seed_child(seed, "hull", 3)),   -- only for what the triangles need (skipped in a layout-only pass)
    grng = saucer.rng.new(saucer.seed_child(seed, "hull", 4)),   -- the glyphs (triangles only too)
  }
  c.pal_name = c.fam.palettes[c.rng:int(1, #c.fam.palettes)]
  c.pal = H.palettes[c.pal_name]
  return c
end

-- fix-station-hull: the spinning layer's collision shapes, in its own frame (x from the spin centre, y and z from
-- the axis), recorded whether or not triangles are built: a sphere { c, r }, a capsule { a, b, r }, an annulus about
-- the x axis { x0, x1, rin, rout } and a torus { n (unit axis), R, r } about the spin centre
local function spin_shape(c, layer, shape)
  if layer == "ring" then c.spin[#c.spin + 1] = shape end
end

local function add(c, layer, part)
  local l = c.parts[layer]
  l[#l + 1] = part
  return part
end

local function box(c, layer, x0, y0, z0, x1, y1, z1, color, emi)
  if not c.mesh then return end   -- layout only: the sim wants the solids, not the triangles
  local AY = (layer == "ring" or layer == "ringd") and 0 or c.AY
  return add(c, layer, { kind = "box", min = { math.min(x0, x1), math.min(y0, y1) + AY, math.min(z0, z1) },
                         max = { math.max(x0, x1), math.max(y0, y1) + AY, math.max(z0, z1) }, color = color, emissive = emi })
end

-- a cylinder along x from x0 to x1 about the axis through (y, z)
local function xcyl(c, layer, x0, x1, y, z, r, color, seg, emi, r1)
  if not c.mesh then return end   -- layout only: the sim wants the solids, not the triangles
  local AY = (layer == "ring" or layer == "ringd") and 0 or c.AY
  local lo, hi = math.min(x0, x1), math.max(x0, x1)
  local kind = r1 and "cone" or "cylinder"
  -- roll -pi/2 turns +y into +x; a cone's r is its +y end's start, so a cone narrows toward x1 when x0 < x1
  return add(c, layer, { kind = kind, c = { 0, 0, 0 }, r = r, r1 = r1, h = hi - lo, seg = seg or 12, color = color,
                         emissive = emi, roll = -PI / 2, pos = { lo, y + AY, z } })
end

-- an annulus about the x axis, thick along x from x0 to x1
local function xring(c, layer, x, w, rin, rout, seg, color, emi)
  spin_shape(c, layer, { kind = "annulus", x0 = x - w / 2, x1 = x + w / 2, rin = rin, rout = rout })
  if not c.mesh then return end   -- layout only: the sim wants the solids, not the triangles
  local AY = (layer == "ring" or layer == "ringd") and 0 or c.AY
  return add(c, layer, { kind = "ring", c = { 0, -w / 2, 0 }, rin = rin, r = rout, h = w, seg = seg, color = color, emissive = emi,
                         roll = -PI / 2, pos = { x, AY, 0 } })
end

-- a box at radius r0..r1 on the axis' circle, angle a (0 = +z, pi/2 = +y), x0..x1 along the axis, half-width hw
local function rbox(c, layer, x0, x1, r0, r1, hw, a, color, emi)
  if not c.mesh then return end   -- layout only: the sim wants the solids, not the triangles
  local AY = (layer == "ring" or layer == "ringd") and 0 or c.AY
  return add(c, layer, { kind = "box", min = { x0, -hw, r0 }, max = { x1, hw, r1 }, color = color, emissive = emi,
                         pitch = a, pos = { 0, AY, 0 } })
end

-- a square rod between two points (anchor meters, y relative to the axis), half-thickness w
local function rod(c, layer, a, b, w, color, emi)
  if not c.mesh then return end   -- layout only: the sim wants the solids, not the triangles
  local AY = (layer == "ring" or layer == "ringd") and 0 or c.AY
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local hz = sm.sqrt(dx * dx + dz * dz)
  local len = sm.sqrt(hz * hz + dy * dy)
  if len < 1e-3 then return nil end
  return add(c, layer, { kind = "box", min = { -w, -w, 0 }, max = { w, w, len }, color = color, emissive = emi,
                         yaw = sm.atan2(dx, dz), pitch = -sm.atan2(dy, hz), pos = { a[1], a[2] + AY, a[3] } })
end

local function sphere(c, layer, x, y, z, r, color, emi, seg)
  if not c.mesh then return end   -- layout only: the sim wants the solids, not the triangles
  local AY = (layer == "ring" or layer == "ringd") and 0 or c.AY
  return add(c, layer, { kind = "sphere", c = { x, y + AY, z }, r = r, h = r, seg = seg or 8, rings = 3, color = color, emissive = emi })
end

-- a collision box (anchor meters, absolute y), a little inside what is drawn
local function solid(c, x0, y0, z0, x1, y1, z1)
  c.solids[#c.solids + 1] = { { math.min(x0, x1), math.min(y0, y1), math.min(z0, z1) },
                              { math.max(x0, x1), math.max(y0, y1), math.max(z0, z1) } }
end

local function light(c, x, y, z, color, kind, size, period, extra)
  local l = { p = { x, y + c.AY, z }, c = color, kind = kind, size = size, period = period or 90, phase = c.drng:int(0, 89) }
  for k, v in pairs(extra or {}) do l[k] = v end
  c.lights[#c.lights + 1] = l
  return l
end

-- digits as lit boxes on a wall facing +x (face = +1) or -x, centred at (x, y, z), pixel size s
local function sign(c, layer, text, x, y, z, s, color, face)
  if not c.mesh then return end   -- layout only: the sim wants the solids, not the triangles
  local n = #text
  local width = n * 4 * s - s
  for i = 1, n do
    local g = DIGITS[text:sub(i, i)]
    if g then
      for row = 1, 5 do
        for col = 1, 3 do
          if g[row]:sub(col, col) == "1" then
            local zz = z - width / 2 + ((i - 1) * 4 + (col - 1)) * s
            box(c, layer, x, y + (5 - row) * s, zz, x + face * s * 0.6, y + (6 - row) * s, zz + s, color, 1)
          end
        end
      end
    end
  end
end

-- a small parked craft (lib/meshkit.lua ship): y is the belly, relative to the axis
local function parked_ship(c, layer, x, y, z, yaw, s, col, acc)
  if not c.mesh then return end   -- layout only: the sim wants the solids, not the triangles
  local AY = (layer == "ring" or layer == "ringd") and 0 or c.AY
  for _, part in ipairs(require("lib.meshkit").ship(x, y + AY, z, yaw, s, col, acc)) do add(c, layer, part) end
end

-- ---------------------------------------------------------------------------------------------------
-- the hangar cell: the shell of dock.lua's boxes, skinned and dressed, in anchor meters
-- ---------------------------------------------------------------------------------------------------
local function bay_cell(c, bay_no)
  local T, P = c.T, c.pal
  local w = T.wall
  local lo = { T.back_x, T.floor_y, -T.half_w }
  local hi = { T.front_x, T.floor_y + T.height, T.half_w }
  local ch = T.floor_y + T.height
  local dz, dh = T.door.half, T.door.height
  local WALL, FLOOR, STRIP, WARN = { 0.36, 0.39, 0.47 }, { 0.27, 0.3, 0.35 }, P.glow, { 1.0, 0.75, 0.15 }
  -- the boxes of dock.solids (kept in step by the tests), unskinned: walls are one colour inside and out
  local function raw(x0, y0, z0, x1, y1, z1, col) add(c, "core", { kind = "box", min = { x0, y0, z0 }, max = { x1, y1, z1 }, color = col }) end
  raw(lo[1], lo[2] - 2, lo[3] - w, hi[1], lo[2], hi[3] + w, FLOOR)
  raw(lo[1], hi[2], lo[3] - w, hi[1], hi[2] + w, hi[3] + w, WALL)
  raw(lo[1], lo[2], lo[3] - w, hi[1], hi[2], lo[3], WALL)
  raw(lo[1], lo[2], hi[3], hi[1], hi[2], hi[3] + w, WALL)
  raw(lo[1] - w, lo[2], lo[3], lo[1], hi[2], -dz, WALL)
  raw(lo[1] - w, lo[2], dz, lo[1], hi[2], hi[3], WALL)
  raw(lo[1] - w, lo[2] + dh, -dz, lo[1], hi[2], dz, WALL)
  raw(lo[1] - 3.5, lo[2] - 0.01, -dz, lo[1] - w, lo[2], dz, FLOOR)
  raw(lo[1] - 3.5, lo[2], -dz - w, lo[1] - w, hi[2], -dz, WALL)
  raw(lo[1] - 3.5, lo[2], dz, lo[1] - w, hi[2], dz + w, WALL)
  raw(lo[1] - 3.5 - w, lo[2], -dz - w, lo[1] - 3.5, hi[2], dz + w, WALL)
  -- outer skin: plating ribs on the roof and flanks, a hazard-striped lip round the mouth, lit window rows
  local sk = P.plate
  local function skin(x0, y0, z0, x1, y1, z1, col, emi) add(c, "core", { kind = "box", min = { x0, y0, z0 }, max = { x1, y1, z1 }, color = col or sk, emissive = emi }) end
  skin(lo[1] - 4, hi[2] + w, lo[3] - w - 0.8, hi[1] + 0.4, hi[2] + w + 0.9, hi[3] + w + 0.8)
  skin(lo[1] - 4, lo[2] - 2.9, lo[3] - w - 0.8, hi[1] + 0.4, lo[2] - 2, hi[3] + w + 0.8, shade(sk, 0.8))
  skin(lo[1] - 4, lo[2] - 2.9, lo[3] - w - 0.8, hi[1] + 0.4, hi[2] + w + 0.9, lo[3] - w, sk)
  skin(lo[1] - 4, lo[2] - 2.9, hi[3] + w, hi[1] + 0.4, hi[2] + w + 0.9, hi[3] + w + 0.8, sk)
  -- (the sides run the full height: a pod you can read from far away)
  for i = 0, 6 do
    local x = lo[1] + 2 + i * ((hi[1] - lo[1] - 6) / 6)
    add(c, "detail", { kind = "box", min = { x, lo[2] - 3.3, lo[3] - w - 1.3 }, max = { x + 1.2, hi[2] + w + 1.3, lo[3] - w - 0.8 }, color = shade(sk, 0.7) })
    add(c, "detail", { kind = "box", min = { x, lo[2] - 3.3, hi[3] + w + 0.8 }, max = { x + 1.2, hi[2] + w + 1.3, hi[3] + w + 1.3 }, color = shade(sk, 0.7) })
    add(c, "detail", { kind = "box", min = { x, hi[2] + w + 0.9, lo[3] - w }, max = { x + 1.2, hi[2] + w + 1.5, hi[3] + w }, color = shade(sk, 0.7) })
  end
  for _, z in ipairs({ lo[3] - w - 0.85, hi[3] + w + 0.85 }) do
    for k = 0, 9 do
      local x = lo[1] + 1 + k * 5
      if c.drng:int(1, 4) > 1 then
        add(c, "detail", { kind = "box", min = { x, hi[2] - 4, z - 0.15 }, max = { x + 2.4, hi[2] - 2.6, z + 0.15 }, color = P.glow, emissive = 1 })
      end
    end
  end
  -- hazard lip and bay number over the mouth
  for k = 0, 11 do
    local zz = lo[3] + k * (hi[3] - lo[3]) / 12
    add(c, "core", { kind = "box", min = { hi[1] + 0.8, hi[2] + 0.6, zz }, max = { hi[1] + 1.2, hi[2] + 1.4, zz + (hi[3] - lo[3]) / 12 }, color = k % 2 == 0 and WARN or { 0.12, 0.12, 0.14 } })
  end
  sign(c, "core", string.format("%02d", bay_no), hi[1] + 1.2, hi[2] + 2.4, 0, 1.3, P.accent, 1)
  -- the interior: floor markings, pad, door frame, lit strips
  local pad = T.pad
  local function d(x0, y0, z0, x1, y1, z1, col, emi) add(c, "detail", { kind = "box", min = { x0, y0, z0 }, max = { x1, y1, z1 }, color = col, emissive = emi }) end
  d(pad[1] - 15, lo[2], pad[2] - 15, pad[1] + 15, lo[2] + 0.12, pad[2] + 15, { 0.2, 0.22, 0.27 })
  for _, s in ipairs({ -1, 1 }) do
    d(pad[1] + s * 15 - 0.25, lo[2] + 0.12, pad[2] - 15, pad[1] + s * 15 + 0.25, lo[2] + 0.2, pad[2] + 15, WARN, 0.8)
    d(pad[1] - 15, lo[2] + 0.12, pad[2] + s * 15 - 0.25, pad[1] + 15, lo[2] + 0.2, pad[2] + s * 15 + 0.25, WARN, 0.8)
  end
  for i = 0, 7 do
    local x = lo[1] + 4 + i * ((hi[1] - lo[1] - 8) / 7)
    d(x, hi[2] - 0.1, lo[3] + 4, x + 0.5, hi[2], hi[3] - 4, STRIP, 1)
  end
  for _, z in ipairs({ lo[3] + 0.05, hi[3] - 0.25 }) do d(lo[1], lo[2] + 0.1, z, hi[1], lo[2] + 0.3, z + 0.2, STRIP, 1) end
  -- the station door in the back wall: a lit frame and a warm glow beyond
  d(lo[1] - 0.2, lo[2], -dz - 0.3, lo[1] + 0.1, lo[2] + dh + 0.3, -dz, WARN, 0.8)
  d(lo[1] - 0.2, lo[2], dz, lo[1] + 0.1, lo[2] + dh + 0.3, dz + 0.3, WARN, 0.8)
  d(lo[1] - 0.2, lo[2] + dh, -dz, lo[1] + 0.1, lo[2] + dh + 0.3, dz, WARN, 0.8)
  d(lo[1] - 3.4, lo[2] + 0.05, -dz, lo[1] - 3.3, lo[2] + dh, dz, { 1.0, 0.85, 0.6 }, 1)
  -- the lit "docking" sign above the door
  sign(c, "detail", string.format("%02d", bay_no), lo[1] + 0.2, lo[2] + dh + 1.2, 0, 0.7, STRIP, 1)
  for i = 0, 3 do d(lo[1] + 0.2, lo[2] + dh + 0.6 + i * 0.01, -2.2 + i * 1.2, lo[1] + 0.5, lo[2] + dh + 1.0, -1.4 + i * 1.2, P.accent, 1) end
  -- ---- dressing -------------------------------------------------------------------------------
  local r = c.drng
  local hw = T.half_w
  -- two ceiling cranes on rails, a hook hanging from each
  for _, z in ipairs({ -(hw - 4), hw - 4 }) do d(lo[1] + 2, hi[2] - 1.5, z - 0.4, hi[1] - 2, hi[2], z + 0.4, { 0.2, 0.2, 0.22 }) end
  for _, cx in ipairs({ lo[1] + 14 + r:int(0, 5), hi[1] - 12 - r:int(0, 5) }) do
    d(cx - 1.2, hi[2] - 3.0, -(hw - 3.6), cx + 1.2, hi[2] - 1.5, hw - 3.6, { 0.85, 0.65, 0.15 })
    local tz = r:int(-hw // 2, hw // 2)
    d(cx - 1.6, hi[2] - 4.2, tz - 1.6, cx + 1.6, hi[2] - 3.0, tz + 1.6, { 0.22, 0.22, 0.25 })
    d(cx - 0.12, hi[2] - 12, tz - 0.12, cx + 0.12, hi[2] - 4.2, tz + 0.12, { 0.1, 0.1, 0.1 })
    d(cx - 0.5, hi[2] - 13.2, tz - 0.5, cx + 0.5, hi[2] - 12, tz + 0.5, WARN, 0.4)
    d(cx - 0.3, hi[2] - 3.1, -(hw - 3.8), cx + 0.3, hi[2] - 3.0, -(hw - 3.4), { 1, 0.3, 0.2 }, 1)
  end
  -- crate stacks and fuel tanks along both side walls, clear of the pad and the mouth
  local tints = { { 0.6, 0.48, 0.3 }, { 0.45, 0.5, 0.42 }, { 0.62, 0.3, 0.22 }, { 0.3, 0.4, 0.6 } }
  for _, side in ipairs({ -1, 1 }) do
    local x = lo[1] + 3
    while x < hi[1] - 8 do
      local kind = r:int(1, 5)
      local zc = side * (hw - 2.4)
      if kind <= 3 then
        local s = 1.8 + r:int(0, 2) * 0.4
        for k = 0, r:int(0, 2) do
          d(x, lo[2] + k * s, zc - s / 2, x + s, lo[2] + (k + 1) * s * 0.97, zc + s / 2, tints[r:int(1, 4)])
          d(x - 0.02, lo[2] + k * s + s * 0.45, zc - s / 2 - 0.02, x + s + 0.02, lo[2] + k * s + s * 0.55, zc + s / 2 + 0.02, { 0.2, 0.2, 0.2 })
        end
        x = x + s + 0.8
      elseif kind == 4 then
        add(c, "detail", { kind = "cylinder", c = { x + 1.4, lo[2], zc }, r = 1.4, h = 4.4, seg = 10, color = { 0.7, 0.72, 0.76 } })
        d(x + 0.2, lo[2] + 1.6, zc - 0.02, x + 2.6, lo[2] + 2.0, zc + 0.02, WARN, 0.6)
        x = x + 3.4
      else
        -- a cargo pallet with a loader arm beside it
        d(x, lo[2], zc - 1.3, x + 2.6, lo[2] + 0.3, zc + 1.3, { 0.3, 0.28, 0.25 })
        d(x + 0.3, lo[2] + 0.3, zc - 0.9, x + 1.1, lo[2] + 1.7, zc + 0.9, tints[r:int(1, 4)])
        d(x + 1.5, lo[2] + 0.3, zc - 0.9, x + 2.3, lo[2] + 1.1, zc + 0.9, tints[r:int(1, 4)])
        x = x + 3.4
      end
    end
  end
  -- fuel lines: two floor pipes with valve blocks, a coupling and a hose reaching the pad's edge
  for _, side in ipairs({ -1, 1 }) do
    local zl = side * (hw - 7)
    add(c, "detail", { kind = "cylinder", c = { 0, 0, 0 }, r = 0.28, h = hi[1] - lo[1] - 6, seg = 6, color = { 0.8, 0.55, 0.15 },
                       roll = -PI / 2, pos = { lo[1] + 3, lo[2] + 0.35, zl } })
    for k = 1, 5 do
      local x = lo[1] + 3 + k * ((hi[1] - lo[1] - 6) / 6)
      d(x - 0.5, lo[2] + 0.05, zl - 0.55, x + 0.5, lo[2] + 0.75, zl + 0.55, { 0.25, 0.25, 0.28 })
      d(x - 0.1, lo[2] + 0.75, zl - 0.1, x + 0.1, lo[2] + 1.1, zl + 0.1, { 1, 0.3, 0.2 }, 0.5)
    end
    local hx = pad[1] + r:int(-6, 6)
    d(hx - 0.2, lo[2] + 0.05, zl * 0.5 - 0.0, hx + 0.2, lo[2] + 0.45, zl - 0.0, { 0.12, 0.12, 0.14 })
  end
  -- signage: lit chevrons on the floor leading in, bay lights on the walls, a status light over the door
  for k = 0, 4 do
    local x = hi[1] - 6 - k * 5
    d(x, lo[2] + 0.12, -3.2, x + 0.5, lo[2] + 0.2, -0.3, STRIP, 1)
    d(x, lo[2] + 0.12, 0.3, x + 0.5, lo[2] + 0.2, 3.2, STRIP, 1)
  end
  for _, side in ipairs({ -1, 1 }) do
    for k = 0, 3 do
      local x = lo[1] + 8 + k * 12
      d(x, lo[2] + 6.5, side * (hw - 0.05) - 0.05, x + 1.6, lo[2] + 7.1, side * (hw - 0.05) + 0.05, P.glow, 1)
      d(x, lo[2] + 1.2, side * (hw - 0.1) - 0.1, x + 0.3, hi[2] - 1.6, side * (hw - 0.1) + 0.1, shade(WALL, 0.55))
    end
  end
  -- two side pads: one with a parked shuttle, one empty with its outline lit
  local sz = hw - 9
  for si, side in ipairs({ -1, 1 }) do
    local px, pz = pad[1] - 2, side * sz
    local col = r:int(0, 1) == 0
    d(px - 7, lo[2], pz - 5.5, px + 7, lo[2] + 0.1, pz + 5.5, { 0.2, 0.22, 0.26 })
    for _, ee in ipairs({ { -7, -5.5, 7, -5.2 }, { -7, 5.2, 7, 5.5 }, { -7, -5.5, -6.7, 5.5 }, { 6.7, -5.5, 7, 5.5 } }) do
      d(px + ee[1], lo[2] + 0.1, pz + ee[2], px + ee[3], lo[2] + 0.18, pz + ee[4], (si == 1) and WARN or STRIP, 0.8)
    end
    if si == (col and 1 or 2) then
      parked_ship(c, "detail", px, lo[2] + 0.12 - c.AY, pz, side > 0 and 0.2 or -0.2, 0.9, r:int(0, 1) == 0 and { 0.62, 0.64, 0.7 } or { 0.7, 0.5, 0.32 }, P.accent)
    end
  end
  -- the bay's own beacons on the roof's front corners
  for _, z in ipairs({ lo[3] - 0.5, hi[3] + 0.5 }) do
    light(c, hi[1] + 1, hi[2] + w + 1 - c.AY, z, { 1, 0.75, 0.2 }, "blink", 4, 70)
  end
  return { lo = lo, hi = hi }
end

-- ---------------------------------------------------------------------------------------------------
-- alien building blocks (add-alien-stations). Points are { x, y, z } in anchor meters, y relative to the
-- station's axis; on the spinning layers ("ring", "ringd") x is relative to the spin centre and y to it too.
-- ---------------------------------------------------------------------------------------------------
local function lay_y(c, layer) return (layer == "ring" or layer == "ringd") and 0 or c.AY end

-- a tapered limb from a to b: radius r0 at a, r1 at b (r1 = 0: a shard's point)
local function limb(c, layer, a, b, r0, r1, color, seg, emi)
  -- (a shard's point, r1 = 0, thins to nothing: its capsule keeps two thirds of the base)
  spin_shape(c, layer, { kind = "capsule", a = { a[1], a[2], a[3] }, b = { b[1], b[2], b[3] }, r = math.max(r0, r1) * (r1 == 0 and 0.67 or 1) })
  if not c.mesh then return end
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local hz = sm.sqrt(dx * dx + dz * dz)
  local len = sm.sqrt(hz * hz + dy * dy)
  if len < 1e-3 then return nil end
  -- pitch tips +y toward the horizontal, yaw turns it about y: +y lands on (b - a) / len
  return add(c, layer, { kind = (r1 == r0) and "cylinder" or "cone", c = { 0, 0, 0 }, r = r0, r1 = r1, h = len,
                         seg = seg or 8, color = color, emissive = emi, pitch = sm.atan2(hz, dy), yaw = sm.atan2(dx, dz),
                         pos = { a[1], a[2] + lay_y(c, layer), a[3] } })
end

-- an ellipsoid (a sphere scaled per axis), optionally turned
local function blob(c, layer, p, rx, ry, rz, color, emi, seg, yaw, pitch, roll)
  spin_shape(c, layer, { kind = "sphere", c = { p[1], p[2], p[3] }, r = math.max(rx, ry, rz) * 0.9 })
  if not c.mesh then return end
  seg = seg or 10
  return add(c, layer, { kind = "sphere", c = { 0, 0, 0 }, r = 1, h = 1, seg = seg, rings = seg <= 6 and 2 or 3,
                         color = color, emissive = emi, scale = { rx, ry, rz }, yaw = yaw, pitch = pitch, roll = roll,
                         pos = { p[1], p[2] + lay_y(c, layer), p[3] } })
end

-- a box turned about its own centre p (half sizes hx, hy, hz)
local function slab(c, layer, p, hx, hy, hz, color, emi, yaw, pitch, roll)
  if not c.mesh then return end
  return add(c, layer, { kind = "box", min = { -hx, -hy, -hz }, max = { hx, hy, hz }, color = color, emissive = emi,
                         yaw = yaw, pitch = pitch, roll = roll, pos = { p[1], p[2] + lay_y(c, layer), p[3] } })
end

-- the turn of view/mesh parts (roll about z, then pitch about x, then yaw about y), for placing things on a turned part
local function turn(p, yaw, pitch, roll)
  local a, b, cc = p[1], p[2], p[3]
  local cr, sr = sm.cos(roll or 0), sm.sin(roll or 0)
  local cp, sp = sm.cos(pitch or 0), sm.sin(pitch or 0)
  local cy, sy = sm.cos(yaw or 0), sm.sin(yaw or 0)
  a, b = a * cr - b * sr, a * sr + b * cr
  b, cc = b * cp - cc * sp, b * sp + cc * cp
  a, cc = a * cy + cc * sy, -a * sy + cc * cy
  return { a, b, cc }
end
M.turn = turn

local function len3(x, y, z) return sm.sqrt(x * x + y * y + z * z) end
local function lerp3(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end

-- keep a point within reach r of the axis (its y, z pulled in)
local function clamp_r(p, r)
  local d = sm.sqrt(p[2] * p[2] + p[3] * p[3])
  if d > r then return { p[1], p[2] * r / d, p[3] * r / d } end
  return p
end

-- collision along a limb: a box every ~2r of its length (y relative to the axis like the limb)
local function solid_limb(c, a, b, r)
  local d = len3(b[1] - a[1], b[2] - a[2], b[3] - a[3])
  local n = math.max(1, math.min(8, math.floor(d / (2 * r)) + 1))
  local h = r * 0.75
  for i = 0, n - 1 do
    local p = lerp3(a, b, (i + 0.5) / n)
    solid(c, p[1] - h, c.AY + p[2] - h, p[3] - h, p[1] + h, c.AY + p[2] + h, p[3] + h)
  end
end

local function solid_ball(c, p, r)
  local h = r * 0.72
  solid(c, p[1] - h, c.AY + p[2] - h, p[3] - h, p[1] + h, c.AY + p[2] + h, p[3] + h)
end

-- a unit vector from yaw and elevation (y up)
local function dir(yaw, el)
  local ce = sm.cos(el)
  return { ce * sm.sin(yaw), sm.sin(el), ce * sm.cos(yaw) }
end

-- the station's alphabet: a dozen glyphs of 3 x 4 cells, from the station's own glyph stream
local function alphabet(c)
  local out = {}
  for g = 1, 12 do
    local bits, on = {}, 0
    for k = 1, 12 do
      bits[k] = c.grng:int(0, 9) < 5
      if bits[k] then on = on + 1 end
    end
    if on < 4 then bits[2], bits[5], bits[8], bits[11] = true, true, true, true end
    out[g] = bits
  end
  return out
end

-- a line of n glyphs on a wall facing +x (face = 1) or -x, running along z, centred at (x, y, z), cell size s
local function glyphs(c, layer, n, x, y, z, s, color, face)
  if not c.mesh then return end
  c.alpha = c.alpha or alphabet(c)
  local w = n * 4 * s - s
  for i = 1, n do
    local g = c.alpha[c.grng:int(1, #c.alpha)]
    for row = 1, 4 do
      for col = 1, 3 do
        if g[(row - 1) * 3 + col] then
          local zz = z - w / 2 + ((i - 1) * 4 + col - 1) * s
          box(c, layer, x, y + (4 - row) * s, zz, x + face * s * 0.6, y + (5 - row) * s, zz + s, color, 1)
        end
      end
    end
  end
end

-- a column of n glyphs down a slab's face: centred at p, on the side facing (sin yaw, 0, cos yaw), cell size s
local function glyph_column(c, layer, n, p, yaw, s, color)
  if not c.mesh then return end
  c.alpha = c.alpha or alphabet(c)
  local top = p[2] + n * 5 * s / 2
  for i = 1, n do
    local g = c.alpha[c.grng:int(1, #c.alpha)]
    for row = 1, 4 do
      for col = 1, 3 do
        if g[(row - 1) * 3 + col] then
          local q = turn({ (col - 2) * s, 0, 0 }, yaw)
          slab(c, layer, { p[1] + q[1], top - ((i - 1) * 5 + row) * s, p[3] + q[3] }, s * 0.48, s * 0.48, s * 0.3, color, 1, yaw)
        end
      end
    end
  end
end

-- the silhouette's own cheap limb (axis-relative points, a few sides)
local function far_limb(c, far, a, b, r, color)
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local hz = sm.sqrt(dx * dx + dz * dz)
  far[#far + 1] = { kind = "cylinder", c = { 0, 0, 0 }, r = r, h = sm.sqrt(hz * hz + dy * dy), seg = 4, color = color,
                    pitch = sm.atan2(hz, dy), yaw = sm.atan2(dx, dz), pos = { a[1], a[2] + c.AY, a[3] } }
end

-- a ring on the spinning layer, centred on the spin centre, its axis turned by roll then yaw
local function add_ring(c, ri, w, roll, yaw, color)
  spin_shape(c, "ring", { kind = "torus", n = turn({ 0, 1, 0 }, yaw, 0, roll), R = ri - 0.75 * w, r = w })
  if not c.mesh then return end
  return add(c, "ring", { kind = "ring", c = { 0, -w, 0 }, rin = ri - w * 1.5, r = ri, h = 2 * w, seg = 48, color = color,
                          roll = roll, yaw = yaw, pos = { 0, 0, 0 } })
end

-- ---------------------------------------------------------------------------------------------------
-- the pieces every family shares: docking pods, floating monoliths, cocoon clusters and conduits
-- ---------------------------------------------------------------------------------------------------
-- a docking pod on a stalk off the stem at x, angle a (0 = +z, pi/2 = +y), rad off the axis; its iris mouth
-- faces +x. Shaped by the family: a polyp, a cut crystal, a cocoon or an orb
local function pod(c, x, a, rad, no)
  local P, s, fam = c.pal, c.s, c.fam.id
  local cy, cz = rad * sm.sin(a), rad * sm.cos(a)
  local root = { x - 14 * s, 0, 0 }
  local tip = { x - 16 * s, cy, cz }
  limb(c, "core", root, tip, 7 * s, 4.5 * s, P.trim, 8)
  limb(c, "detail", lerp3(root, tip, 0.15), lerp3(root, tip, 0.85), 1.4 * s, 1.4 * s, P.glow, 5, 0.8)
  solid_limb(c, lerp3(root, tip, 0.2), lerp3(root, tip, 0.8), 5 * s)
  local px0, px1 = x - 40 * s, x + 6 * s
  local mid = { (px0 + px1) / 2, cy, cz }
  if fam == "coral" then
    blob(c, "core", mid, 24 * s, 13 * s, 15 * s, P.plate, nil, 10)
    for k = -1, 1 do xring(c, "detail", mid[1] + k * 12 * s, 2 * s, 12 * s, 15.5 * s, 10, P.trim) end
    for k = 1, 4 do
      local q = turn({ 0, 15 * s, 0 }, 0, 0, k * 1.57 + 0.4)
      blob(c, "detail", { mid[1] - 8 * s, cy + q[2], cz + q[1] }, 3 * s, 3 * s, 3 * s, P.accent, 0.5, 6)
    end
  elseif fam == "crystal" then
    slab(c, "core", mid, 23 * s, 11 * s, 11 * s, P.plate, nil, 0, PI / 4)
    for k = 0, 2 do
      local d = dir(k * 2.1 + a, 0.6)
      limb(c, "core", { mid[1] - 10 * s, cy, cz }, { mid[1] - 10 * s + d[1] * 6 * s, cy + d[2] * 26 * s, cz + d[3] * 26 * s },
           5 * s, 0, P.glow, 4, 0.35)
    end
  elseif fam == "spiral" then
    blob(c, "core", mid, 26 * s, 10 * s, 10 * s, P.plate, nil, 10)
    for k = 0, 9 do
      local t = k / 9
      local q = turn({ 0, 10.5 * s, 0 }, 0, 0, t * TAU * 1.5)
      blob(c, "detail", { px0 + 6 * s + t * 34 * s, cy + q[2], cz + q[1] }, 2.2 * s, 2.2 * s, 2.2 * s, P.accent, 0.4, 5)
    end
  else
    blob(c, "core", mid, 17 * s, 15 * s, 15 * s, P.plate, nil, 12)
    xring(c, "core", mid[1], 2.5 * s, 18 * s, 21 * s, 16, P.glow, 0.7)
  end
  -- the iris: a glowing disc in a ring of petals, the pod's number and a line of glyphs over it
  xcyl(c, "core", px1 - 1, px1 + 0.5, cy, cz, 7.5 * s, { 1.0, 0.85, 0.6 }, 12, 0.9)
  xring(c, "core", px1, 1.6 * s, 7.5 * s, 10 * s, 12, P.accent, 0.8)
  for k = 0, 5 do
    local q = turn({ 0, 10.5 * s, 0 }, 0, 0, k * TAU / 6)
    limb(c, "detail", { px1, cy + q[2], cz + q[1] }, { px1 + 4 * s, cy + q[2] * 1.25, cz + q[1] * 1.25 }, 1.6 * s, 0, P.trim, 4)
  end
  if s > 0.5 then
    sign(c, "detail", string.format("%02d", no), px1 + 0.6, cy + 13 * s, cz, 0.9, P.glow, 1)
    glyphs(c, "detail", 3, px1 + 0.6, cy - 17 * s, cz, 1.0, P.accent, 1)
  end
  light(c, px1 + 1, cy + 16 * s, cz, c.drng:int(1, 2) == 1 and P.accent or P.glow, "pulse", 3.5, 120)
  solid(c, px0 + 2, c.AY + cy - 10 * s, cz - 11 * s, px1 - 1, c.AY + cy + 10 * s, cz + 11 * s)
  return { x = px1, y = cy, z = cz }
end

-- a floating monolith: a tall slab, slightly askew, with glyph columns lit down both faces and a light over it
local function monolith(c, p, h, yaw)
  local P, s = c.pal, c.s
  slab(c, "core", p, 4 * s, h / 2, 1.6 * s, P.panel, nil, yaw, 0, 0.08)
  slab(c, "detail", { p[1], p[2] - h / 2 - 3 * s, p[3] }, 2.5 * s, 1.0 * s, 1.0 * s, P.glow, 0.9, yaw)
  if s > 0.5 then
    for _, side in ipairs({ -1, 1 }) do
      local f = turn({ 0, 0, side * 1.7 * s }, yaw)
      glyph_column(c, "detail", math.max(2, math.floor(h / (7 * s))), { p[1] + f[1], p[2], p[3] + f[3] }, yaw, 1.1 * s, P.glow)
    end
  end
  light(c, p[1], p[2] + h / 2 + 4 * s, p[3], P.glow, "pulse", 3, 160)
  solid(c, p[1] - 3 * s, c.AY + p[2] - h * 0.45, p[3] - 3 * s, p[1] + 3 * s, c.AY + p[2] + h * 0.45, p[3] + 3 * s)
end

-- a cluster of cocoons hung on a surface point p (outward normal nrm): silk threads, lit seams
local function cocoons(c, p, nrm, n, size)
  local P = c.pal
  local r = c.drng
  for k = 1, n do
    local off = { (r:float() - 0.5) * size * 3, (r:float() - 0.5) * size * 3, (r:float() - 0.5) * size * 3 }
    local q = { p[1] + nrm[1] * size * 1.6 + off[1], p[2] + nrm[2] * size * 1.6 + off[2], p[3] + nrm[3] * size * 1.6 + off[3] }
    local yaw, pitch = sm.atan2(nrm[1], nrm[3]), sm.atan2(sm.sqrt(nrm[1] * nrm[1] + nrm[3] * nrm[3]), nrm[2])
    blob(c, "detail", q, size * 0.55, size * (1.1 + r:float() * 0.6), size * 0.55, k % 3 == 0 and P.accent or P.plate,
         k % 3 == 0 and 0.35 or nil, 8, yaw, pitch)
    blob(c, "detail", q, size * 0.6, size * 0.12, size * 0.6, P.glow, 0.8, 6, yaw, pitch)
    limb(c, "detail", p, q, size * 0.08, size * 0.04, P.trim, 4)
  end
end

-- a pulsing conduit: a thin lit line with swollen nodes every `step`
local function conduit(c, layer, a, b, r, step, color)
  limb(c, layer, a, b, r, r, color, 5, 0.85)
  local d = len3(b[1] - a[1], b[2] - a[2], b[3] - a[3])
  local n = math.max(1, math.floor(d / step))
  for k = 1, n - 1 do blob(c, layer, lerp3(a, b, k / n), r * 2.6, r * 2.6, r * 2.6, color, 1, 6) end
end

-- ---------------------------------------------------------------------------------------------------
-- the stem: from the cell's back passage to the body, shaped by the family
-- ---------------------------------------------------------------------------------------------------
local function stem(c, F)
  local P, s, fam = c.pal, c.s, c.fam.id
  local x0, x1 = F.body_front, F.back
  local L = x1 - x0
  local sw = 10 * s
  solid(c, x0, c.AY - sw * 0.8, -sw * 0.8, x1, c.AY + sw * 0.8, sw * 0.8)
  if fam == "coral" then
    limb(c, "core", { x0, 0, 0 }, { x1, 0, 0 }, 9 * s, 7 * s, P.trim, 10)
    local n = math.max(3, math.floor(L / (38 * s)))
    for k = 0, n - 1 do
      local x = x1 - (k + 0.5) * L / n
      local w = (k % 2 == 0) and 1.0 or 0.75
      blob(c, "core", { x, 0, 0 }, 18 * s * w, 13 * s * w, 14 * s * w, P.plate, nil, 10)
      xring(c, "detail", x + 9 * s * w, 1.6 * s, 11 * s * w, 14.5 * s * w, 10, P.trim)
    end
  elseif fam == "crystal" then
    xcyl(c, "core", x0, x1, 0, 0, 10 * s, P.plate, 6)
    local n = math.max(3, math.floor(L / (70 * s)))
    for k = 1, n do
      local x = x1 - k * L / (n + 1)
      xcyl(c, "core", x, x + 9 * s, 0, 0, 19 * s, P.glow, 6, 0.3, 10 * s)
      xcyl(c, "core", x - 9 * s, x, 0, 0, 10 * s, P.glow, 6, 0.3, 19 * s)
    end
  elseif fam == "spiral" then
    limb(c, "core", { x0, 0, 0 }, { x1, 0, 0 }, 5 * s, 5 * s, P.trim, 8)
    local n = math.max(8, math.floor(L / (14 * s)))
    for strand = 0, 2 do
      local prev
      for k = 0, n do
        local t = k / n
        local q = turn({ 0, 9 * s, 0 }, 0, 0, strand * TAU / 3 + t * L / (120 * s) * TAU)
        local p = { x1 - t * L, q[2], q[1] }
        if prev then limb(c, "core", prev, p, 4.5 * s, 4.5 * s, P.plate, 6) end
        prev = p
      end
    end
  else
    xcyl(c, "core", x0, x1, 0, 0, 8 * s, P.plate, 10)
    local n = math.max(3, math.floor(L / (50 * s)))
    for k = 1, n do
      local x = x1 - k * L / (n + 1)
      xring(c, "core", x, 3 * s, 14 * s, 18 * s, 16, P.glow, 0.6)
    end
  end
  -- three lit conduits along it
  for k = 0, 2 do
    local q = turn({ 0, (fam == "coral" and 10.5 or 11.5) * s, 0 }, 0, 0, k * TAU / 3 + 0.5)
    conduit(c, "detail", { x0, q[2], q[1] }, { x1 - 4, q[2], q[1] }, 0.7 * math.max(s, 0.5), 30 * s, P.glow)
  end
end

-- ---------------------------------------------------------------------------------------------------
-- the families' bodies. Each grows within F.R of the axis between F.aft_end and F.body_front, adds its
-- solids and lights, fills the spinning layer, and returns the silhouette's parts and a few surface points
-- (where cocoons hang) as { p, normal } pairs.
-- ---------------------------------------------------------------------------------------------------
local B = {}

-- Reef: a coral trunk, branching tendrils ending in glowing polyps, habitat bulbs and a halo of drifting spores
function B.coral(c, F, far)
  local P, s, R, rng = c.pal, c.s, F.R, c.rng
  local spots = {}
  local n = rng:int(9, 12)
  local ph1, ph2 = rng:float() * TAU, rng:float() * TAU
  local trunk = {}
  for i = 0, n - 1 do
    local t = i / (n - 1)
    local x = F.body_front - t * F.body
    trunk[i + 1] = { p = { x, 0.12 * R * sm.sin(t * PI * 1.3 + ph1), 0.12 * R * sm.sin(t * PI * 0.9 + ph2) },
                     r = R * (0.15 + 0.09 * sm.sin(t * PI)) }
  end
  for i, tk in ipairs(trunk) do
    blob(c, "core", tk.p, tk.r * 1.35, tk.r, tk.r * 0.95, P.plate, nil, 12)
    far[#far + 1] = { kind = "sphere", c = { 0, 0, 0 }, r = 1, h = 1, seg = 6, rings = 2, color = P.plate, scale = { tk.r * 1.35, tk.r, tk.r * 0.95 },
                      pos = { tk.p[1], tk.p[2] + c.AY, tk.p[3] } }
    solid_ball(c, tk.p, tk.r)
    if i > 1 then limb(c, "core", trunk[i - 1].p, tk.p, trunk[i - 1].r * 0.7, tk.r * 0.7, P.trim, 10) end
    -- chitin plates along its back, lit pores between them
    for k = 0, c.mesh and 4 or -1 do
      local a = k * TAU / 5 + i * 0.4
      local q = turn({ 0, tk.r * 0.98, 0 }, 0, 0, a)
      slab(c, "detail", { tk.p[1], tk.p[2] + q[2], tk.p[3] + q[1] }, tk.r * 0.45, tk.r * 0.06, tk.r * 0.22, P.trim, nil, 0, -a)
      local g = turn({ 0, tk.r * 0.93, 0 }, 0, 0, a + TAU / 10)
      blob(c, "detail", { tk.p[1], tk.p[2] + g[2], tk.p[3] + g[1] }, tk.r * 0.05, tk.r * 0.05, tk.r * 0.05, P.glow, 1, 6)
    end
    spots[#spots + 1] = { p = { tk.p[1], tk.p[2] - tk.r * 0.9, tk.p[3] }, n = { 0, -1, 0 } }
  end
  -- tendrils: four or five bending segments each, tapering to a polyp
  local nb = rint(rng, c.K.branches)
  for b = 1, nb do
    local tk = trunk[rng:int(1, n)]
    local d = dir(rng:float() * TAU, (rng:float() - 0.5) * 2.4)
    d = { d[1] * 0.35, d[2], d[3] }
    local p = { tk.p[1] + d[1] * tk.r, tk.p[2] + d[2] * tk.r, tk.p[3] + d[3] * tk.r }
    local total = R * (0.45 + 0.25 * rng:float())
    local segs = 5
    local r0 = R * 0.055
    for k = 1, segs do
      local bend = dir(rng:float() * TAU, (rng:float() - 0.5) * 2)
      d = { d[1] * 0.8 + bend[1] * 0.35, d[2] * 0.8 + bend[2] * 0.35, d[3] * 0.8 + bend[3] * 0.35 }
      local dl = len3(d[1], d[2], d[3])
      d = { d[1] / dl, d[2] / dl, d[3] / dl }
      local q = clamp_r({ p[1] + d[1] * total / segs, p[2] + d[2] * total / segs, p[3] + d[3] * total / segs }, R * 0.9)
      q[1] = math.max(F.aft_end + 30 * s, math.min(F.body_front, q[1]))
      local r1 = r0 * (1 - k / (segs + 1.5))
      limb(c, "core", p, q, r0 * (1 - (k - 1) / (segs + 1.5)), r1, k % 2 == 0 and P.plate or P.trim, 8)
      if k <= 3 then solid_limb(c, p, q, r1 * 1.2) end
      if k == 1 then far[#far + 1] = { kind = "cone", c = { 0, 0, 0 }, r = r0, r1 = r1, h = len3(q[1] - p[1], q[2] - p[2], q[3] - p[3]), seg = 5,
                                       color = P.trim, pitch = sm.atan2(sm.sqrt((q[1] - p[1]) ^ 2 + (q[3] - p[3]) ^ 2), q[2] - p[2]),
                                       yaw = sm.atan2(q[1] - p[1], q[3] - p[3]), pos = { p[1], p[2] + c.AY, p[3] } } end
      -- buds along the way
      if c.mesh and c.mrng:int(0, 2) > 0 then
        blob(c, "detail", lerp3(p, q, 0.5), r1 * 0.9, r1 * 0.9, r1 * 0.9, P.accent, 0.25, 6)
      end
      p = q
    end
    -- the polyp: a crown of petals round a glowing mouth
    local pr = R * 0.03
    blob(c, "core", p, pr, pr, pr, P.plate, nil, 8)
    blob(c, "core", { p[1] + d[1] * pr, p[2] + d[2] * pr, p[3] + d[3] * pr }, pr * 0.6, pr * 0.6, pr * 0.6, P.glow, 1, 8)
    for k = 0, c.mesh and 5 or -1 do
      local side = dir(k * TAU / 6, 0)
      limb(c, "detail", p, { p[1] + (d[1] + side[1] * 0.7) * pr * 2.2, p[2] + (d[2] + side[2] * 0.7) * pr * 2.2,
                             p[3] + (d[3] + side[3] * 0.7) * pr * 2.2 }, pr * 0.25, 0, P.accent, 4)
    end
    light(c, p[1], p[2], p[3], (b % 2 == 0) and P.glow or P.accent, "pulse", 6, 100 + b * 7)
    if b % 3 == 0 then spots[#spots + 1] = { p = p, n = d } end
  end
  -- habitat bulbs on the trunk, their window bands lit
  for k = 1, rng:int(7, 10) do
    local tk = trunk[rng:int(2, n - 1)]
    local a = rng:float() * TAU
    local q = turn({ 0, 1, 0 }, 0, 0, a)
    local nrm = { 0, q[2], q[1] }
    local base = { tk.p[1], tk.p[2] + nrm[2] * tk.r * 0.85, tk.p[3] + nrm[3] * tk.r * 0.85 }
    local hgt = R * (0.12 + 0.06 * rng:float())
    local wid = hgt * 0.45
    if c.mesh then
      local pts = { 0.25 * wid, 0, 0.8 * wid, 0.12 * hgt, wid, 0.4 * hgt, 0.75 * wid, 0.72 * hgt, 0.3 * wid, 0.92 * hgt, 0.35 * wid, hgt }
      add(c, "core", { kind = "lathe", points = pts, seg = 12, color = P.plate, pitch = -a, pos = { base[1], base[2] + c.AY, base[3] } })
      add(c, "detail", { kind = "ring", c = { 0, 0.5 * hgt, 0 }, rin = wid * 0.9, r = wid * 1.02, h = hgt * 0.03, seg = 12, color = P.glow,
                         emissive = 1, pitch = -a, pos = { base[1], base[2] + c.AY, base[3] } })
    end
    local top = { base[1], base[2] + nrm[2] * hgt, base[3] + nrm[3] * hgt }
    solid_limb(c, base, top, wid * 0.8)
    light(c, top[1], top[2], top[3], P.glow, "steady", 5, 0)
  end
  -- aft: a fan of short tendrils behind the trunk
  local tail = trunk[n]
  for k = 0, 4 do
    local a = k * TAU / 5
    local q = turn({ 0, R * 0.25, 0 }, 0, 0, a)
    local e = { F.aft_end + 30 * s, tail.p[2] + q[2], tail.p[3] + q[1] }
    limb(c, "core", tail.p, e, tail.r * 0.3, R * 0.01, P.trim, 6)
    solid_limb(c, tail.p, lerp3(tail.p, e, 0.6), tail.r * 0.25)
    light(c, e[1], e[2], e[3], P.accent, "blink", 4, 90)
  end
  -- the spore halo: two drifting rings of seeds on the spinning layer
  for h = -1, 1, 2 do
    local x = h * F.body * 0.22
    local rr = R * (0.72 + 0.08 * h)
    xring(c, "ring", x, 1.5 * s, rr - 0.6 * s, rr + 0.6 * s, 48, P.glow, 0.6)
    for k = 0, 27 do -- (fix-station-hull: the layout pass too: the spores collide)
      local q = turn({ 0, rr, 0 }, 0, 0, k * TAU / 28)
      blob(c, "ring", { x + ((k % 3) - 1) * 6 * s, q[2], q[1] }, 7 * s, 7 * s, 7 * s, k % 4 == 0 and P.glow or P.plate, k % 4 == 0 and 0.8 or nil, 6)
    end
    far[#far + 1] = { kind = "ring", c = { 0, -1, 0 }, rin = rr - 1, r = rr + 1, h = 2, seg = 24, color = P.glow, emissive = 0.6, roll = -PI / 2,
                      pos = { F.hx + x, c.AY, 0 } }
  end
  return spots
end

-- Lattice: a cut-crystal core in a lattice of nodes and struts, great shards grown out of it, a halo of
-- floating splinters turning round it
function B.crystal(c, F, far)
  local P, s, R, rng = c.pal, c.s, F.R, c.rng
  local spots = {}
  local hx, half = F.hx, F.body / 2
  -- the core: a long double pyramid, square in section, with lit seams down its edges
  local cr = R * 0.26
  for _, e in ipairs({ { F.body_front, 1 }, { F.body_back, -1 } }) do
    limb(c, "core", { hx, 0, 0 }, { e[1], 0, 0 }, cr, 0, P.plate, 4, 0.12)
    far[#far + 1] = { kind = "cone", c = { 0, 0, 0 }, r = cr, r1 = 0, h = half, seg = 4, color = P.plate, emissive = 0.12,
                      pitch = PI / 2, yaw = e[2] * PI / 2, pos = { hx, c.AY, 0 } }
    for k = 0, 3 do
      local q = turn({ 0, cr, 0 }, 0, 0, k * PI / 2)
      limb(c, "detail", { hx, q[2], q[1] }, { e[1], 0, 0 }, 1.6 * s, 0.4 * s, P.glow, 4, 1)
    end
  end
  for k = -2, 2 do
    local x = hx + k * half * 0.3
    local w = cr * (1 - math.abs(k) * 0.3) * 0.72
    solid(c, x - half * 0.15, c.AY - w, -w, x + half * 0.15, c.AY + w, w)
  end
  -- the lattice: jittered grid nodes inside an ellipsoid round the core, struts between neighbours
  local nx, ny = 6, 5
  local sp = R * 0.38
  local nodes, at = {}, {}
  for i = 0, nx - 1 do
    for j = 0, ny - 1 do
      for k = 0, ny - 1 do
        local x = F.body_back + (i + 0.5) * F.body / nx + (rng:float() - 0.5) * sp * 0.3
        local y = (j - (ny - 1) / 2) * sp + (rng:float() - 0.5) * sp * 0.3
        local z = (k - (ny - 1) / 2) * sp + (rng:float() - 0.5) * sp * 0.3
        local ex, er = (x - hx) / half, sm.sqrt(y * y + z * z) / (R * 0.86)
        if ex * ex + er * er <= 1 and sm.sqrt(y * y + z * z) > cr * 0.8 then
          local nd = { p = { x, y, z }, i = i, j = j, k = k }
          nodes[#nodes + 1] = nd
          at[i .. "," .. j .. "," .. k] = nd
        end
      end
    end
  end
  for _, nd in ipairs(nodes) do
    local glow = (nd.i + nd.j + nd.k) % 4 == 0
    blob(c, "core", nd.p, R * 0.028, R * 0.04, R * 0.028, glow and P.glow or P.trim, glow and 0.7 or nil, 4)
    for _, o in ipairs({ { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }) do
      local nb = at[(nd.i + o[1]) .. "," .. (nd.j + o[2]) .. "," .. (nd.k + o[3])]
      if nb and rng:int(0, 99) < 60 then
        rod(c, "core", nd.p, nb.p, R * 0.0055, P.trim)
        if c.mesh and c.mrng:int(0, 3) == 0 then rod(c, "detail", nd.p, nb.p, R * 0.0065, P.glow, 0.7) end
      end
    end
  end
  -- great shards out of the outer nodes, siblings at their feet
  local nb = rint(rng, c.K.branches)
  for b = 1, nb do
    local nd = nodes[rng:int(1, #nodes)]
    local p = nd.p
    local rr = sm.sqrt(p[2] * p[2] + p[3] * p[3])
    local d = { (rng:float() - 0.5) * 0.5, p[2] / rr, p[3] / rr }
    local dl = len3(d[1], d[2], d[3])
    d = { d[1] / dl, d[2] / dl, d[3] / dl }
    local L = R * (0.22 + 0.3 * rng:float())
    local tip = clamp_r({ p[1] + d[1] * L, p[2] + d[2] * L, p[3] + d[3] * L }, R * 0.97)
    local base_r = R * (0.035 + 0.035 * rng:float())
    local glow = b % 3 == 0
    limb(c, "core", p, tip, base_r, 0, glow and P.glow or P.plate, rng:int(4, 6), glow and 0.45 or 0.1)
    solid_limb(c, p, lerp3(p, tip, 0.55), base_r * 0.9)
    if b <= 8 then
      far[#far + 1] = { kind = "cone", c = { 0, 0, 0 }, r = base_r, r1 = 0, h = len3(tip[1] - p[1], tip[2] - p[2], tip[3] - p[3]), seg = 4,
                        color = P.plate, pitch = sm.atan2(sm.sqrt((tip[1] - p[1]) * (tip[1] - p[1]) + (tip[3] - p[3]) * (tip[3] - p[3])), tip[2] - p[2]),
                        yaw = sm.atan2(tip[1] - p[1], tip[3] - p[3]), pos = { p[1], p[2] + c.AY, p[3] } }
    end
    for k = 1, (c.mesh and 3 or 0) do
      local side = dir(c.mrng:float() * TAU, (c.mrng:float() - 0.5) * 2)
      local e = { p[1] + (d[1] + side[1] * 0.6) * L * 0.35, p[2] + (d[2] + side[2] * 0.6) * L * 0.35, p[3] + (d[3] + side[3] * 0.6) * L * 0.35 }
      limb(c, "detail", p, clamp_r(e, R * 0.97), base_r * 0.45, 0, k == 2 and P.glow or P.trim, 4, k == 2 and 0.6 or nil)
    end
    light(c, tip[1], tip[2], tip[3], glow and P.glow or P.accent, "pulse", 5, 140 + b * 5)
    if b % 3 == 1 then spots[#spots + 1] = { p = lerp3(p, tip, 0.3), n = { 0, -1, 0 } } end
  end
  -- the aft: a cluster of shards pointing back
  for k = 0, 5 do
    local q = turn({ 0, R * 0.12, 0 }, 0, 0, k * TAU / 6)
    local e = { F.aft_end + 25 * s, q[2] * 1.6, q[1] * 1.6 }
    limb(c, "core", { F.body_back + 40 * s, q[2], q[1] }, e, R * 0.04, 0, k % 2 == 0 and P.plate or P.glow, 5, k % 2 == 0 and 0.1 or 0.5)
    solid_limb(c, { F.body_back + 40 * s, q[2], q[1] }, lerp3({ F.body_back + 40 * s, q[2], q[1] }, e, 0.5), R * 0.03)
  end
  light(c, F.aft_end + 20 * s, 0, 0, P.glow, "strobe", 8, 150)
  -- the halo: splinters on the spinning layer, laid along their circle
  for h = 0, 1 do
    local x = (h == 0 and -1 or 1) * half * 0.35
    local rr = R * (0.9 - 0.12 * h)
    for k = 0, 23 do -- (fix-station-hull: the layout pass too: the splinters collide)
      local a = k * TAU / 24 + h * 0.13
      local q = turn({ 0, rr, 0 }, 0, 0, a)
      local t = turn({ 0, 1, 0 }, 0, 0, a + PI / 2)
      local p = { x, q[2], q[1] }
      local l = R * (0.04 + 0.03 * (k % 3))
      limb(c, "ring", { p[1], p[2] - t[2] * l, p[3] - t[1] * l }, { p[1], p[2] + t[2] * l, p[3] + t[1] * l }, R * 0.012, 0,
           k % 2 == 0 and P.glow or P.plate, 4, k % 2 == 0 and 0.6 or 0.1)
    end
    far[#far + 1] = { kind = "ring", c = { 0, -1, 0 }, rin = rr - 2, r = rr + 2, h = 2, seg = 24, color = P.glow, emissive = 0.5, roll = -PI / 2,
                      pos = { F.hx + x, c.AY, 0 } }
  end
  return spots
end

-- Helix: a long horn down the axis, a nautilus of growing chambers round its middle, and two or three
-- flaring helices of linked nodules that turn round it, lopsided, one bigger than the rest
function B.spiral(c, F, far)
  local P, s, R, rng = c.pal, c.s, F.R, c.rng
  local spots = {}
  local hx = F.hx
  -- the horn
  local r0 = R * 0.1
  limb(c, "core", { F.body_front + 20 * s, 0, 0 }, { F.aft_end + 10 * s, 0, 0 }, r0, R * 0.012, P.plate, 10)
  far[#far + 1] = { kind = "cone", c = { 0, 0, 0 }, r = r0, r1 = R * 0.012, h = F.body_front - F.aft_end, seg = 6, color = P.plate,
                    pitch = PI / 2, yaw = -PI / 2, pos = { F.body_front + 20 * s, c.AY, 0 } }
  local span = F.body_front - F.aft_end
  for k = 0, 9 do
    local x0 = F.body_front - k * span / 10
    local x1 = x0 - span / 10
    local w = r0 + (R * 0.012 - r0) * (k + 0.5) / 10
    solid(c, x1, c.AY - w * 0.75, -w * 0.75, x0, c.AY + w * 0.75, w * 0.75)
    xring(c, "detail", x0 - 6 * s, 4 * s, w * 0.95, w * 1.12, 12, k % 2 == 0 and P.trim or P.accent, k % 2 == 0 and nil or 0.4)
  end
  -- the nautilus: chambers on a widening spiral in the x-y plane round the horn's middle
  local nc = rng:int(12, 15)
  local prev
  for k = 1, nc do
    local t = k / nc
    local ang = k * 0.62
    local rho = R * (0.03 + 0.25 * t * t)
    local p = { hx + sm.cos(ang) * rho * 1.6, sm.sin(ang) * rho, 0 }
    local br = R * (0.02 + 0.09 * t)
    blob(c, "core", p, br * 1.2, br, br * 1.1, (k % 2 == 0) and P.plate or P.trim, nil, 10)
    solid_ball(c, p, br)
    if k % 3 == 0 then
      blob(c, "detail", { p[1], p[2], p[3] + br * 1.02 }, br * 0.35, br * 0.35, br * 0.08, P.glow, 1, 8)
      blob(c, "detail", { p[1], p[2], p[3] - br * 1.02 }, br * 0.35, br * 0.35, br * 0.08, P.glow, 1, 8)
      light(c, p[1], p[2] + br, p[3], P.glow, "steady", 5, 0)
    end
    if prev then limb(c, "core", prev.p, p, prev.br * 0.6, br * 0.6, P.trim, 8) end
    if k > nc - 5 then
      far[#far + 1] = { kind = "sphere", c = { 0, 0, 0 }, r = 1, h = 1, seg = 6, rings = 2, color = P.plate, scale = { br * 1.2, br, br * 1.1 },
                        pos = { p[1], p[2] + c.AY, p[3] } }
    end
    spots[#spots + 1] = { p = { p[1], p[2] - br, p[3] }, n = { 0, -1, 0 } }
    prev = { p = p, br = br }
  end
  -- the helices (spinning): flaring out toward the back, nodules on them, rungs between
  local nh = rng:int(2, 3)
  local turns = 1.4 + rng:float()
  local npts = 40
  local hel = {}
  for h = 1, nh do
    local k_h = 1 - 0.16 * (h - 1)
    local a0 = h * TAU / nh + rng:float() * 0.4
    local pts = {}
    for i = 0, npts do
      local t = i / npts
      local x = (F.body_front - t * F.body * 1.04) - hx
      local rad = R * k_h * (0.22 + 0.66 * t * (2 - t) * 0.5 + 0.33 * t * 0.5)
      local q = turn({ 0, math.min(rad, R * 0.92), 0 }, 0, 0, a0 + t * turns * TAU)
      pts[i + 1] = { x, q[2], q[1] }
    end
    hel[h] = pts
    local th = R * 0.035 * k_h
    for i = 1, npts do
      local a, b = pts[i], pts[i + 1]
      limb(c, "ring", a, b, th * (1 - 0.45 * (i - 1) / npts), th * (1 - 0.45 * i / npts), (i % 2 == 0) and P.plate or P.trim, 8)
      if i % 4 == 0 then
        local nr = th * 1.8
        blob(c, "ring", b, nr, nr, nr, P.plate, nil, 8)
        blob(c, "ringd", { b[1] + nr * 0.6, b[2], b[3] }, nr * 0.45, nr * 0.45, nr * 0.45, P.glow, 1, 6)
      end
      if i % 3 == 0 then far_limb(c, far, { hel[h][i - 2][1] + hx, hel[h][i - 2][2], hel[h][i - 2][3] }, { b[1] + hx, b[2], b[3] }, th, P.plate) end
    end
    -- the helix grows out of the horn on two spokes
    limb(c, "ring", { pts[1][1], 0, 0 }, pts[1], th * 0.8, th, P.trim, 8)
    limb(c, "ring", { pts[npts // 2 + 1][1], 0, 0 }, pts[npts // 2 + 1], th * 0.6, th * 0.8, P.trim, 8)
  end
  for i = 4, npts, 6 do
    for h = 1, nh - 1 do
      limb(c, "ringd", hel[h][i], hel[h + 1][i], R * 0.006, R * 0.006, P.glow, 5, 0.8)
    end
  end
  -- the aft: the horn's point and a few barbs round it
  for k = 0, 3 do
    local q = turn({ 0, R * 0.08, 0 }, 0, 0, k * PI / 2 + 0.4)
    local base = { F.aft_end + 120 * s, 0, 0 }
    limb(c, "core", base, { F.aft_end + 20 * s, q[2], q[1] }, R * 0.015, 0, P.trim, 5)
  end
  light(c, F.aft_end + 6 * s, 0, 0, P.accent, "strobe", 8, 150)
  -- (the barbs on the horn's flank, where cocoons hang)
  for k = 1, rint(rng, c.K.branches) // 3 do
    local x = F.body_front - rng:float() * span * 0.9
    local a = rng:float() * TAU
    local q = turn({ 0, 1, 0 }, 0, 0, a)
    local w = r0 * (1 - (F.body_front - x) / span * 0.85)
    local p = { x, q[2] * w, q[1] * w }
    limb(c, "core", p, { x - R * 0.06, q[2] * (w + R * 0.12), q[1] * (w + R * 0.12) }, R * 0.012, 0, P.accent, 5, 0.2)
    spots[#spots + 1] = { p = p, n = { 0, q[2], q[1] } }
  end
  return spots
end

-- Gyre: a great orb cradled on the stem, nested shells of rings and plates turning round it on tilted axes,
-- standing stones circling it and a tail of smaller orbs behind
function B.shells(c, F, far)
  local P, s, R, rng = c.pal, c.s, F.R, c.rng
  local spots = {}
  local hx = F.hx
  local orb = R * 0.3
  blob(c, "core", { hx, 0, 0 }, orb, orb, orb, P.plate, nil, 16)
  far[#far + 1] = { kind = "sphere", c = { 0, 0, 0 }, r = orb, h = orb, seg = 8, rings = 3, color = P.plate, pos = { hx, c.AY, 0 } }
  solid_ball(c, { hx, 0, 0 }, orb)
  for _, dx in ipairs({ -0.55, 0.55 }) do solid_ball(c, { hx + dx * orb, 0, 0 }, orb * 0.75) end
  -- lit bands and irises on the orb
  for k = -2, 2 do
    local x = hx + k * orb * 0.33
    local rr = sm.sqrt(math.max(0, orb * orb - (k * orb * 0.33) * (k * orb * 0.33)))
    xring(c, "detail", x, 3 * s, rr - 1, rr + 2.5 * s, 32, k == 0 and P.glow or P.trim, k == 0 and 1 or nil)
  end
  for k = 0, 5 do
    local a = k * TAU / 6 + 0.3
    local q = turn({ 0, orb * 0.97, 0 }, 0, 0, a)
    blob(c, "core", { hx + orb * 0.25, q[2] * 0.97, q[1] * 0.97 }, orb * 0.12, orb * 0.16, orb * 0.16, P.glow, 0.9, 10)
    light(c, hx + orb * 0.25, q[2], q[1], P.glow, "pulse", 7, 200 + k * 11)
    spots[#spots + 1] = { p = { hx - orb * 0.3, q[2] * 0.95, q[1] * 0.95 }, n = { 0, q[2] / orb, q[1] / orb } }
  end
  -- the cradle: four arms from the stem's end round the orb
  for k = 0, 3 do
    local q = turn({ 0, orb * 1.15, 0 }, 0, 0, k * PI / 2 + PI / 4)
    local a = { F.body_front, 0, 0 }
    local m = { hx + orb * 0.4, q[2], q[1] }
    limb(c, "core", a, m, R * 0.025, R * 0.018, P.trim, 8)
    limb(c, "core", m, { hx - orb * 0.5, q[2] * 0.9, q[1] * 0.9 }, R * 0.018, R * 0.008, P.trim, 8)
    solid_limb(c, a, m, R * 0.02)
  end
  -- the shells (spinning): rings on tilted axes, each with plates and lit nodes on it
  local rmax = math.min(R * 0.92, F.body / 2 + R * 0.05)
  local tilts = { 0.45, 1.15, 0.2, 1.45 }
  local ns = 4
  for i = 1, ns do
    local ri = orb + (rmax - orb) * (i - 0.4) / (ns - 0.4)
    local tau, psi = tilts[i] + (rng:float() - 0.5) * 0.3, rng:float() * TAU
    local roll = -PI / 2 + tau
    local w = R * (0.018 + 0.006 * i)
    add_ring(c, ri, w, roll, psi, i % 2 == 0 and P.trim or P.plate)
    if i >= ns - 1 then
      far[#far + 1] = { kind = "ring", c = { 0, -w, 0 }, rin = ri - w, r = ri, h = 2 * w, seg = 28, color = P.plate, roll = roll, yaw = psi,
                        pos = { hx, c.AY, 0 } }
    end
    local plates = rng:int(6, 10)
    for k = 0, plates - 1 do
      local u = k * TAU / plates + rng:float() * 0.2
      local p = turn({ ri * sm.cos(u), 0, ri * sm.sin(u) }, psi, 0, roll)
      local tnd = turn({ -sm.sin(u), 0, sm.cos(u) }, psi, 0, roll)
      local half = ri * 0.12
      limb(c, "ring", { p[1] - tnd[1] * half, p[2] - tnd[2] * half, p[3] - tnd[3] * half }, { p[1] + tnd[1] * half, p[2] + tnd[2] * half, p[3] + tnd[3] * half },
           w * 2.2, w * 2.2, k % 3 == 0 and P.accent or P.plate, 6, k % 3 == 0 and 0.3 or nil)
      blob(c, "ringd", p, w * 1.6, w * 1.6, w * 1.6, P.glow, 1, 6)
    end
  end
  -- standing stones circling the orb (still): monoliths at the shells' edge
  local nst = math.max(4, rint(rng, c.K.branches) // 2)
  for k = 0, nst - 1 do
    local a = k * TAU / nst + 0.2
    local q = turn({ 0, math.min(R * 0.95, rmax + R * 0.06), 0 }, 0, 0, a)
    local p = { hx + (rng:float() - 0.5) * F.body * 0.5, q[2], q[1] }
    if c.mesh then
      slab(c, "core", p, 6 * s, R * 0.06, 6 * s, P.panel, nil, 0, -a)
      slab(c, "detail", p, 6.4 * s, R * 0.004, 6.4 * s, P.glow, 1, 0, -a)
    end
    solid_ball(c, p, 8 * s)
    light(c, p[1], p[2], p[3], P.accent, "pulse", 5, 170)
  end
  -- the tail: smaller orbs behind, on a bending line
  local prev = { hx - orb * 0.9, 0, 0 }
  local n = rng:int(3, 5)
  for k = 1, n do
    local t = k / n
    local p = { hx - orb - (hx - orb - F.aft_end - 30 * s) * t, R * 0.08 * sm.sin(t * 3), R * 0.06 * sm.cos(t * 2) }
    local r = orb * (0.45 - 0.3 * t)
    blob(c, "core", p, r, r, r, k % 2 == 0 and P.trim or P.plate, nil, 12)
    xring(c, "detail", p[1], 2 * s, r * 0.98, r * 1.1, 16, P.glow, 0.8)
    limb(c, "core", prev, p, r * 0.25, r * 0.2, P.trim, 6)
    solid_ball(c, p, r)
    prev = p
  end
  light(c, prev[1] - 10 * s, prev[2], prev[3], P.glow, "strobe", 7, 150)
  return spots
end

-- ---------------------------------------------------------------------------------------------------
-- the frame: the station's measures, the first draws of its stream (envelope and generate share it, so the
-- placement knows the hull's box without building it)
-- ---------------------------------------------------------------------------------------------------
local function frame(c)
  local K, T, rng = c.K, c.T, c.rng
  local s = c.s
  local F = { s = s }
  F.R = rint(rng, K.radius)
  F.stem = rint(rng, K.stem)
  F.body = rint(rng, K.body)
  F.aft = rint(rng, K.aft)
  F.back = T.back_x - 3.5 - T.wall                 -- where the cell's door passage ends: the stem starts here
  F.body_front = F.back - F.stem
  F.body_back = F.body_front - F.body
  F.aft_end = F.body_back - F.aft
  F.hx = (F.body_front + F.body_back) / 2
  local pad = 24 * s
  -- the box in anchor meters (y absolute); the body keeps within R of the axis, the pods and stones too
  F.lo = { F.aft_end - pad, c.AY - F.R - pad, -F.R - pad }
  F.hi = { T.front_x + 6, c.AY + F.R + pad, F.R + pad }
  F.centre = { (F.lo[1] + F.hi[1]) / 2, c.AY, 0 }
  local hx_, hr = (F.hi[1] - F.lo[1]) / 2, F.R + pad
  F.radius = sm.sqrt(hx_ * hx_ + hr * hr)
  return F
end

-- the sphere that holds a station of this seed, without building it -> centre (anchor meters), radius,
-- and its bounding box lo, hi
function M.envelope(seed, class, family)
  local c = new_ctx(seed, class or "port", false, family)
  local F = frame(c)
  return F.centre, F.radius, F.lo, F.hi
end

-- mesh ~= false builds the triangles too; the sim asks for the layout alone (M.get) and the view builds the parts
-- the first time it draws (M.parts): the same stream of random numbers either way, so the same station
function M.generate(seed, class, bay_no_in, mesh, family)
  class = class or "port"
  local c = new_ctx(seed, class, mesh ~= false, family)
  local F = frame(c)
  local K, P, rng = c.K, c.pal, c.rng
  local s = c.s
  local bay_no = bay_no_in or rng:int(1, 24)
  if bay_no_in then rng:int(1, 24) end   -- (the stream stays the same whether or not the number is given)
  local npods, nmono, ncoc = rint(rng, K.pods), rint(rng, K.monoliths), rint(rng, K.cocoons)
  local info = { R = F.R, arm = F.stem, stem = F.stem, body = F.body, aft = F.aft, bay_no = bay_no, hx = F.hx,
                 family = c.fam.id, family_name = c.fam.name, palette = c.pal_name, axis_y = c.AY,
                 body_front = F.body_front, body_back = F.body_back, aft_end = F.aft_end, back = F.back,
                 monoliths = nmono, cocoons = ncoc }

  -- the hangar cell, the stem that carries it, and a glyph band over its mouth
  local cell = bay_cell(c, bay_no)
  glyphs(c, "core", 5, cell.hi[1] + 1.3, cell.hi[2] + 6.2, 0, 1.0, P.glow, 1)
  stem(c, F)

  -- the body
  local far = c.mesh and c.parts.far or {}
  local spots = B[c.fam.id](c, F, far)

  -- docking pods off the stem: the first near the cell (the far hangar's), the rest spread along it
  local pods = {}
  local span0, span1 = F.back - 40 * s - 30, F.body_front + 60 * s
  for k = 1, npods do
    local f = (k - 0.5) / npods
    local x = span0 + (span1 - span0) * f + rng:int(-6, 6)
    local a = (k * 2.399) % TAU          -- golden angle: pods spread round the stem
    local rad = (70 + rng:int(0, 110)) * s + (class == "outpost" and 8 or 18)
    if k == 1 then
      x = F.back - 70 * s - 8
      rad = (62 + rng:int(0, 30)) * s + (class == "outpost" and 8 or 18)
    end
    pods[k] = pod(c, x, a, rad, rng:int(1, 40))
  end
  local fp = pods[1]
  info.far_bay = fp and { fp.x + 36, c.AY + fp.y, fp.z } or { F.back, c.AY, 0 }
  info.pods = #pods

  -- monoliths floating round the stem, between the pods
  for k = 1, nmono do
    local x = F.body_front + (F.back - F.body_front) * (k / (nmono + 1)) + rng:int(-20, 20) * s
    local a = rng:float() * TAU
    local q = turn({ 0, (150 + rng:int(0, 90)) * s, 0 }, 0, 0, a)
    monolith(c, { x, q[2], q[1] }, (50 + rng:int(0, 30)) * s, rng:float() * PI)
  end
  -- cocoon clusters on the body's surface spots and along the stem
  for k = 1, ncoc do
    local sp = spots[(k * 5) % math.max(1, #spots) + 1]
    if k % 3 == 0 or not sp then
      local x = F.body_front + (F.back - F.body_front) * (0.2 + 0.6 * rng:float())
      sp = { p = { x, -12 * s, 0 }, n = { 0, -1, 0 } }
    end
    cocoons(c, sp.p, sp.n, rng:int(3, 6), 9 * s)
  end

  -- the silhouette: the stem, the cell and the pods as a few boxes (the body added its own)
  local function fbox(x0, y0, z0, x1, y1, z1, col, emi) far[#far + 1] = { kind = "box", min = { x0, y0 + c.AY, z0 }, max = { x1, y1 + c.AY, z1 }, color = col, emissive = emi } end
  fbox(F.body_front, -9 * s, -9 * s, F.back, 9 * s, 9 * s, P.trim)
  fbox(cell.lo[1] - 4, cell.lo[2] - 2.9 - c.AY, cell.lo[3] - 1.5, cell.hi[1], cell.hi[2] + 1.5 - c.AY, cell.hi[3] + 1.5, P.plate)
  fbox(cell.hi[1], cell.lo[2] - c.AY + 2, -9, cell.hi[1] + 0.8, cell.hi[2] - c.AY - 2, 9, { 1.0, 0.85, 0.55 }, 1)
  for k = 1, #pods do
    local p = pods[k]
    fbox(p.x - 44 * s, p.y - 10 * s, p.z - 12 * s, p.x, p.y + 10 * s, p.z + 12 * s, P.plate)
    fbox(p.x, p.y - 6 * s, p.z - 6 * s, p.x + 0.6, p.y + 6 * s, p.z + 6 * s, { 1.0, 0.85, 0.55 }, 1)
  end

  -- (the hull data the view and the tests read)
  info.extent = { lo = F.lo, hi = F.hi }
  info.centre = F.centre
  info.radius = F.radius
  info.length = F.hi[1] - F.lo[1]
  info.width = F.hi[3] - F.lo[3]
  info.height = F.hi[2] - F.lo[2]
  local L = { seed = seed, class = class, info = info, parts = c.mesh and c.parts or nil, solids = c.solids, spin = c.spin, lights = c.lights, far_bay = info.far_bay,
              pal = P, spin_pos = { F.hx, c.AY, 0 }, bay = cell, ring_r = F.R, family = c.fam.id }
  L.counts = {}
  if c.mesh then for k, v in pairs(c.parts) do L.counts[k] = #v end end
  L.hash = M.hash(L)
  return L
end

function M.hash(L)
  local parts = { L.class, L.family, L.info.palette, string.format("%.1f,%.1f,%.1f,%d,%d", L.info.R, L.info.stem, L.info.body, L.info.pods, L.info.bay_no) }
  for _, b in ipairs(L.solids) do parts[#parts + 1] = string.format("s%.1f,%.1f,%.1f,%.1f", b[1][1], b[1][2], b[1][3], b[2][1]) end
  for _, l in ipairs(L.lights) do parts[#parts + 1] = string.format("l%.1f,%.1f,%.1f,%d", l.p[1], l.p[2], l.p[3], l.phase) end
  return string.format("%016x", saucer.hash64(table.concat(parts, ";"), 1))
end

-- ---------------------------------------------------------------------------------------------------
-- per trader: the class, the seed and the world placement
-- ---------------------------------------------------------------------------------------------------
function M.class_of(tr) return (tr and tr.outpost) and "outpost" or "port" end

function M.seed_of(seed, sid, idx) return saucer.seed_child(seed or 0, "hull", (sid or 1) * 16 + (idx or 1)) end
function M.seed_for(state, idx) return M.seed_of(state.seed, state.sector and state.sector.id or 1, idx) end

local cache, order = {}, {}
function M.get(seed, class, bay_no, family)
  family = family or M.family_of(seed)
  local key = class .. ":" .. seed .. ":" .. tostring(bay_no) .. ":" .. family
  local L = cache[key]
  if not L then
    L = M.generate(seed, class, bay_no, false, family)
    cache[key] = L
    order[#order + 1] = key
    if #order > 24 then cache[table.remove(order, 1)] = nil end
  end
  return L
end

-- the triangles of a layout from M.get (built on demand, a few kept)
local full, full_order = {}, {}
function M.parts(L)
  if L.parts then return L.parts end
  local F = full[L.hash]
  if not F then
    F = M.generate(L.seed, L.class, L.info.bay_no, true, L.family)
    full[L.hash] = F
    full_order[#full_order + 1] = L.hash
    if #full_order > 3 then full[table.remove(full_order, 1)] = nil end
  end
  return F.parts
end

function M.parts_ready(L) return L.parts ~= nil or full[L.hash] ~= nil end

function M.for_trader(state, idx)
  local list = state.sector.traders or { state.sector.trader }
  local tr = list[idx] or list[1]
  -- the arrival hangar's number inside (sim/stationgen.lua) is the one over the mouth outside
  local sg = require("sim.stationgen")
  local ss = sg.seed_for(state, idx or 1)
  return M.get(M.seed_for(state, idx or 1), M.class_of(tr), sg.bay_number(ss), M.family_of(ss)), tr
end

-- the collision boxes of every trader's hull in world meters (the cell's own are sim/dock.lua's)
function M.world_solids(state)
  local out = {}
  local list = state.sector.traders or { state.sector.trader }
  for idx, tr in ipairs(list) do
    local L = M.for_trader(state, idx)
    local p = tr.pos
    for _, b in ipairs(L.solids) do
      out[#out + 1] = { { b[1][1] + p[1], b[1][2] + p[2], b[1][3] + p[3] }, { b[2][1] + p[1], b[2][2] + p[2], b[2][3] + p[3] } }
    end
  end
  return out
end

-- fix-station-hull: the nearest point of a spin shape to q (in the spin frame) -> that point, the shape's
-- thickness there (0 for an annulus, whose point is on its surface)
local function nearest(sh, q)
  if sh.kind == "sphere" then return sh.c, sh.r end
  if sh.kind == "capsule" then
    local a, b = sh.a, sh.b
    local ab = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
    local l2 = ab[1] * ab[1] + ab[2] * ab[2] + ab[3] * ab[3]
    local t = l2 > 0 and ((q[1] - a[1]) * ab[1] + (q[2] - a[2]) * ab[2] + (q[3] - a[3]) * ab[3]) / l2 or 0
    t = math.max(0, math.min(1, t))
    return { a[1] + ab[1] * t, a[2] + ab[2] * t, a[3] + ab[3] * t }, sh.r
  end
  if sh.kind == "torus" then
    local n = sh.n
    local d = q[1] * n[1] + q[2] * n[2] + q[3] * n[3]
    local pl = { q[1] - n[1] * d, q[2] - n[2] * d, q[3] - n[3] * d }
    local l = len3(pl[1], pl[2], pl[3])
    if l < 1e-6 then return nil end
    return { pl[1] * sh.R / l, pl[2] * sh.R / l, pl[3] * sh.R / l }, sh.r
  end
  -- annulus about the x axis: clamp x to its thickness and the radius to rin..rout
  local rr = sm.sqrt(q[2] * q[2] + q[3] * q[3])
  local x = math.max(sh.x0, math.min(sh.x1, q[1]))
  local k = math.max(sh.rin, math.min(sh.rout, rr))
  if rr < 1e-6 then return { x, k, 0 }, 0 end
  return { x, q[2] * k / rr, q[3] * k / rr }, 0
end
M.spin_nearest = nearest

M.SPIN_NEAR = 6000   -- m from a trader's anchor: nearer than this its spinning layer is checked
-- a hull (a sphere of radius r about pos, world meters) against every trader's spinning layer at this tick ->
-- pos pushed out of what it overlaps (a new table), and the number of shapes it was pushed from. The layer's turn
-- comes from the tick (the same as the view's), so every peer and every replay sees the same push.
function M.spin_push(state, pos, r)
  local list = state.sector.traders or { state.sector.trader }
  local hits = 0
  local ang = (state.tick or 0) * M.kit().spin
  local ca, sa = sm.cos(ang), sm.sin(ang)
  for idx, tr in ipairs(list) do
    local ex, ey, ez = pos[1] - tr.pos[1], pos[2] - tr.pos[2], pos[3] - tr.pos[3]
    local L = (ex * ex + ey * ey + ez * ez < M.SPIN_NEAR * M.SPIN_NEAR) and M.for_trader(state, idx) or {}
    local sp = L.spin_pos or { 0, 0, 0 }
    local cx, cy, cz = tr.pos[1] + sp[1], tr.pos[2] + sp[2], tr.pos[3] + sp[3]
    local dx, dy, dz = pos[1] - cx, pos[2] - cy, pos[3] - cz
    if L.spin and #L.spin > 0 and len3(dx, dy, dz) < (L.spin_reach or M.spin_reach(L)) + r then
      -- into the layer's frame: undo its pitch (about x) by the tick's angle
      local q = { dx, dy * ca + dz * sa, -dy * sa + dz * ca }
      for _, sh in ipairs(L.spin) do
        local np, th = nearest(sh, q)
        if np then
          local vx, vy, vz = q[1] - np[1], q[2] - np[2], q[3] - np[3]
          local d = len3(vx, vy, vz)
          local need = r + th
          if d < need then
            if d < 1e-6 then vx, vy, vz, d = 0, 1, 0, 1 end
            local k = (need - d) / d
            q = { q[1] + vx * k, q[2] + vy * k, q[3] + vz * k }
            hits = hits + 1
          end
        end
      end
      if hits > 0 then
        pos = { cx + q[1], cy + q[2] * ca - q[3] * sa, cz + q[2] * sa + q[3] * ca }
      end
    end
  end
  return pos, hits
end

-- how far from the spin centre the spinning layer's shapes reach (memoised on the layout)
function M.spin_reach(L)
  local m = 0
  for _, sh in ipairs(L.spin or {}) do
    local e
    if sh.kind == "sphere" then e = len3(sh.c[1], sh.c[2], sh.c[3]) + sh.r
    elseif sh.kind == "capsule" then e = math.max(len3(sh.a[1], sh.a[2], sh.a[3]), len3(sh.b[1], sh.b[2], sh.b[3])) + sh.r
    elseif sh.kind == "torus" then e = sh.R + sh.r
    else e = math.max(math.abs(sh.x0), math.abs(sh.x1)) + sh.rout end
    if e > m then m = e end
  end
  L.spin_reach = m
  return m
end

-- where the far hangar's space door opens: in front of a docking pod, in world meters
function M.far_bay_pos(state, idx)
  local L, tr = M.for_trader(state, idx)
  local p = tr.pos
  local f = L.far_bay
  return { p[1] + f[1] + 28, p[2] + f[2], p[3] + f[3] }
end

-- the sphere that holds a trader's whole station (world meters) -> centre, radius, bounding box lo, hi
function M.bounds(state, idx)
  local L, tr = M.for_trader(state, idx)
  local p = tr.pos
  local e = L.info.extent
  return { p[1] + L.info.centre[1], p[2] + L.info.centre[2], p[3] + L.info.centre[3] }, L.info.radius,
         { p[1] + e.lo[1], p[2] + e.lo[2], p[3] + e.lo[3] }, { p[1] + e.hi[1], p[2] + e.hi[2], p[3] + e.hi[3] }
end

return M
