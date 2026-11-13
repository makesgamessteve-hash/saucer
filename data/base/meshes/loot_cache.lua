-- SPDX-License-Identifier: MIT
-- A small floating relic cache drawn under each loot sprite.
local kit = require("lib.meshkit")

return function(params, rng)
  local s = params.size or 1
  return { parts = {
    kit.part("cone", { c = { 0, -0.5 * s, 0 }, r = 0.0, r1 = 0.45 * s, h = 0.5 * s, seg = 6,
                       color = { 0.6, 0.55, 0.9 }, emissive = 0.3 }),
    kit.part("cone", { c = { 0, 0, 0 }, r = 0.45 * s, r1 = 0.0, h = 0.5 * s, seg = 6, color = { 0.7, 0.65, 1.0 },
                       emissive = 0.3 }),
  } }
end
