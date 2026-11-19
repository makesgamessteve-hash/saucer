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

-- add-tractor-beam: the Tractor Room. The operator's sling seat hangs from the
-- ceiling out over the floor window, facing inward (-x); its back is at +x
function BUILD.beam_seat(out, f, y)
  local b = f.box
  local cz = (b[2] + b[4]) / 2
  local ceil = y + 1.9
  out[#out + 1] = box(b[1], y + 0.42, b[2], b[3], y + 0.52, b[4], f.color)
  out[#out + 1] = box(b[3] - 0.12, y + 0.52, b[2], b[3], y + f.h + 0.25, b[4], f.color)
  out[#out + 1] = box(b[3] - 0.14, y + f.h + 0.05, cz - 0.12, b[3] - 0.11, y + f.h + 0.2, cz + 0.12, { 0.2, 0.2, 0.22 })
  -- harness straps and the hanger bars to the ceiling rail
  for _, z in ipairs({ b[2] + 0.06, b[4] - 0.06 }) do
    out[#out + 1] = box(b[3] - 0.13, y + 0.55, z - 0.025, b[3] - 0.11, y + f.h + 0.2, z + 0.025, { 0.95, 0.75, 0.1 })
    out[#out + 1] = props.tube({ b[3] - 0.05, y + f.h + 0.25, z }, { b[3] + 0.25, ceil, z }, 0.035, { 0.6, 0.62, 0.7 }, 6)
  end
  out[#out + 1] = box(b[1] - 0.1, ceil - 0.08, b[2] - 0.1, b[3] + 0.4, ceil, b[4] + 0.1, { 0.4, 0.42, 0.48 })
  -- a foot bar
  out[#out + 1] = props.tube({ b[1] - 0.05, y + 0.2, b[2] }, { b[1] - 0.05, y + 0.2, b[4] }, 0.03, { 0.6, 0.62, 0.7 }, 6)
end
-- a console arm beside the seat: pedestal, sloped top, a screen facing the
-- operator's lap and a row of lit buttons (live readouts: view/render.lua)
function BUILD.beam_arm(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1] + 0.05, y, b[2] + 0.05, b[3] - 0.05, y + f.h - 0.1, b[4] - 0.05, darker(f.color, 0.8))
  out[#out + 1] = box(b[1], y + f.h - 0.1, b[2], b[3], y + f.h, b[4], f.color)
  local inner = f.side > 0 and b[2] or b[4]
  out[#out + 1] = box(b[1] + 0.06, y + f.h, inner - 0.01, b[3] - 0.06, y + f.h + 0.003, inner + 0.01, { 0.3, 1.0, 0.7 },
                      { emissive = 1 })
  out[#out + 1] = box(b[1] + 0.08, y + f.h + 0.003, b[2] + 0.04, b[3] - 0.08, y + f.h + 0.008, b[4] - 0.04,
                      { 0.03, 0.07, 0.1 }, { emissive = 0.6 })
  for k = 0, 3 do
    local x0 = b[1] + 0.1 + k * 0.12
    out[#out + 1] = box(x0, y + f.h, b[2] + 0.02, x0 + 0.07, y + f.h + 0.03, b[2] + 0.08,
                        k == 0 and { 1, 0.3, 0.2 } or { 0.3, 0.8, 1 }, { emissive = 1 })
  end
  -- a stubby joystick for the trim thrusters
  local cx, cz = b[3] - 0.15, (b[2] + b[4]) / 2
  out[#out + 1] = P("cylinder", { c = { cx, y + f.h, cz }, r = 0.025, h = 0.18, seg = 6, color = { 0.2, 0.2, 0.22 } })
  out[#out + 1] = P("sphere", { c = { cx, y + f.h + 0.2, cz }, r = 0.045, h = 0.045, seg = 8, rings = 2,
                                color = f.side > 0 and { 1, 0.75, 0.3 } or { 0.3, 0.9, 1 }, emissive = 1 })
end
-- the cargo lift tube over the beam hatch: it hangs from the ceiling and ends
-- in a flared mouth above head height, so the operator sees down through the
-- floor window; shrunk loot rides up the beam into it and on into the hold
function BUILD.cargo_tube(out, f, y)
  local c = f.circle
  local r = c[3]
  local lo = 1.55
  out[#out + 1] = P("cylinder", { c = { c[1], y + lo, c[2] }, r = r - 0.05, h = f.h - lo + 0.3, seg = 16, color = f.color,
                                  emissive = 0.25, open = true })
  out[#out + 1] = P("ring", { c = { c[1], y + lo - 0.06, c[2] }, rin = r - 0.06, r = r + 0.18, h = 0.08, seg = 16,
                              color = { 1.0, 0.75, 0.2 }, emissive = 0.6 })
  for _, h in ipairs({ lo + 0.02, f.h - 0.12 }) do
    out[#out + 1] = P("ring", { c = { c[1], y + h, c[2] }, rin = r - 0.08, r = r + 0.04, h = 0.12, seg = 16,
                                color = { 0.42, 0.44, 0.5 } })
  end
  for k = 0, 3 do
    local a = k * sm.tau / 4 + 0.4
    out[#out + 1] = P("box", { min = { -0.03, lo, r - 0.02 }, max = { 0.03, f.h, r + 0.03 }, yaw = a, pos = { c[1], y, c[2] },
                               color = { 0.3, 0.9, 1.0 }, emissive = 1 })
  end
end
-- a hold rack: six cubbies (lit by the renderer when a hold slot is used)
function BUILD.hold_rack(out, f, y)
  local b = f.box
  local back = math.abs(b[4]) > math.abs(b[2]) and 1 or -1
  out[#out + 1] = box(b[1], y, b[2], b[3], y + 0.1, b[4], darker(f.color, 0.7))
  out[#out + 1] = box(b[1], y + f.h - 0.06, b[2], b[3], y + f.h, b[4], darker(f.color, 0.7))
  local zb = back > 0 and b[4] - 0.05 or b[2]
  out[#out + 1] = box(b[1], y, zb, b[3], y + f.h, zb + 0.05, f.color)
  for k = 0, 3 do
    local x = b[1] + k * (b[3] - b[1]) / 3
    out[#out + 1] = box(x - 0.03, y, b[2], x + 0.03, y + f.h, b[4], f.color)
  end
  for h = 1, 2 do
    out[#out + 1] = box(b[1], y + h * 0.6 - 0.03, b[2], b[3], y + h * 0.6, b[4], f.color)
  end
  -- yellow-black kick stripes
  for k = 0, 7 do
    local x0 = b[1] + k * (b[3] - b[1]) / 8
    local zf = back > 0 and b[2] - 0.01 or b[4] + 0.005
    out[#out + 1] = box(x0, y + 0.01, zf, x0 + (b[3] - b[1]) / 8, y + 0.09, zf + 0.005,
                        k % 2 == 0 and { 0.95, 0.75, 0.1 } or { 0.1, 0.1, 0.1 })
  end
end

-- helm (milestone 2): a low desk under the pilot's eye line with a flat radar
-- well in the middle, and two angled wing screens; live readouts are drawn on
-- top of these by the renderer (view/render.lua console())
function BUILD.helm_desk(out, f, y)
  -- add-mesh-builder: the cockpit console recipe (meshes/cockpit.lua), with the size lever
  -- and the throttle orb standing on it at their neutral poses
  local b = f.box
  local cockpit = data.load("meshes/cockpit.lua")
  local cx, cz = (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
  local con = cockpit({ kind = "console", w = b[3] - b[1], d = b[4] - b[2], h = f.h, color = f.color })
  local all = kit.transform(con.parts, { pos = { cx, y, cz } })
  all = kit.merge(all, kit.transform(cockpit({ kind = "lever" }).parts, { pos = { cx + 0.85, y + f.h, cz } }),
                  kit.transform(cockpit({ kind = "orb" }).parts, { pos = { cx - 0.85, y + f.h, cz } }))
  for _, p in ipairs(all) do
    p.node = nil -- the props are baked at their neutral pose here; the nodes are for the rigs
    out[#out + 1] = p
  end
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


-- add-holodeck-home-life: the Holodeck's partition (dark, a lit grid on the
-- room side), the arch round its opening, the control panel and the TV
local HOLO = { 0.95, 0.75, 0.25 }
function BUILD.holo_wall(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y, b[2], b[3], y + f.h, b[4], f.color)
  -- grid on the inner (+x) face
  local x = b[3] + 0.005
  for k = 0, math.floor((b[4] - b[2]) / 0.8) do
    local z = b[2] + k * 0.8
    if z <= b[4] then out[#out + 1] = box(x, y, z - 0.02, x + 0.01, y + f.h, z + 0.02, HOLO, { emissive = 0.9 }) end
  end
  for k = 1, 4 do
    local yy = y + k * 0.8
    out[#out + 1] = box(x, yy - 0.02, b[2], x + 0.01, yy + 0.02, b[4], HOLO, { emissive = 0.9 })
  end
  -- a plain trim on the engine room side
  out[#out + 1] = box(b[1] - 0.01, y, b[2], b[1], y + 0.15, b[4], { 0.35, 0.35, 0.4 })
end
function BUILD.holo_arch(out, f, y)
  local b = f.box
  local h = f.h
  -- two posts and a lintel, lit edges
  out[#out + 1] = box(b[1], y, b[2], b[3], y + h, b[2] + 0.12, darker(f.color, 0.55))
  out[#out + 1] = box(b[1], y, b[4] - 0.12, b[3], y + h, b[4], darker(f.color, 0.55))
  out[#out + 1] = box(b[1], y + h - 0.16, b[2], b[3], y + h, b[4], darker(f.color, 0.55))
  out[#out + 1] = box(b[1] - 0.01, y, b[2] + 0.1, b[3] + 0.01, y + h - 0.14, b[2] + 0.13, f.color, { emissive = 1 })
  out[#out + 1] = box(b[1] - 0.01, y, b[4] - 0.13, b[3] + 0.01, y + h - 0.14, b[4] - 0.1, f.color, { emissive = 1 })
  out[#out + 1] = box(b[1] - 0.01, y + h - 0.17, b[2] + 0.1, b[3] + 0.01, y + h - 0.14, b[4] - 0.1, f.color, { emissive = 1 })
  -- a threshold plate
  out[#out + 1] = box(b[1] - 0.15, y + 0.005, b[2] + 0.12, b[3] + 0.15, y + 0.025, b[4] - 0.12, { 0.3, 0.3, 0.34 })
end
function BUILD.holo_panel(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y + 0.75, b[2], b[3], y + f.h, b[4], f.color)
  out[#out + 1] = box(b[1] + 0.05, y, b[2] + 0.15, b[3], y + 0.75, b[4] - 0.15, darker(f.color, 0.7))
  -- the program screen (faces -x) and a row of program keys
  out[#out + 1] = box(b[1] - 0.01, y + 0.95, b[2] + 0.06, b[1], y + f.h - 0.08, b[4] - 0.06, { 0.1, 0.08, 0.02 },
                      { emissive = 0.3 })
  for k = 0, 3 do
    local z = b[2] + 0.12 + k * (b[4] - b[2] - 0.24) / 3
    out[#out + 1] = box(b[1] - 0.02, y + 1.0 + (k % 2) * 0.12, z - 0.04, b[1] - 0.01, y + 1.36 - (k % 2) * 0.1, z + 0.04,
                        k == 1 and { 0.4, 1, 0.6 } or HOLO, { emissive = 1 })
  end
  for k = 0, 4 do
    local z = b[2] + 0.1 + k * (b[4] - b[2] - 0.2) / 4
    out[#out + 1] = box(b[1] - 0.04, y + 0.8, z - 0.05, b[1], y + 0.88, z + 0.05, k % 2 == 0 and HOLO or { 0.5, 0.8, 1 },
                        { emissive = 0.8 })
  end
end
-- add-home-among-stars: a display plinth (stepped column with a lit top) and a
-- raised garden bed with soil
function BUILD.plinth(out, f, y)
  local b = f.box
  local i = 0.06
  out[#out + 1] = box(b[1], y, b[2], b[3], y + 0.12, b[4], darker(f.color, 0.8))
  out[#out + 1] = box(b[1] + i, y + 0.12, b[2] + i, b[3] - i, y + f.h - 0.06, b[4] - i, f.color)
  out[#out + 1] = box(b[1] - 0.02, y + f.h - 0.06, b[2] - 0.02, b[3] + 0.02, y + f.h, b[4] + 0.02, { 0.55, 0.85, 1.0 },
                      { emissive = 0.6 })
end
function BUILD.planter(out, f, y)
  local b = f.box
  out[#out + 1] = box(b[1], y, b[2], b[3], y + f.h, b[4], f.color)
  out[#out + 1] = box(b[1] + 0.07, y + f.h, b[2] + 0.07, b[3] - 0.07, y + f.h + 0.02, b[4] - 0.07, { 0.24, 0.17, 0.11 })
end
function BUILD.tv(out, f, y)
  local b = f.box
  -- low stand with two shelves
  out[#out + 1] = box(b[1], y, b[2], b[3], y + f.h, b[4], f.color)
  out[#out + 1] = box(b[1] - 0.01, y + 0.08, b[2] + 0.1, b[1], y + f.h - 0.08, b[4] - 0.1, darker(f.color, 0.6))
  -- the screen above it, facing the sofa (-x); its picture is drawn by view/render.lua
  local cz, hw = (b[2] + b[4]) / 2, 1.08
  local x = (b[1] + b[3]) / 2
  out[#out + 1] = box(x - 0.05, y + f.h + 0.12, cz - hw, x + 0.04, y + f.h + 1.32, cz + hw, { 0.06, 0.06, 0.08 })
  out[#out + 1] = box(x - 0.02, y + f.h, cz - 0.1, x + 0.02, y + f.h + 0.12, cz + 0.1, { 0.2, 0.2, 0.22 })
  -- a speaker bar and a little console box on the stand
  out[#out + 1] = box(b[1] + 0.05, y + f.h, cz - 0.7, b[1] + 0.18, y + f.h + 0.1, cz + 0.7, { 0.15, 0.15, 0.17 })
  out[#out + 1] = box(b[1] + 0.05, y + f.h, cz + 0.8, b[1] + 0.3, y + f.h + 0.08, cz + 1.0, { 0.85, 0.85, 0.9 })
end

-- the holodeck room itself: black floor and ceiling with a lit grid, the
-- grid carried up the curved hull wall between the partition ends
local function holo_room(out, L)
  local H = L.holodeck
  if not H then return end
  local d2 = L.decks[2]
  local R = d2.radius
  local x0, z0, x1, z1 = H.room[1], H.room[2], H.room[3], H.room[4]
  local y, yc = d2.floor, d2.ceiling
  out[#out + 1] = box(x0, y + 0.004, z0, x1, y + 0.012, z1, { 0.03, 0.03, 0.05 })
  out[#out + 1] = box(x0, yc - 0.012, z0, x1, yc - 0.004, z1, { 0.03, 0.03, 0.05 })
  for k = 0, math.floor((x1 - x0) / 0.8) do
    local x = x0 + k * 0.8
    local w = sm.sqrt(math.max(0, R * R - x * x))
    local a, c = math.max(z0, -w), math.min(z1, w)
    if c > a then
      out[#out + 1] = box(x - 0.02, y + 0.012, a, x + 0.02, y + 0.02, c, HOLO, { emissive = 0.9 })
      out[#out + 1] = box(x - 0.02, yc - 0.02, a, x + 0.02, yc - 0.012, c, HOLO, { emissive = 0.6 })
    end
  end
  for k = 0, math.floor((z1 - z0) / 0.8) do
    local z = z0 + k * 0.8
    local w = sm.sqrt(math.max(0, R * R - z * z))
    local a, c = x0, math.min(x1, w)
    if c > a then
      out[#out + 1] = box(a, y + 0.012, z - 0.02, c, y + 0.02, z + 0.02, HOLO, { emissive = 0.9 })
      out[#out + 1] = box(a, yc - 0.02, z - 0.02, c, yc - 0.012, z + 0.02, HOLO, { emissive = 0.6 })
    end
  end
  -- the curved wall: a dark lining with vertical grid lines and three rings
  local a0, a1 = sm.atan2(x0, z1), sm.atan2(x0, z0)
  if a1 < a0 then a1 = a1 + sm.tau end
  local n = math.floor((a1 - a0) * R / 0.8)
  for k = 0, n do
    local a = a0 + (a1 - a0) * k / n
    local r = R - 0.05
    out[#out + 1] = P("box", { min = { -0.42, 0, -0.03 }, max = { 0.42, yc - y, 0.0 }, color = { 0.03, 0.03, 0.05 },
                               pos = { sm.sin(a) * r, y, sm.cos(a) * r }, yaw = a })
    out[#out + 1] = P("box", { min = { -0.02, 0, -0.05 }, max = { 0.02, yc - y, -0.03 }, color = HOLO, emissive = 0.9,
                               pos = { sm.sin(a) * r, y, sm.cos(a) * r }, yaw = a })
    for j = 1, 3 do
      out[#out + 1] = P("box", { min = { -0.42, j * 0.8 - 0.02, -0.05 }, max = { 0.42, j * 0.8 + 0.02, -0.03 }, color = HOLO,
                                 emissive = 0.9, pos = { sm.sin(a) * r, y, sm.cos(a) * r }, yaw = a })
    end
  end
  -- emitter studs at the grid crossings on the ceiling
  for _, c in ipairs({ { 5.6, -4.8 }, { 7.2, -2.4 }, { 5.6, -0.8 }, { 6.4, -2.4 } }) do
    out[#out + 1] = P("cylinder", { c = { c[1], yc - 0.08, c[2] }, r = 0.12, h = 0.07, seg = 8, color = { 1, 0.9, 0.6 },
                                    emissive = 1 })
  end
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

-- add-tractor-beam: a round deck floor made of strips, with a rectangular
-- hole (x0, z0, x1, z1) left open for a stairwell
local function strip_floor(out, y, R, hole, cols)
  local zs = { -R }
  local z = -R
  while z + 0.8 < R do
    z = z + 0.8
    zs[#zs + 1] = z
  end
  zs[#zs + 1] = R
  if hole then
    zs[#zs + 1] = hole[2]
    zs[#zs + 1] = hole[4]
    table.sort(zs)
  end
  for i = 1, #zs - 1 do
    local z0, z1 = zs[i], zs[i + 1]
    if z1 - z0 > 1e-6 then
      local far = math.max(math.abs(z0), math.abs(z1))
      local w = far < R and sm.sqrt(R * R - far * far) or 0
      local col = cols[(i % 2) + 1]
      if w > 0 then
        if hole and z0 >= hole[2] - 1e-6 and z1 <= hole[4] + 1e-6 then
          if hole[1] > -w then out[#out + 1] = box(-w, y - 0.3, z0, hole[1], y, z1, col) end
          if hole[3] < w then out[#out + 1] = box(hole[3], y - 0.3, z0, w, y, z1, col) end
        else
          out[#out + 1] = box(-w, y - 0.3, z0, w, y, z1, col)
        end
      end
    end
  end
end

local function belly_hole(L)
  local b = L.belly_stairs
  if not b then return nil end
  return { math.min(b.low, b.high), b.z0, math.max(b.low, b.high), b.z1 }
end

-- add-dock-land-eva: the lower deck's wall is 24 panels round the deck, with the
-- aft panel left out for the hull door: a frame (posts, lintel, sill) and a lit
-- strip round the opening. The door's sliding leaves are drawn by view/gear.lua.
local function lower_wall(out, L)
  local d2 = L.decks[2]
  local R = d2.radius + 0.2
  local T = L.hatch_door
  local w = 2 * R * sm.sin(sm.pi / 24) * 1.02
  local h = d2.ceiling - d2.floor
  for k = 0, 23 do
    local a = sm.tau * k / 24
    if not (T and k == 12) then
      out[#out + 1] = P("box", { min = { -w / 2, 0, -0.1 }, max = { w / 2, h, 0.1 }, color = { 0.78, 0.76, 0.70 },
                                 pos = { sm.sin(a) * R, d2.floor, sm.cos(a) * R }, yaw = a })
    end
  end
  if T then
    local W, H = T.width, T.height
    local z = -R
    for _, sx in ipairs({ -1, 1 }) do
      out[#out + 1] = P("box", { min = { sx * (W / 2 + 0.07) - 0.07, d2.floor, z - 0.18 }, max = { sx * (W / 2 + 0.07) + 0.07, d2.floor + h, z + 0.18 },
                                 color = { 0.34, 0.35, 0.42 } })
      out[#out + 1] = P("box", { min = { sx * (W / 2) - 0.02, d2.floor + 0.1, z + 0.17 }, max = { sx * (W / 2) + 0.02, d2.floor + H, z + 0.19 },
                                 color = { 1.0, 0.75, 0.2 }, emissive = 0.9 })
    end
    out[#out + 1] = P("box", { min = { -W / 2 - 0.14, d2.floor + H, z - 0.18 }, max = { W / 2 + 0.14, d2.floor + h, z + 0.18 },
                               color = { 0.34, 0.35, 0.42 } })
    out[#out + 1] = P("box", { min = { -W / 2, d2.floor + H - 0.04, z + 0.17 }, max = { W / 2, d2.floor + H, z + 0.19 },
                               color = { 1.0, 0.75, 0.2 }, emissive = 0.9 })
    -- the sill strip and a hazard-striped threshold
    out[#out + 1] = P("box", { min = { -W / 2, d2.floor, z - 0.5 }, max = { W / 2, d2.floor + 0.02, z + 0.4 },
                               color = { 0.95, 0.75, 0.15 } })
  end
end

-- the lower deck's floor (with the belly stairwell open) and its rim
local function lower_floor(out, L)
  local d2 = L.decks[2]
  local R = d2.radius + 0.2
  strip_floor(out, d2.floor, R, belly_hole(L), { { 0.42, 0.40, 0.38 }, { 0.45, 0.43, 0.41 } })
  out[#out + 1] = P("ring", { c = { 0, d2.floor - 0.3, 0 }, rin = R - 0.9, r = R, h = 0.3, seg = 24, color = { 0.42, 0.40, 0.38 } })
end

-- the belly stair: solid steps from the Tractor Room up to the lower deck,
-- side walls under the lower deck and lit nosings
local function belly_stairs(out, L)
  local b = L.belly_stairs
  if not b or not L.decks[b.lo] then return end
  local lo, hi = L.decks[b.lo].floor, L.decks[b.hi].floor
  local n = b.steps
  local run = (b.high - b.low) / n
  for i = 0, n - 1 do
    local top = lo + (hi - lo) * (i + 1) / n
    local xa, xb = b.low + i * run, b.low + (i + 1) * run
    local x0, x1 = math.min(xa, xb), math.max(xa, xb)
    out[#out + 1] = box(x0, lo - 0.3, b.z0, x1, top, b.z1, i % 2 == 0 and { 0.38, 0.40, 0.46 } or { 0.42, 0.44, 0.5 })
    out[#out + 1] = box(xa - 0.03, top - 0.02, b.z0 + 0.1, xa + 0.03, top + 0.004, b.z1 - 0.1, { 1.0, 0.75, 0.3 },
                        { emissive = 0.8 })
  end
  local x0, x1 = math.min(b.low, b.high), math.max(b.low, b.high)
  local ceil = L.decks[b.lo].ceiling
  out[#out + 1] = box(x0, lo, b.z0 - 0.12, x1, ceil, b.z0, { 0.62, 0.60, 0.56 })
  out[#out + 1] = box(x0, lo, b.z1, x1, ceil, b.z1 + 0.12, { 0.62, 0.60, 0.56 })
  out[#out + 1] = box(b.high - 0.12 * (b.high > b.low and -1 or 1), lo, b.z0, b.high, ceil, b.z1, { 0.62, 0.60, 0.56 })
  -- handrails following the pitch
  for _, z in ipairs({ b.z0 + 0.06, b.z1 - 0.06 }) do
    out[#out + 1] = props.bar({ b.low, lo + 0.95, z }, { b.high, hi + 0.95, z }, 0.05, 0.06, { 0.6, 0.62, 0.7 })
  end
end

-- the Tractor Room's shell: floor ring round the window, the window well down
-- to the emitter, the wall (open where the stair comes in), ceiling lights and
-- hazard markings round the glass
local function belly_room(out, L)
  local d3, T = L.decks[3], L.tractor
  if not d3 or not T then return end
  local y, R = d3.floor, d3.radius + 0.2
  local H = d3.ceiling - d3.floor
  out[#out + 1] = P("ring", { c = { 0, y - 0.3, 0 }, rin = T.window, r = R, h = 0.3, seg = 32, color = { 0.36, 0.38, 0.42 } })
  -- deck plate grid lines
  for _, rr in ipairs({ 2.9, 3.9 }) do
    out[#out + 1] = P("ring", { c = { 0, y, 0 }, rin = rr - 0.03, r = rr + 0.03, h = 0.006, seg = 32, color = { 0.25, 0.27, 0.3 } })
  end
  -- yellow and black hazard stripes round the window, a lit rim inside them
  for k = 0, 23 do
    local a = k * sm.tau / 24
    out[#out + 1] = P("box", { min = { -0.24, 0, T.window + 0.05 }, max = { 0.24, 0.012, T.window + 0.45 }, yaw = a,
                               pos = { 0, y, 0 }, color = k % 2 == 0 and { 0.95, 0.75, 0.1 } or { 0.1, 0.1, 0.1 } })
  end
  out[#out + 1] = P("ring", { c = { 0, y, 0 }, rin = T.window - 0.02, r = T.window + 0.05, h = 0.03, seg = 32,
                              color = { 0.3, 0.9, 1.0 }, emissive = 1 })
  -- the window well: a short sleeve from the glass down to the emitter ring
  out[#out + 1] = P("cylinder", { c = { 0, y - 0.6, 0 }, r = T.window + 0.04, h = 0.6, seg = 32, color = { 0.3, 0.32, 0.38 },
                                  open = true })
  -- the hatch rim at the bottom of the well
  out[#out + 1] = P("ring", { c = { 0, y - 0.6, 0 }, rin = T.hatch, r = T.hatch + 0.12, h = 0.06, seg = 16,
                              color = { 0.95, 0.75, 0.1 } })
  -- the wall: panels round the room, open where the belly stair arrives
  local b = L.belly_stairs
  local skip = b and sm.atan2((b.low + b.high) / 2, (b.z0 + b.z1) / 2) or nil
  for k = 0, 23 do
    local a = (k + 0.5) * sm.tau / 24
    local open = skip and math.abs(sm.wrap(a - skip)) < 0.42
    if not open then
      local hw = R * sm.sin(sm.pi / 24) + 0.02
      out[#out + 1] = P("box", { min = { -hw, 0, 0 }, max = { hw, H, 0.12 }, yaw = a, pos = { sm.sin(a) * R, y, sm.cos(a) * R },
                                 color = k % 2 == 0 and { 0.66, 0.66, 0.64 } or { 0.62, 0.62, 0.6 } })
      -- a rib and a lit strip on every other panel
      if k % 2 == 1 then
        out[#out + 1] = P("box", { min = { -0.08, 0, -0.1 }, max = { 0.08, H, 0 }, yaw = a,
                                   pos = { sm.sin(a) * R, y, sm.cos(a) * R }, color = { 0.45, 0.46, 0.5 } })
        out[#out + 1] = P("box", { min = { -0.4, 1.2, -0.02 }, max = { 0.4, 1.26, 0 }, yaw = a,
                                   pos = { sm.sin(a) * R, y, sm.cos(a) * R }, color = { 0.3, 0.9, 1.0 }, emissive = 1 })
      end
    end
  end
  -- warning panels either side of the stair opening
  if skip then
    for _, da in ipairs({ -0.5, 0.5 }) do
      local a = skip + da
      out[#out + 1] = P("box", { min = { -0.3, 0.9, -0.03 }, max = { 0.3, 1.5, 0 }, yaw = a,
                                 pos = { sm.sin(a) * R, y, sm.cos(a) * R }, color = { 0.95, 0.75, 0.1 }, emissive = 0.3 })
    end
  end
  -- ceiling: the underside of the lower deck, with light panels and a cove ring
  out[#out + 1] = P("ring", { c = { 0, d3.ceiling - 0.12, 0 }, rin = R - 0.2, r = R, h = 0.05, seg = 24,
                              color = { 0.6, 0.85, 1.0 }, emissive = 1 })
  for _, q in ipairs({ { 3.0, 0 }, { -3.0, 0.4 }, { 0, 3.0 }, { 0, -3.0 } }) do
    out[#out + 1] = box(q[1] - 0.45, d3.ceiling - 0.04, q[2] - 0.45, q[1] + 0.45, d3.ceiling, q[2] + 0.45, { 1.0, 0.9, 0.7 },
                        { emissive = 1 })
  end
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
  for _, p in ipairs(only == 1 and {} or { { 4, 4 }, { -4, 4 }, { 0, -1.8 }, { 2.3, -3.6 }, { -5, -3 } }) do
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
  if L.hatch_door then
    -- the baseboard in 24 pieces, none across the hull door
    local w = 2 * Rw * sm.sin(sm.pi / 24) * 1.02
    for k = 0, 23 do
      if k ~= 12 then
        local a = sm.tau * k / 24
        out[#out + 1] = P("box", { min = { -w / 2, 0, -0.1 }, max = { w / 2, 0.14, 0 }, yaw = a,
                                   pos = { sm.sin(a) * Rw, d2.floor, sm.cos(a) * Rw }, color = { 0.35, 0.34, 0.33 } })
      end
    end
  else
    out[#out + 1] = P("ring", { c = { 0, d2.floor, 0 }, rin = Rw - 0.1, r = Rw, h = 0.14, seg = 24, color = { 0.35, 0.34, 0.33 } })
  end
  out[#out + 1] = P("ring", { c = { 0, d2.ceiling - 0.14, 0 }, rin = Rw - 0.22, r = Rw, h = 0.05, seg = 24,
                              color = { 0.6, 0.85, 1.0 }, emissive = 1 })
  for k = 0, 11 do
    local a = k * sm.tau / 12
    -- add-dock-land-eva: no pilaster in the hull door's opening (azimuth pi)
    if not (L.hatch_door and k == 6) then
      out[#out + 1] = P("box", { min = { -0.14, 0, -0.16 }, max = { 0.14, d2.ceiling - d2.floor, 0 }, yaw = a,
                                 pos = { sm.sin(a) * Rw, d2.floor, sm.cos(a) * Rw }, color = { 0.66, 0.64, 0.6 } })
    end
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

-- add-presentation-packaging: surface materials. Parts get a mat tag (and a
-- texture scale) after they are built; the renderer draws each material as
-- its own mesh with a Grok Imagine detail texture multiplied by the part's
-- colour. Lit trim (emissive) and parts that already have a mat stay as they are.
local MAT_OF = {
  table = "wood", wardrobe = "wood", stool = "wood", books = "wood", plant = "wood", hold_rack = "metal",
  sofa = "fabric", armchair = "fabric", chair = "fabric", rug = "fabric", bed = "fabric", beam_seat = "fabric",
  counter = "tile", fridge = "tile", shower = "tile", tub = "tile",
  engine = "metal", console = "metal", helm_desk = "metal", helm_wing = "metal", lab_bench = "metal",
  terminal = "metal", beam_arm = "metal", cargo_tube = "metal", rail = "metal", tv = "metal",
  wall = "panel", box = "panel",
}
local MAT_UV = { wood = 0.8, fabric = 1.0, tile = 1.25, floor = 0.35, metal = 0.6, panel = 0.45 }
local function tag(out, n0, mat)
  if not mat then return end
  for i = n0 + 1, #out do
    local p = out[i]
    if not p.mat and not p.emissive then
      p.mat = mat
      p.uv = MAT_UV[mat]
    end
  end
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
    tag(out, 0, "floor")
    lights(out, L, 1)
    dome_frame(out, L)
  elseif gid == "2:deck" then
    local d2 = L.decks[2]
    lower_floor(out, L)
    tag(out, 0, "floor")
    local n0 = #out
    lower_wall(out, L)
    tag(out, n0, "panel")
    for i = 0, 11 do
      local a = sm.tau * (i + 0.5) / 12
      local r = d2.radius + 0.04
      out[#out + 1] = P("box", { min = { -0.35, -0.35, -0.03 }, max = { 0.35, 0.35, 0.03 }, color = { 0.2, 0.5, 0.8 },
                                 emissive = 0.6, pos = { sm.sin(a) * r, d2.floor + 1.8, sm.cos(a) * r }, yaw = a })
    end
    lights(out, L, 2)
    lower_trim(out, L)
  elseif gid == "3:deck" then
    belly_room(out, L)
    belly_stairs(out, L)
    tag(out, 0, "metal")
  elseif gid == "1:Stairs" then
    stairs(out, L)
    tag(out, 0, "wood")
    stair_rails(out, L)
  elseif gid == "2:Holodeck" then
    holo_room(out, L)
  end
  decor(out, L, gid)
  for _, f in ipairs(L.furniture) do
    local cx, cz
    if f.circle then cx, cz = f.circle[1], f.circle[2] else cx, cz = (f.box[1] + f.box[3]) / 2, (f.box[2] + f.box[4]) / 2 end
    if fold.group_of(L, f.deck, cx, cz) == gid then
      local n0 = #out
      ;(BUILD[f.kind] or BUILD.box)(out, f, L.decks[f.deck].floor)
      tag(out, n0, f.mat or MAT_OF[f.kind])
    end
  end
  local a = g.anchor
  return { parts = kit.transform(out, { pos = { -a[1], -a[2], -a[3] } }) }
end

return function(params, rng)
  local L = data.load("saucer/interior.lua")
  if params.part == "group" then return group(L, params.group) end
  if params.part == "door" then return door(L, params.door) end
  if params.part == "belly_glass" then
    -- add-tractor-beam: the Tractor Room's floor window (drawn see-through)
    local d3, T = L.decks[3], L.tractor
    if not d3 or not T then return { parts = {} } end
    return { parts = {
      P("ring", { c = { 0, d3.floor - 0.03, 0 }, rin = T.hatch + 0.12, r = T.window, h = 0.02, seg = 32,
                  color = { 0.55, 0.85, 1.0 }, emissive = 0.1 }),
    } }
  end
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
  lower_floor(out, L)
  lower_wall(out, L)
  belly_room(out, L)
  belly_stairs(out, L)
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
  holo_room(out, L)
  decor(out, L)
  return { parts = out }
end
