-- SPDX-License-Identifier: MIT
-- Drawing a trader station on foot (OpenSpec add-pocket-station-visits).
-- The layout (sim/stationgen.lua) becomes two meshes per station, built once:
-- the shell (floors, walls with their doorways, ceilings; the station kit's
-- wall texture) and the detail pass (wall panels and trim, pipes, light
-- strips, door frames and signs, crates, fuel tanks, landing pads, gantries,
-- market stalls with awnings and goods, the bar's counter, shelves, stools,
-- tables and neon). Live each frame: the folk (stall keepers, the bartender,
-- bar patrons, strollers, the pickpocket), other players on foot, the hangar
-- force fields with space beyond, and the saucer folding into (or growing
-- out of) your hand. Render-only: nothing here touches the sim state.
local sg = require("sim.stationgen")
local visit = require("sim.visit")
local configs = require("sim.config")
local vec = require("lib.vec")
local assets = require("view.assets")
local sm = saucer.math
local M = {}

local cache = {}

local KIND_COLOR = {
  market = { 1.0, 0.72, 0.25 }, bar = { 1.0, 0.35, 0.8 }, hangar = { 0.35, 0.9, 1.0 }, corridor = { 0.9, 0.92, 1.0 },
}
M.KIND_COLOR = KIND_COLOR
local METAL, DARK, TRIM = { 0.52, 0.5, 0.48 }, { 0.2, 0.19, 0.2 }, { 0.75, 0.72, 0.66 }
local FLOOR = { 0.34, 0.33, 0.36 }
-- per-area wall and floor tints over the station kit's texture
local WALL_TINT = { market = { 1.0, 0.9, 0.75 }, bar = { 0.62, 0.45, 0.66 }, hangar = { 0.78, 0.82, 0.88 },
                    corridor = { 0.92, 0.92, 0.98 } }
local FLOOR_TINT = { market = { 0.55, 0.45, 0.35 }, bar = { 0.4, 0.24, 0.22 }, hangar = { 0.36, 0.38, 0.42 },
                     corridor = { 0.45, 0.45, 0.5 } }
local HAZARD = { 1.0, 0.72, 0.1 }
-- add-presentation-packaging: the floor tints were picked for the old plain
-- texture; the tread-plate art is darker, so floors are lifted by this much
local ART_FLOOR = 2.0
local AD_PALETTE = { { 1.0, 0.45, 0.2 }, { 0.3, 0.85, 1.0 }, { 0.95, 0.85, 0.25 }, { 0.85, 0.35, 0.9 }, { 0.4, 1.0, 0.55 } }

local DIGITS = {
  ["0"] = { "111", "101", "101", "101", "111" }, ["1"] = { "010", "110", "010", "010", "111" },
  ["2"] = { "111", "001", "111", "100", "111" }, ["3"] = { "111", "001", "111", "001", "111" },
  ["4"] = { "101", "101", "111", "001", "001" }, ["5"] = { "111", "100", "111", "001", "111" },
  ["6"] = { "111", "100", "111", "101", "111" }, ["7"] = { "111", "001", "010", "010", "010" },
  ["8"] = { "111", "101", "111", "101", "111" }, ["9"] = { "111", "101", "111", "001", "111" },
}

local function box(x0, y0, z0, x1, y1, z1, color, extra)
  local p = { kind = "box", min = { math.min(x0, x1), math.min(y0, y1), math.min(z0, z1) },
              max = { math.max(x0, x1), math.max(y0, y1), math.max(z0, z1) }, color = color }
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end
local function cyl(x, y, z, r, h, color, seg, extra)
  local p = { kind = "cylinder", c = { x, y, z }, r = r, h = h, seg = seg or 8, color = color }
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end
local function shade(c, f) return { c[1] * f, c[2] * f, c[3] * f } end

