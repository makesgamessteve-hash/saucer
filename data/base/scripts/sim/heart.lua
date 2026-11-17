-- SPDX-License-Identifier: MIT
-- The Heart site (concept §5.6; OpenSpec add-wider-dark): the last site of
-- the mystery, in the Heart sector at the far end of the galaxy's spine. Its
-- core is the middle of its vault hall. Bringing the Heart Key there opens
-- the Heart; every player inside the site then votes on an ending at the
-- core (a panel opens for them there). When everyone present has voted the
-- ending is applied to the universe (sim/mystery.lua M.effect) and everyone
-- present gets the centerpiece.
local vec = require("lib.vec")
local mystery = require("sim.mystery")
local items = require("sim.items")
local panel = require("sim.panel")
local M = {}

M.CORE_RANGE = 45

local function game() return require("sim.game") end

-- index of the Heart site in the current sector, or nil
function M.site(state)
  for i, s in ipairs(state.sector.sites) do
    if s.heart then return i end
  end
  return nil
end

-- the core: the middle of the Heart site's vault hall
function M.core(state)
  local i = M.site(state)
  if not i then return nil end
  local ruin = game().ruin(i)
  if not ruin then return nil end
  local ruinm = require("sim.ruin")
  local kit = ruinm.kit_of(ruin.kit)
  local origin = state.sector.sites[i].pos
  for _, r in ipairs(ruin.rooms) do
    if r.kind == "vault" then
      local mn, mx = ruinm.room_box(r, kit, origin)
      return { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }, i, r.id
    end
  end
  local mn, mx = ruinm.room_box(ruin.rooms[#ruin.rooms], kit, origin)
  return { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }, i, ruin.rooms[#ruin.rooms].id
end

local function key_item(state, p)
  local ki = mystery.index_of(state.mystery, "heart_key")
  for _, it in ipairs(p.hold) do
    if it.echo and it.echo == ki then return it end
  end
  return nil
end
M.key_item = key_item

function M.present(state)
  local i = M.site(state)
  local out = {}
  for _, p in ipairs(state.players) do
    if i and p.site == i then out[#out + 1] = p.index end
  end
  return out
end

function M.near_core(state, p)
  local core, i = M.core(state)
  return core ~= nil and p.site == i and vec.dist(p.ship.pos, core) <= M.CORE_RANGE
end

function M.step(state, ctx)
  local m = state.mystery
  if not m.heart_sector or (state.sector_id or 1) ~= m.heart_sector or m.ending or not mystery.active(m) then return end
  for _, p in ipairs(state.players) do
    if M.near_core(state, p) and p.mode ~= "foot" then
      local key = key_item(state, p)
      if not m.heart_open and key and m.act >= 3 then
        items.remove(p, key.uid)
        mystery.open_heart(m, p.index)
        for _, o in ipairs(state.players) do
          ctx.msg(state, o, string.format("P%d set the Heart Key in its lock. The Heart opens.", p.index))
          ctx.msg(state, o, "Everyone inside the Heart site: vote on an ending at the core")
          ctx.fx(state, o, "echo")
        end
      end
      if m.heart_open and not m.votes[tostring(p.index)] and not p.panel then panel.open(p, "heart") end
    end
  end
  if m.heart_open then
    local id = mystery.tally(m, M.present(state))
    if id then M.resolve(state, id, ctx) end
  end
end

function M.resolve(state, id, ctx)
  local m = state.mystery
  if not mystery.finish(m, id) then return false end
  local e = mystery.ending_of(m, id)
  local present = {}
  for _, pi in ipairs(M.present(state)) do present[pi] = true end
  for _, p in ipairs(state.players) do
    if p.panel and p.panel.kind == "heart" then p.panel = false end
    ctx.msg(state, p, "ENDING: " .. e.title .. ". " .. e.text)
    ctx.fx(state, p, "echo")
    require("sim.books").add(p, "ending")
    if present[p.index] then
      local it = items.stamp(p, mystery.centerpiece(m), 5, nil)
      it.hot = false
      p.hold[#p.hold + 1] = it
      ctx.msg(state, p, "You carry the " .. it.name .. " home")
    end
  end
  saucer.events.emit({ type = "ending", ending = id })
  return true
end

function M.rows(state, p)
  local m = state.mystery
  local rows = {}
  local mine = m.votes[tostring(p.index)]
  for _, e in ipairs(m.endings) do
    local id = e.id
    rows[#rows + 1] = { text = (mine == id and "* " or "") .. e.title .. ": " .. e.text, act = function(st, pl)
      mystery.vote(st.mystery, pl.index, id)
      pl.panel = false
    end }
  end
  local n, total = 0, #M.present(state)
  for _ in pairs(m.votes) do n = n + 1 end
  rows[#rows + 1] = { text = string.format("Votes: %d of %d present", n, total), enabled = false }
  rows[#rows + 1] = { text = "Close (vote later at the core)", act = function(_, pl) pl.panel = false end }
  return rows
end

return M
