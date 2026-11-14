-- SPDX-License-Identifier: MIT
-- Hero mesh: the player saucer's hull, generated from primitives (concept §11.8).
-- params: config = "villa" | "seat" (anything else: a scaled generic hull),
-- diameter, height, part = "hull" | "dome". The Villa's walkable interior and
-- its glass dome come from meshes/interior.lua.
local kit = require("lib.meshkit")
local P = kit.part

local HULL, RIM = { 0.78, 0.80, 0.86 }, { 0.32, 0.34, 0.42 }

local function villa_hull()
  local parts = {
    -- open shell: no internal caps, so the lower deck is not cut by discs
    P("lathe", { seg = 32, color = HULL, uv = 0.5, open = true, points = {
      2.7, -5.6, 7.5, -4.9, 11.6, -2.6, 13.0, -0.9, 12.9, -0.3, 12.0, 0.3, 10.8, 0.62 } }),
    P("cylinder", { c = { 0, -5.75, 0 }, r = 2.8, h = 0.15, seg = 16, color = { 0.3, 0.9, 1.0 }, emissive = 0.9 }),
    P("ring", { c = { 0, -1.0, 0 }, rin = 12.8, r = 13.3, h = 0.6, seg = 32, color = RIM }),
  }
  local light = { P("box", { min = { -0.35, -0.95, 13.25 }, max = { 0.35, -0.55, 13.4 }, color = { 1.0, 0.75, 0.3 },
                             emissive = 1 }) }
  parts = kit.merge(parts, kit.radial_array(light, 16))
  local strut = { P("cone", { c = { 0, -6.6, 6.0 }, r = 0.5, r1 = 0.25, h = 1.6, seg = 6, color = RIM }) }
  parts = kit.merge(parts, kit.radial_array(strut, 3, 0.5))
  return parts
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

return function(params, rng)
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
  if params.config == "seat" then return { parts = seat_hull() } end
  return { parts = generic_hull(R, H) }
end
