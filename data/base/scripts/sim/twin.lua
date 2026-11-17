-- SPDX-License-Identifier: MIT
-- Two-saucer finds (OpenSpec add-playtest-recs, playtest recommendation 9):
-- in co-op every derelict with room for two hulls keeps one twin vault. Its
-- shutter only opens while a partner holds the shutter anchor: one saucer
-- beams the anchor (it stays where it is: the beam latches it) and hovers
-- near it; while it does, the other saucer can beam up the vault. Both get a
-- prize. Layout is derived from the ruin (not saved); state.twins holds the
-- live hold and whether the vault is taken (per sector, stashed on a fold).
local vec = require("lib.vec")
local loot = require("sim.loot")
local M = {}

M.MIN_GAP = 30     -- metres between the anchor and the vault (two Villas fit)
M.HOLD_RANGE = 55  -- the holder must stay this close to the anchor
M.TIER_BONUS = 2   -- the prize is this many tiers above the vault's slot

local function game() return require("sim.game") end

-- active at all? (two or more players in the game)
function M.on(state) return #(state.players or {}) >= 2 end

-- layout(ruin) -> { vault = slot, anchor = slot } or nil (derived, cached)
local memo = setmetatable({}, { __mode = "k" })
function M.layout(ruin)
  if not ruin then return nil end
  local c = memo[ruin]
  if c ~= nil then return c or nil end
  local best
  for _, s in ipairs(ruin.slots or {}) do
    if not s.strong and (not best or s.tier > best.tier) then best = s end
  end
  local anchor, ad
  if best then
    for _, s in ipairs(ruin.slots) do
      if s ~= best and not s.strong then
        local dx, dz = s.pos[1] - best.pos[1], s.pos[3] - best.pos[3]
        local d = dx * dx + dz * dz
        if d >= M.MIN_GAP * M.MIN_GAP and (not ad or d < ad) then anchor, ad = s, d end
      end
    end
  end
  c = (best and anchor) and { vault = best, anchor = anchor } or false
  memo[ruin] = c
  return c or nil
end

function M.key(site) return tostring(site) end

function M.entry(state, site)
  state.twins = state.twins or {}
  local k = M.key(site)
  state.twins[k] = state.twins[k] or { done = false, by = 0 }
  return state.twins[k]
end

function M.anchor_pos(L) return { L.anchor.pos[1], L.anchor.pos[2] + 1.5, L.anchor.pos[3] } end

-- the player holding the anchor of `site` (still close enough), or nil
function M.holder(state, site)
  local e = state.twins and state.twins[M.key(site)]
  if not e or (e.by or 0) == 0 then return nil end
  local h = state.players[e.by]
  local L = M.layout(game().ruin(site))
  if not h or not L or h.site ~= site or h.mode == "foot" then return nil end
  if vec.dist(h.ship.pos, M.anchor_pos(L)) > M.HOLD_RANGE then return nil end
  return h
end

-- is the vault open for p (a partner holds the anchor)?
function M.open_for(state, site, p)
  local h = M.holder(state, site)
  return h ~= nil and h ~= p
end

function M.prize(state, site, L, owner_index)
  local s = L.vault
  local item = loot.roll(saucer.seed_child(s.seed, "twin", owner_index), 1, math.min(5, s.tier + M.TIER_BONUS))
  item.tier = math.min(5, s.tier + M.TIER_BONUS)
  item.twin = true
  return item
end

-- tractor candidates for p at site (co-op only)
function M.candidates(state, p, site, ruin)
  if not M.on(state) or site == 0 then return {} end
  local L = M.layout(ruin)
  if not L then return {} end
  local e = state.twins and state.twins[M.key(site)]
  if e and e.done then return {} end
  local out = {}
  local held = e and (e.by or 0) == p.index and M.holder(state, site) == p
  if not held then
    out[#out + 1] = { key = "anchor:" .. site, kind = "anchor", pos = M.anchor_pos(L), room = L.anchor.room,
      item = { name = "Shutter anchor", type = "anchor", size = 1, value = 0, ident = true } }
  end
  local v = L.vault
  out[#out + 1] = { key = "twin:" .. site, kind = "twin", pos = { v.pos[1], v.pos[2] + 0.5, v.pos[3] }, room = v.room,
    sealed = not M.open_for(state, site, p),
    item = { name = "Twin vault", type = "twin", size = 1, value = 0, ident = true } }
  return out
end

-- the anchor was beamed: p holds the shutter open while it stays close
function M.hold(state, p, site, ctx)
  local e = M.entry(state, site)
  e.by = p.index
  ctx.msg(state, p, "You hold the shutter anchor. Stay close: a partner can now beam up the twin vault.")
  for _, o in ipairs(state.players) do
    if o ~= p then
      ctx.msg(state, o, string.format("P%d holds the twin vault open at site %d - beam it up!", p.index, site))
      ctx.fx(state, o, "scan")
    end
  end
  return e
end

-- the vault was beamed up by p: a prize each for p and the holder
function M.take(state, p, site, ctx)
  local e = M.entry(state, site)
  local L = M.layout(game().ruin(site))
  local h = M.holder(state, site)
  if e.done or not L or not h or h == p then
    ctx.msg(state, p, "The twin vault's shutter fell shut before it came up.")
    return false
  end
  e.done, e.by = true, 0
  local items = require("sim.items")
  local civ = game().civ_of(state.sector.sites[site])
  local got = {}
  for _, who in ipairs({ p, h }) do
    local it = items.stamp(who, M.prize(state, site, L, who.record_index), math.min(5, L.vault.tier + M.TIER_BONUS),
      civ and civ.id)
    it.hot = true
    if #who.hold < require("sim.upgrades").hold_slots(who) then
      who.hold[#who.hold + 1] = it
    else
      state.gifts = state.gifts or {}
      state.gifts[#state.gifts + 1] = { pos = vec.copy(who.ship.pos), item = it, to = who.index, from = 0, site = site }
    end
    who.twins = (who.twins or 0) + 1
    got[#got + 1] = it
    ctx.msg(state, who, "Twin vault open: " .. items.label(it) .. " for you")
    ctx.fx(state, who, "echo")
  end
  return true, got
end

-- per tick: a holder who drifted away lets the shutter fall
function M.step(state, ctx)
  if not state.twins then return end
  for site = 1, #state.sector.sites do
    local e = state.twins[M.key(site)]
    if e and (e.by or 0) > 0 and not e.done and not M.holder(state, site) then
      local h = state.players[e.by]
      e.by = 0
      if h then ctx.msg(state, h, "You let go of the shutter anchor: the twin vault closes.") end
    end
  end
end

return M
