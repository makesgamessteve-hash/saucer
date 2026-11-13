-- SPDX-License-Identifier: MIT
-- Trader station: a ring habitat with spokes and a docking spire.
local kit = require("lib.meshkit")

return function(params, rng)
  local c = { 0.72, 0.66, 0.58 }
  local parts = {
    kit.part("ring", { rin = 34, r = 40, h = 8, seg = 32, color = c, uv = 0.25 }),
    kit.part("cylinder", { c = { 0, -10, 0 }, r = 8, h = 20, seg = 16, color = { 0.5, 0.5, 0.56 } }),
    kit.part("cone", { c = { 0, 10, 0 }, r = 6, r1 = 1, h = 22, seg = 12, color = { 0.6, 0.6, 0.66 } }),
    kit.part("sphere", { c = { 0, 34, 0 }, r = 2.5, h = 2.5, seg = 10, rings = 3, color = { 1, 0.4, 0.3 }, emissive = 1 }),
  }
  local spoke = { kit.part("box", { min = { -1.5, -1.5, 8 }, max = { 1.5, 1.5, 34 }, color = { 0.45, 0.45, 0.5 } }) }
  parts = kit.merge(parts, kit.radial_array(spoke, 4))
  local window = { kit.part("box", { min = { -2, -1, 39.8 }, max = { 2, 1, 40.4 }, color = { 1, 0.85, 0.5 },
                                     emissive = 1 }) }
  parts = kit.merge(parts, kit.radial_array(window, 16, rng:float() * 0.2))
  return { parts = parts }
end