-- a wall face of area a: axis 1 = the plane x = at, axis 3 = z = at, spanning
-- [u0, u1] on the other axis. -> list of open intervals (doorways, mouths)
local function face_openings(L, a, axis, at)
  local out = {}
  for _, d in ipairs(L.doors) do
    if d.axis == axis and math.abs(d.at - at) < 1e-6 and (d.a == a.id or d.b == a.id) then
      out[#out + 1] = { d.lo, d.hi, d = d }
    end
  end
  return out
end

-- the parts of [u0, u1] not covered by the intervals in `holes`
local function subtract(u0, u1, holes)
  table.sort(holes, function(x, y) return x[1] < y[1] end)
  local out, cur = {}, u0
  for _, h in ipairs(holes) do
    if h[1] > cur then out[#out + 1] = { cur, math.min(h[1], u1) } end
    cur = math.max(cur, h[2])
  end
  if cur < u1 then out[#out + 1] = { cur, u1 } end
  return out
end

-- neighbours sharing the plane: intervals where another area touches this face
local function neighbours(L, a, axis, at)
  local out = {}
  for _, b in ipairs(L.areas) do
    if b ~= a then
      local bb = b.box
      local lo, hi, plane_lo, plane_hi
      if axis == 1 then lo, hi, plane_lo, plane_hi = bb[2], bb[4], bb[1], bb[3]
      else lo, hi, plane_lo, plane_hi = bb[1], bb[3], bb[2], bb[4] end
      if math.abs(plane_lo - at) < 1e-6 or math.abs(plane_hi - at) < 1e-6 then out[#out + 1] = { lo, hi, b = b } end
    end
  end
  return out
end

-- every wall segment of the layout -> list of { axis, at, u0, u1, h, area, inward }
function M.wall_segments(L)
  local segs = {}
  for _, a in ipairs(L.areas) do
    local b = a.box
    local faces = {
      { axis = 1, at = b[1], u0 = b[2], u1 = b[4], inward = 1, sign = -1 },
      { axis = 1, at = b[3], u0 = b[2], u1 = b[4], inward = -1, sign = 1 },
      { axis = 3, at = b[2], u0 = b[1], u1 = b[3], inward = 1, sign = -1 },
      { axis = 3, at = b[4], u0 = b[1], u1 = b[3], inward = -1, sign = 1 },
    }
    for _, f in ipairs(faces) do
      local mouth = a.mouth and a.mouth.axis == f.axis and a.mouth.sign == f.sign
      if not mouth then
        local holes = face_openings(L, a, f.axis, f.at)
        -- shared stretches are walled once, by the lower id, as tall as the taller side
        local nb = neighbours(L, a, f.axis, f.at)
        local mine = subtract(f.u0, f.u1, holes)
        for _, piece in ipairs(mine) do
          local cuts = {}
          for _, n in ipairs(nb) do
            local lo, hi = math.max(piece[1], n[1]), math.min(piece[2], n[2])
            if hi > lo then cuts[#cuts + 1] = { lo, hi, n = n } end
          end
          for _, free in ipairs(subtract(piece[1], piece[2], cuts)) do
            segs[#segs + 1] = { axis = f.axis, at = f.at, u0 = free[1], u1 = free[2], h = a.h, area = a, inward = f.inward }
          end
          for _, c in ipairs(cuts) do
            if a.id < c.n.b.id then
              segs[#segs + 1] = { axis = f.axis, at = f.at, u0 = c[1], u1 = c[2], h = math.max(a.h, c.n.b.h), area = a,
                                  inward = f.inward, shared = true }
            end
          end
        end
      end
    end
  end
  return segs
end

local function seg_box(s, y0, y1, t, off)
  local w = t / 2
  local at = s.at + (off or 0) * s.inward
  if s.axis == 1 then return { at - w, y0, s.u0 }, { at + w, y1, s.u1 } end
  return { s.u0, y0, at - w }, { s.u1, y1, at + w }
end

function M.shell_parts(L)
  local k = sg.kit()
  local wall_c, uv = k.color, k.uv or 0.125
  local parts = {}
  local C = M.colors(L)
  for _, a in ipairs(L.areas) do
    local b = a.box
    local wt = (a.wing and C.wall) or WALL_TINT[a.kind] or { 1, 1, 1 }
    local tint = { wall_c[1] * wt[1], wall_c[2] * wt[2], wall_c[3] * wt[3] }
    parts[#parts + 1] = box(b[1], -0.25, b[2], b[3], 0, b[4], (a.wing and C.floor) or FLOOR_TINT[a.kind] or FLOOR, { uv = 0.25, mat = "floor" })
    parts[#parts + 1] = box(b[1], a.h, b[2], b[3], a.h + 0.3, b[4], shade(tint, 0.7), { uv = uv, mat = "ceiling" })
  end
  for _, s in ipairs(M.wall_segments(L)) do
    local mn, mx = seg_box(s, 0, s.h, sg.WALL)
    local wt = (s.area.wing and C.wall) or WALL_TINT[s.area.kind] or { 1, 1, 1 }
    parts[#parts + 1] = { kind = "box", min = mn, max = mx, color = { wall_c[1] * wt[1], wall_c[2] * wt[2], wall_c[3] * wt[3] },
                          uv = uv }
  end
  -- lintels over every doorway, up to the taller side's ceiling
  for _, d in ipairs(L.doors) do
    local top = math.max(L.areas[d.a].h, L.areas[d.b].h)
    local s = { axis = d.axis, at = d.at, u0 = d.lo, u1 = d.hi, inward = 1 }
    local mn, mx = seg_box(s, d.h, top, sg.WALL)
    parts[#parts + 1] = { kind = "box", min = mn, max = mx, color = wall_c, uv = uv }
  end
  return parts
end

-- a horizontal pipe from a to b at height y (a and b differ on one axis)
local function pipe(a, b, y, r, color)
  local dx, dz = b[1] - a[1], b[2] - a[2]
  local len = sm.sqrt(dx * dx + dz * dz)
  return { kind = "cylinder", c = { 0, -len / 2, 0 }, r = r, h = len, seg = 6, color = color,
           pos = { (a[1] + b[1]) / 2, y, (a[2] + b[2]) / 2 }, yaw = sm.atan2(dx, dz), pitch = 1.5708 }
end

local function wall_detail(out, s)
  local len = s.u1 - s.u0
  if len < 0.8 then return end
  local col = KIND_COLOR[s.area.kind] or TRIM
  -- skirting light strip and a dark kick plate
  local mn, mx = seg_box(s, 0, 0.3, 0.08, 0.17)
  out[#out + 1] = { kind = "box", min = mn, max = mx, color = DARK }
  mn, mx = seg_box(s, 0.3, 0.36, 0.06, 0.2)
  out[#out + 1] = { kind = "box", min = mn, max = mx, color = col, emissive = 0.8 }
  -- wall panels every ~4 m
  local n = math.max(1, math.floor(len / 4 + 0.5))
  local ph = math.min(3.2, s.h - 1.2)
  for i = 0, n - 1 do
    local u0 = s.u0 + len * i / n + 0.25
    local u1 = s.u0 + len * (i + 1) / n - 0.25
    if u1 - u0 > 0.4 then
      local q = { axis = s.axis, at = s.at, u0 = u0, u1 = u1, inward = s.inward }
      mn, mx = seg_box(q, 0.7, 0.7 + ph, 0.06, 0.18)
      out[#out + 1] = { kind = "box", min = mn, max = mx, color = shade(METAL, 0.85 + 0.1 * (i % 2)) }
      mn, mx = seg_box(q, 0.7 + ph * 0.45, 0.7 + ph * 0.45 + 0.05, 0.03, 0.22)
      out[#out + 1] = { kind = "box", min = mn, max = mx, color = shade(col, 0.9), emissive = 0.5 }
    end
  end
  -- a pipe run under the ceiling
  if s.h > 4 then
    local y = s.h - 0.6
    local off = s.at + s.inward * 0.35
    if s.axis == 1 then out[#out + 1] = pipe({ off, s.u0 + 0.1 }, { off, s.u1 - 0.1 }, y, 0.09, { 0.62, 0.36, 0.2 })
    else out[#out + 1] = pipe({ s.u0 + 0.1, off }, { s.u1 - 0.1, off }, y, 0.09, { 0.62, 0.36, 0.2 }) end
  end
end

local function solid_detail(out, s)
  if s.look == "crate" then
    local b = s.box
    local sz = b[3] - b[1]
    local tints = { { 0.6, 0.48, 0.3 }, { 0.45, 0.5, 0.42 }, { 0.62, 0.3, 0.22 } }
    for k = 0, (s.stack or 1) - 1 do
      local c = tints[((s.tint or 1) + k - 1) % 3 + 1]
      local y = k * sz
      out[#out + 1] = box(b[1], y, b[2], b[3], y + sz * 0.97, b[4], c)
      out[#out + 1] = box(b[1] - 0.02, y + sz * 0.45, b[2] - 0.02, b[3] + 0.02, y + sz * 0.55, b[4] + 0.02, shade(c, 0.6))
      out[#out + 1] = box(b[1] + sz * 0.2, y + sz * 0.7, b[2] - 0.03, b[1] + sz * 0.45, y + sz * 0.85, b[2], HAZARD,
        { emissive = 0.2 })
    end
  elseif s.look == "tank" then
    local x, z, r = s.c[1], s.c[2], s.r
    out[#out + 1] = cyl(x, 0, z, r, s.h, { 0.7, 0.72, 0.76 }, 12)
    out[#out + 1] = { kind = "sphere", c = { x, s.h, z }, r = r, h = r * 0.5, seg = 12, rings = 3, color = { 0.7, 0.72, 0.76 } }
    for _, y in ipairs({ 0.8, s.h - 0.8 }) do out[#out + 1] = cyl(x, y, z, r * 1.03, 0.25, HAZARD, 12) end
    out[#out + 1] = cyl(x, s.h * 0.5, z, r * 1.02, 0.4, { 1, 0.3, 0.2 }, 12, { emissive = 0.4 })
  elseif s.look == "pillar" then
    local x, z = s.c[1], s.c[2]
    out[#out + 1] = cyl(x, 0, z, s.r, s.h, METAL, 8)
    out[#out + 1] = cyl(x, 0, z, s.r * 1.5, 0.3, DARK, 8)
    out[#out + 1] = cyl(x, s.h - 0.4, z, s.r * 1.6, 0.4, DARK, 8)
    out[#out + 1] = cyl(x, 2.2, z, s.r * 1.08, 0.12, { 1, 0.75, 0.35 }, 8, { emissive = 1 })
  elseif s.look == "counter" then
    local b = s.box
    local c = s.color or { 0.8, 0.6, 0.3 }
    out[#out + 1] = box(b[1], 0, b[2], b[3], s.h - 0.06, b[4], shade(c, 0.55))
    out[#out + 1] = box(b[1] - 0.06, s.h - 0.06, b[2] - 0.06, b[3] + 0.06, s.h, b[4] + 0.06, { 0.75, 0.72, 0.66 })
    out[#out + 1] = box(b[1], 0.15, b[2] - 0.01, b[3], 0.22, b[4] + 0.01, c, { emissive = 0.9 })
  elseif s.look == "bar_counter" then
    local b = s.box
    out[#out + 1] = box(b[1], 0, b[2], b[3], s.h - 0.07, b[4], { 0.32, 0.18, 0.22 })
    out[#out + 1] = box(b[1] - 0.08, s.h - 0.07, b[2] - 0.08, b[3] + 0.08, s.h, b[4] + 0.08, { 0.85, 0.82, 0.78 })
    out[#out + 1] = box(b[1] - 0.01, 0.25, b[2], b[3] + 0.01, 0.3, b[4], { 1, 0.35, 0.8 }, { emissive = 1 })
  elseif s.look == "vending" then
    local b = s.box
    local c = s.color or { 1, 0.5, 0.2 }
    out[#out + 1] = box(b[1], 0, b[2], b[3], s.h, b[4], { 0.28, 0.28, 0.33 })
    -- the lit front faces the concourse: a screen, rows of goods, a coin slot
    local f = s.face
    local fx = f > 0 and b[3] or b[1]
    local d = f * 0.03
    local mid = (b[2] + b[4]) / 2
    out[#out + 1] = box(fx, 0.35, b[2] + 0.1, fx + d, 1.75, b[4] - 0.1, shade(c, 0.5), { emissive = 0.6 })
    for row = 0, 3 do
      for col = 0, 2 do
        local pc = AD_PALETTE[(row * 3 + col) % #AD_PALETTE + 1]
        out[#out + 1] = box(fx + d, 0.5 + row * 0.33, b[2] + 0.14 + col * 0.22, fx + d * 2, 0.7 + row * 0.33, b[2] + 0.3 + col * 0.22, pc, { emissive = 0.9 })
      end
    end
    out[#out + 1] = box(fx, 1.78, b[2] + 0.05, fx + d * 3, 1.9, b[4] - 0.05, c, { emissive = 1 })
    out[#out + 1] = box(fx, 0.1, mid - 0.12, fx + d * 2, 0.3, mid + 0.12, { 0.1, 0.1, 0.1 })
  elseif s.look == "kiosk" then
    local x, z, r = s.c[1], s.c[2], s.r
    local c = s.color or { 0.3, 0.85, 1 }
    out[#out + 1] = cyl(x, 0, z, r, 1.5, { 0.3, 0.3, 0.36 }, 8)
    out[#out + 1] = cyl(x, 0, z, r * 1.3, 0.15, DARK, 8)
    local fx = x + s.face * r * 0.98
    out[#out + 1] = box(fx, 0.9, z - 0.3, fx + s.face * 0.05, 1.45, z + 0.3, c, { emissive = 1 })
    out[#out + 1] = box(fx, 0.88, z - 0.32, fx + s.face * 0.04, 0.92, z + 0.32, { 1, 1, 1 }, { emissive = 0.8 })
    out[#out + 1] = cyl(x, 1.5, z, r * 0.9, 0.1, c, 8, { emissive = 1 })
  elseif s.look == "table" then
    local x, z = s.c[1], s.c[2]
    out[#out + 1] = cyl(x, 0, z, 0.08, s.h, DARK, 6)
    out[#out + 1] = cyl(x, 0, z, 0.35, 0.05, DARK, 10)
    out[#out + 1] = cyl(x, s.h, z, s.r, 0.06, { 0.55, 0.35, 0.3 }, 14)
    out[#out + 1] = cyl(x + 0.15, s.h + 0.06, z, 0.04, 0.16, { 0.4, 1, 0.7 }, 6, { emissive = 0.8 })
  end
end

local function prop_detail(out, q, L, rng)
  if q.kind == "pad" then
    local x, z, r = q.at[1], q.at[2], q.r
    out[#out + 1] = { kind = "ring", c = { x, 0.01, z }, rin = r - 0.5, r = r, h = 0.03, seg = 32, color = HAZARD, emissive = 0.7 }
    out[#out + 1] = { kind = "ring", c = { x, 0.01, z }, rin = r * 0.42, r = r * 0.42 + 0.3, h = 0.03, seg = 24,
                      color = { 0.35, 0.9, 1.0 }, emissive = 0.9 }
    out[#out + 1] = box(x - 2.5, 0.005, z - 0.3, x + 2.5, 0.035, z + 0.3, { 0.95, 0.95, 0.9 }, { emissive = 0.3 })
    out[#out + 1] = box(x - 0.3, 0.005, z - 2.5, x + 0.3, 0.035, z + 2.5, { 0.95, 0.95, 0.9 }, { emissive = 0.3 })
    for k = 0, 11 do
      local a = k * sm.tau / 12
      out[#out + 1] = cyl(x + sm.sin(a) * (r + 0.4), 0, z + sm.cos(a) * (r + 0.4), 0.15, 0.12, { 0.4, 1, 0.6 }, 6,
        { emissive = 1 })
    end
  elseif q.kind == "gantry" then
    local x, z, y = q.at[1], q.at[2], q.y
    local half = q.len / 2 - 0.5
    if q.axis == 3 then
      for _, ox in ipairs({ -6, 6 }) do out[#out + 1] = box(x + ox - 0.3, y, z - half, x + ox + 0.3, y + 0.6, z + half, DARK) end
      out[#out + 1] = box(x - 6, y - 0.2, z - 1, x + 6, y + 0.8, z + 1, { 0.75, 0.6, 0.2 })
      out[#out + 1] = box(x - 0.8, y - 1.6, z - 0.8, x + 0.8, y - 0.2, z + 0.8, DARK)
      out[#out + 1] = box(x - 0.5, y - 1.7, z - 0.5, x + 0.5, y - 1.6, z + 0.5, { 1, 0.9, 0.7 }, { emissive = 1 })
    else
      for _, oz in ipairs({ -6, 6 }) do out[#out + 1] = box(x - half, y, z + oz - 0.3, x + half, y + 0.6, z + oz + 0.3, DARK) end
      out[#out + 1] = box(x - 1, y - 0.2, z - 6, x + 1, y + 0.8, z + 6, { 0.75, 0.6, 0.2 })
      out[#out + 1] = box(x - 0.8, y - 1.6, z - 0.8, x + 0.8, y - 0.2, z + 0.8, DARK)
      out[#out + 1] = box(x - 0.5, y - 1.7, z - 0.5, x + 0.5, y - 1.6, z + 0.5, { 1, 0.9, 0.7 }, { emissive = 1 })
    end
  elseif q.kind == "awning" then
    local x, z, w, dir = q.at[1], q.at[2], q.w, q.dir
    for _, ox in ipairs({ -w / 2 + 0.08, w / 2 - 0.08 }) do
      out[#out + 1] = box(x + ox - 0.05, 0, z - dir * 0.9, x + ox + 0.05, 2.5, z - dir * 0.8, DARK)
    end
    out[#out + 1] = { kind = "wedge", min = { -w / 2, 0, 0 }, max = { w / 2, 0.35, 1.9 }, low = 0.05, color = q.color,
                      pos = { x, 2.5, z - dir * 1.0 }, yaw = dir > 0 and 0 or sm.pi }
    for k = 0, 3 do
      local u = -w / 2 + (k + 0.5) * w / 4
      out[#out + 1] = box(x + u - 0.2, 2.3, z + dir * 0.85, x + u + 0.2, 2.5, z + dir * 0.9, k % 2 == 0 and { 1, 1, 0.95 } or q.color)
    end
    out[#out + 1] = box(x - 0.9, 2.95, z - dir * 0.95, x + 0.9, 3.4, z - dir * 0.85, q.color, { emissive = 1 })
  elseif q.kind == "goods" then
    local x, z, w = q.at[1], q.at[2], q.w
    local cols = { { 0.9, 0.3, 0.3 }, { 0.3, 0.8, 0.4 }, { 0.95, 0.85, 0.3 }, { 0.4, 0.6, 1.0 }, { 0.8, 0.5, 0.9 } }
    for k = 0, 5 do
      local u = -w / 2 + (k + 0.5) * w / 6
      local c = cols[(q.seed + k) % #cols + 1]
      if (q.seed + k) % 3 == 0 then
        out[#out + 1] = { kind = "sphere", c = { x + u, 1.14, z }, r = 0.11, h = 0.11, seg = 6, rings = 3, color = c }
      elseif (q.seed + k) % 3 == 1 then
        out[#out + 1] = box(x + u - 0.12, 1.05, z - 0.12, x + u + 0.12, 1.3, z + 0.12, c)
      else
        out[#out + 1] = cyl(x + u, 1.05, z, 0.07, 0.3, c, 6, { emissive = 0.4 })
      end
    end
  elseif q.kind == "planter" then
    local x, z, r = q.at[1], q.at[2], q.r
    out[#out + 1] = cyl(x, 0, z, r, 0.6, DARK, 10)
    out[#out + 1] = { kind = "sphere", c = { 0, 0, 0 }, r = r * 0.95, h = r * 0.95, seg = 8, rings = 3, color = { 0.25, 0.55, 0.28 },
                      pos = { x, 1.0, z }, scale = { 1, 0.9, 1 } }
    out[#out + 1] = { kind = "sphere", c = { 0, 0, 0 }, r = r * 0.5, h = r * 0.5, seg = 8, rings = 3, color = { 0.95, 0.5, 0.7 },
                      pos = { x + r * 0.4, 1.4, z }, emissive = 0.3 }
  elseif q.kind == "shelf" then
    local x, z, len, dir = q.at[1], q.at[2], q.len, q.dir
    for k = 0, 2 do
      local y = 1.2 + k * 0.6
      out[#out + 1] = box(x - 0.15, y, z - len / 2, x + 0.15, y + 0.05, z + len / 2, { 0.5, 0.35, 0.25 })
      local n = math.floor(len / 0.35)
      for i = 0, n - 1 do
        local bz = z - len / 2 + (i + 0.5) * len / n
        local cols = { { 0.4, 1, 0.6 }, { 1, 0.5, 0.2 }, { 0.6, 0.6, 1 }, { 1, 0.9, 0.4 } }
        out[#out + 1] = cyl(x, y + 0.05, bz, 0.05, 0.25 + ((i + k) % 3) * 0.05, cols[(i + k * 3) % 4 + 1], 6, { emissive = 0.7 })
      end
    end
    out[#out + 1] = box(x - 0.05, 1.0, z - len / 2 - 0.1, x + 0.05, 3.2, z + len / 2 + 0.1, { 0.25, 0.15, 0.2 })
  elseif q.kind == "neon" then
    local x, z, len, y = q.at[1], q.at[2], q.len, q.y
    out[#out + 1] = box(x - 0.04, y, z - len / 2, x + 0.04, y + 0.12, z + len / 2, { 1, 0.3, 0.85 }, { emissive = 1 })
    out[#out + 1] = box(x - 0.04, y - 0.3, z - len / 2, x + 0.04, y - 0.24, z + len / 2, { 0.3, 0.9, 1 }, { emissive = 1 })
  elseif q.kind == "stool" then
    local x, z = q.at[1], q.at[2]
    out[#out + 1] = cyl(x, 0, z, 0.05, 0.72, DARK, 6)
    out[#out + 1] = cyl(x, 0.72, z, 0.22, 0.08, { 0.75, 0.25, 0.3 }, 10)
  elseif q.kind == "ad_panel" then
    -- a lit advert on the wall: a frame, a coloured field and a few glyph bars
    local x, z, w = q.at[1], q.at[2], q.w
    local f = q.face
    out[#out + 1] = box(x, 1.4, z - w / 2 - 0.08, x + f * 0.05, 3.5, z + w / 2 + 0.08, DARK)
    out[#out + 1] = box(x + f * 0.05, 1.5, z - w / 2, x + f * 0.08, 3.4, z + w / 2, shade(q.color, 0.55), { emissive = 0.8 })
    for k = 0, 4 do
      local g = ((q.seed + k * 7) % 5) + 1
      local zz = z - w / 2 + 0.2 + k * (w - 0.4) / 5
      out[#out + 1] = box(x + f * 0.08, 1.7 + (g % 3) * 0.2, zz, x + f * 0.11, 3.1 - (g % 2) * 0.35, zz + (w - 0.4) / 5 * 0.7, q.color, { emissive = 1 })
    end
  elseif q.kind == "bench" then
    local x, z, len, side = q.at[1], q.at[2], q.len, q.side
    out[#out + 1] = box(x - 0.22, 0.42, z - len / 2, x + 0.22, 0.5, z + len / 2, { 0.45, 0.32, 0.25 })
    out[#out + 1] = box(x - side * 0.2, 0.5, z - len / 2, x - side * 0.26, 1.0, z + len / 2, { 0.38, 0.27, 0.22 })
    for _, zz in ipairs({ z - len / 2 + 0.2, z + len / 2 - 0.2 }) do out[#out + 1] = box(x - 0.2, 0, zz - 0.05, x + 0.2, 0.42, zz + 0.05, DARK) end
  elseif q.kind == "banner" then
    -- a cloth banner hanging from the ceiling with a lit trim
    local x, z, y = q.at[1], q.at[2], q.y
    local w, h = 1.4, 2.6
    if q.axis == 1 then
      out[#out + 1] = box(x - 0.04, y - h - 0.2, z - w / 2, x + 0.04, y - 0.2, z + w / 2, shade(q.color, 0.7))
      out[#out + 1] = box(x - 0.05, y - h - 0.2, z - w / 2, x + 0.05, y - h - 0.12, z + w / 2, q.color, { emissive = 1 })
      out[#out + 1] = box(x - 0.05, y - h * 0.65, z - w * 0.2, x + 0.05, y - h * 0.4, z + w * 0.2, { 1, 1, 0.95 }, { emissive = 0.5 })
    else
      out[#out + 1] = box(x - w / 2, y - h - 0.2, z - 0.04, x + w / 2, y - 0.2, z + 0.04, shade(q.color, 0.7))
      out[#out + 1] = box(x - w / 2, y - h - 0.2, z - 0.05, x + w / 2, y - h - 0.12, z + 0.05, q.color, { emissive = 1 })
      out[#out + 1] = box(x - w * 0.2, y - h * 0.65, z - 0.05, x + w * 0.2, y - h * 0.4, z + 0.05, { 1, 1, 0.95 }, { emissive = 0.5 })
    end
    out[#out + 1] = box(x - 0.03, y - 0.25, z - 0.03, x + 0.03, y, z + 0.03, DARK)
  elseif q.kind == "skylight" then
    -- a ring skylight: a dark pane with a lit rim, so the ceiling reads as a structure
    local x, z, y, w = q.at[1], q.at[2], q.y, q.w
    out[#out + 1] = { kind = "ring", c = { x, y - 0.06, z }, rin = w * 0.36, r = w * 0.5, h = 0.1, seg = 20, color = { 1, 0.95, 0.85 }, emissive = 1 }
    out[#out + 1] = { kind = "ring", c = { x, y - 0.08, z }, rin = w * 0.1, r = w * 0.34, h = 0.04, seg = 20, color = { 0.55, 0.7, 1.0 }, emissive = 0.5 }
  elseif q.kind == "drone" then
    local x, z, y = q.at[1], q.at[2], q.y
    out[#out + 1] = { kind = "sphere", c = { x, y, z }, r = 0.28, h = 0.28, seg = 8, rings = 3, color = { 0.6, 0.62, 0.7 } }
    out[#out + 1] = { kind = "ring", c = { x, y + 0.2, z }, rin = 0.3, r = 0.42, h = 0.04, seg = 10, color = DARK }
    out[#out + 1] = { kind = "sphere", c = { x + 0.2, y, z }, r = 0.07, h = 0.07, seg = 6, rings = 2, color = { 0.4, 1, 0.8 }, emissive = 1 }
  elseif q.kind == "rail_crane" then
    local x, z, y = q.at[1], q.at[2], q.y
    local half = q.span / 2 - 0.4
    local lo, hi = q.along[1] + 0.4, q.along[2] - 0.4
    if q.axis == 3 then
      -- rails run along z on both sides; the bridge spans x
      for _, ox in ipairs({ -half, half }) do out[#out + 1] = box(x + ox - 0.3, y - 1.1, lo, x + ox + 0.3, y - 0.5, hi, { 0.18, 0.18, 0.2 }) end
      out[#out + 1] = box(x - half, y - 2.6, z - 0.6, x + half, y - 1.1, z + 0.6, { 0.85, 0.65, 0.15 })
      out[#out + 1] = box(x - 1.2, y - 3.4, z - 1.1, x + 1.2, y - 2.6, z + 1.1, { 0.22, 0.22, 0.25 })
      out[#out + 1] = box(x - 0.08, y - 3.4 - q.hook * 8, z - 0.08, x + 0.08, y - 3.4, z + 0.08, { 0.1, 0.1, 0.1 })
      out[#out + 1] = box(x - 0.4, y - 4.5 - q.hook * 8, z - 0.4, x + 0.4, y - 3.4 - q.hook * 8, z + 0.4, HAZARD, { emissive = 0.4 })
      out[#out + 1] = box(x + half - 0.1, y - 2.5, z - 0.2, x + half + 0.1, y - 2.2, z + 0.2, { 1, 0.3, 0.2 }, { emissive = 1 })
    else
      for _, oz in ipairs({ -half, half }) do out[#out + 1] = box(lo, y - 1.1, z + oz - 0.3, hi, y - 0.5, z + oz + 0.3, { 0.18, 0.18, 0.2 }) end
      out[#out + 1] = box(x - 0.6, y - 2.6, z - half, x + 0.6, y - 1.1, z + half, { 0.85, 0.65, 0.15 })
      out[#out + 1] = box(x - 1.1, y - 3.4, z - 1.2, x + 1.1, y - 2.6, z + 1.2, { 0.22, 0.22, 0.25 })
      out[#out + 1] = box(x - 0.08, y - 3.4 - q.hook * 8, z - 0.08, x + 0.08, y - 3.4, z + 0.08, { 0.1, 0.1, 0.1 })
      out[#out + 1] = box(x - 0.4, y - 4.5 - q.hook * 8, z - 0.4, x + 0.4, y - 3.4 - q.hook * 8, z + 0.4, HAZARD, { emissive = 0.4 })
      out[#out + 1] = box(x - 0.2, y - 2.5, z + half - 0.1, x + 0.2, y - 2.2, z + half + 0.1, { 1, 0.3, 0.2 }, { emissive = 1 })
    end
  elseif q.kind == "fuelline" then
    local x, z, len = q.at[1], q.at[2], q.len
    local ax = q.axis
    local p0 = ax == 1 and { x - len / 2, z } or { x, z - len / 2 }
    local p1 = ax == 1 and { x + len / 2, z } or { x, z + len / 2 }
    out[#out + 1] = pipe(p0, p1, 0.32, 0.14, { 0.8, 0.55, 0.15 })
    for k = 1, 5 do
      local f = k / 6
      local px, pz = p0[1] + (p1[1] - p0[1]) * f, p0[2] + (p1[2] - p0[2]) * f
      out[#out + 1] = box(px - 0.3, 0, pz - 0.3, px + 0.3, 0.62, pz + 0.3, { 0.25, 0.25, 0.28 })
      out[#out + 1] = box(px - 0.06, 0.62, pz - 0.06, px + 0.06, 0.95, pz + 0.06, { 1, 0.3, 0.2 }, { emissive = 0.5 })
    end
    -- the floor-level warning stripe beside the line
    local off = q.side * 0.5
    if ax == 1 then out[#out + 1] = box(p0[1], 0, z + off - 0.06, p1[1], 0.03, z + off + 0.06, HAZARD, { emissive = 0.3 })
    else out[#out + 1] = box(x + off - 0.06, 0, p0[2], x + off + 0.06, 0.03, p1[2], HAZARD, { emissive = 0.3 }) end
  elseif q.kind == "hose_reel" then
    local x, z = q.at[1], q.at[2]
    out[#out + 1] = box(x - 0.5, 0, z - 0.5, x + 0.5, 0.15, z + 0.5, DARK)
    out[#out + 1] = { kind = "ring", c = { 0, -0.35, 0 }, rin = 0.15, r = 0.75, h = 0.7, seg = 10, color = { 0.16, 0.16, 0.18 }, roll = 1.5708,
                      pos = { x, 0.95, z }, yaw = q.axis == 1 and 1.5708 or 0 }
    out[#out + 1] = box(x - 0.12, 0.15, z - 0.12, x + 0.12, 0.95, z + 0.12, METAL)
    out[#out + 1] = { kind = "ring", c = { 0, -0.18, 0 }, rin = 0.3, r = 0.6, h = 0.36, seg = 10, color = { 0.8, 0.55, 0.15 }, roll = 1.5708,
                      pos = { x, 0.95, z }, yaw = q.axis == 1 and 1.5708 or 0 }
  elseif q.kind == "lane" then
    -- two lit guide lines down the middle toward the pad, the mouth end striped
    local ax = q.axis
    for _, o in ipairs({ -1.4, 1.4 }) do
      local v = (ax == 1 and q.at[2] or q.at[1]) + o
      if ax == 1 then out[#out + 1] = box(q.from, 0.0, v - 0.08, q.to, 0.04, v + 0.08, { 0.35, 0.9, 1 }, { emissive = 1 })
      else out[#out + 1] = box(v - 0.08, 0.0, q.from, v + 0.08, 0.04, q.to, { 0.35, 0.9, 1 }, { emissive = 1 }) end
    end
  elseif q.kind == "wall_ship" then
    -- a cradle bolted to the wall, a small craft nose-in on it (or the cradle empty)
    local x, z, y = q.at[1], q.at[2], q.y
    local ax, sd = q.axis, q.side
    local function bx(u0, v0, y0, u1, v1, y1, c, e)
      if ax == 1 then out[#out + 1] = box(x + u0, y0, z + v0, x + u1, y1, z + v1, c, e and { emissive = e } or nil)
      else out[#out + 1] = box(x + v0, y0, z + u0, x + v1, y1, z + u1, c, e and { emissive = e } or nil) end
    end
    -- the wall is at +side * 1.3 from `at`; inward is -side
    bx(-3.2, sd * 1.3, y - 0.5, 3.2, -sd * 4.8, y, DARK)
    bx(-3.2, -sd * 4.8, y - 0.5, 3.2, -sd * 4.7, y + 0.04, { 0.35, 0.9, 1 }, 1)
    bx(-3.3, sd * 1.3, y - 2.4, -3.0, sd * 0.9, y + 3.6, DARK)
    bx(3.0, sd * 1.3, y - 2.4, 3.3, sd * 0.9, y + 3.6, DARK)
    bx(-0.4, sd * 1.3, y + 3.6, 0.4, sd * 0.9, y + 4.4, { 1, 0.3, 0.2 }, 1)
    if not q.empty then
      local yaw = ax == 1 and (-sd * 1.5708) or (sd > 0 and 0 or sm.pi)
      local cu, cv = 0, -sd * 1.7
      local sx, sz = x + (ax == 1 and cu or cv), z + (ax == 1 and cv or cu)
      for _, part in ipairs(require("lib.meshkit").ship(sx, y + 0.05, sz, yaw, 0.6, q.color, { 1, 0.5, 0.2 })) do out[#out + 1] = part end
    end
  elseif q.kind == "catwalk" then
    local x, z, len, y = q.at[1], q.at[2], q.len, q.y
    local ax, sd = q.axis, q.side
    local function bx(u0, v0, y0, u1, v1, y1, c, e)
      if ax == 1 then out[#out + 1] = box(x + u0, y0, z + v0, x + u1, y1, z + v1, c, e and { emissive = e } or nil)
      else out[#out + 1] = box(x + v0, y0, z + u0, x + v1, y1, z + u1, c, e and { emissive = e } or nil) end
    end
    bx(-len / 2, -0.8, y - 0.12, len / 2, 0.8, y, { 0.3, 0.3, 0.34 })
    bx(-len / 2, -sd * 0.8 - 0.04, y, len / 2, -sd * 0.8 + 0.04, y + 1.05, { 0.9, 0.7, 0.15 })
    bx(-len / 2, -sd * 0.8 - 0.05, y + 1.0, len / 2, -sd * 0.8 + 0.05, y + 1.08, { 1, 0.85, 0.3 }, 0.5)
    for k = 0, math.floor(len / 5) do
      local u = -len / 2 + k * 5
      bx(u - 0.08, -sd * 0.8 - 0.08, y, u + 0.08, -sd * 0.8 + 0.08, y + 1.05, { 0.9, 0.7, 0.15 })
      bx(u - 0.1, sd * 0.7, y - 1.4, u + 0.1, sd * 0.9, y - 0.12, DARK)
    end
    bx(-len / 2, sd * 0.8, y - 0.1, len / 2, sd * 0.86, y - 0.04, { 0.35, 0.9, 1 }, 1)
  elseif q.kind == "booth" then
    local x, z, y = q.at[1], q.at[2], q.y
    local ax, sd = q.axis, q.side
    local function bx(u0, v0, y0, u1, v1, y1, c, e)
      if ax == 1 then out[#out + 1] = box(x + u0, y0, z + v0, x + u1, y1, z + v1, c, e and { emissive = e } or nil)
      else out[#out + 1] = box(x + v0, y0, z + u0, x + v1, y1, z + u1, c, e and { emissive = e } or nil) end
    end
    bx(-2.4, -1.4, y, 2.4, 1.4, y + 2.8, { 0.3, 0.32, 0.38 })
    bx(-2.4, -sd * 1.4 - 0.04, y + 1.2, 2.4, -sd * 1.4 + 0.04, y + 2.4, { 0.5, 0.85, 1 }, 0.9)
    bx(-2.5, -1.5, y + 2.8, 2.5, 1.5, y + 3.0, DARK)
    bx(-0.6, -0.6, y + 3.0, 0.6, 0.6, y + 3.7, { 1, 0.7, 0.25 }, 0.8)
  elseif q.kind == "bay_sign" then
    -- the bay's number in big lit pixels on the wall opposite the mouth
    local x, z, y = q.at[1], q.at[2], q.y
    local s = 0.55
    local n = #q.text
    local width = n * 4 * s - s
    local f = q.face
    for i = 1, n do
      local g = DIGITS[q.text:sub(i, i)]
      if g then
        for row = 1, 5 do
          for col = 1, 3 do
            if g[row]:sub(col, col) == "1" then
              local u = -width / 2 + ((i - 1) * 4 + (col - 1)) * s
              local yy = y + (5 - row) * s
              if q.axis == 3 then
                out[#out + 1] = box(x + u, yy, z + f * 0.02, x + u + s, yy + s, z + f * 0.14, { 0.35, 0.9, 1 }, { emissive = 1 })
              else
                out[#out + 1] = box(x + f * 0.02, yy, z + u, x + f * 0.14, yy + s, z + u + s, { 0.35, 0.9, 1 }, { emissive = 1 })
              end
            end
          end
        end
      end
    end
  elseif q.kind == "cart" then
    local x, z = q.at[1], q.at[2]
    out[#out + 1] = { kind = "box", min = { -0.45, 0.2, -0.3 }, max = { 0.45, 0.28, 0.3 }, color = { 0.3, 0.3, 0.34 }, pos = { x, 0, z }, yaw = q.yaw }
    out[#out + 1] = { kind = "box", min = { -0.4, 0.28, -0.25 }, max = { 0.4, 0.8, 0.25 }, color = { 0.75, 0.2, 0.18 }, pos = { x, 0, z }, yaw = q.yaw }
    out[#out + 1] = { kind = "box", min = { -0.42, 0.78, -0.27 }, max = { 0.42, 0.84, 0.27 }, color = HAZARD, pos = { x, 0, z }, yaw = q.yaw, emissive = 0.3 }
    out[#out + 1] = { kind = "box", min = { 0.35, 0.84, -0.05 }, max = { 0.55, 1.1, 0.05 }, color = DARK, pos = { x, 0, z }, yaw = q.yaw }
  elseif q.kind == "lamp" then
    local x, z, y = q.at[1], q.at[2], q.y
    out[#out + 1] = cyl(x, y, z, 0.01, 0.6, DARK, 4)
    out[#out + 1] = { kind = "cone", c = { x, y - 0.35, z }, r = 0.35, r1 = 0.08, h = 0.35, seg = 10, color = { 0.95, 0.6, 0.3 } }
    out[#out + 1] = { kind = "sphere", c = { x, y - 0.38, z }, r = 0.1, h = 0.1, seg = 6, rings = 3, color = { 1, 0.9, 0.6 },
                      emissive = 1 }
  end
end

-- ---------------------------------------------------------------------------------------------------
-- add-alien-stations: the alien wing's look. Ribs arching over halls and passages (a little askew), organic
-- walls (half-sunk growths and glowing veins), and the chambers' things: growth pillars, pods, cocoon racks,
-- eggs, glowing plants, altars, braziers, pools, ledges, floating monoliths, glyph walls and orbiting lights.
-- Coloured by the station's family (kits/station.lua walk.alien.colors).
-- ---------------------------------------------------------------------------------------------------
function M.colors(L)
  local W = sg.kit().walk.alien
  return W.colors[L.family] or W.colors.coral
end

local function ell(out, x, y, z, rx, ry, rz, color, emi, seg, rings)
  out[#out + 1] = { kind = "sphere", c = { 0, 0, 0 }, r = 1, h = 1, seg = seg or 8, rings = rings or 3, color = color, emissive = emi,
                    scale = { rx, ry, rz }, pos = { x, y, z } }
end

-- a square rod from a to b (3D), half-thickness w
local function rod3(out, a, b, w, color, emi)
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local hz = sm.sqrt(dx * dx + dz * dz)
  local len = sm.sqrt(hz * hz + dy * dy)
  if len < 1e-3 then return end
  out[#out + 1] = { kind = "box", min = { -w, -w, 0 }, max = { w, w, len }, color = color, emissive = emi,
                    yaw = sm.atan2(dx, dz), pitch = -sm.atan2(dy, hz), pos = a }
end

local function glyph_bits(rng)
  local bits, on = {}, 0
  for k = 1, 12 do
    bits[k] = rng:int(0, 9) < 5
    if bits[k] then on = on + 1 end
  end
  if on < 4 then bits[2], bits[5], bits[8], bits[11] = true, true, true, true end
  return bits
end

-- a glyph on a wall plane: axis 1 (x = at, running along z) or 3, at u (its middle), y (its foot), cell s
local function glyph(out, axis, at, inward, u, y, s, color, rng)
  local g = glyph_bits(rng)
  for row = 1, 4 do
    for col = 1, 3 do
      if g[(row - 1) * 3 + col] then
        local uu = u + (col - 2.5) * s
        local yy = y + (4 - row) * s
        local p0, p1 = at + inward * 0.04, at + inward * 0.1
        if axis == 1 then out[#out + 1] = box(p0, yy, uu, p1, yy + s * 0.9, uu + s * 0.9, color, { emissive = 1 })
        else out[#out + 1] = box(uu, yy, p0, uu + s * 0.9, yy + s * 0.9, p1, color, { emissive = 1 }) end
      end
    end
  end
end

-- an organic wall: growths half sunk into it and glowing veins climbing it
local function organic_wall(out, s, C, rng)
  local len = s.u1 - s.u0
  if len < 1 then return end
  local n = math.max(1, math.floor(len / 4.2))
  for i = 0, n - 1 do
    local u = s.u0 + (i + 0.5) * len / n + (rng:float() - 0.5) * 0.8
    local y = 0.6 + rng:float() * math.min(s.h - 1.5, 5)
    local r = 0.5 + rng:float() * 0.9
    local at = s.at + s.inward * 0.05
    if s.axis == 1 then ell(out, at, y, u, r * 0.45, r * 1.4, r, C.trim, nil, 6, 2)
    else ell(out, u, y, at, r, r * 1.4, r * 0.45, C.trim, nil, 6, 2) end
    if i % 2 == 0 then
      local a3 = s.axis == 1 and { s.at + s.inward * 0.12, 0.2, u } or { u, 0.2, s.at + s.inward * 0.12 }
      local du = (rng:float() - 0.5) * 2.4
      local top = math.min(s.h - 0.3, 3 + rng:float() * 4)
      local b3 = s.axis == 1 and { a3[1], top, math.max(s.u0, math.min(s.u1, u + du)) } or { math.max(s.u0, math.min(s.u1, u + du)), top, a3[3] }
      rod3(out, a3, b3, 0.05, C.glow, 0.9)
    end
  end
  -- a lit band of glyphs at eye height, now and then
  if len > 6 and rng:int(0, 2) == 0 then
    local u = s.u0 + len * (0.25 + 0.5 * rng:float())
    for k = 0, 2 do glyph(out, s.axis, s.at, s.inward, u + (k - 1) * 0.9, 1.7, 0.2, C.accent, rng) end
  end
end

-- ribs arching across a hall every q.step meters along its long axis, a little askew
local function ribs(out, q, C)
  local b = q.box
  local along = q.axis
  local lo, hi = along == 1 and b[1] or b[2], along == 1 and b[3] or b[4]
  local clo, chi = along == 1 and b[2] or b[1], along == 1 and b[4] or b[3]
  local w = (chi - clo) / 2
  local mid = (clo + chi) / 2
  local top = q.h - 0.2
  local n = 6
  local u = lo + q.step * 0.5
  local k = 0
  while u < hi - 0.4 do
    local sk = q.skew * ((k % 3) - 1) * 0.5
    local prev
    for i = 0, n do
      local th = i * sm.pi / n
      local across = -sm.cos(th) * (w - 0.25)
      local y = sm.sin(th) * top
      local uu = math.max(lo + 0.1, math.min(hi - 0.1, u + across * sk))
      local p = along == 1 and { uu, y, mid + across } or { mid + across, y, uu }
      if prev then rod3(out, prev, p, 0.13, k % 2 == 0 and C.trim or shade(C.trim, 0.8)) end
      prev = p
    end
    -- a glowing node at the crown
    local cp = along == 1 and { u, top - 0.15, mid } or { mid, top - 0.15, u }
    ell(out, cp[1], cp[2], cp[3], 0.22, 0.22, 0.22, C.glow, 1, 5, 2)
    u = u + q.step
    k = k + 1
  end
end

local function alien_solid(out, s, C)
  local seed = s.seed or 1
  local rng = saucer.rng.new(seed)
  if s.look == "growth" then
    local x, z, r = s.c[1], s.c[2], s.r
    out[#out + 1] = { kind = "cone", c = { x, 0, z }, r = r, r1 = r * 0.5, h = s.h, seg = 8, color = C.trim }
    local y = 0.4
    while y < s.h - 0.5 do
      local rr = r * (0.9 + rng:float() * 0.5)
      ell(out, x + (rng:float() - 0.5) * r * 0.4, y + rr * 0.6, z + (rng:float() - 0.5) * r * 0.4, rr, rr * 1.3, rr, C.wall, nil, 8)
      if rng:int(0, 2) == 0 then ell(out, x + rr * 0.85, y + rr * 0.6, z, rr * 0.2, rr * 0.2, rr * 0.2, C.glow, 1, 5, 2) end
      y = y + rr * 2.2
    end
    out[#out + 1] = { kind = "cone", c = { x, s.h - 2.5, z }, r = r * 0.5, r1 = r * 2.0, h = 2.5, seg = 8, color = C.trim }
  elseif s.look == "pod" then
    ell(out, s.c[1], s.h * 0.5, s.c[2], s.r, s.h * 0.55, s.r, C.wall, nil, 10)
    ell(out, s.c[1], s.h * 0.5, s.c[2], s.r * 1.03, s.h * 0.08, s.r * 1.03, C.glow, 1, 10)
  elseif s.look == "egg" then
    ell(out, s.c[1], s.h * 0.48, s.c[2], s.r, s.h * 0.5, s.r, C.accent, 0.25, 10)
    ell(out, s.c[1], 0.1, s.c[2], s.r * 1.25, 0.12, s.r * 1.25, C.trim, nil, 10)
  elseif s.look == "plant" then
    local x, z = s.c[1], s.c[2]
    out[#out + 1] = cyl(x, 0, z, s.r * 0.18, s.h, C.trim, 6)
    ell(out, x, s.h, z, s.r * 0.8, s.r * 0.55, s.r * 0.8, C.glow, 0.9, 8)
    for k = 0, 3 do
      local a = k * sm.tau / 4 + rng:float()
      rod3(out, { x, s.h * 0.4, z }, { x + sm.sin(a) * s.r, s.h * 0.7, z + sm.cos(a) * s.r }, 0.04, C.accent, 0.6)
    end
  elseif s.look == "rack" then
    local b = s.box
    out[#out + 1] = box(b[1], 0, b[2], b[3], 0.2, b[4], C.trim)
    out[#out + 1] = box(b[1], s.h - 0.2, b[2], b[3], s.h, b[4], C.trim)
    local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
    local n = s.n or 3
    for k = 0, n - 1 do
      local y = 0.5 + (s.h - 1) * (k + 0.5) / n
      local rr = math.min(b[3] - b[1], b[4] - b[2]) * 0.38
      ell(out, cx, y, cz, rr, (s.h - 1) / n * 0.42, rr, k % 2 == 0 and C.wall or C.accent, k % 2 == 0 and nil or 0.3, 8)
      ell(out, cx, y, cz, rr * 1.05, 0.05, rr * 1.05, C.glow, 1, 8, 2)
    end
  elseif s.look == "altar" then
    local b = s.box
    out[#out + 1] = box(b[1], 0, b[2], b[3], s.h, b[4], C.trim)
    out[#out + 1] = box(b[1] + 0.2, s.h, b[2] + 0.2, b[3] - 0.2, s.h + 0.05, b[4] - 0.2, C.glow, { emissive = 1 })
  elseif s.look == "brazier" then
    out[#out + 1] = { kind = "cone", c = { s.c[1], 0, s.c[2] }, r = s.r * 0.5, r1 = s.r, h = s.h, seg = 6, color = C.trim }
    ell(out, s.c[1], s.h + 0.25, s.c[2], s.r * 0.6, 0.45, s.r * 0.6, C.accent, 1, 6)
  end
end

local function alien_prop(out, q, L, C)
  if q.kind == "ribs" then
    ribs(out, q, C)
  elseif q.kind == "pool" then
    out[#out + 1] = { kind = "cylinder", c = { q.at[1], 0.0, q.at[2] }, r = q.r, h = 0.04, seg = 20, color = C.glow, emissive = 0.8 }
    out[#out + 1] = { kind = "ring", c = { q.at[1], 0.0, q.at[2] }, rin = q.r, r = q.r + 0.6, h = 0.25, seg = 20, color = C.trim }
  elseif q.kind == "orbiter" then
    ell(out, q.at[1], q.y, q.at[2], q.r, q.r, q.r, C.accent, 0.9, 8)
    out[#out + 1] = { kind = "ring", c = { q.at[1], q.y - 0.05, q.at[2] }, rin = q.r * 1.5, r = q.r * 1.7, h = 0.1, seg = 16, color = C.glow,
                      emissive = 1 }
  elseif q.kind == "ledge" then
    local b = q.box
    local w = q.w
    local sides = { { b[1], b[2], b[3], b[2] + w }, { b[1], b[4] - w, b[3], b[4] }, { b[1], b[2] + w, b[1] + w, b[4] - w },
                    { b[3] - w, b[2] + w, b[3], b[4] - w } }
    for i, sd in ipairs(sides) do
      if i ~= (q.gap or 0) + 1 then
        out[#out + 1] = box(sd[1], q.y - 0.35, sd[2], sd[3], q.y, sd[4], C.trim)
        out[#out + 1] = box(sd[1], q.y - 0.42, sd[2], sd[3], q.y - 0.35, sd[4], C.glow, { emissive = 0.9 })
      end
    end
  elseif q.kind == "monolith" then
    out[#out + 1] = { kind = "box", min = { -q.w / 2, 0, -q.w * 0.2 }, max = { q.w / 2, q.h, q.w * 0.2 }, color = shade(C.trim, 0.5),
                      yaw = q.yaw, pos = { q.at[1], q.y, q.at[2] } }
    local rng = saucer.rng.new(math.floor(q.at[1] * 7 + q.at[2] * 13) % 9973 + 1)
    for _, f in ipairs({ -1, 1 }) do
      local n = math.max(1, math.min(6, math.floor(q.h / 1.2)))
      for k = 0, n - 1 do
        local g = glyph_bits(rng)
        for row = 1, 4 do
          for col = 1, 3 do
            if g[(row - 1) * 3 + col] then
              local s = q.w / 5
              out[#out + 1] = { kind = "box", min = { (col - 2.5) * s, 0, f * q.w * 0.2 }, max = { (col - 1.6) * s, s * 0.9, f * (q.w * 0.2 + 0.03) },
                                color = C.glow, emissive = 1, yaw = q.yaw,
                                pos = { q.at[1], q.y + q.h - (k + 0.15) * 1.2 - row * s, q.at[2] } }
            end
          end
        end
      end
    end
    ell(out, q.at[1], q.y - 0.6, q.at[2], q.w * 0.6, 0.15, q.w * 0.6, C.glow, 1, 8)
  elseif q.kind == "glyphwall" then
    local b = q.box
    local rng = saucer.rng.new(q.seed or 1)
    for _, f in ipairs({ { 1, b[1], 1, b[2], b[4] }, { 1, b[3], -1, b[2], b[4] }, { 3, b[2], 1, b[1], b[3] }, { 3, b[4], -1, b[1], b[3] } }) do
      local u = f[4] + 2
      while u < f[5] - 2 do
        if rng:int(0, 2) > 0 then glyph(out, f[1], f[2], f[3], u, 2.4 + rng:int(0, 2) * 1.2, 0.3, C.glow, rng) end
        u = u + 1.6
      end
    end
  end
end

-- alien_parts(L, out[, pick]): the alien wing's parts. pick(area) -> the list an area's parts go in (default: out)
function M.alien_parts(L, out, pick)
  local C = M.colors(L)
  local rng = saucer.rng.new(saucer.seed_child(L.seed or 1, "alien-view", 1))
  local function into(a) return (pick and a and pick(a)) or out end
  local function at(x, z) return into(sg.area_at(L, x, z)) end
  for _, s in ipairs(M.wall_segments(L)) do
    if s.area.wing then organic_wall(into(s.area), s, C, rng) end
  end
  for _, s in ipairs(L.solids) do
    local c = s.c or { (s.box[1] + s.box[3]) / 2, (s.box[2] + s.box[4]) / 2 }
    alien_solid(at(c[1], c[2]), s, C)
  end
  for _, q in ipairs(L.props) do
    local c = q.at or (q.box and { (q.box[1] + q.box[3]) / 2, (q.box[2] + q.box[4]) / 2 }) or { 0, 0 }
    alien_prop(at(c[1], c[2]), q, L, C)
  end
  -- the chambers' ceilings: a glowing ring of pores round a dark eye
  for _, a in ipairs(L.areas) do
    if a.kind == "chamber" then
      local c = sg.center(a)
      local r = math.min(a.box[3] - a.box[1], a.box[4] - a.box[2]) * 0.2
      local o = into(a)
      o[#o + 1] = { kind = "ring", c = { c[1], a.h - 0.25, c[2] }, rin = r, r = r + 0.5, h = 0.2, seg = 20, color = C.glow, emissive = 1 }
      o[#o + 1] = { kind = "cylinder", c = { c[1], a.h - 0.3, c[2] }, r = r, h = 0.25, seg = 20, color = shade(C.trim, 0.4) }
    end
  end
  return out
end

-- the wing's parts as one mesh per wing area, with the area's box (drawn only near it: M.WING_DRAW)
M.WING_DRAW = 70
function M.wing_meshes(L)
  local lists, order = {}, {}
  local rest = {}
  M.alien_parts(L, rest, function(a)
    if not a.wing then return nil end
    if not lists[a.id] then lists[a.id] = {} order[#order + 1] = a end
    return lists[a.id]
  end)
  local out = {}
  for _, a in ipairs(order) do
    out[#out + 1] = { mesh = saucer.mesh.build({ parts = lists[a.id] }), box = a.box, n = #lists[a.id] }
  end
  return out, rest
end

function M.detail_parts(L)
  local out = {}
  for _, s in ipairs(M.wall_segments(L)) do if not s.area.wing then wall_detail(out, s) end end
  for _, s in ipairs(L.solids) do solid_detail(out, s) end
  for _, q in ipairs(L.props) do prop_detail(out, q, L) end
  -- ceiling light strips, door frames and the signs over doorways
  for _, a in ipairs(L.areas) do
    local b = a.box
    local col = KIND_COLOR[a.kind] or TRIM
    if a.kind == "corridor" and not a.wing then
      local long = (b[4] - b[2]) >= (b[3] - b[1])
      for _, o in ipairs({ -1, 1 }) do
        if long then
          local x = (b[1] + b[3]) / 2 + o * (b[3] - b[1]) * 0.25
          out[#out + 1] = box(x - 0.15, a.h - 0.08, b[2] + 0.4, x + 0.15, a.h, b[4] - 0.4, { 1, 0.95, 0.85 }, { emissive = 1 })
        else
          local z = (b[2] + b[4]) / 2 + o * (b[4] - b[2]) * 0.25
          out[#out + 1] = box(b[1] + 0.4, a.h - 0.08, z - 0.15, b[3] - 0.4, a.h, z + 0.15, { 1, 0.95, 0.85 }, { emissive = 1 })
        end
      end
      -- ducts and a cable tray along the ceiling, lit floor lines to every side door
      if long then
        for _, o in ipairs({ -1, 1 }) do
          local x = (b[1] + b[3]) / 2 + o * ((b[3] - b[1]) / 2 - 0.9)
          out[#out + 1] = box(x - 0.35, a.h - 1.3, b[2] + 0.2, x + 0.35, a.h - 0.55, b[4] - 0.2, { 0.5, 0.52, 0.58 })
          out[#out + 1] = box(x - 0.37, a.h - 1.0, b[2] + 0.2, x + 0.37, a.h - 0.94, b[4] - 0.2, { 1, 0.75, 0.3 }, { emissive = 0.8 })
          out[#out + 1] = box(x - 0.6, a.h - 0.5, b[2] + 0.2, x - 0.2, a.h - 0.4, b[4] - 0.2, DARK)
        end
        for _, d in ipairs(L.doors) do
          if d.axis == 1 and d.a == a.id then
            local zc = (d.lo + d.hi) / 2
            local col2 = KIND_COLOR[L.areas[d.b].kind] or TRIM
            local x0, x1 = math.min(0, d.at), math.max(0, d.at)
            out[#out + 1] = box(x0, 0.0, zc - 0.07, x1, 0.035, zc + 0.07, col2, { emissive = 1 })
          end
        end
      end
      -- ribs across the concourse ceiling
      if long then
        for z = b[2] + 2, b[4] - 1, 4 do out[#out + 1] = box(b[1], a.h - 0.5, z - 0.15, b[3], a.h, z + 0.15, DARK) end
      end
    elseif a.kind == "hangar" then
      for z = b[2] + 4, b[4] - 3, 8 do
        for _, x in ipairs({ b[1] + 0.4, b[3] - 0.4 }) do
          out[#out + 1] = box(x - 0.2, a.h - 3, z - 0.6, x + 0.2, a.h - 2.4, z + 0.6, { 1, 0.95, 0.8 }, { emissive = 1 })
        end
      end
      -- ceiling trusses
      for x = b[1] + 4, b[3] - 3, 6 do out[#out + 1] = box(x - 0.25, a.h - 1.2, b[2], x + 0.25, a.h, b[4], DARK) end
      -- hazard stripes along the mouth's floor edge
      local m = a.mouth
      if m then
        local at = m.axis == 1 and (m.sign > 0 and b[3] or b[1]) or (m.sign > 0 and b[4] or b[2])
        local u0, u1 = m.axis == 1 and b[2] or b[1], m.axis == 1 and b[4] or b[3]
        local n = math.floor((u1 - u0) / 1.2)
        for k = 0, n - 1 do
          local c = k % 2 == 0 and HAZARD or DARK
          local v0, v1 = u0 + k * (u1 - u0) / n, u0 + (k + 1) * (u1 - u0) / n
          if m.axis == 1 then out[#out + 1] = box(at - m.sign * 1.2, 0.0, v0, at, 0.05, v1, c, { emissive = 0.15 })
          else out[#out + 1] = box(v0, 0.0, at - m.sign * 1.2, v1, 0.05, at, c, { emissive = 0.15 }) end
        end
        -- the mouth's frame
        if m.axis == 1 then
          out[#out + 1] = box(at - 0.4, a.h - 1.0, b[2], at + 0.4, a.h, b[4], DARK)
          out[#out + 1] = box(at - 0.5, a.h - 1.1, b[2], at + 0.5, a.h - 0.95, b[4], { 0.35, 0.9, 1 }, { emissive = 1 })
        else
          out[#out + 1] = box(b[1], a.h - 1.0, at - 0.4, b[3], a.h, at + 0.4, DARK)
          out[#out + 1] = box(b[1], a.h - 1.1, at - 0.5, b[3], a.h - 0.95, at + 0.5, { 0.35, 0.9, 1 }, { emissive = 1 })
        end
      end
    elseif a.kind == "market" then
      for x = b[1] + 4, b[3] - 3, 6 do
        for z = b[2] + 4, b[4] - 3, 6 do
          out[#out + 1] = cyl(x, a.h - 2.2, z, 0.02, 2.2, DARK, 4)
          out[#out + 1] = { kind = "sphere", c = { x, a.h - 2.3, z }, r = 0.28, h = 0.28, seg = 8, rings = 3,
                            color = { 1, 0.8, 0.45 }, emissive = 1 }
        end
      end
    elseif a.kind == "bar" then
      out[#out + 1] = box(b[1] + 0.3, a.h - 0.06, b[2] + 0.3, b[3] - 0.3, a.h, b[2] + 0.4, { 1, 0.3, 0.85 }, { emissive = 1 })
      out[#out + 1] = box(b[1] + 0.3, a.h - 0.06, b[4] - 0.4, b[3] - 0.3, a.h, b[4] - 0.3, { 0.3, 0.9, 1 }, { emissive = 1 })
    end
  end
  for _, d in ipairs(L.doors) do
    local B = L.areas[d.b]
    local col = KIND_COLOR[B.kind] or TRIM
    for _, u in ipairs({ d.lo, d.hi }) do
      if d.axis == 1 then out[#out + 1] = box(d.at - 0.3, 0, u - 0.18, d.at + 0.3, d.h, u + 0.18, DARK)
      else out[#out + 1] = box(u - 0.18, 0, d.at - 0.3, u + 0.18, d.h, d.at + 0.3, DARK) end
    end
    if d.axis == 1 then
      out[#out + 1] = box(d.at - 0.32, d.h - 0.12, d.lo, d.at + 0.32, d.h, d.hi, col, { emissive = 1 })
      out[#out + 1] = box(d.at - 0.34, d.h + 0.5, (d.lo + d.hi) / 2 - 1.4, d.at + 0.34, d.h + 1.2, (d.lo + d.hi) / 2 + 1.4,
        col, { emissive = 1 })
    else
      out[#out + 1] = box(d.lo, d.h - 0.12, d.at - 0.32, d.hi, d.h, d.at + 0.32, col, { emissive = 1 })
      out[#out + 1] = box((d.lo + d.hi) / 2 - 1.4, d.h + 0.5, d.at - 0.34, (d.lo + d.hi) / 2 + 1.4, d.h + 1.2, d.at + 0.34,
        col, { emissive = 1 })
    end
  end
  return out
end

-- the station's two static meshes (cached by layout hash; never in the state)
function M.meshes(L)
  local hit = cache[L.hash]
  if hit then return hit end
  local shell = M.shell_parts(L)
  local det = M.detail_parts(L)
  -- add-presentation-packaging: floors and walls get their own textures
  local floors, walls, ceilings = {}, {}, {}
  local kc = sg.kit().color
  for _, q in ipairs(shell) do
    if q.mat == "floor" then
      floors[#floors + 1] = { kind = q.kind, min = q.min, max = q.max, uv = 0.3, color = vec.scale(q.color, ART_FLOOR) }
    elseif q.mat == "ceiling" then
      ceilings[#ceilings + 1] = { kind = q.kind, min = q.min, max = q.max, uv = 0.25, color = { 0.45, 0.45, 0.5 } }
    else
      -- the hall art has its own colours: keep the area tint, drop the kit's rust
      local c = { q.color[1] / kc[1], q.color[2] / kc[2], q.color[3] / kc[3] }
      walls[#walls + 1] = { kind = q.kind, min = q.min, max = q.max, uv = 0.1, color = vec.scale(c, 0.9) }
    end
  end
  local wing, rest = M.wing_meshes(L)
  for _, q in ipairs(rest) do det[#det + 1] = q end
  hit = { shell = saucer.mesh.build({ parts = shell }), detail = saucer.mesh.build({ parts = det }), wing = wing,
          floor = saucer.mesh.build({ parts = floors }), walls = saucer.mesh.build({ parts = walls }),
          ceiling = saucer.mesh.build({ parts = ceilings }),
          nshell = #shell, ndetail = #det }
  cache[L.hash] = hit
  return hit
end

-- in front of the camera, low and to the right: where your hand holds the coin
function M.hand_pose(eye, yaw, pitch)
  local f = vec.aim(yaw, pitch)
  local r = vec.right(yaw)
  local p = vec.add(eye, vec.add(vec.scale(f, 0.44), vec.add(vec.scale(r, 0.14), { 0, -0.21, 0 })))
  return p
end

local function smooth(t) return t * t * (3 - 2 * t) end

-- where the folding (or unfolding) saucer is this frame -> { size, pos, scale, yaw } or nil
function M.morph_pose(state, p, L, hand)
  local st = p.station
  local ship = p.ship
  if not ship.morph or not st then return nil end
  local t = smooth(visit.morph_t(p))
  local coin = configs.get(visit.pocket_size()).diameter
  if st.coin == "fold" then
    local from = ship.morph.from
    local h = sg.hangars(L)[1]
    local c = configs.get(from)
    local start = { h.pad[1], c.interior and L.pad_y or c.height / 2 + 0.4, h.pad[2] }
    local k = (coin / c.diameter) ^ t
    local f = (k - coin / c.diameter) / (1 - coin / c.diameter)
    return { size = from, pos = vec.add(hand, vec.scale(vec.sub(start, hand), f)), scale = k,
             yaw = st.body.yaw + sm.pi * (1 - f) * 0.5 }
  end
  if st.coin == "grow" and st.grow then
    local c = configs.get(ship.size)
    local pad = { st.grow.pad[1], c.interior and L.pad_y or c.height / 2 + 0.4, st.grow.pad[2] }
    local k0 = coin / c.diameter
    local k = k0 ^ (1 - t)
    local f = (k - k0) / (1 - k0)
    return { size = ship.size, pos = vec.add(hand, vec.scale(vec.sub(pad, hand), f)), scale = k,
             yaw = st.body.yaw + sm.pi * f * 0.5 }
  end
  return nil
end

-- add-presentation-packaging: shop signs over the stalls (Grok Imagine
-- decals) and a crowd of sprite folk browsing the market and standing about
-- the bar and concourse. Render-only, placed from the layout hash.
M.SIGN_OF = { scrap = "sign_scrap", chandler = "sign_scrap", curio = "sign_gems", archive = "sign_gems",
              outfit = "sign_gems", grocer = "sign_food" }
M.FOLK_SPRITES = { "folk_1", "folk_2", "folk_3", "folk_4" }
M.CROWD = { market = 6, bar = 3, corridor = 2, hangar = 1, chamber = 2 }

M.decal = assets.decal

function M.signs(v, A, L)
  local n = 0
  for _, s in ipairs(L.stalls) do
    local tex = A.tex[M.SIGN_OF[s.vendor] or ""]
    if tex then
      local dir = s.yaw == 0 and 1 or -1
      M.decal(v, A, tex, A.pal.sprites, { s.keeper[1], 3.35, s.keeper[2] - dir * 0.6 }, s.yaw, 1.6, 1.6)
      n = n + 1
    end
  end
  if L.bar and A.tex.sign_bar then
    local b = L.bar
    local back = { -sm.sin(b.yaw), sm.cos(b.yaw) }
    M.decal(v, A, A.tex.sign_bar, A.pal.sprites, { b.keeper[1] - back[1] * 1.2, 3.1, b.keeper[2] - back[2] * 1.2 },
            b.yaw, 1.5, 1.5)
    n = n + 1
  end
  return n
end

-- deterministic crowd spots for a layout -> list of { pos = {x, z}, sprite, phase }
local crowds = {} -- by layout hash (render-side only, never in the state)
function M.crowd(L)
  if crowds[L.hash] then return crowds[L.hash] end
  local out = {}
  local seed = 0
  for i = 1, #(L.hash or "") do seed = (seed * 31 + L.hash:byte(i)) % 2147483647 end
  local rng = saucer.rng.new(seed + 1)
  for _, a in ipairs(L.areas) do
    local b = a.box
    local want, tries = M.CROWD[a.kind] or 0, 0
    while want > 0 and tries < 40 do
      tries = tries + 1
      local x = b[1] + 1.5 + rng:float() * math.max(0, b[3] - b[1] - 3)
      local z = b[2] + 1.5 + rng:float() * math.max(0, b[4] - b[2] - 3)
      if sg.free(L, x, z, 0.6) then
        want = want - 1
        out[#out + 1] = { pos = { x, z }, sprite = M.FOLK_SPRITES[rng:int(1, #M.FOLK_SPRITES)], phase = rng:float() * 6.28,
                          area = a.kind }
      end
    end
  end
  crowds[L.hash] = out
  return out
end

function M.draw_crowd(v, A, state, L)
  local n = 0
  for _, c in ipairs(M.crowd(L)) do
    local tex = A.tex[c.sprite]
    if tex then
      local sway = 0.15 * sm.sin(state.tick * 0.01 + c.phase)
      v:billboard(tex, { c.pos[1] + sway, 0.92 + 0.02 * sm.sin(state.tick * 0.05 + c.phase), c.pos[2] }, 0.92,
                  { palette = A.pal.sprites, height = 1.84, tint = { 0.85, 0.85, 0.85, 1 } })
      n = n + 1
    end
  end
  return n
end

function M.draw_folk(v, A, state, p, L)
  local n = M.signs(v, A, L) + M.draw_crowd(v, A, state, L)
  local tick = state.tick
  local function npc(sp, x, z, yaw, y)
    local m = A.npc[sp] or A.npc[1]
    v:mesh(m, { pos = { x, y or 0, z }, yaw = yaw })
    n = n + 1
  end
  for i, s in ipairs(L.stalls) do
    local sway = 0.25 * sm.sin(tick * 0.02 + i)
    npc(s.species, s.keeper[1] + sway * 0.3, s.keeper[2], s.yaw + sway * 0.4)
  end
  if L.bar then
    local b = L.bar
    local slide = 1.2 * sm.sin(tick * 0.008)
    npc(b.species, b.keeper[1], b.keeper[2] + slide, b.yaw)
    for i, q in ipairs(b.patrons) do
      npc(q.species, q.pos[1], q.pos[2], q.yaw + 0.2 * sm.sin(tick * 0.01 + i), q.seated and -0.28 or 0)
    end
  end
  for _, w in ipairs(L.walkers) do
    local x, z, yaw = sg.walker_at(w, tick)
    npc(w.species, x, z, yaw, 0.03 * math.abs(sm.sin(tick * 0.25)))
  end
  local th = p.station.thief
  if th then
    local bob = th.mode == "flee" and 0.06 * math.abs(sm.sin(tick * 0.5)) or 0
    npc(L.thief.species, th.pos[1], th.pos[2], th.yaw, bob)
    if th.mode == "flee" then
      v:billboard(A.tex.glow, { th.pos[1], 2.3, th.pos[2] }, 0.5, { palette = A.pal.base, tint = { 1, 0.25, 0.2, 0.9 } })
      -- the coin glints in his fist
      v:mesh(A.saucer[visit.pocket_size()].hull, { pos = { th.pos[1] + 0.3, 1.0, th.pos[2] }, scale = 1.5, yaw = tick * 0.1,
                                                   tex = A.tex.hull, palette = A.pal.base })
      n = n + 2
    end
  end
  -- other players walking the same station
  for _, o in ipairs(state.players) do
    if o ~= p and o.mode == "foot" and o.station and o.station.seed == p.station.seed then
      v:mesh(A.person, { pos = o.station.body.pos, yaw = o.station.body.yaw })
      n = n + 1
    end
  end
  return n
end

function M.render(v, state, p)
  local assets = require("view.assets")
  local A = assets.init()
  local L = visit.layout(state, p)
  local ms = M.meshes(L)
  local eye, yaw, pitch = visit.viewpoint(p)
  M.cam = require("view.xr").adjust(v, { pos = eye, yaw = yaw, pitch = pitch, fov = 75, near = 0.02, far = 2000 })
  v:camera(M.cam)
  v:fog({ color = { 0.05, 0.05, 0.09 }, density = 0.005, clear = { 0.0, 0.0, 0.03 }, light = { 0.3, 0.9, 0.35 },
          ambient = 0.85 })
  -- add-realistic-lighting: indoors no sun reaches, only the station's own warm and white lamps
  local lightsv = require("view.lights")
  if v.lighting then v:lighting({ ambient = lightsv.AMBIENT_INSIDE, exposure = lightsv.EXPOSURE }) end
  lightsv.station_lamps(v, L, eye)
  v:mesh(A.stars, { pos = eye, sky = true })
  -- space beyond the hangar mouths: the nebulae and a distant sun
  for _, h in pairs(sg.hangars(L)) do
    local m = h.mouth
    local dir = m.axis == 1 and { m.sign, 0, 0 } or { 0, 0, m.sign }
    local c = sg.center(h)
    v:billboard(A.tex.nebula, { c[1] + dir[1] * 900, 120, c[2] + dir[3] * 900 }, 700,
                { palette = A.pal.base, tint = { 0.8, 0.7, 1, 0.9 } })
  end
  if A.tex.station_hall and ms.walls then
    v:mesh(ms.walls, { tex = A.tex.station_hall, palette = A.pal.kits })
    v:mesh(ms.floor, { tex = A.tex.floor_station, palette = A.pal.kits })
    v:mesh(ms.ceiling, { tex = A.tex.mat_metal, palette = A.pal.interior })
  else
    v:mesh(ms.shell, { tex = assets.kit_texture(A, sg.kit()), palette = A.pal.base })
  end
  v:mesh(ms.detail, { palette = A.pal.base })
  local n = 4
  -- add-alien-stations: each wing area's growths and props only when the eye is near it
  for _, w in ipairs(ms.wing or {}) do
    local b, d = w.box, M.WING_DRAW
    if eye[1] > b[1] - d and eye[1] < b[3] + d and eye[3] > b[2] - d and eye[3] < b[4] + d then
      v:mesh(w.mesh, { palette = A.pal.base })
      n = n + 1
    end
  end
  -- the force fields across the hangar mouths
  for _, h in pairs(sg.hangars(L)) do
    local m, b = h.mouth, h.box
    local at = m.axis == 1 and (m.sign > 0 and b[3] or b[1]) or (m.sign > 0 and b[4] or b[2])
    local pos, sc
    if m.axis == 1 then pos, sc = { at, h.h / 2, (b[2] + b[4]) / 2 }, { 0.05, h.h, b[4] - b[2] }
    else pos, sc = { (b[1] + b[3]) / 2, h.h / 2, at }, { b[3] - b[1], h.h, 0.05 } end
    v:mesh(A.unit, { pos = pos, scale = sc, ghost = true, tint = { 0.35, 0.8, 1, 0.12 + 0.04 * sm.sin(state.tick * 0.05) } })
    n = n + 1
  end
  -- the market's spinning holo sign
  for _, q in ipairs(L.props) do
    if q.kind == "holosign" then
      v:mesh(A.unit, { pos = { q.at[1], q.y, q.at[2] }, yaw = state.tick * 0.01, scale = { 3.2, 1.0, 0.05 }, ghost = true,
                       tint = { 1, 0.75, 0.3, 0.45 } })
      v:billboard(A.tex.glow, { q.at[1], q.y, q.at[2] }, 2.2, { palette = A.pal.base, tint = { 1, 0.8, 0.4, 0.5 } })
      n = n + 2
    end
  end
  n = n + M.draw_folk(v, A, state, p, L)
  -- your hand, the coin in it, and the saucer folding into it / growing out of it
  local hand = M.hand_pose(eye, yaw, pitch)
  local st = p.station
  local mp = M.morph_pose(state, p, L, hand)
  if mp then
    local m = A.saucer[mp.size]
    local c = configs.get(mp.size)
    v:mesh(m.hull, { pos = mp.pos, yaw = mp.yaw, scale = mp.scale, tex = A.tex.hull, palette = A.pal.base })
    if c.interior then
      v:mesh(A.glass, { pos = mp.pos, yaw = mp.yaw, scale = mp.scale, ghost = true, tint = { 0.55, 0.8, 1, 0.3 } })
    else
      v:mesh(m.dome, { pos = mp.pos, yaw = mp.yaw, scale = mp.scale, ghost = true, tint = { 0.55, 0.8, 1, 0.3 } })
    end
    local dia = c.diameter * mp.scale
    if dia < 1.5 then
      v:billboard(A.tex.glow, mp.pos, math.max(0.05, dia * 0.9), { palette = A.pal.base, tint = { 0.6, 0.9, 1, 0.35 } })
    end
    n = n + 3
  end
  -- add-dock-land-eva: the Villa docked in the arrival hangar stands on its pad
  if st.coin == "docked" then
    local h = sg.hangars(L)[1]
    if h then
      local at = { h.pad[1], L.pad_y + 0.2, h.pad[2] }
      v:mesh(A.saucer[1].hull, { pos = at, yaw = sm.pi, tex = A.tex.hull, palette = A.pal.base })
      v:mesh(A.glass, { pos = at, yaw = sm.pi, ghost = true, tint = { 0.55, 0.8, 1, 0.3 } })
      n = n + 2
    end
  end
  local show_hand = st.coin == "hand" or st.coin == "fold" or (st.coin == "grow" and visit.morph_t(p) < 0.25)
  if show_hand and not v.xr then
    v:mesh(A.hand, { pos = hand, yaw = yaw, pitch = 0 })
    n = n + 1
    if st.coin == "hand" then
      local ps = visit.pocket_size()
      v:mesh(A.saucer[ps].hull, { pos = { hand[1], hand[2] + 0.012, hand[3] }, yaw = state.tick * 0.02, tex = A.tex.hull,
                                  palette = A.pal.base })
      v:billboard(A.tex.glow, { hand[1], hand[2] + 0.03, hand[3] }, 0.05, { palette = A.pal.base, tint = { 0.6, 1, 1, 0.5 } })
      n = n + 2
    end
  end
  return n
end

return M
