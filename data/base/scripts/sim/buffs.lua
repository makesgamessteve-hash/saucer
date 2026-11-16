-- SPDX-License-Identifier: MIT
-- Timed buffs from home comforts (OpenSpec add-holodeck-home-life): a meal,
-- a pot of tea, an hour on the holodeck beach. p.buffs = { id -> until tick }
-- (saved). factor(state, p, stat) multiplies every active buff's stat.
local data = require("lib.data")
local M = {}

M.TICKS_PER_MINUTE = 60 * 60

function M.defs() return data.load("home/buffs.lua") end

function M.active(state, p, id)
  return ((p.buffs or {})[id] or 0) > state.tick
end

-- give(state, p, id, minutes): starts or extends a buff (never shortens it)
function M.give(state, p, id, minutes)
  if not M.defs()[id] then return false end
  p.buffs = p.buffs or {}
  local til = state.tick + math.floor(minutes * M.TICKS_PER_MINUTE)
  if til > (p.buffs[id] or 0) then p.buffs[id] = til end
  return true
end

function M.factor(state, p, stat)
  local f = 1
  local defs = M.defs()
  for _, id in ipairs(saucer.util.sorted_keys(p.buffs or {})) do
    local d = defs[id]
    if d and M.active(state, p, id) and d.stats[stat] then f = f * d.stats[stat] end
  end
  return f
end

-- active buffs as { id, name, left (seconds) }, sorted by id (the HUD lists them)
function M.list(state, p)
  local out = {}
  local defs = M.defs()
  for _, id in ipairs(saucer.util.sorted_keys(p.buffs or {})) do
    if defs[id] and M.active(state, p, id) then
      out[#out + 1] = { id = id, name = defs[id].name, left = (p.buffs[id] - state.tick) / 60 }
    end
  end
  return out
end

return M
