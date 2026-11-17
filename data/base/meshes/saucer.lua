-- SPDX-License-Identifier: MIT
-- Hero mesh: the player saucer's hull, generated from primitives (concept §11.8).
-- params: config = "villa" | "seat" (anything else: a scaled generic hull),
-- diameter, height, part = "hull" | "dome". The Villa's walkable interior and
-- its glass dome come from meshes/interior.lua.
local kit = require("lib.meshkit")
local data = require("lib.data")
local props = data.load("meshes/props.lua")
local sm = saucer.math
local P = kit.part
local M = {}

local HULL, RIM = { 0.78, 0.80, 0.86 }, { 0.32, 0.34, 0.42 }

local function villa_hull()
  local parts = {
    -- open shell: no internal caps, so the lower deck is not cut by discs
    P("lathe", { seg = 32, color = HULL, uv = 0.5, open = true, points = {
      2.7, -5.6, 7.5, -4.9, 11.6, -2.6, 13.0, -0.9, 12.9, -0.3, 12.0, 0.3, 10.8, 0.62 } }),
    -- add-tractor-beam: the beam emitter ring round the Tractor Room's floor
    -- window (the window and the hatch iris sit inside it)
    P("ring", { c = { 0, -5.75, 0 }, rin = 1.98, r = 2.8, h = 0.15, seg = 24, color = { 0.3, 0.9, 1.0 }, emissive = 0.9 }),
    P("ring", { c = { 0, -5.8, 0 }, rin = 1.9, r = 2.05, h = 0.06, seg = 24, color = RIM }),
    P("ring", { c = { 0, -1.0, 0 }, rin = 12.8, r = 13.3, h = 0.6, seg = 32, color = RIM }),
  }
  local light = { P("box", { min = { -0.35, -0.95, 13.25 }, max = { 0.35, -0.55, 13.4 }, color = { 1.0, 0.75, 0.3 },
                             emissive = 1 }) }
  parts = kit.merge(parts, kit.radial_array(light, 16))
  -- eight focusing lenses on the emitter ring
  local lens = { P("box", { min = { -0.16, -5.86, 2.25 }, max = { 0.16, -5.75, 2.6 }, color = { 0.85, 1.0, 1.0 }, emissive = 1 }) }
  parts = kit.merge(parts, kit.radial_array(lens, 8, 0.39))
  local strut = { P("cone", { c = { 0, -6.6, 6.0 }, r = 0.5, r1 = 0.25, h = 1.6, seg = 6, color = RIM }) }
  parts = kit.merge(parts, kit.radial_array(strut, 3, 0.5))
  return kit.merge(parts, M.villa_detail())
end

