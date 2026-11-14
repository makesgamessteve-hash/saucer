-- SPDX-License-Identifier: MIT
-- Hero mesh: the player's on-foot body (seen in the chase view and by other
-- players). Feet at the origin, facing +z.
local kit = require("lib.meshkit")
local P = kit.part

return function(params, rng)
  local suit = params.color or { 0.9, 0.55, 0.2 }
  return { parts = {
    P("box", { min = { -0.17, 0, -0.1 }, max = { -0.03, 0.8, 0.1 }, color = { 0.25, 0.27, 0.35 } }),
    P("box", { min = { 0.03, 0, -0.1 }, max = { 0.17, 0.8, 0.1 }, color = { 0.25, 0.27, 0.35 } }),
    P("box", { min = { -0.22, 0.8, -0.13 }, max = { 0.22, 1.42, 0.13 }, color = suit }),
    P("box", { min = { -0.3, 0.85, -0.08 }, max = { -0.22, 1.4, 0.08 }, color = suit }),
    P("box", { min = { 0.22, 0.85, -0.08 }, max = { 0.3, 1.4, 0.08 }, color = suit }),
    P("sphere", { c = { 0, 1.6, 0 }, r = 0.14, h = 0.16, seg = 8, rings = 3, color = { 0.95, 0.8, 0.65 } }),
    P("box", { min = { -0.1, 1.58, 0.1 }, max = { 0.1, 1.64, 0.14 }, color = { 0.3, 0.9, 1.0 }, emissive = 1 }),
  } }
end
