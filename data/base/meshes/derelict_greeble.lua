-- SPDX-License-Identifier: MIT
-- Exterior dressing for a derelict room: antenna masts and hull ribs.
local kit = require("lib.meshkit")

return function(params, rng)
  local w, d, top = params.w or 8, params.d or 8, params.top or 4
  local parts = {}
  local n = rng:int(1, 3)
  for i = 1, n do
    local x, z = (rng:float() - 0.5) * w * 0.8, (rng:float() - 0.5) * d * 0.8
    parts[#parts + 1] = kit.part("cylinder", { c = { x, top, z }, r = 0.15, h = 2 + rng:float() * 5, seg = 6,
                                               color = { 0.4, 0.4, 0.45 } })
    parts[#parts + 1] = kit.part("box", { min = { x - 0.25, top + 1.5, z - 0.25 }, max = { x + 0.25, top + 1.9, z + 0.25 },
                                          color = { 1, 0.3, 0.2 }, emissive = rng:int(0, 1) })
  end
  local rib = { kit.part("box", { min = { -w / 2 - 0.3, top, -0.4 }, max = { w / 2 + 0.3, top + 0.6, 0.4 },
                                  color = { 0.35, 0.36, 0.4 } }) }
  parts = kit.merge(parts, kit.linear_array(kit.transform(rib, { pos = { 0, 0, -d / 2 + 1 } }), 2, { 0, 0, d - 2 }))
  return { parts = parts }
end
