-- SPDX-License-Identifier: MIT
-- Milestone 3 props, all code-generated: a Snatcher's nest and the Resonant
-- vault monolith (params.kind). The Watcher and the Snatcher have recipes of
-- their own (meshes/watcher.lua, meshes/snatcher.lua, with named nodes and
-- collision); kind = "watcher" / "snatcher" here still builds them.
local kit = require("lib.meshkit")


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

return function(params, rng)
  local k = params.kind or "watcher"
  if k == "snatcher" then return require("lib.data").load("meshes/snatcher.lua")(params, rng) end
  if k == "nest" then return { parts = nest() } end
  if k == "vault" then return { parts = vault(params.open) } end
  return require("lib.data").load("meshes/watcher.lua")(params, rng)
end
