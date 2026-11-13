-- SPDX-License-Identifier: MIT
-- Hero mesh: the player saucer, generated from primitives (concept §11.8).
-- params: diameter, height, part = "hull" | "dome", config = "villa"|...
local kit = require("lib.meshkit")

return function(params, rng)
  local R, H = (params.diameter or 24) / 2, params.height or 8
  local hull_c, rim_c = { 0.78, 0.80, 0.86 }, { 0.32, 0.34, 0.42 }
  if params.part == "dome" then
    return { parts = {
      kit.part("hemisphere", { c = { 0, 0.10 * H, 0 }, r = 0.42 * R, h = 0.42 * H, seg = 20, rings = 5,
                               color = { 0.55, 0.85, 1.0 }, emissive = 0.15 }),
    } }
  end
  local parts = {
    kit.part("lathe", { seg = 24, color = hull_c, uv = 0.5, points = {
      0.22 * R, -0.50 * H, 0.62 * R, -0.36 * H, 0.97 * R, -0.08 * H, 1.00 * R, -0.02 * H,
      0.92 * R, 0.06 * H, 0.46 * R, 0.12 * H } }),
    kit.part("ring", { c = { 0, -0.07 * H, 0 }, rin = 0.96 * R, r = 1.02 * R, h = 0.06 * H, seg = 24, color = rim_c }),
    kit.part("cylinder", { c = { 0, -0.56 * H, 0 }, r = 0.18 * R, h = 0.08 * H, seg = 12, color = { 0.3, 0.9, 1.0 },
                           emissive = 0.9 }),
    -- deck under the dome
    kit.part("cylinder", { c = { 0, 0.10 * H, 0 }, r = 0.43 * R, h = 0.03 * H, seg = 20, color = { 0.42, 0.44, 0.5 } }),
  }
  -- rim lights
  local light = { kit.part("box", { min = { -0.04 * R, -0.03 * H, 0.985 * R }, max = { 0.04 * R, 0.01 * H, 1.03 * R },
                                    color = { 1.0, 0.75, 0.3 }, emissive = 1 }) }
  parts = kit.merge(parts, kit.radial_array(light, 12))
  -- landing struts
  local strut = { kit.part("cone", { c = { 0, -0.62 * H, 0.45 * R }, r = 0.05 * R, r1 = 0.02 * R, h = 0.2 * H, seg = 6,
                                     color = rim_c }) }
  parts = kit.merge(parts, kit.radial_array(strut, 3, 0.5))
  -- the Villa carries a home under its dome: garden, pool, quarters
  if params.config == "villa" then
    parts = kit.merge(parts, {
      kit.part("cylinder", { c = { -0.15 * R, 0.13 * H, 0.1 * R }, r = 0.12 * R, h = 0.02 * H, color = { 0.25, 0.7, 0.3 } }),
      kit.part("box", { min = { 0.05 * R, 0.13 * H, -0.2 * R }, max = { 0.28 * R, 0.15 * H, 0.0 }, color = { 0.2, 0.5, 0.9 },
                        emissive = 0.4 }),
      kit.part("box", { min = { -0.3 * R, 0.13 * H, -0.28 * R }, max = { -0.08 * R, 0.24 * H, -0.12 * R },
                        color = { 0.9, 0.85, 0.75 } }),
      kit.part("cone", { c = { -0.15 * R, 0.15 * H, 0.1 * R }, r = 0.05 * R, r1 = 0, h = 0.2 * H, seg = 6,
                         color = { 0.2, 0.55, 0.25 } }),
    })
  end
  return { parts = parts }
end
