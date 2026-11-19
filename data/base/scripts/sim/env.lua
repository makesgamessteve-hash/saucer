-- SPDX-License-Identifier: MIT
-- What the air is like where a saucer or a person is (OpenSpec
-- add-dock-land-eva): breathable, vacuum or toxic, the pull of gravity and
-- the temperature. Pure functions of the sector, never stored.
--   open space and derelict hulls: vacuum, no pull
--   a planet city: toxic air, 1.2 g;  a moon city: vacuum, 0.16 g;  an asteroid city: vacuum, no pull
--   a trader station's hangar: air, 1 g
local M = {}

M.AIR = { name = "air", breathable = true, vacuum = false, toxic = false, g = 1.0, temp = 21, rad = 0 }
M.VACUUM = { name = "vacuum", breathable = false, vacuum = true, toxic = false, g = 0.0, temp = -60, rad = 0.2 }

local BODY = {
  planet = { name = "toxic air", breathable = false, vacuum = false, toxic = true, g = 1.2, temp = 48, rad = 0.1 },
  moon = { name = "vacuum", breathable = false, vacuum = true, toxic = false, g = 0.16, temp = -85, rad = 0.35 },
  asteroid = { name = "vacuum", breathable = false, vacuum = true, toxic = false, g = 0.02, temp = -120, rad = 0.5 },
}

local function copy(t)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  return r
end

-- the environment at a site (0 = open space)
function M.of_site(site)
  if not site or site == 0 then return copy(M.VACUUM) end
  local game = require("sim.game")
  local ruin = game.ruin(site)
  local cities = require("sim.cities")
  if ruin and cities.is_city(ruin) then
    return copy(BODY[ruin.city.body] or BODY.planet)
  end
  return copy(M.VACUUM)
end

-- the environment for player p right now: a station hangar has air
function M.at(state, p)
  if p.station or (p.berth and p.berth.kind == "bay") then return copy(M.AIR) end
  return M.of_site(p.site)
end

function M.breathable(state, p) return M.at(state, p).breathable end

return M