-- add-detail-pass: panel seams, a second light row, antennas, a sensor dish,
-- belly and rear thrusters with glowing throats, docking lights and vents.
-- All built once into the hull mesh (render.lua adds the thruster glow sprites).
local PROFILE = { 2.7, -5.6, 7.5, -4.9, 11.6, -2.6, 13.0, -0.9 }
local SEAM, GLOWC = { 0.5, 0.52, 0.58 }, { 0.45, 0.85, 1.0 }
M.THRUSTERS = {
  belly = { { 6.0, 0.7854 }, { 6.0, 2.3562 }, { 6.0, 3.9270 }, { 6.0, 5.4978 } },  -- { radius, angle }
  belly_y = -5.68,
  rear = { { -2.2, -1.5, -12.7 }, { 2.2, -1.5, -12.7 } },                          -- nozzle tips
}
function M.villa_detail()
  local parts = {}
  local function add(p) parts[#parts + 1] = p end
  -- radial seams down the underside, slightly proud of the skin
  for k = 0, 23 do
    local a = k * sm.tau / 24
    local sa, ca = sm.sin(a), sm.cos(a)
    for i = 1, #PROFILE - 2, 2 do
      local r0, y0, r1, y1 = PROFILE[i], PROFILE[i + 1], PROFILE[i + 2], PROFILE[i + 3]
      local dr, dy = r1 - r0, y1 - y0
      local len = sm.sqrt(dr * dr + dy * dy)
      local nr, ny = dy / len * 0.04, -dr / len * 0.04
      add(props.bar({ sa * (r0 + nr), y0 + ny, ca * (r0 + nr) }, { sa * (r1 + nr), y1 + ny, ca * (r1 + nr) }, 0.09, 0.05, SEAM))
    end
  end
  -- circumferential seams at the profile corners and halfway along each panel
  for _, rc in ipairs({ { 5.1, -5.25 }, { 7.5, -4.9 }, { 9.55, -3.75 }, { 11.6, -2.6 } }) do
    add(P("ring", { c = { 0, rc[2] - 0.05, 0 }, rin = rc[1] - 0.12, r = rc[1] + 0.06, h = 0.1, seg = 32, color = SEAM }))
  end
  -- a second, cyan light row on the upper rim
  local light = { P("box", { min = { -0.12, 0.0, 12.35 }, max = { 0.12, 0.12, 12.6 }, color = GLOWC, emissive = 1 }) }
  parts = kit.merge(parts, kit.radial_array(light, 24, 0.13))
  -- antennas: two masts aft with red tips and cross bars
  for _, a in ipairs({ 2.55, -2.55 }) do
    local x, z = sm.sin(a) * 11.4, sm.cos(a) * 11.4
    add(P("cylinder", { c = { x, 0.35, z }, r = 0.07, h = 2.8, seg = 6, color = RIM }))
    add(P("sphere", { c = { x, 3.2, z }, r = 0.16, h = 0.16, seg = 6, rings = 2, color = { 1, 0.25, 0.2 }, emissive = 1 }))
    for k = 0, 1 do
      add(P("box", { min = { -0.5 + k * 0.15, 1.5 + k * 0.7, -0.03 }, max = { 0.5 - k * 0.15, 1.56 + k * 0.7, 0.03 },
                     yaw = a + sm.pi / 2, pos = { x, 0, z }, color = RIM }))
    end
  end
  -- a sensor dish on the rear rim
  add(P("cylinder", { c = { 0, 0.35, -11.3 }, r = 0.18, h = 0.6, seg = 6, color = RIM }))
  add(P("cone", { c = { 0, 0.9, -11.3 }, r = 0.12, r1 = 0.95, h = 0.4, seg = 12, color = HULL, open = true }))
  add(P("cylinder", { c = { 0, 0.9, -11.3 }, r = 0.04, h = 0.7, seg = 4, color = RIM }))
  -- belly thrusters: nozzle bells with glowing throats
  for _, t in ipairs(M.THRUSTERS.belly) do
    local x, z = sm.sin(t[2]) * t[1], sm.cos(t[2]) * t[1]
    add(P("cone", { c = { x, -5.66, z }, r = 0.6, r1 = 0.38, h = 0.62, seg = 10, color = { 0.4, 0.42, 0.48 }, open = true }))
    add(P("cylinder", { c = { x, -5.2, z }, r = 0.4, h = 0.06, seg = 10, color = GLOWC, emissive = 1 }))
    add(P("ring", { c = { x, -5.7, z }, rin = 0.56, r = 0.66, h = 0.06, seg = 10, color = RIM }))
  end
  -- rear main thrusters (pointing aft, -z)
  for _, tip in ipairs(M.THRUSTERS.rear) do
    local base = { tip[1], tip[2], tip[3] + 0.9 }
    add(P("cone", { c = { 0, 0, 0 }, r = 0.38, r1 = 0.62, h = 0.9, seg = 10, color = { 0.4, 0.42, 0.48 }, open = true,
                    pitch = -sm.pi / 2, pos = base }))
    add(P("cylinder", { c = { 0, 0.3, 0 }, r = 0.42, h = 0.05, seg = 10, color = GLOWC, emissive = 1, pitch = -sm.pi / 2,
                        pos = base }))
    add(P("box", { min = { -0.7, -0.5, -0.2 }, max = { 0.7, 0.5, 1.2 }, color = RIM, pos = base }))
  end
  -- docking lights under the bow, and vent grilles round the belly
  for _, x in ipairs({ -1.2, 1.2 }) do
    add(P("box", { min = { x - 0.15, -2.2, 11.4 }, max = { x + 0.15, -2.0, 11.7 }, color = { 1, 1, 0.95 }, emissive = 1 }))
  end
  local vent = {}
  for k = 0, 3 do
    vent[#vent + 1] = P("box", { min = { -0.6, -4.62 - k * 0.0, 7.9 + k * 0.22 }, max = { 0.6, -4.5, 8.02 + k * 0.22 },
                                 color = { 0.2, 0.21, 0.25 } })
  end
  return kit.merge(parts, kit.radial_array(vent, 6, 0.26))
end

