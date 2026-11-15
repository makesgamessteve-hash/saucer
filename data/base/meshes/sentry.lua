-- SPDX-License-Identifier: MIT
-- Milestone 3 props, all code-generated: the Watcher ceiling turret, the
-- small duct-crawling Snatcher, a Snatcher's nest and the Resonant vault
-- monolith (params.kind). Local +z is "forward" (where a Watcher looks).
local kit = require("lib.meshkit")

local GREY, DARK, GLOW = { 0.5, 0.52, 0.58 }, { 0.22, 0.23, 0.28 }, { 1.0, 0.95, 0.7 }

local function watcher()
  return {
    kit.part("cylinder", { c = { 0, 1.2, 0 }, r = 0.35, h = 1.8, seg = 8, color = DARK }),
    kit.part("cylinder", { c = { 0, 2.6, 0 }, r = 1.4, h = 0.25, seg = 12, color = GREY }),
    kit.part("sphere", { c = { 0, 0, 0 }, r = 1.25, h = 1.25, seg = 14, rings = 4, color = GREY }),
    kit.part("ring", { c = { 0, -0.1, 0 }, rin = 1.2, r = 1.45, h = 0.2, seg = 14, color = DARK }),
    -- the lens looks along +z
    kit.part("box", { min = { -0.45, -0.35, 0.9 }, max = { 0.45, 0.35, 1.55 }, color = DARK }),
    kit.part("box", { min = { -0.3, -0.22, 1.5 }, max = { 0.3, 0.22, 1.62 }, color = GLOW, emissive = 1 }),
  }
end

local function snatcher()
  local parts = {
    kit.part("sphere", { c = { 0, 0, 0 }, r = 0.5, h = 0.38, seg = 10, rings = 3, color = { 0.45, 0.4, 0.5 } }),
    kit.part("box", { min = { -0.18, 0.05, 0.38 }, max = { 0.18, 0.2, 0.52 }, color = GLOW, emissive = 1 }),
  }
  -- four grabbing arms
  for _, s in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
    parts[#parts + 1] = kit.part("box", { min = { s[1] * 0.35 - 0.06, -0.45, s[2] * 0.35 - 0.06 },
                                          max = { s[1] * 0.35 + 0.06, -0.05, s[2] * 0.35 + 0.06 }, color = DARK })
    parts[#parts + 1] = kit.part("box", { min = { s[1] * 0.55 - 0.05, -0.55, s[2] * 0.55 - 0.05 },
                                          max = { s[1] * 0.55 + 0.05, -0.35, s[2] * 0.55 + 0.05 }, color = DARK })
  end
  return parts
end

local function nest()
  return {
    kit.part("ring", { c = { 0, -0.5, 0 }, rin = 0.7, r = 1.1, h = 0.35, seg = 10, color = { 0.4, 0.33, 0.25 } }),
    kit.part("cone", { c = { 0, -0.5, 0 }, r = 0.75, r1 = 0.2, h = 0.4, seg = 8, color = { 0.33, 0.28, 0.22 } }),
  }
end

-- a tall split monolith; params.open slides the halves apart
local function vault(open)
  local g = (open or 0) * 3.0
  local parts = {}
  for _, s in ipairs({ -1, 1 }) do
    local x0, x1 = s < 0 and -4 - g or 0.15 + g, s < 0 and -0.15 - g or 4 + g
    parts[#parts + 1] = kit.part("box", { min = { x0, -9, -1.5 }, max = { x1, 9, 1.5 }, color = { 0.12, 0.1, 0.2 } })
    parts[#parts + 1] = kit.part("box", { min = { s < 0 and x1 - 0.25 or x0, -8, -1.55 },
      max = { s < 0 and x1 or x0 + 0.25, 8, 1.55 }, color = { 0.75, 0.5, 1.0 }, emissive = 1 })
  end
  parts[#parts + 1] = kit.part("ring", { c = { 0, -9.5, 0 }, rin = 5, r = 6.5, h = 0.6, seg = 16,
                                         color = { 0.5, 0.35, 0.8 }, emissive = 0.4 })
  return parts
end

return function(params, _rng)
  local k = params.kind or "watcher"
  if k == "snatcher" then return { parts = snatcher() } end
  if k == "nest" then return { parts = nest() } end
  if k == "vault" then return { parts = vault(params.open) } end
  return { parts = watcher() }
end
