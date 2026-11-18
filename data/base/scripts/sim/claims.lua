-- SPDX-License-Identifier: MIT
-- Shared-object claims (OpenSpec add-multiplayer-foundation 1.6). Per-player loot is rolled once per
-- player, so two people can both take "the same" slot. A SHARED object exists once: an Echo, the
-- Resonant vault's Curio, a gifted item, a twin vault and its shutter anchor. The first completed
-- pickup claims it. When two or more players complete a pull of the same shared object on the same tick,
-- the one with the lowest (record_index + tick) mod n wins and the others are told they were beaten to
-- it (their beam lets go; nothing is taken from them). The winner and the tick are written to
-- state.claims[key] = { by = player index, tick = n }, which exists only after a contest, so a game
-- where nobody races for anything is unchanged.
local M = {}

M.SHARED = { echo = true, curio = true, gift = true, twin = true, anchor = true }

function M.is_shared(kind) return M.SHARED[kind] == true end

-- the winner of a same-tick tie among players (a list of players) at `tick` with n players in the game
function M.winner(players, tick, n)
  local best, bv
  for _, p in ipairs(players) do
    local v = (p.record_index + tick) % n
    if not bv or v < bv or (v == bv and p.record_index < best.record_index) then best, bv = p, v end
  end
  return best
end

-- does p's beam finish this tick? (a pull in progress on a shared find)
local function finishing(p, dt)
  local t = p.tractor
  return t and t.key and M.is_shared(t.kind) and t.t + dt >= t.total - 1e-9
end

-- resolve(state, dt, ctx): called once at the start of a tick, before anyone steps
function M.resolve(state, dt, ctx)
  local n = #state.players
  if n < 2 then return end
  local by_key
  for _, p in ipairs(state.players) do
    if finishing(p, dt) then
      by_key = by_key or {}
      local k = p.tractor.site .. "|" .. p.tractor.key
      by_key[k] = by_key[k] or {}
      table.insert(by_key[k], p)
    end
  end
  if not by_key then return end
  local keys = {}
  for k in pairs(by_key) do keys[#keys + 1] = k end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local list = by_key[k]
    if #list > 1 then
      local w = M.winner(list, state.tick, n)
      state.claims = state.claims or {}
      state.claims[k] = { by = w.index, tick = state.tick }
      for _, p in ipairs(list) do
        if p ~= w then
          p.tractor = false
          ctx.msg(state, p, string.format("P%d got there first: the beam lets go", w.index))
          ctx.fx(state, p, "denied")
        end
      end
      ctx.msg(state, w, "You claimed it: another beam was on it the same moment")
    end
  end
end

-- has someone else claimed this object (by a contest)? -> player index or nil
function M.claimed_by(state, site, key)
  local c = state.claims and state.claims[site .. "|" .. key]
  return c and c.by or nil
end

return M