local function seat_hull()
  local parts = {
    P("lathe", { seg = 16, color = HULL, uv = 0.5, points = {
      0.25, -0.7, 0.72, -0.56, 0.9, -0.28, 0.86, -0.12, 0.62, -0.02 } }),
    P("cylinder", { c = { 0, -0.75, 0 }, r = 0.22, h = 0.06, seg = 10, color = { 0.3, 0.9, 1.0 }, emissive = 0.9 }),
    -- the one seat
    P("box", { min = { -0.28, -0.05, -0.3 }, max = { 0.28, 0.05, 0.22 }, color = { 0.85, 0.45, 0.2 } }),
    P("box", { min = { -0.28, 0.05, -0.36 }, max = { 0.28, 0.62, -0.24 }, color = { 0.85, 0.45, 0.2 } }),
    -- control yoke and a strip of instruments
    P("box", { min = { -0.4, -0.12, 0.42 }, max = { 0.4, 0.02, 0.58 }, color = { 0.3, 0.32, 0.4 } }),
    P("box", { min = { -0.3, 0.02, 0.48 }, max = { 0.3, 0.05, 0.54 }, color = { 0.3, 1.0, 0.7 }, emissive = 1 }),
    P("ring", { c = { 0, -0.06, 0 }, rin = 0.6, r = 0.66, h = 0.05, seg = 16, color = RIM }),
  }
  local light = { P("box", { min = { -0.04, -0.3, 0.86 }, max = { 0.04, -0.2, 0.92 }, color = { 1.0, 0.75, 0.3 },
                             emissive = 1 }) }
  -- add-detail-pass: twin tail fins with tip lights, a rear thruster and a seam ring
  for _, x in ipairs({ -0.38, 0.38 }) do
    parts[#parts + 1] = P("wedge", { min = { x - 0.025, -0.2, -0.95 }, max = { x + 0.025, 0.22, -0.55 }, low = 0.1, color = RIM })
    parts[#parts + 1] = P("box", { min = { x - 0.03, 0.18, -0.97 }, max = { x + 0.03, 0.24, -0.9 }, color = { 1, 0.25, 0.2 },
                                   emissive = 1 })
  end
  parts[#parts + 1] = P("cone", { c = { 0, 0, 0 }, r = 0.12, r1 = 0.2, h = 0.25, seg = 8, color = RIM, open = true,
                                  pitch = -sm.pi / 2, pos = { 0, -0.35, -0.78 } })
  parts[#parts + 1] = P("cylinder", { c = { 0, 0.1, 0 }, r = 0.14, h = 0.02, seg = 8, color = { 0.45, 0.85, 1.0 }, emissive = 1,
                                      pitch = -sm.pi / 2, pos = { 0, -0.35, -0.78 } })
  parts[#parts + 1] = P("ring", { c = { 0, -0.44, 0 }, rin = 0.78, r = 0.82, h = 0.03, seg = 16, color = { 0.5, 0.52, 0.58 } })
  return kit.merge(parts, kit.radial_array(light, 6))
end

local function generic_hull(R, H)
  return {
    P("lathe", { seg = 24, color = HULL, uv = 0.5, points = {
      0.22 * R, -0.50 * H, 0.62 * R, -0.36 * H, 0.97 * R, -0.08 * H, 1.00 * R, -0.02 * H,
      0.92 * R, 0.06 * H, 0.46 * R, 0.12 * H } }),
    P("cylinder", { c = { 0, 0.10 * H, 0 }, r = 0.43 * R, h = 0.03 * H, seg = 20, color = { 0.42, 0.44, 0.5 } }),
  }
end

return setmetatable(M, { __call = function(_, params, rng)
  local R, H = (params.diameter or 26) / 2, params.height or 12
  if params.part == "dome" then
    if params.config == "seat" then
      return { parts = { P("hemisphere", { c = { 0, -0.04, 0 }, r = 0.64, h = 0.74, seg = 14, rings = 4,
                                           color = { 0.55, 0.85, 1.0 }, emissive = 0.1 }) } }
    end
    return { parts = { P("hemisphere", { c = { 0, 0.10 * H, 0 }, r = 0.42 * R, h = 0.42 * H, seg = 20, rings = 5,
                                         color = { 0.55, 0.85, 1.0 }, emissive = 0.15 }) } }
  end
  if params.config == "villa" then return { parts = villa_hull() } end
  if params.config == "pocket" then
    -- add-pocket-station-visits: the coin is the whole Villa, shrunk to fit a
    -- palm (a big coin, five centimetres across) with its glass dome on top
    local k = R / 13.0
    local parts = kit.merge(villa_hull(), { P("hemisphere", { c = { 0, 0.5, 0 }, r = 10.6, h = 5.2, seg = 20, rings = 5,
                                                             color = { 0.55, 0.85, 1.0 }, emissive = 0.25 }) })
    return { parts = kit.transform(parts, { scale = k }) }
  end
  if params.config == "seat" then return { parts = seat_hull() } end
  return { parts = generic_hull(R, H) }
end })
