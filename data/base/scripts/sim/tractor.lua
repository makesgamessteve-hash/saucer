-- SPDX-License-Identifier: MIT
-- Tractor beam (concept §6.2): lock the nearest visible loot in a cone in
-- front of the saucer; the item's size class must not exceed the current
-- saucer's tractor class. Locking takes LOCK_TIME seconds.
-- Targets: this player's loot instances, the next Echo of the mystery, items
-- a Snatcher left in its nest, Fold Retreat caches, and (in open space) the
-- unique Curio of an opened Resonant vault.
local vec = require("lib.vec")
local data = require("lib.data")
local configs = require("sim.config")
local loot = require("sim.loot")
local mystery = require("sim.mystery")
local M = {}

M.CONE = 0.82
M.LOCK_TIME = 0.5

local function civ_id(state, site_idx)
  local site = state.sector.sites[site_idx]
  local civ = site and data.load("civs/civs.lua")[site.civ]
  return civ and civ.id or nil
end

-- candidates(state, p, site, ruin) -> list of {key, kind, pos, item, echo, room}
function M.candidates(state, p, site_idx, ruin)
  local out = {}
  if ruin then
    local civ = civ_id(state, site_idx)
    for _, s in ipairs(ruin.slots) do
      local key = site_idx .. ":" .. s.id
      if not p.looted[key] then
        local item = loot.roll(loot.instance_seed(s.seed, p.record_index), s.max_size, s.tier)
        item.tier, item.civ = s.tier, civ
        out[#out + 1] = { key = key, kind = "slot", pos = s.pos, room = s.room, item = item }
      end
    end
    local echo = mystery.echo_at(state.mystery, site_idx)
    if echo then
      for _, r in ipairs(ruin.rooms) do
        if r.echo_pos then
          out[#out + 1] = { key = "echo:" .. echo, kind = "echo", pos = r.echo_pos, echo = echo, room = r.id,
            item = mystery.item(state.mystery, echo) }
        end
      end
    end
  end
  for i, n in ipairs(state.nests or {}) do
    if n.site == site_idx and n.owner == p.record_index then
      out[#out + 1] = { key = "nest:" .. i, kind = "nest", index = i, pos = n.pos, item = n.item }
    end
  end
  for i, c in ipairs(state.caches or {}) do
    if c.site == site_idx and c.owner == p.record_index and #c.items > 0 then
      out[#out + 1] = { key = "cache:" .. i, kind = "cache", index = i, pos = c.pos,
        item = { name = string.format("Cache (%d item%s)", #c.items, #c.items == 1 and "" or "s"), size = 1, value = 0,
                 type = "cache", ident = true } }
    end
  end
  local v = state.vault
  if site_idx == 0 and v and state.mystery.vault_open and not v.taken then
    out[#out + 1] = { key = "vault:curio", kind = "curio", pos = { v.pos[1], v.pos[2] + 2, v.pos[3] },
      item = mystery.curio(state.mystery) }
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
