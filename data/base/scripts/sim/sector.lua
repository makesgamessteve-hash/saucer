-- SPDX-License-Identifier: MIT
-- Sector generation: derelict sites around the start and a trader station.
local data = require("lib.data")
local M = {}

M.SITES = 3

function M.generate(seed)
  local rng = saucer.rng.new(saucer.seed_child(seed, "sector", 0))
  local civs = data.load("civs/civs.lua")
  local sites = {}
  for i = 1, M.SITES do
    local pos
    if i == 1 then
      pos = { rng:int(-20, 20) - 96, -8, 150 + rng:int(0, 30) }
    else
      local a = saucer.math.tau * (i - 1) / M.SITES + rng:float() * 0.6
      local d = 420 + rng:int(0, 220)
      pos = { saucer.math.sin(a) * d // 1, rng:int(-40, 40), saucer.math.cos(a) * d // 1 }
    end
    sites[i] = {
      id = i, pos = pos, seed = saucer.seed_child(seed, "site", i),
      kit = (i == 2) and "station" or "starship", civ = rng:int(1, #civs),
    }
    -- the first derelict is the tutorial: a Velari hulk with a Cruiser-size hangar
    if i == 1 then sites[i].civ, sites[i].first = 1, 3 end
  end
  return { sites = sites, trader = { pos = { -260, 30, -140 } } }
end

return M
