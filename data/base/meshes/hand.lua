-- SPDX-License-Identifier: MIT
-- Hero mesh: your own hand, palm up, as seen holding the pocketed saucer
-- (OpenSpec add-pocket-station-visits). Origin at the middle of the palm,
-- fingers toward +z, the sleeve running back toward -z.
local kit = require("lib.meshkit")
local P = kit.part

return function(params, rng)
  local skin = params.skin or { 0.95, 0.78, 0.62 }
  local sleeve = params.sleeve or { 0.9, 0.55, 0.2 }
  local parts = {
    P("box", { min = { -0.042, -0.012, -0.045 }, max = { 0.042, 0.008, 0.045 }, color = skin }),
    P("box", { min = { -0.045, -0.026, -0.12 }, max = { 0.045, 0.016, -0.06 }, color = sleeve }),
    P("box", { min = { -0.052, -0.032, -0.07 }, max = { 0.052, 0.022, -0.05 }, color = { sleeve[1] * 0.6, sleeve[2] * 0.6, sleeve[3] * 0.6 } }),
    P("box", { min = { -0.04, -0.02, -0.06 }, max = { 0.04, 0.0, -0.04 }, color = skin }),
  }
  -- four fingers curling up at the tips, and the thumb off to the side
  for i, x in ipairs({ -0.03, -0.01, 0.01, 0.03 }) do
    local l = (i == 1 or i == 4) and 0.035 or 0.045
    parts[#parts + 1] = P("box", { min = { x - 0.009, -0.008, 0.045 }, max = { x + 0.009, 0.006, 0.045 + l }, color = skin })
    parts[#parts + 1] = P("box", { min = { x - 0.008, 0.004, 0.04 + l }, max = { x + 0.008, 0.022, 0.05 + l }, color = skin })
  end
  parts[#parts + 1] = P("box", { min = { 0.042, -0.006, -0.02 }, max = { 0.075, 0.01, 0.0 }, color = skin, yaw = 0.0 })
  parts[#parts + 1] = P("box", { min = { 0.064, 0.0, -0.02 }, max = { 0.08, 0.02, 0.012 }, color = skin })
  return { parts = parts }
end
