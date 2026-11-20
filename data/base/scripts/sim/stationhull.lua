-- SPDX-License-Identifier: MIT
-- The outside of a trader station (OpenSpec add-huge-stations).
--
-- generate(seed, class) lays out a kilometre-scale megastructure in "anchor" meters: the origin is the
-- trader's `pos`, the dock anchor, and the hangar cell of sim/dock.lua sits at its +x end, so the station
-- hangs off the cell's back wall toward -x: a long visitor arm to a hub drum, one or two rings that spin
-- about the x axis, spokes, docking arms with pods and parked ships, habitat drums, solar wings, radiator
-- fins, masts with dishes, cargo racks, lit windows, beacons and panel greebles. The hangar cell is one small
-- bay among many.
--
-- The result is plain data, a pure function of (seed, class, the dock tune and the kit): the same on every
-- platform, never saved. Mesh parts come in layers (view/stationhull.lua turns each into one mesh):
--   core    standing hull: arm, hub, spine, pods, arrays, the hangar cell's shell
--   detail  its trusses, greebles, windows and the hangar's dressing (drawn near)
--   ring    spinning rings, spokes and drums (turn about the x axis through `spin`)
--   ringd   their windows and greebles (drawn near)
--   far     one cheap silhouette of everything (drawn from afar)
-- plus `solids` (boxes for the physics world), `lights` and `far_bay`, where the far hangar's pod opens.
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
local function new_ctx(seed, class)
  local H = M.kit()
  local K = H.classes[class]
  if not K then error("unknown station class " .. tostring(class)) end
  local T = data.load("saucer/dock.lua")
  local c = {
    H = H, K = K, T = T, class = class, seed = seed,
    AY = T.floor_y + T.height / 2,
    parts = { core = {}, detail = {}, ring = {}, ringd = {}, far = {} },
    solids = {}, lights = {},
    rng = saucer.rng.new(saucer.seed_child(seed, "hull", 1)),
    drng = saucer.rng.new(saucer.seed_child(seed, "hull", 2)),
  }
  c.pal = H.palettes[c.rng:int(1, #H.palettes)]
  return c
end

local function add(c, layer, part)
  local l = c.parts[layer]
  l[#l + 1] = part
  return part
end

local function box(c, layer, x0, y0, z0, x1, y1, z1, color, emi)
  local AY = (layer == "ring" or layer == "ringd") and 0 or c.AY
  return add(c, layer, { kind = "box", min = { math.min(x0, x1), math.min(y0, y1) + AY, math.min(z0, z1) },
                         max = { math.max(x0, x1), math.max(y0, y1) + AY, math.max(z0, z1) }, color = color, emissive = emi })
end

-- a cylinder along x from x0 to x1 about the axis through (y, z)
local function xcyl(c, layer, x0, x1, y, z, r, color, seg, emi, r1)
  local AY = (layer == "ring" or layer == "ringd") and 0 or c.AY
  local lo, hi = math.min(x0, x1), math.max(x0, x1)
  local kind = r1 and "cone" or "cylinder"
  -- roll -pi/2 turns +y into +x; a cone's r is its +y end's start, so a cone narrows toward x1 when x0 < x1
  return add(c, layer, { kind = kind, c = { 0, 0, 0 }, r = r, r1 = r1, h = hi - lo, seg = seg or 12, color = color,
                         emissive = emi, roll = -PI / 2, pos = { lo, y + AY, z } })
end

-- an annulus about the x axis, thick along x from x0 to x1
local function xring(c, layer, x, w, rin, rout, seg, color, emi)
  local AY = (layer == "ring" or layer == "ringd") and 0 or c.AY
  return add(c, layer, { kind = "ring", c = { 0, -w / 2, 0 }, rin = rin, r = rout, h = w, seg = seg, color = color, emissive = emi,
                         roll = -PI / 2, pos = { x, AY, 0 } })
end

-- a box at radius r0..r1 on the axis' circle, angle a (0 = +z, pi/2 = +y), x0..x1 along the axis, half-width hw
local function rbox(c, layer, x0, x1, r0, r1, hw, a, color, emi)
  local AY = (layer == "ring" or layer == "ringd") and 0 or c.AY
  return add(c, layer, { kind = "box", min = { x0, -hw, r0 }, max = { x1, hw, r1 }, color = color, emissive = emi,
                         pitch = a, pos = { 0, AY, 0 } })
end

-- a square rod between two points (anchor meters, y relative to the axis), half-thickness w
local function rod(c, layer, a, b, w, color, emi)
  local AY = (layer == "ring" or layer == "ringd") and 0 or c.AY
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local hz = sm.sqrt(dx * dx + dz * dz)
  local len = sm.sqrt(hz * hz + dy * dy)
  if len < 1e-3 then return nil end
  return add(c, layer, { kind = "box", min = { -w, -w, 0 }, max = { w, w, len }, color = color, emissive = emi,
                         yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, hz), pos = { a[1], a[2] + AY, a[3] } })
end

local function sphere(c, layer, x, y, z, r, color, emi, seg)
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
  local WALL, FLOOR, STRIP, WARN = { 0.36, 0.39, 0.47 }, { 0.27, 0.3, 0.35 }, { 0.35, 0.9, 1.0 }, { 1.0, 0.75, 0.15 }
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
-- the megastructure
-- ---------------------------------------------------------------------------------------------------
local function window_rows(c, layer, x, hw, r, rows, spacing, a0, a1, glow, density, facing)
  -- lit window strips on a cylinder of radius r about the axis: `rows` rows across hw*2 at x +/- ...
  local rng = c.drng
  local n = math.max(6, math.floor((a1 - a0) * r / spacing))
  for row = 1, rows do
    local xx = x - hw + (row - 0.5) * (2 * hw / rows)
    local k = 0
    while k < n do
      if rng:float() < density then
        local run = rng:int(1, 2)
        local a = a0 + (a1 - a0) * (k + run / 2) / n
        local len = run * (a1 - a0) * r / n * 0.8
        local th = 0.9
        if facing > 0 then rbox(c, layer, xx - 0.9, xx + 0.9, r - 0.1, r + th, len / 2, a, glow, 1)
        else rbox(c, layer, xx - 0.9, xx + 0.9, r - th, r + 0.1, len / 2, a, glow, 1) end
        k = k + run
      else
        k = k + 1
      end
    end
  end
end

-- a docking arm pod facing +x: beam from the arm, a body with a lit mouth, a frame, a number, a beacon
local function pod(c, x, a, rad, no, ship)
  local P, K = c.pal, c.K
  local s = (c.class == "outpost") and 0.3 or 1.0
  local ca, sa = sm.cos(a), sm.sin(a)
  local cy, cz = rad * sa, rad * ca       -- the pod's centre off the axis
  local axw = 5 * s                         -- beam half-thickness
  rod(c, "core", { x, 0, 0 }, { x, cy, cz }, axw, P.trim)
  rod(c, "detail", { x, 0, 0 }, { x, cy, cz }, axw * 0.45, P.panel)
  for k = 1, 3 do
    local f = k / 4
    rod(c, "detail", { x - 3 * s, cy * f, cz * f }, { x + 3 * s, cy * f, cz * f }, axw * 1.15, P.panel)
  end
  local px0, px1 = x - 36 * s, x + 6 * s
  local hh, hz = 9 * s, 12 * s
  box(c, "core", px0, cy - hh, cz - hz, px1, cy + hh, cz + hz, P.plate)
  box(c, "core", px0 + 2 * s, cy + hh, cz - hz + 1 * s, px1 - 2 * s, cy + hh + 1.5 * s, cz + hz - 1 * s, P.trim)
  -- the mouth: a dark recess with a glowing back, a frame and a hazard lip
  box(c, "core", px1 - 0.2, cy - hh * 0.62, cz - hz * 0.75, px1 + 0.4, cy + hh * 0.62, cz + hz * 0.75, { 1.0, 0.85, 0.55 }, 0.9)
  local fw = 0.8 * s + 0.4
  box(c, "core", px1, cy - hh * 0.62 - fw, cz - hz * 0.75 - fw, px1 + 0.9, cy - hh * 0.62, cz + hz * 0.75 + fw, P.accent, 0.8)
  box(c, "core", px1, cy + hh * 0.62, cz - hz * 0.75 - fw, px1 + 0.9, cy + hh * 0.62 + fw, cz + hz * 0.75 + fw, P.accent, 0.8)
  box(c, "core", px1, cy - hh * 0.62, cz - hz * 0.75 - fw, px1 + 0.9, cy + hh * 0.62, cz - hz * 0.75, P.accent, 0.8)
  box(c, "core", px1, cy - hh * 0.62, cz + hz * 0.75, px1 + 0.9, cy + hh * 0.62, cz + hz * 0.75 + fw, P.accent, 0.8)
  if s > 0.5 then sign(c, "detail", string.format("%02d", no), px1, cy + hh * 0.62 + fw + 1.2, cz, 0.9, P.glow, 1) end
  -- flank windows and ribs
  for k = 0, 5 do
    local xx = px0 + 3 * s + k * 6 * s
    if c.drng:int(1, 3) > 1 then box(c, "detail", xx, cy - hh * 0.3, cz + hz, xx + 2.4 * s, cy + hh * 0.3, cz + hz + 0.25, P.glow, 1) end
    box(c, "detail", xx + 3 * s, cy - hh, cz - hz - 0.3, xx + 3.6 * s, cy + hh, cz + hz + 0.3, P.trim)
  end
  light(c, px1 + 1, cy + hh + 2 * s - 0 - 0 - 0, cz, c.drng:int(1, 2) == 1 and { 1, 0.25, 0.2 } or { 0.3, 1, 0.4 }, "blink", 3.5, 80)
  if ship and s > 0.5 then
    parked_ship(c, "detail", px1 + 14, cy - hh * 0.5, cz + c.drng:int(-4, 4), c.drng:float() * 0.5 - 0.25, 1.0,
                c.drng:int(0, 1) == 0 and { 0.62, 0.64, 0.7 } or { 0.7, 0.5, 0.32 }, P.accent)
  end
  solid(c, px0 + 1, c.AY + cy - hh + 1, cz - hz + 1, px1 - 1, c.AY + cy + hh - 1, cz + hz - 1)
  return { x = px1, y = cy, z = cz }
end

-- a dish on a mast: the mast from the axis' radius out, a hemisphere dish, its feed, and a beacon
local function mast(c, x, a, r0, len)
  local P = c.pal
  local ca, sa = sm.cos(a), sm.sin(a)
  local s = (c.class == "outpost") and 0.35 or 1.0
  local y0, z0 = r0 * sa, r0 * ca
  local y1, z1 = (r0 + len) * sa, (r0 + len) * ca
  rod(c, "core", { x, y0, z0 }, { x, y1, z1 }, 1.4 * s, P.trim)
  for k = 1, math.floor(len / (9 * s)) do
    local f = (k * 9 * s) / len
    if f < 1 then
      local yy, zz = y0 + (y1 - y0) * f, z0 + (z1 - z0) * f
      rod(c, "detail", { x - 2.5 * s, yy, zz }, { x + 2.5 * s, yy, zz }, 0.35 * s, P.panel)
    end
  end
  -- the dish: a hemisphere facing +x
  add(c, "core", { kind = "hemisphere", c = { 0, 0, 0 }, r = 12 * s, h = 5 * s, seg = 10, rings = 3, color = P.plate, roll = -PI / 2,
                   pos = { x - 0.5, y1 + c.AY, z1 } })
  rod(c, "core", { x, y1, z1 }, { x + 9 * s, y1, z1 }, 0.35 * s, P.trim)
  box(c, "core", x + 8.5 * s, y1 - 1 * s, z1 - 1 * s, x + 10 * s, y1 + 1 * s, z1 + 1 * s, P.accent, 0.7)
  light(c, x - 1, y1 + 0, z1, { 1, 0.2, 0.15 }, "blink", 3, 110)
  solid(c, x - 1.0, c.AY + math.min(y0, y1) - 1, math.min(z0, z1) - 1, x + 1.0, c.AY + math.max(y0, y1) + 1, math.max(z0, z1) + 1)
end

function M.generate(seed, class, bay_no_in)
  class = class or "port"
  local c = new_ctx(seed, class)
  local K, P, T, rng, H = c.K, c.pal, c.T, c.rng, c.H
  local s = (class == "outpost") and 0.3 or 1.0
  local R = rint(rng, K.radius)
  local arm = rint(rng, K.arm)
  local hub_r, hub_len = rint(rng, K.hub_r), rint(rng, K.hub_len)
  local nrings, nspokes = rint(rng, K.rings), rint(rng, K.spokes)
  local narms, ndrums, nmasts = rint(rng, K.arms), rint(rng, K.drums), rint(rng, K.masts)
  local nwings, ncargo = rint(rng, K.wings), rint(rng, K.cargo)
  local aft = rint(rng, K.aft)
  local bay_no = bay_no_in or rng:int(1, 24)
  rng:int(1, 24)   -- (the stream stays the same whether or not the number is given)
  local back = T.back_x - 3.5 - T.wall            -- where the cell's door passage ends: the arm starts here
  local hub_front = back - arm
  local hx = hub_front - hub_len / 2
  local hub_back = hub_front - hub_len
  local aft_end = hub_back - aft
  local aw = math.max(2.5, hub_r * 0.12)          -- visitor arm half-width
  local tube_w, tube_t = 56 * s, 34 * s            -- the big ring's width along x and its radial thickness
  local rin, rout = R - tube_t / 2, R + tube_t / 2
  local ring_seg = math.max(24, math.min(64, math.floor(R / 9)))
  local info = { R = R, arm = arm, hub_r = hub_r, hub_len = hub_len, rings = nrings, spokes = nspokes, arms = narms,
                 drums = ndrums, masts = nmasts, wings = nwings, cargo = ncargo, aft = aft, bay_no = bay_no, hx = hx,
                 palette = P.name, axis_y = c.AY, hub_front = hub_front, aft_end = aft_end, back = back }

  -- the hangar cell and the arm that carries it
  local cell = bay_cell(c, bay_no)
  box(c, "core", hub_front, -aw, -aw, back, aw, aw, P.trim)
  box(c, "core", hub_front + 2, -aw * 1.3, -aw * 0.5, back - 1, -aw * 0.7, aw * 0.5, P.panel)
  solid(c, hub_front, c.AY - aw * 0.8, -aw * 0.8, back, c.AY + aw * 0.8, aw * 0.8)
  for _, sy in ipairs({ -1, 1 }) do
    for _, sz in ipairs({ -1, 1 }) do
      box(c, "core", hub_front, sy * aw - 0.5, sz * aw - 0.5, back, sy * aw + 0.5, sz * aw + 0.5, shade(P.plate, 1.1))
    end
  end
  -- collars with lit windows every ~55 m, truss bays between them
  local nc = math.max(2, math.floor(arm / (55 * math.max(s, 0.6))))
  for k = 1, nc do
    local x = back - k * arm / (nc + 1)
    box(c, "core", x - 3 * s, -aw * 1.5, -aw * 1.5, x + 3 * s, aw * 1.5, aw * 1.5, P.plate)
    box(c, "detail", x - 3.2 * s, -aw * 0.6, aw * 1.5, x + 3.2 * s, aw * 0.6, aw * 1.5 + 0.3, P.glow, 1)
    box(c, "detail", x - 3.2 * s, -aw * 0.6, -aw * 1.5 - 0.3, x + 3.2 * s, aw * 0.6, -aw * 1.5, P.glow, 1)
    box(c, "detail", x - 1 * s, aw * 1.5, -aw * 0.3, x + 1 * s, aw * 1.5 + 2.5 * s, aw * 0.3, P.accent, 0.6)
  end
  local nb = math.floor(arm / (9 * math.max(s, 0.5)))
  for k = 0, nb - 1 do
    local x0 = hub_front + k * arm / nb
    local x1 = x0 + arm / nb
    local w = aw * 1.02
    rod(c, "detail", { x0, -w, -w }, { x1, w, -w }, 0.35 * math.max(s, 0.6), P.panel)
    rod(c, "detail", { x0, w, -w }, { x1, -w, -w }, 0.35 * math.max(s, 0.6), P.panel)
    rod(c, "detail", { x0, -w, w }, { x1, w, w }, 0.35 * math.max(s, 0.6), P.panel)
    rod(c, "detail", { x0, w, w }, { x1, -w, w }, 0.35 * math.max(s, 0.6), P.panel)
  end
  -- cable run and a pipe bundle along the arm
  add(c, "detail", { kind = "cylinder", c = { 0, 0, 0 }, r = 0.5 * math.max(s, 0.6), h = arm, seg = 6, color = { 0.8, 0.55, 0.15 }, roll = -PI / 2,
                     pos = { hub_front, c.AY + aw + 1.2, 0 } })

  -- the hub: a drum with a nose, a lit observation band and docking collars, a tower on top
  xcyl(c, "core", hub_back, hub_front, 0, 0, hub_r, P.plate, 20)
  xcyl(c, "core", hub_front, hub_front + 22 * s, 0, 0, hub_r, P.trim, 20, nil, hub_r * 0.5)   -- the nose cone toward the bay
  xcyl(c, "core", hub_back - 18 * s, hub_back, 0, 0, hub_r * 0.55, P.trim, 14, nil, hub_r)
  xring(c, "core", hx, 8 * s, hub_r - 0.3, hub_r + 1.2, 20, P.glow, 1)
  xring(c, "core", hx + hub_len * 0.3, 3 * s, hub_r - 0.3, hub_r + 0.9, 20, P.accent, 0.7)
  xring(c, "core", hx - hub_len * 0.3, 3 * s, hub_r - 0.3, hub_r + 0.9, 20, P.accent, 0.7)
  box(c, "core", hx - 14 * s, hub_r - 2, -9 * s, hx + 14 * s, hub_r + 26 * s, 9 * s, P.plate)
  box(c, "detail", hx - 14.2 * s, hub_r + 14 * s, -7 * s, hx + 14.2 * s, hub_r + 20 * s, 7 * s, P.glow, 1)
  sphere(c, "core", hx, hub_r + 28 * s, 0, 7 * s, P.trim, nil, 8)
  solid(c, hub_back, c.AY - hub_r * 0.78, -hub_r * 0.78, hub_front, c.AY + hub_r * 0.78, hub_r * 0.78)
  solid(c, hx - 12 * s, c.AY + hub_r - 4, -7 * s, hx + 12 * s, c.AY + hub_r + 24 * s, 7 * s)
  light(c, hx, hub_r + 36 * s, 0, { 1, 1, 1 }, "strobe", 5, 150)
  -- hub detail: window grids and panel seams around the drum
  for k = 0, 23 do
    local a = k * TAU / 24
    if k % 2 == 0 then rbox(c, "detail", hub_back + 4, hub_front - 4, hub_r - 0.2, hub_r + 0.5, 0.7 * (hub_r / 60), a, P.panel) end
    for row = 1, 4 do
      if c.drng:int(1, 10) > 3 then
        local xx = hub_back + 10 + (row - 1) * (hub_len - 20) / 3
        rbox(c, "detail", xx, xx + 5, hub_r - 0.2, hub_r + 0.7, 1.4 * math.max(s, 0.5), a + 0.065, P.glow, 1)
      end
    end
  end

  -- the aft spine: a long mast behind the hub, with cargo racks, wings and a thruster cluster
  local sr = hub_r * 0.28
  xcyl(c, "core", aft_end, hub_back - 18 * s, 0, 0, sr, P.trim, 12)
  solid(c, aft_end, c.AY - sr * 0.8, -sr * 0.8, hub_back - 18 * s, c.AY + sr * 0.8, sr * 0.8)
  for k = 1, math.floor(aft / (22 * math.max(s, 0.5))) do
    local x = hub_back - 18 * s - k * 22 * math.max(s, 0.5)
    if x > aft_end + 6 then xring(c, "detail", x, 2 * s, sr, sr * 1.35, 12, P.panel) end
  end
  -- thrusters: four glowing nozzles
  for k = 0, 3 do
    local a = k * TAU / 4 + PI / 4
    local y, z = sm.sin(a) * sr * 0.6, sm.cos(a) * sr * 0.6
    xcyl(c, "core", aft_end - 9 * s, aft_end, y, z, sr * 0.35, P.panel, 8, nil, sr * 0.55)
    xcyl(c, "core", aft_end - 10 * s, aft_end - 9 * s, y, z, sr * 0.38, { 0.4, 0.8, 1.0 }, 8, 1)
  end
  light(c, aft_end - 12 * s, 0, 0, { 0.4, 0.8, 1.0 }, "steady", 8, 0)
  -- cargo racks: a frame with a grid of coloured containers
  local cargo_cols = { P.accent, { 0.6, 0.6, 0.62 }, { 0.35, 0.5, 0.7 }, { 0.7, 0.3, 0.25 }, { 0.8, 0.75, 0.55 } }
  for rk = 1, ncargo do
    local x = hub_back - 18 * s - (rk * aft / (ncargo + 1.5))
    local half = 3.6 * s
    for arm_i = 0, 3 do
      local a = arm_i * PI / 2
      local ca, sa = sm.cos(a), sm.sin(a)
      rod(c, "core", { x, sr * sa, sr * ca }, { x, (sr + 40 * s) * sa, (sr + 40 * s) * ca }, 1.0 * s, P.trim)
      for i = 0, 3 do
        for j = 0, 1 do
          local rr = sr + 8 * s + i * 8 * s
          local oy, oz = rr * sa, rr * ca
          local px, py = -sa, ca   -- sideways
          local col = cargo_cols[(rk + arm_i + i + j) % #cargo_cols + 1]
          local lx = x - half + j * 2 * half * 0.5
          box(c, "core", lx, oy - 3 * s + 0, oz - 3 * s, lx + half * 0.9, oy + 3 * s, oz + 3 * s, col)
          if i == 0 and j == 0 then box(c, "detail", lx, oy + (px ~= 0 and 0 or 0), oz, lx, oy, oz, col) end
        end
      end
    end
    solid(c, x - half, c.AY - 44 * s, -44 * s, x + half, c.AY + 44 * s, 44 * s)
  end
  -- solar wings: paired panels with a grid and a spar, and nav lights at the tips
  for wi = 1, nwings do
    local x = hub_back - 18 * s - aft * (0.3 + 0.55 * (wi - 1) / math.max(1, nwings))
    local len = (R * 0.62) * (0.8 + 0.4 * rng:float())
    local wd = 55 * s * (0.8 + 0.5 * rng:float())
    local twist = (wi - 1) * PI / 2
    for sgn = -1, 1, 2 do
      local ey, ez = sm.cos(twist) * sgn, sm.sin(twist) * sgn
      -- panel in the x-(y or z) plane
      local y0, y1 = 0, len * ey
      local z0, z1 = 0, len * ez
      if wi % 2 == 1 then
        box(c, "core", x - wd / 2, math.min(sr, sgn * len), -0.8 * s, x + wd / 2, math.max(sgn * len, sr), 0.8 * s, { 0.16, 0.2, 0.42 })
        box(c, "core", x - 1.2 * s, math.min(0, sgn * len), -2 * s, x + 1.2 * s, math.max(0, sgn * len), 2 * s, P.trim)
        local cells = math.max(4, math.floor(len / (22 * math.max(s, 0.5))))
        for k = 0, cells do
          local yy = sgn * (k * len / cells)
          box(c, "detail", x - wd / 2, yy - 0.3, -0.9 * s, x + wd / 2, yy + 0.3, 0.9 * s, { 0.4, 0.5, 0.85 }, 0.15)
        end
        for k = 1, 3 do
          local xx = x - wd / 2 + k * wd / 4
          box(c, "detail", xx - 0.25, math.min(0, sgn * len), -0.9 * s, xx + 0.25, math.max(0, sgn * len), 0.9 * s, { 0.4, 0.5, 0.85 }, 0.15)
        end
        light(c, x, sgn * len, 0, sgn > 0 and { 0.3, 1, 0.4 } or { 1, 0.25, 0.2 }, "blink", 3.5, 100)
        solid(c, x - wd / 2, c.AY + math.min(sr, sgn * len) , -1.2 * s, x + wd / 2, c.AY + math.max(sgn * len, sr), 1.2 * s)
      else
        box(c, "core", x - wd / 2, -0.8 * s, math.min(sr, sgn * len), x + wd / 2, 0.8 * s, math.max(sgn * len, sr), { 0.16, 0.2, 0.42 })
        box(c, "core", x - 1.2 * s, -2 * s, math.min(0, sgn * len), x + 1.2 * s, 2 * s, math.max(0, sgn * len), P.trim)
        local cells = math.max(4, math.floor(len / (22 * math.max(s, 0.5))))
        for k = 0, cells do
          local zz = sgn * (k * len / cells)
          box(c, "detail", x - wd / 2, -0.9 * s, zz - 0.3, x + wd / 2, 0.9 * s, zz + 0.3, { 0.4, 0.5, 0.85 }, 0.15)
        end
        light(c, x, 0, sgn * len, sgn > 0 and { 0.3, 1, 0.4 } or { 1, 0.25, 0.2 }, "blink", 3.5, 100)
        solid(c, x - wd / 2, c.AY - 1.2 * s, math.min(sr, sgn * len), x + wd / 2, c.AY + 1.2 * s, math.max(sgn * len, sr))
      end
    end
    -- radiator fins on the spine beside the wings
    for k = 0, 3 do
      local a = k * PI / 2 + PI / 4
      local fx = x + wd * 0.75
      local ca, sa = sm.cos(a), sm.sin(a)
      rod(c, "core", { fx, sr * sa, sr * ca }, { fx, (sr + 46 * s) * sa, (sr + 46 * s) * ca }, 0.9 * s, { 0.85, 0.85, 0.88 })
      for q = 1, 3 do
        local f = q / 4
        rod(c, "detail", { fx - 6 * s, (sr + 46 * s * f) * sa, (sr + 46 * s * f) * ca }, { fx + 6 * s, (sr + 46 * s * f) * sa, (sr + 46 * s * f) * ca }, 0.25 * s, { 0.7, 0.3, 0.2 })
      end
    end
  end

  -- the big ring: a body, bands, spokes and habitat drums, all turning about the x axis through the hub
  local function ring_at(x, Rr, w, t, seg, spokes, spoke_r0, wide)
    local rin2, rout2 = Rr - t / 2, Rr + t / 2
    xring(c, "ring", x - hx, w, rin2, rout2, seg, P.plate)
    xring(c, "ring", x - hx - w * 0.5, 1.6 * s, rin2 - 0.4, rout2 + 0.4, seg, P.trim)
    xring(c, "ring", x - hx + w * 0.5, 1.6 * s, rin2 - 0.4, rout2 + 0.4, seg, P.trim)
    xring(c, "ring", x - hx - w * 0.24, 1.0 * s, rout2 - 0.1, rout2 + 0.9, seg, P.accent, 0.8)
    xring(c, "ring", x - hx + w * 0.24, 1.0 * s, rout2 - 0.1, rout2 + 0.9, seg, P.accent, 0.8)
    xring(c, "ring", x - hx, 1.0 * s, rin2 - 0.9, rin2 + 0.1, seg, P.glow, 1)
    for k = 0, spokes - 1 do
      local a = k * TAU / spokes + 0.2
      rbox(c, "ring", x - hx - 3.5 * wide, x - hx + 3.5 * wide, spoke_r0, rin2 + 1, 3.5 * wide, a, P.trim)
      rbox(c, "ring", x - hx - 1, x - hx + 1, spoke_r0, rin2, 4.2 * wide, a, P.panel)
      -- a lit tube along each spoke
      rbox(c, "ringd", x - hx - 0.4, x - hx + 0.4, spoke_r0 + 4, rin2 - 2, 3.6 * wide, a, P.glow, 0.9)
    end
    -- seams: radial ribs on the rim every few segments
    for k = 0, seg - 1 do
      local a = k * TAU / seg
      rbox(c, "ringd", x - hx - w / 2, x - hx + w / 2, rout2, rout2 + 0.4 * math.max(s, 0.6), 0.5 * math.max(s, 0.6), a, P.panel)
    end
  end
  ring_at(hx, R, tube_w, tube_t, ring_seg, nspokes, hub_r * 0.5, math.max(s, 0.4))
  -- window rows on the rim, outside and in
  window_rows(c, "ringd", 0, tube_w * 0.45, rout, K.window_rows, 15 * math.max(s, 0.5), 0, TAU, P.glow, 0.72, 1)
  window_rows(c, "ringd", 0, tube_w * 0.45, rin, K.window_rows - 1, 15 * math.max(s, 0.5), 0, TAU, P.glow, 0.72, -1)
  -- habitat drums riding the outer rim
  for k = 1, ndrums do
    local a = (k - 1) * TAU / ndrums + rng:float() * 0.3
    local dr = (22 + rng:int(0, 12)) * s
    local dl = (70 + rng:int(0, 60)) * s
    local ox = rng:int(-6, 6) * s
    local rr = rout + dr * 0.9
    local y, z = rr * sm.sin(a), rr * sm.cos(a)
    xcyl(c, "ring", ox - dl / 2, ox + dl / 2, y, z, dr, P.plate, 14)
    xcyl(c, "ring", ox - dl / 2 - 3 * s, ox - dl / 2, y, z, dr * 0.5, P.trim, 10, nil, dr * 0.95)
    xcyl(c, "ring", ox + dl / 2, ox + dl / 2 + 3 * s, y, z, dr * 0.5, P.trim, 10, nil, dr * 0.95)
    xcyl(c, "ring", ox - dl / 2 + dl * 0.2, ox - dl / 2 + dl * 0.2 + 2 * s, y, z, dr * 1.04, P.accent, 14, 0.7)
    for q = 1, 8 do
      local xa = ox - dl / 2 + dl * (q - 0.5) / 8
      local wa = q * 0.7
      local yy, zz = y + dr * 0.97 * sm.sin(a + PI / 2 + wa * 0.0), z
      -- port windows on the drum's flank facing the hub's neighbour (a short strip on top)
      local rb = rr + dr * 0.99
      rbox(c, "ringd", xa - 1.2, xa + 1.2, rb - 0.1, rb + 0.5, 1.0 * s + 0.4, a + (q % 2 == 0 and 0.04 or -0.04) * (dr * 0.5 / rr) * 10, P.glow, 1)
    end
    rod(c, "ring", { ox, rout * sm.sin(a), rout * sm.cos(a) }, { ox, y, z }, 2 * s, P.trim)
  end
  -- ring collision: a polygon of short tangent boxes, a little inside the plating
  do
    local n = math.max(24, math.floor(2 * PI * R / (34 * math.max(s, 0.4))))
    local L = 2 * PI * R / n
    for k = 0, n - 1 do
      local a = (k + 0.5) * TAU / n
      local cy, cz = R * sm.sin(a), R * sm.cos(a)
      local hh = math.max(tube_t * 0.38, 1.5)
      local ex = math.abs(sm.sin(a)) * L / 2 + math.abs(sm.cos(a)) * hh
      local ez = math.abs(sm.cos(a)) * L / 2 + math.abs(sm.sin(a)) * hh
      solid(c, hx - tube_w * 0.4, c.AY + cy - ex * 0.9, cz - ez * 0.9, hx + tube_w * 0.4, c.AY + cy + ex * 0.9, cz + ez * 0.9)
    end
  end
  -- the inner ring, nearer the bay, on spokes to the visitor arm
  if nrings > 1 then
    local R2 = R * 0.5
    local x2 = hub_front + arm * 0.42
    local t2 = tube_t * 0.62
    ring_at(x2, R2, tube_w * 0.55, t2, math.max(20, ring_seg - 12), 4, aw * 1.2, math.max(s, 0.4) * 0.8)
    window_rows(c, "ringd", x2 - hx, tube_w * 0.2, R2 + t2 / 2, 2, 14 * math.max(s, 0.5), 0, TAU, P.glow, 0.7, 1)
    local n = math.max(16, math.floor(2 * PI * R2 / (30 * math.max(s, 0.4))))
    local L = 2 * PI * R2 / n
    for k = 0, n - 1 do
      local a = (k + 0.5) * TAU / n
      local cy, cz = R2 * sm.sin(a), R2 * sm.cos(a)
      local hh = math.max(t2 * 0.38, 1.2)
      local ex = math.abs(sm.sin(a)) * L / 2 + math.abs(sm.cos(a)) * hh
      local ez = math.abs(sm.cos(a)) * L / 2 + math.abs(sm.sin(a)) * hh
      solid(c, x2 - tube_w * 0.2, c.AY + cy - ex * 0.9, cz - ez * 0.9, x2 + tube_w * 0.2, c.AY + cy + ex * 0.9, cz + ez * 0.9)
    end
    info.inner = { x = x2, r = R2 }
  end

  -- docking arms: pods on beams off the visitor arm, one of them the far hangar
  local pods = {}
  local span0, span1 = back - 40 * s - 30, hub_front + 40 * s
  for k = 1, narms do
    local f = (k - 0.5) / narms
    local x = span0 + (span1 - span0) * f + rng:int(-6, 6)
    -- keep clear of the inner ring's plane
    if info.inner and math.abs(x - info.inner.x) < 40 * s + 10 then x = x + 55 * s end
    local a = (k * 2.399) % TAU           -- golden angle: arms spread round the arm
    local rad = (60 + rng:int(0, 80)) * s + (class == "outpost" and 8 or 18)
    if k == 1 then
      -- the far hangar's pod sits near the cell, so a Villa grown there is still "docked" at the trader
      x = back - 70 * s - 8
      rad = (62 + rng:int(0, 30)) * s + (class == "outpost" and 8 or 18)
    end
    pods[k] = pod(c, x, a, rad, rng:int(1, 40), rng:int(0, 2) > 0)
  end
  -- the pod whose mouth faces most nearly away from the others is the far hangar's: take the first
  local far = pods[1]
  info.far_bay = far and { far.x + 36, c.AY + far.y, far.z } or { back, c.AY, 0 }

  -- masts with dishes and beacons
  for k = 1, nmasts do
    local a = (k - 0.5) * TAU / nmasts + rng:float() * 0.5
    local x = hub_back + rng:int(0, math.floor(hub_len)) * 0.9
    local len = (60 + rng:int(0, 70)) * s
    mast(c, x, a, hub_r + 2, len)
  end

  -- greeble pass on the hub, arm and spine: small boxes (vents, hatches, tanks) seeded round the surfaces
  local dg = K.detail
  local n_greeble = math.floor(380 * dg)
  for _ = 1, n_greeble do
    local x = rfloat(c.drng, aft_end + 10, hub_front)
    local a = c.drng:float() * TAU
    local rr
    local hwid
    if x > hub_back then rr, hwid = hub_r, 6 * s
    elseif x < hub_back - 18 * s then rr, hwid = sr, 2 * s
    else rr, hwid = hub_r * 0.55, 3 * s end
    local kind = c.drng:int(1, 4)
    local col = kind == 1 and P.panel or (kind == 2 and P.trim or (kind == 3 and P.accent or shade(P.plate, 0.85)))
    local lx = c.drng:int(2, 7) * s * 1.2
    rbox(c, "detail", x, x + lx, rr - 0.3, rr + (0.5 + c.drng:float() * 1.4) * math.max(s, 0.6), hwid * (0.3 + c.drng:float() * 0.7) * 0.5, a, col, kind == 3 and 0.2 or nil)
  end

  -- ---- the silhouette: everything as a few dozen parts -------------------------------------------
  local f = c.parts.far
  local function fbox(x0, y0, z0, x1, y1, z1, col, emi) f[#f + 1] = { kind = "box", min = { x0, y0 + c.AY, z0 }, max = { x1, y1 + c.AY, z1 }, color = col, emissive = emi } end
  f[#f + 1] = { kind = "ring", c = { 0, -tube_w / 2, 0 }, rin = rin, r = rout, h = tube_w, seg = 28, color = P.plate, roll = -PI / 2, pos = { hx, c.AY, 0 } }
  f[#f + 1] = { kind = "ring", c = { 0, -0.6, 0 }, rin = rout - 0.5, r = rout + 1.0, h = 1.2, seg = 28, color = P.glow, emissive = 0.8, roll = -PI / 2, pos = { hx, c.AY, 0 } }
  if info.inner then
    f[#f + 1] = { kind = "ring", c = { 0, -tube_w * 0.27, 0 }, rin = info.inner.r - tube_t * 0.31, r = info.inner.r + tube_t * 0.31, h = tube_w * 0.55, seg = 20,
                  color = P.plate, roll = -PI / 2, pos = { info.inner.x, c.AY, 0 } }
  end
  for k = 0, 3 do
    local a = k * PI / 2 + 0.2
    f[#f + 1] = { kind = "box", min = { -3, -3, hub_r }, max = { 3, 3, rin }, color = P.trim, pitch = a, pos = { hx, c.AY, 0 } }
  end
  f[#f + 1] = { kind = "cylinder", c = { 0, 0, 0 }, r = hub_r, h = hub_len + 22 * s, seg = 12, color = P.plate, roll = -PI / 2, pos = { hub_back, c.AY, 0 } }
  f[#f + 1] = { kind = "cylinder", c = { 0, 0, 0 }, r = sr, h = aft, seg = 6, color = P.trim, roll = -PI / 2, pos = { aft_end, c.AY, 0 } }
  fbox(hub_front, -aw, -aw, back, aw, aw, P.trim)
  fbox(hx - 14 * s, hub_r - 2, -9 * s, hx + 14 * s, hub_r + 26 * s, 9 * s, P.plate)
  fbox(hx - hub_len * 0.5 + 6, hub_r * 0.2, hub_r - 0.2, hx - hub_len * 0.5 + 12, hub_r * 0.3, hub_r + 0.8, P.glow, 1)
  fbox(cell.lo[1] - 4, cell.lo[2] - 2.9 - c.AY, cell.lo[3] - 1.5, cell.hi[1], cell.hi[2] + 1.5 - c.AY, cell.hi[3] + 1.5, P.plate)
  fbox(cell.hi[1], cell.lo[2] - c.AY + 2, -9, cell.hi[1] + 0.8, cell.hi[2] - c.AY - 2, 9, { 1.0, 0.85, 0.55 }, 1)
  for k = 1, #pods do
    local p = pods[k]
    local sz = 12 * s
    fbox(p.x - 42 * s, p.y - 9 * s, p.z - sz, p.x, p.y + 9 * s, p.z + sz, P.plate)
    fbox(p.x, p.y - 5 * s, p.z - 9 * s, p.x + 0.6, p.y + 5 * s, p.z + 9 * s, { 1.0, 0.85, 0.55 }, 1)
    local a = sm.atan2(p.y, p.z)
    f[#f + 1] = { kind = "box", min = { -3 * s, -3 * s, 0 }, max = { 3 * s, 3 * s, sm.sqrt(p.y * p.y + p.z * p.z) }, color = P.trim, pitch = a,
                  pos = { p.x - 30 * s, c.AY, 0 } }
  end
  -- wings, as flat boxes
  for wi = 1, nwings do
    local x = hub_back - 18 * s - aft * (0.3 + 0.55 * (wi - 1) / math.max(1, nwings))
    for _, sgn in ipairs({ -1, 1 }) do
      -- (the near layers drew them from their own seeds; this is the same footprint, rounded)
      local len = R * 0.62
      local wd = 55 * s
      if wi % 2 == 1 then fbox(x - wd / 2, math.min(sr, sgn * len), -0.8, x + wd / 2, math.max(sgn * len, sr), 0.8, { 0.16, 0.2, 0.42 })
      else fbox(x - wd / 2, -0.8, math.min(sr, sgn * len), x + wd / 2, 0.8, math.max(sgn * len, sr), { 0.16, 0.2, 0.42 }) end
    end
  end
  -- (the hull data the view and the tests read)
  local ext = { lo = { aft_end - 14, -R - 40 * s, -R - 40 * s }, hi = { cell.hi[1] + 6, R + 40 * s, R + 40 * s } }
  info.extent = { lo = { ext.lo[1], c.AY + ext.lo[2], ext.lo[3] }, hi = { ext.hi[1], c.AY + ext.hi[2], ext.hi[3] } }
  info.centre = { hx, c.AY, 0 }
  info.radius = sm.sqrt(((ext.hi[1] - ext.lo[1]) / 2) ^ 2 + R * R)
  info.pods = #pods
  info.length = ext.hi[1] - ext.lo[1]
  info.width = 2 * (R + tube_t / 2)
  local L = { seed = seed, class = class, info = info, parts = c.parts, solids = c.solids, lights = c.lights, far_bay = info.far_bay,
              pal = P, spin_pos = { hx, c.AY, 0 }, bay = cell, ring_r = R }
  L.counts = {}
  for k, v in pairs(c.parts) do L.counts[k] = #v end
  L.hash = M.hash(L)
  return L
end

function M.hash(L)
  local parts = { L.class, L.info.palette, string.format("%.1f,%.1f,%.1f,%d,%d", L.info.R, L.info.arm, L.info.hub_r, L.info.pods, L.info.bay_no) }
  for _, name in ipairs({ "core", "detail", "ring", "ringd", "far" }) do
    local l = L.parts[name]
    parts[#parts + 1] = name .. #l
    for i = 1, #l, math.max(1, #l // 40) do
      local p = l[i]
      local a = p.min or p.pos or p.c
      parts[#parts + 1] = string.format("%s%.1f,%.1f,%.1f", p.kind, a[1], a[2], a[3])
    end
  end
  for _, b in ipairs(L.solids) do parts[#parts + 1] = string.format("s%.1f,%.1f,%.1f", b[1][1], b[1][2], b[1][3]) end
  return string.format("%016x", saucer.hash64(table.concat(parts, ";"), 1))
end

-- ---------------------------------------------------------------------------------------------------
-- per trader: the class, the seed and the world placement
-- ---------------------------------------------------------------------------------------------------
function M.class_of(tr) return (tr and tr.outpost) and "outpost" or "port" end

function M.seed_of(seed, sid, idx) return saucer.seed_child(seed or 0, "hull", (sid or 1) * 16 + (idx or 1)) end
function M.seed_for(state, idx) return M.seed_of(state.seed, state.sector and state.sector.id or 1, idx) end

local cache, order = {}, {}
function M.get(seed, class, bay_no)
  local key = class .. ":" .. seed .. ":" .. tostring(bay_no)
  local L = cache[key]
  if not L then
    L = M.generate(seed, class, bay_no)
    cache[key] = L
    order[#order + 1] = key
    if #order > 8 then cache[table.remove(order, 1)] = nil end
  end
  return L
end

function M.for_trader(state, idx)
  local list = state.sector.traders or { state.sector.trader }
  local tr = list[idx] or list[1]
  -- the arrival hangar's number inside (sim/stationgen.lua) is the one over the mouth outside
  local sg = require("sim.stationgen")
  return M.get(M.seed_for(state, idx or 1), M.class_of(tr), sg.bay_number(sg.seed_for(state, idx or 1))), tr
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
