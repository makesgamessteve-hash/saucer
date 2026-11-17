-- SPDX-License-Identifier: MIT
-- Hero mesh: station folk (OpenSpec add-pocket-station-visits). One recipe,
-- several species (station/folk.lua): params skin, suit, head ("round",
-- "dome", "stalk", "wide", "hood"), tall (overall scale), glow. Feet at the
-- origin, facing +z, about as tall as a person. Retro low-poly boxes.
local kit = require("lib.meshkit")
local P = kit.part

return function(params, rng)
  local skin = params.skin or { 0.95, 0.8, 0.65 }
  local suit = params.suit or { 0.3, 0.45, 0.7 }
  local dark = { suit[1] * 0.55, suit[2] * 0.55, suit[3] * 0.55 }
  local head = params.head or "round"
  local eye = params.glow and { 0.7, 0.9, 1.0 } or { 0.1, 0.1, 0.12 }
  local parts
  if head == "hood" then
    -- a long cloak, a deep hood and two red eyes in the dark
    parts = {
      P("cone", { c = { 0, 0, 0 }, r = 0.34, r1 = 0.2, h = 1.35, seg = 8, color = suit }),
      P("box", { min = { -0.27, 0.95, -0.09 }, max = { 0.27, 1.32, 0.09 }, color = dark }),
      P("sphere", { c = { 0, 1.5, 0 }, r = 0.2, h = 0.22, seg = 8, rings = 3, color = suit }),
      P("cone", { c = { 0, 1.62, -0.02 }, r = 0.16, r1 = 0.02, h = 0.26, seg = 6, color = suit }),
      P("box", { min = { -0.12, 1.4, 0.13 }, max = { 0.12, 1.6, 0.19 }, color = { 0.04, 0.03, 0.06 } }),
      P("box", { min = { -0.08, 1.5, 0.19 }, max = { -0.03, 1.53, 0.2 }, color = { 1, 0.2, 0.2 }, emissive = 1 }),
      P("box", { min = { 0.03, 1.5, 0.19 }, max = { 0.08, 1.53, 0.2 }, color = { 1, 0.2, 0.2 }, emissive = 1 }),
      P("box", { min = { -0.33, 0.7, 0.0 }, max = { -0.24, 1.25, 0.1 }, color = dark }),
      P("box", { min = { 0.24, 0.7, 0.0 }, max = { 0.33, 1.25, 0.1 }, color = dark }),
    }
  else
    parts = {
      P("box", { min = { -0.17, 0, -0.1 }, max = { -0.03, 0.78, 0.1 }, color = dark }),
      P("box", { min = { 0.03, 0, -0.1 }, max = { 0.17, 0.78, 0.1 }, color = dark }),
      P("box", { min = { -0.2, 0, 0.02 }, max = { -0.02, 0.08, 0.17 }, color = { 0.15, 0.13, 0.12 } }),
      P("box", { min = { 0.02, 0, 0.02 }, max = { 0.2, 0.08, 0.17 }, color = { 0.15, 0.13, 0.12 } }),
      P("box", { min = { -0.23, 0.78, -0.13 }, max = { 0.23, 1.4, 0.13 }, color = suit }),
      P("box", { min = { -0.24, 1.05, 0.13 }, max = { 0.24, 1.1, 0.14 }, color = dark }),
      P("box", { min = { -0.31, 0.82, -0.08 }, max = { -0.23, 1.38, 0.08 }, color = suit }),
      P("box", { min = { 0.23, 0.82, -0.08 }, max = { 0.31, 1.38, 0.08 }, color = suit }),
      P("box", { min = { -0.31, 0.74, -0.06 }, max = { -0.23, 0.82, 0.06 }, color = skin }),
      P("box", { min = { 0.23, 0.74, -0.06 }, max = { 0.31, 0.82, 0.06 }, color = skin }),
      P("box", { min = { -0.06, 1.4, -0.05 }, max = { 0.06, 1.47, 0.05 }, color = skin }),
    }
    if head == "dome" then
      parts[#parts + 1] = P("sphere", { c = { 0, 0, 0 }, r = 0.15, h = 0.15, seg = 8, rings = 4, color = skin,
                                        pos = { 0, 1.62, 0 }, scale = { 1, 1.45, 1 } })
      parts[#parts + 1] = P("box", { min = { -0.1, 1.6, 0.12 }, max = { -0.03, 1.64, 0.15 }, color = eye, emissive = params.glow and 1 or 0 })
      parts[#parts + 1] = P("box", { min = { 0.03, 1.6, 0.12 }, max = { 0.1, 1.64, 0.15 }, color = eye, emissive = params.glow and 1 or 0 })
    elseif head == "stalk" then
      parts[#parts + 1] = P("sphere", { c = { 0, 0, 0 }, r = 0.16, h = 0.13, seg = 8, rings = 3, color = skin,
                                        pos = { 0, 1.56, 0 }, scale = { 1.1, 0.8, 1 } })
      for _, x in ipairs({ -0.08, 0.08 }) do
        parts[#parts + 1] = P("cylinder", { c = { x, 1.62, 0.02 }, r = 0.018, h = 0.2, seg = 5, color = skin })
        parts[#parts + 1] = P("sphere", { c = { x, 1.84, 0.02 }, r = 0.045, h = 0.045, seg = 6, rings = 3, color = { 1, 0.95, 0.6 },
                                          emissive = 0.6 })
      end
    elseif head == "wide" then
      parts[#parts + 1] = P("box", { min = { -0.24, 1.46, -0.13 }, max = { 0.24, 1.72, 0.13 }, color = skin })
      for _, x in ipairs({ -0.17, -0.07, 0.07, 0.17 }) do
        parts[#parts + 1] = P("box", { min = { x - 0.025, 1.62, 0.13 }, max = { x + 0.025, 1.66, 0.14 }, color = { 1, 0.6, 0.2 },
                                       emissive = 1 })
      end
      parts[#parts + 1] = P("box", { min = { -0.12, 1.5, 0.13 }, max = { 0.12, 1.53, 0.14 }, color = dark })
    else
      parts[#parts + 1] = P("sphere", { c = { 0, 1.6, 0 }, r = 0.14, h = 0.16, seg = 8, rings = 3, color = skin })
      parts[#parts + 1] = P("box", { min = { -0.15, 1.66, -0.15 }, max = { 0.15, 1.76, 0.1 }, color = dark })
      parts[#parts + 1] = P("box", { min = { -0.08, 1.6, 0.12 }, max = { -0.03, 1.63, 0.14 }, color = eye })
      parts[#parts + 1] = P("box", { min = { 0.03, 1.6, 0.12 }, max = { 0.08, 1.63, 0.14 }, color = eye })
    end
  end
  local tall = params.tall or 1
  if tall ~= 1 then parts = kit.transform(parts, { scale = tall }) end
  return { parts = parts }
end
