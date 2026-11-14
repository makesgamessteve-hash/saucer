-- SPDX-License-Identifier: MIT
-- Tractor beam (concept §6.2): lock the nearest visible loot in a cone in
-- front of the saucer; the item's size class must not exceed the current
-- saucer's tractor class. Locking takes LOCK_TIME seconds.
local vec = require("lib.vec")
local configs = require("sim.config")
local loot = require("sim.loot")
local mystery = require("sim.mystery")
local M = {}

M.CONE = 0.82
M.LOCK_TIME = 0.5

-- candidates(state, p, site, ruin) -> list of {key, pos, item, echo}
function M.candidates(state, p, site_idx, ruin)
  local out = {}
  if not ruin then return out end
  for _, s in ipairs(ruin.slots) do
    local key = site_idx .. ":" .. s.id
    if not p.looted[key] then
      out[#out + 1] = { key = key, pos = s.pos, room = s.room,
        item = loot.roll(loot.instance_seed(s.seed, p.record_index), s.max_size, s.tier) }
    end
  end
  local echo = mystery.echo_at(state.mystery, site_idx)
  if echo then
    for _, r in ipairs(ruin.rooms) do
      if r.echo_pos then
        out[#out + 1] = { key = "echo:" .. echo, pos = r.echo_pos, echo = echo, room = r.id,
          item = { name = "Echo " .. echo, size = 1, value = 0, type = "echo", rarity = "relic" } }
      end
    end
  end
  return out
end

-- best target in the cone (nearest), or nil. eye/yaw/pitch: where the
-- player looks from (the helm or the body under the dome); default: the hull.
function M.find(state, p, site_idx, ruin, eye, yaw, pitch)
  local ship = p.ship
  local c = configs.get(ship.size)
  eye = eye or ship.pos
  local dir = vec.aim(yaw or ship.yaw, pitch or ship.pitch)
  local best, bd
  for _, cand in ipairs(M.candidates(state, p, site_idx, ruin)) do
    local d = vec.dist(cand.pos, eye)
    if saucer.physics.cone_visible(eye, dir, M.CONE, c.tractor_range, cand.pos, 1) and (not bd or d < bd) then
      best, bd = cand, d
    end
  end
  return best
end

-- can this saucer lift it?
function M.can_lift(ship, item)
  return item.size <= configs.get(ship.size).tractor_class
end

return M
