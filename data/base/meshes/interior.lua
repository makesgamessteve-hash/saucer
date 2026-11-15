-- SPDX-License-Identifier: MIT
-- Hero mesh: the Villa's interior, generated from saucer/interior.lua.
-- params.part = "rooms" (floors, stairs, walls, furniture, lights) or "glass"
-- (the dome, drawn see-through). Everything is in hull-local meters.
local kit = require("lib.meshkit")
local data = require("lib.data")
local sm = saucer.math

local P = kit.part
local props = data.load("meshes/props.lua")

local function box(x0, y0, z0, x1, y1, z1, color, extra)
  local p = P("box", { min = { x0, y0, z0 }, max = { x1, y1, z1 }, color = color })
  for k, v in pairs(extra or {}) do p[k] = v end
  return p
end

local function darker(c, f) return { c[1] * f, c[2] * f, c[3] * f } end

-- one builder per furniture kind; b = { x0, z0, x1, z1 }, y = floor height
local BUILD = {}
function BUILD.box(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y, b[2], b[3], y + f.h, b[4], f.color)
end
BUILD.wall, BUILD.wardrobe = BUILD.box, BUILD.box
function BUILD.rail(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y + f.h - 0.08, b[2], b[3], y + f.h, b[4], f.color)
  out[#out + 1] = box(b[1], y + 0.25, b[2], b[3], y + f.h - 0.08, b[4], { 0.55, 0.8, 0.95 }, { emissive = 0.1 })
  -- add-detail-pass: balusters every half meter and a kick plate
  local along = (b[3] - b[1]) >= (b[4] - b[2]) and 1 or 3
  local a0, a1 = along == 1 and b[1] or b[2], along == 1 and b[3] or b[4]
  local n = math.max(1, math.floor((a1 - a0) / 0.5 + 0.5))
  for k = 0, n do
    local a = a0 + (a1 - a0) * k / n
    if along == 1 then out[#out + 1] = box(a - 0.025, y, b[2] - 0.01, a + 0.025, y + f.h, b[4] + 0.01, f.color)
    else out[#out + 1] = box(b[1] - 0.01, y, a - 0.025, b[3] + 0.01, y + f.h, a + 0.025, f.color) end
  end
  out[#out + 1] = box(b[1], y, b[2], b[3], y + 0.12, b[4], { 0.35, 0.37, 0.42 })
end
function BUILD.console(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y, b[2], b[3], y + f.h * 0.75, b[4], f.color)
  -- sloped desk top, low edge toward the pilot (-z): local +x is turned to -z
  local hd, hw = (b[4] - b[2]) / 2, (b[3] - b[1]) / 2
  out[#out + 1] = P("wedge", { min = { -hd, 0, -hw }, max = { hd, f.h * 0.25, hw }, low = 0.2, yaw = sm.pi / 2,
                               pos = { (b[1] + b[3]) / 2, y + f.h * 0.75, (b[2] + b[4]) / 2 },
                               color = darker(f.color, 0.8) })
  -- glowing screens and buttons
  local w = b[3] - b[1]
  for i = 0, 2 do
    local x0 = b[1] + w * (0.08 + i * 0.31)
    out[#out + 1] = box(x0, y + f.h * 0.76, b[2] - 0.02, x0 + w * 0.24, y + f.h * 0.96, b[2] + 0.02,
                        i == 1 and { 0.3, 1.0, 0.7 } or { 0.3, 0.7, 1.0 }, { emissive = 1 })
  end
end
function BUILD.chair(out, f, y)
  local b = f.box
  local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
  out[#out + 1] = P("cylinder", { c = { cx, y, cz }, r = 0.12, h = 0.45, seg = 6, color = { 0.3, 0.3, 0.35 } })
  out[#out + 1] = box(b[1], y + 0.45, b[2], b[3], y + 0.6, b[4], f.color)
  out[#out + 1] = box(b[1], y + 0.6, b[2] - 0.05, b[3], y + f.h, b[2] + 0.12, f.color)
end
function BUILD.counter(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1] + 0.05, y, b[2] + 0.05, b[3] - 0.05, y + f.h - 0.06, b[4] - 0.05, darker(f.color, 0.75))
  out[#out + 1] = box(b[1], y + f.h - 0.06, b[2], b[3], y + f.h, b[4], f.color)
end
function BUILD.fridge(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y, b[2], b[3], y + f.h, b[4], f.color)
  out[#out + 1] = box(b[1] + 0.1, y + 0.9, b[2] - 0.04, b[1] + 0.16, y + 1.6, b[2], { 0.3, 0.3, 0.35 })
end
function BUILD.stool(out, f, y)
  local b = f.box
  local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
  out[#out + 1] = P("cylinder", { c = { cx, y, cz }, r = 0.05, h = f.h - 0.06, seg = 6, color = { 0.6, 0.6, 0.65 } })
  out[#out + 1] = P("cylinder", { c = { cx, y + f.h - 0.06, cz }, r = 0.24, h = 0.06, seg = 10, color = f.color })
end
function BUILD.rug(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y, b[2], b[3], y + f.h, b[4], f.color)
  out[#out + 1] = box(b[1] + 0.3, y, b[2] + 0.3, b[3] - 0.3, y + f.h + 0.005, b[4] - 0.3, darker(f.color, 0.7))
end
local function seat(out, f, y, back_side)
  local b = f.box
  out[#out + 1] = box(b[1], y, b[2], b[3], y + 0.45, b[4], f.color)
  local bx0, bx1 = b[1], b[1] + 0.25
  if back_side > 0 then bx0, bx1 = b[3] - 0.25, b[3] end
  out[#out + 1] = box(bx0, y + 0.45, b[2], bx1, y + f.h, b[4], darker(f.color, 0.85))
  out[#out + 1] = box(b[1], y + 0.45, b[2], b[3], y + 0.65, b[2] + 0.2, darker(f.color, 0.9))
  out[#out + 1] = box(b[1], y + 0.45, b[4] - 0.2, b[3], y + 0.65, b[4], darker(f.color, 0.9))
end
function BUILD.sofa(out, f, y) seat(out, f, y, -1) end
function BUILD.armchair(out, f, y) seat(out, f, y, -1) end
function BUILD.table(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y + f.h - 0.06, b[2], b[3], y + f.h, b[4], f.color)
  out[#out + 1] = box((b[1] + b[3]) / 2 - 0.1, y, (b[2] + b[4]) / 2 - 0.1, (b[1] + b[3]) / 2 + 0.1, y + f.h - 0.06,
                      (b[2] + b[4]) / 2 + 0.1, darker(f.color, 0.7))
end
function BUILD.plant(out, f, y)
  local b = f.box
  local cx, cz, r = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2, (b[3] - b[1]) / 2
  out[#out + 1] = P("cone", { c = { cx, y, cz }, r = r * 0.7, r1 = r, h = 0.5, seg = 8, color = { 0.7, 0.4, 0.25 } })
  out[#out + 1] = P("cone", { c = { cx, y + 0.5, cz }, r = r * 1.1, r1 = 0, h = f.h - 0.5, seg = 7, color = f.color })
  out[#out + 1] = P("sphere", { c = { cx, y + 0.9, cz }, r = r * 0.9, h = r * 0.7, seg = 7, rings = 2,
                                color = darker(f.color, 1.2) })
end
function BUILD.bed(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y, b[2], b[3], y + 0.3, b[4], { 0.45, 0.32, 0.22 })
  out[#out + 1] = box(b[1] + 0.05, y + 0.3, b[2] + 0.05, b[3] - 0.05, y + f.h, b[4] - 0.05, f.color)
  out[#out + 1] = box(b[1] + 0.05, y + f.h, b[2] + 0.05, b[3] - 0.05, y + f.h + 0.05, b[2] + (b[4] - b[2]) * 0.6,
                      { 0.30, 0.45, 0.75 })
  out[#out + 1] = box(b[1] + 0.3, y + f.h, b[4] - 0.7, b[3] - 0.3, y + f.h + 0.15, b[4] - 0.15, { 1, 1, 1 })
  out[#out + 1] = box(b[1], y, b[4] - 0.1, b[3], y + 1.1, b[4], { 0.45, 0.32, 0.22 })
end
function BUILD.shower(out, f, y)
  local b = f.box
  local cx, cz, r = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2, (b[3] - b[1]) / 2
  out[#out + 1] = P("cylinder", { c = { cx, y, cz }, r = r, h = 0.1, seg = 12, color = { 0.9, 0.9, 0.92 } })
  out[#out + 1] = P("cylinder", { c = { cx, y + 0.1, cz }, r = r, h = f.h - 0.1, seg = 12, color = f.color, open = true,
                                  emissive = 0.15 })
  out[#out + 1] = P("cylinder", { c = { cx, y + f.h - 0.1, cz }, r = 0.15, h = 0.05, seg = 8, color = { 0.8, 0.8, 0.85 } })
end
function BUILD.tub(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y, b[2], b[3], y + f.h, b[4], f.color)
  out[#out + 1] = box(b[1] + 0.12, y + 0.2, b[2] + 0.12, b[3] - 0.12, y + f.h + 0.005, b[4] - 0.12,
                      { 0.4, 0.7, 0.9 }, { emissive = 0.2 })
end
function BUILD.engine(out, f, y)
  local c = f.circle
  out[#out + 1] = P("cylinder", { c = { c[1], y, c[2] }, r = c[3], h = 0.4, seg = 16, color = { 0.35, 0.36, 0.42 } })
  out[#out + 1] = P("cylinder", { c = { c[1], y + 0.4, c[2] }, r = c[3] * 0.7, h = f.h - 0.8, seg = 16, color = f.color,
                                  emissive = 1 })
  out[#out + 1] = P("cylinder", { c = { c[1], y + f.h - 0.4, c[2] }, r = c[3], h = 0.4, seg = 16,
                                  color = { 0.35, 0.36, 0.42 } })
  for i = 1, 3 do
    out[#out + 1] = P("ring", { c = { c[1], y + 0.4 + i * 0.6, c[2] }, rin = c[3] * 0.72, r = c[3] * 0.95, h = 0.12,
                                seg = 16, color = { 0.8, 0.6, 0.2 } })
  end
end

-- helm (milestone 2): a low desk under the pilot's eye line with a flat radar
-- well in the middle, and two angled wing screens; live readouts are drawn on
-- top of these by the renderer (view/render.lua console())
function BUILD.helm_desk(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y, b[2], b[3], y + f.h - 0.05, b[4], f.color)
  out[#out + 1] = box(b[1] - 0.05, y + f.h - 0.05, b[2] - 0.1, b[3] + 0.05, y + f.h, b[4] + 0.02, darker(f.color, 0.75))
  local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
  out[#out + 1] = P("cylinder", { c = { cx, y + f.h, cz }, r = 0.24, h = 0.012, seg = 16, color = { 0.05, 0.12, 0.1 },
                                  emissive = 0.6 })
  out[#out + 1] = P("ring", { c = { cx, y + f.h, cz }, rin = 0.24, r = 0.27, h = 0.02, seg = 16, color = { 0.3, 1.0, 0.7 },
                              emissive = 1 })
end
function BUILD.helm_wing(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y, b[2], b[3], y + 0.12, b[4], darker(f.color, 0.8))
  out[#out + 1] = box((b[1] + b[3]) / 2 - 0.06, y + 0.12, (b[2] + b[4]) / 2 - 0.06, (b[1] + b[3]) / 2 + 0.06, y + f.h * 0.55,
                      (b[2] + b[4]) / 2 + 0.06, { 0.5, 0.5, 0.55 })
  -- the screen panel, facing the pilot (inward and back)
  local inner = f.side < 0 and b[3] or b[1]
  local outer = f.side < 0 and b[1] or b[3]
  local x0, x1 = math.min(inner, outer), math.max(inner, outer)
  out[#out + 1] = box(x0, y + f.h * 0.55, b[2], x1, y + f.h, b[4], f.color)
  local face = f.side < 0 and x1 + 0.005 or x0 - 0.015
  out[#out + 1] = box(face, y + f.h * 0.58, b[2] + 0.05, face + 0.01, y + f.h * 0.97, b[4] - 0.05, { 0.04, 0.08, 0.12 },
                      { emissive = 0.5 })
end
function BUILD.lab_bench(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1] + 0.05, y, b[2] + 0.05, b[3] - 0.05, y + f.h - 0.08, b[4] - 0.05, darker(f.color, 0.6))
  out[#out + 1] = box(b[1], y + f.h - 0.08, b[2], b[3], y + f.h, b[4], f.color)
  local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
  -- scanner ring and arm over the sample plate
  out[#out + 1] = P("cylinder", { c = { cx, y + f.h, cz }, r = 0.3, h = 0.03, seg = 12, color = { 0.3, 0.9, 1.0 },
                                  emissive = 1 })
  out[#out + 1] = box(cx - 0.05, y + f.h, b[2] + 0.05, cx + 0.05, y + f.h + 0.9, b[2] + 0.15, { 0.6, 0.62, 0.7 })
  out[#out + 1] = P("ring", { c = { cx, y + f.h + 0.55, cz }, rin = 0.3, r = 0.38, h = 0.06, seg = 12,
                              color = { 0.4, 1.0, 0.8 }, emissive = 1 })
  -- a backboard with sample screens
  out[#out + 1] = box(b[1], y + f.h, b[2] - 0.02, b[3], y + f.h + 0.7, b[2] + 0.04, darker(f.color, 0.5))
  for i = 0, 2 do
    local x0 = b[1] + 0.15 + i * (b[3] - b[1] - 0.3) / 3
    out[#out + 1] = box(x0, y + f.h + 0.2, b[2] + 0.04, x0 + (b[3] - b[1] - 0.3) / 3 - 0.08, y + f.h + 0.6, b[2] + 0.05,
                        i == 1 and { 0.9, 0.7, 0.3 } or { 0.3, 0.7, 1.0 }, { emissive = 1 })
  end
end
function BUILD.terminal(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y, b[2], b[3], y + 0.9, b[4], f.color)
  out[#out + 1] = box(b[1] + 0.05, y + 0.9, b[2], b[3] - 0.05, y + f.h, b[2] + 0.2, darker(f.color, 0.8))
  out[#out + 1] = box(b[1] + 0.12, y + 0.95, b[2] + 0.2, b[3] - 0.12, y + f.h - 0.06, b[2] + 0.21, { 1.0, 0.75, 0.3 },
                      { emissive = 1 })
  -- the cargo hatch beside it
  out[#out + 1] = box(b[1], y + 0.005, b[4] + 0.1, b[3], y + 0.02, b[4] + 1.0, { 0.85, 0.65, 0.2 })
end

local function floor_strips(out, L)
  local d1 = L.decks[1]
  local st = L.stairs
  local R = L.dome.radius - 0.1
  local z = st.z0 - 0.8 * 6
  while z < R do
    local z1 = z + 0.8
    local far = math.max(math.abs(z), math.abs(z1))
    if far < R then
      local w = sm.sqrt(R * R - far * far)
      local col = (math.floor((z + 20) / 0.8) % 2 == 0) and { 0.74, 0.72, 0.68 } or { 0.70, 0.68, 0.64 }
      if z >= st.z0 - 1e-6 and z1 <= st.z1 + 1e-6 then
        out[#out + 1] = box(-w, d1.floor - 0.3, z, st.low, d1.floor, z1, col)
        out[#out + 1] = box(st.high, d1.floor - 0.3, z, w, d1.floor, z1, col)
      else
        out[#out + 1] = box(-w, d1.floor - 0.3, z, w, d1.floor, z1, col)
      end
    end
    z = z1
  end
  -- rim where the dome meets the deck
  out[#out + 1] = P("ring", { c = { 0, d1.floor - 0.3, 0 }, rin = R - 1.6, r = L.dome.radius + 0.2, h = 0.36, seg = 32,
                              color = { 0.62, 0.64, 0.70 } })
end

local function stairs(out, L)
  local st, lo, hi = L.stairs, L.decks[2].floor, L.decks[1].floor
  local n = st.steps
  local run = (st.high - st.low) / n
  for i = 0, n - 1 do
    local top = lo + (hi - lo) * (i + 1) / n
    out[#out + 1] = box(st.low + i * run, top - 0.12, st.z0, st.low + (i + 1) * run, top, st.z1,
                        i % 2 == 0 and { 0.5, 0.42, 0.34 } or { 0.56, 0.47, 0.38 })
  end
end

local function lights(out, L, only)
  local d1, d2 = L.decks[1], L.decks[2]
  -- lower deck ceiling panels
  for _, p in ipairs(only == 1 and {} or { { 4, 4 }, { -4, 4 }, { 0, -1.8 }, { 5, -3 }, { -5, -3 } }) do
    out[#out + 1] = box(p[1] - 0.6, d2.ceiling - 0.04, p[2] - 0.6, p[1] + 0.6, d2.ceiling, p[2] + 0.6,
                        { 1.0, 0.9, 0.7 }, { emissive = 1 })
  end
  -- floor lights around the dome rim
  for i = 0, (only == 2 and -1 or 15) do
    local a = sm.tau * i / 16
    local r = L.dome.radius - 0.9
    local x, z = sm.sin(a) * r, sm.cos(a) * r
    out[#out + 1] = box(x - 0.12, d1.floor, z - 0.12, x + 0.12, d1.floor + 0.05, z + 0.12, { 1.0, 0.8, 0.4 },
                        { emissive = 1 })
  end
end

-- add-detail-pass: visual-only dressing (no collision, no sim effect)
-- decor props (saucer/decor.lua) for one fold group, or all when gid is nil
local function decor(out, L, gid)
  local fold = require("sim.fold")
  for _, d in ipairs(data.load("saucer/decor.lua")) do
    if not gid or fold.group_of(L, d.deck, d.at[1], d.at[2]) == gid then props.build(out, d, L.decks[d.deck].floor) end
  end
end

-- the glass dome's frame: meridian struts (none straight ahead of the helm),
-- a ring brace and a lit hub at the crown; plus floor inlay rings
local DOME_PHI = 1.42
local function dome_frame(out, L)
  local d1 = L.decks[1]
  local R, H = L.dome.radius - 0.1, L.dome.height - 0.08
  local col = { 0.55, 0.58, 0.66 }
  for k = 0, 11 do
    local a = (k + 0.5) * sm.tau / 12
    local sa, ca = sm.sin(a), sm.cos(a)
    local prev
    for s = 0, 7 do
      local phi = s / 7 * DOME_PHI
      local p = { sa * R * sm.cos(phi), d1.floor + H * sm.sin(phi), ca * R * sm.cos(phi) }
      if prev then out[#out + 1] = props.bar(prev, p, 0.12, 0.08, col) end
      prev = p
    end
  end
  local phi = 0.75
  local rr = R * sm.cos(phi)
  out[#out + 1] = P("ring", { c = { 0, d1.floor + H * sm.sin(phi) - 0.04, 0 }, rin = rr - 0.12, r = rr, h = 0.08, seg = 32,
                              color = col })
  local top, hub = d1.floor + H * sm.sin(DOME_PHI), R * sm.cos(DOME_PHI) + 0.15
  out[#out + 1] = P("cylinder", { c = { 0, top - 0.1, 0 }, r = hub, h = 0.16, seg = 12, color = col })
  out[#out + 1] = P("cylinder", { c = { 0, top - 0.13, 0 }, r = hub * 0.6, h = 0.03, seg = 12, color = { 1, 0.9, 0.7 },
                                  emissive = 1 })
  for _, ring in ipairs({ { 2.9, 3.05 }, { 7.45, 7.6 } }) do
    out[#out + 1] = P("ring", { c = { 0, d1.floor, 0 }, rin = ring[1], r = ring[2], h = 0.008, seg = 32,
                                color = { 0.3, 0.55, 0.6 } })
  end
end

-- lower deck: ceiling ribs (clear of the stairwell), baseboard, a cove
-- light ring and wall pilasters between the portholes
local function lower_trim(out, L)
  local d2, st = L.decks[2], L.stairs
  local Rw = d2.radius + 0.2
  out[#out + 1] = P("ring", { c = { 0, d2.floor, 0 }, rin = Rw - 0.1, r = Rw, h = 0.14, seg = 24, color = { 0.35, 0.34, 0.33 } })
  out[#out + 1] = P("ring", { c = { 0, d2.ceiling - 0.14, 0 }, rin = Rw - 0.22, r = Rw, h = 0.05, seg = 24,
                              color = { 0.6, 0.85, 1.0 }, emissive = 1 })
  for k = 0, 11 do
    local a = k * sm.tau / 12
    out[#out + 1] = P("box", { min = { -0.14, 0, -0.16 }, max = { 0.14, d2.ceiling - d2.floor, 0 }, yaw = a,
                               pos = { sm.sin(a) * Rw, d2.floor, sm.cos(a) * Rw }, color = { 0.66, 0.64, 0.6 } })
  end
  local function in_well(x, z)
    return x > st.low - 0.25 and x < st.high + 0.25 and z > st.z0 - 0.25 and z < st.z1 + 0.25
  end
  for k = 0, 11 do
    local a = (k + 0.5) * sm.tau / 12
    local sa, ca = sm.sin(a), sm.cos(a)
    local run0
    local t = 1.4
    while t <= Rw - 0.1 + 1e-6 do
      local inside = in_well(sa * t, ca * t)
      if not inside and not run0 then run0 = t end
      local last = t + 0.1 > Rw - 0.1 + 1e-6
      if run0 and (inside or last) then
        local t1 = inside and t - 0.1 or t
        if t1 - run0 > 0.3 then
          local y = d2.ceiling - 0.1
          out[#out + 1] = props.bar({ sa * run0, y, ca * run0 }, { sa * t1, y, ca * t1 }, 0.16, 0.18, { 0.5, 0.5, 0.52 })
        end
        run0 = nil
      end
      t = t + 0.1
    end
  end
end

-- stairs: lit step nosings and a handrail with posts on both sides
local function stair_rails(out, L)
  local st, lo, hi = L.stairs, L.decks[2].floor, L.decks[1].floor
  local n = st.steps
  local run = (st.high - st.low) / n
  for i = 0, n - 1 do
    local top = lo + (hi - lo) * (i + 1) / n
    local x0 = st.low + i * run
    out[#out + 1] = box(x0, top - 0.02, st.z0 + 0.1, x0 + 0.05, top + 0.004, st.z1 - 0.1, { 1.0, 0.75, 0.3 }, { emissive = 0.8 })
  end
  for _, z in ipairs({ st.z0 + 0.08, st.z1 - 0.08 }) do
    out[#out + 1] = props.bar({ st.low, lo + 0.95, z }, { st.high, hi + 0.95, z }, 0.05, 0.06, { 0.6, 0.62, 0.7 })
    for i = 1, n - 1, 3 do
      local x = st.low + (i + 0.5) * run
      local top = lo + (hi - lo) * (i + 1) / n
      out[#out + 1] = props.tube({ x, top, z }, { x, top + 0.95 + 0.5 * run * (hi - lo) / (st.high - st.low), z }, 0.02,
                                 { 0.6, 0.62, 0.7 }, 4)
    end
  end
end

-- one sliding door leaf (drawn by the renderer at its open offset)
local function door(L, id)
  for _, d in ipairs(L.doors or {}) do
    if d.id == id then
      local b = d.box
      local y = L.decks[d.deck].floor
      local h = L.decks[d.deck].ceiling - y
      return { parts = {
        box(b[1], y, b[2] - 0.02, b[3], y + h, b[4] + 0.02, { 0.82, 0.84, 0.9 }),
        box(b[1] + 0.1, y + 1.0, b[2] - 0.03, b[1] + 0.2, y + 1.3, b[4] + 0.03, { 0.3, 1.0, 0.6 }, { emissive = 1 }),
      } }
    end
  end
  return { parts = {} }
end

-- parts for one fold group (see sim/fold.lua), relative to the group's anchor
local function group(L, gid)
  local fold = require("sim.fold")
  local g
  for _, x in ipairs(fold.groups(L)) do
    if x.id == gid then g = x end
  end
  if not g then return { parts = {} } end
  local out = {}
  if gid == "1:deck" then
    floor_strips(out, L)
    lights(out, L, 1)
    dome_frame(out, L)
  elseif gid == "2:deck" then
    local d2 = L.decks[2]
    out[#out + 1] = P("cylinder", { c = { 0, d2.floor - 0.3, 0 }, r = d2.radius + 0.2, h = 0.3, seg = 24,
                                    color = { 0.42, 0.40, 0.38 } })
    out[#out + 1] = P("cylinder", { c = { 0, d2.floor, 0 }, r = d2.radius + 0.2, h = d2.ceiling - d2.floor, seg = 24,
                                    color = { 0.78, 0.76, 0.70 }, open = true })
    for i = 0, 11 do
      local a = sm.tau * (i + 0.5) / 12
      local r = d2.radius + 0.04
      out[#out + 1] = P("box", { min = { -0.35, -0.35, -0.03 }, max = { 0.35, 0.35, 0.03 }, color = { 0.2, 0.5, 0.8 },
                                 emissive = 0.6, pos = { sm.sin(a) * r, d2.floor + 1.8, sm.cos(a) * r }, yaw = a })
    end
    lights(out, L, 2)
    lower_trim(out, L)
  elseif gid == "1:Stairs" then
    stairs(out, L)
    stair_rails(out, L)
  end
  decor(out, L, gid)
  for _, f in ipairs(L.furniture) do
    local cx, cz
    if f.circle then cx, cz = f.circle[1], f.circle[2] else cx, cz = (f.box[1] + f.box[3]) / 2, (f.box[2] + f.box[4]) / 2 end
    if fold.group_of(L, f.deck, cx, cz) == gid then (BUILD[f.kind] or BUILD.box)(out, f, L.decks[f.deck].floor) end
  end
  local a = g.anchor
  return { parts = kit.transform(out, { pos = { -a[1], -a[2], -a[3] } }) }
end

return function(params, rng)
  local L = data.load("saucer/interior.lua")
  if params.part == "group" then return group(L, params.group) end
  if params.part == "door" then return door(L, params.door) end
  if params.part == "glass" then
    return { parts = {
      P("hemisphere", { c = { 0, L.decks[1].floor, 0 }, r = L.dome.radius, h = L.dome.height, seg = 24, rings = 6,
                        color = { 0.55, 0.85, 1.0 }, emissive = 0.1 }),
    } }
  end
  local out = {}
  local d1, d2 = L.decks[1], L.decks[2]
  floor_strips(out, L)
  -- lower deck: floor, inner hull wall, ceiling trim
  out[#out + 1] = P("cylinder", { c = { 0, d2.floor - 0.3, 0 }, r = d2.radius + 0.2, h = 0.3, seg = 24,
                                  color = { 0.42, 0.40, 0.38 } })
  out[#out + 1] = P("cylinder", { c = { 0, d2.floor, 0 }, r = d2.radius + 0.2, h = d2.ceiling - d2.floor, seg = 24,
                                  color = { 0.78, 0.76, 0.70 }, open = true })
  -- portholes on the lower deck wall
  for i = 0, 11 do
    local a = sm.tau * (i + 0.5) / 12
    local r = d2.radius + 0.04
    out[#out + 1] = P("box", { min = { -0.35, -0.35, -0.03 }, max = { 0.35, 0.35, 0.03 }, color = { 0.2, 0.5, 0.8 },
                               emissive = 0.6, pos = { sm.sin(a) * r, d2.floor + 1.8, sm.cos(a) * r }, yaw = a })
  end
  stairs(out, L)
  stair_rails(out, L)
  for _, f in ipairs(L.furniture) do
    local y = L.decks[f.deck].floor
    local b = BUILD[f.kind] or BUILD.box
    b(out, f, y)
  end
  lights(out, L)
  dome_frame(out, L)
  lower_trim(out, L)
  decor(out, L)
  return { parts = out }
end
