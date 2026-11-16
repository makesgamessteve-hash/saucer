-- SPDX-License-Identifier: MIT
-- The living room TV (OpenSpec add-holodeck-home-life). Channels are picked
-- up from trader stations and from alien stations and cities in range
-- (home/channels.lua). Every show comes with a gentle hint about the game
-- right now: where the next Echo hums, what traders pay for, which site is
-- guarded, what the lab or the kitchen could do. Watching (p.tv, transient):
-- you sit on the sofa, Use flips to the next channel, walking gets you up.
local data = require("lib.data")
local vec = require("lib.vec")
local M = {}

function M.channels() return data.load("home/channels.lua") end

local function site_center(state, i)
  local game = require("sim.game")
  local b = game.site_bounds(i)
  local s = state.sector.sites[i]
  if not b then return s.pos end
  return { (b[1][1] + b[2][1]) / 2, (b[1][2] + b[2][2]) / 2, (b[1][3] + b[2][3]) / 2 }
end

-- where a channel is broadcast from: the nearest source of its kind -> pos, dist
function M.source(state, ch, pos)
  local best, bd
  local function try(q)
    local d = vec.dist(q, pos)
    if not bd or d < bd then best, bd = q, d end
  end
  if ch.source == "trader" then
    for _, tr in ipairs(state.sector.traders or { state.sector.trader }) do try(tr.pos) end
  else
    for i, s in ipairs(state.sector.sites) do
      if s.kit == ch.source then try(site_center(state, i)) end
    end
  end
  return best, bd
end

-- channels this saucer picks up right now (in data order)
function M.received(state, p)
  local out = {}
  for _, ch in ipairs(M.channels()) do
    local _, d = M.source(state, ch, p.ship.pos)
    if d and d <= ch.range then out[#out + 1] = ch end
  end
  return out
end

local function minute(state) return state.tick // 3600 end

-- topic -> hint text (or nil when it has nothing to say right now)
M.TOPICS = {}
M.TOPICS.mystery = function(state, p)
  local m = state.mystery
  if m.mode == "off" or m.solved then return nil end
  local books = require("sim.books")
  return string.format("Rumor has it something hums inside site %d.", books.next_echo_site(m))
end
M.TOPICS.vault = function(state)
  local m = state.mystery
  if m.vault_revealed and not m.vault_open then return "Pilots report a sealed structure drifting in open space." end
  return nil
end
M.TOPICS.demand = function(state, p)
  local trade = require("sim.trade")
  local best, bd
  for _, cat in ipairs({ "curio", "module", "material", "tool" }) do
    for _, civ in ipairs(data.load("civs/civs.lua")) do
      local d = trade.demand(state, p.last_trader or 1, cat .. ":" .. civ.id)
      if not bd or d > bd + 1e-9 then best, bd = cat .. "s from " .. civ.name .. " sites", d end
    end
  end
  return "Traders pay well for " .. best .. " this week."
end
M.TOPICS.sentries = function(state, p)
  local game = require("sim.game")
  for i = 1, #state.sector.sites do
    local n = #game.sentries(i)
    if n > 0 and not (p.trails and p.trails[tostring(i)]) then
      return string.format("Watch out: %d sentries guard site %d. A Jammer pulse buys you 12 seconds.", n, i)
    end
  end
  return nil
end
M.TOPICS.lab = function(state, p)
  for _, it in ipairs(p.hold) do
    if not it.ident and not it.echo and not it.home then return "Tip: your lab bench identifies salvage while you fly." end
  end
  return nil
end
M.TOPICS.holo = function(state, p)
  for _, it in ipairs(p.hold) do
    if it.home and it.home.kind == "program" then return "Undecoded data core? A lab bench can read holo programs." end
    if it.home and it.home.kind == "module" then return "Holodeck modules install at the panel by its arch." end
  end
  return "New on the holodeck: programs from traders and from data cores in derelict vaults."
end
M.TOPICS.kitchen = function(state, p)
  local kitchen = require("sim.kitchen")
  local best
  for _, r in ipairs(kitchen.data().recipes) do
    if next(r.needs or {}) and kitchen.can_cook(p, r) then best = r end
  end
  if best then return "Tonight on Cooking Under the Stars: " .. best.name .. "." end
  return "Alien spices from derelict vaults make the best noodles."
end
M.TOPICS.finds = function(state, p)
  for i, s in ipairs(state.sector.sites) do
    if not (p.trails and p.trails[tostring(i)]) then
      return string.format("Old logs say the %s at site %d still has a full vault.", s.kit, i)
    end
  end
  return nil
end

-- what channel ch shows right now -> show title, hint text
-- what is on now: the show and hint tuned in, until the sim minute turns over
function M.now(state, p, ch)
  if p.tv and p.tv.k == minute(state) and p.tv.ch == ch.id and p.tv.show then return p.tv.show, p.tv.hint end
  return M.show(state, p, ch)
end

function M.show(state, p, ch)
  local k = minute(state)
  local show = ch.shows[k % #ch.shows + 1]
  local n = #ch.topics
  for j = 0, n - 1 do
    local topic = ch.topics[(k + j) % n + 1]
    local fn = M.TOPICS[topic]
    local h = fn and fn(state, p)
    if h then return show, h end
  end
  return show, "Static and soft music."
end

-- tune(state, p, idx, ctx): watch the idx-th received channel (the hint goes into the messages)
function M.tune(state, p, idx, ctx)
  local list = M.received(state, p)
  local ch = list[idx]
  if not ch then return false end
  local show, hint = M.show(state, p, ch)
  p.tv = { ch = ch.id, idx = idx, since = state.tick, k = minute(state), show = show, hint = hint }
  p.panel = false
  p.tv_hints = (p.tv_hints or 0) + 1
  p.last_hint = hint
  ctx.msg(state, p, string.format("%s - %s: %s", ch.name, show, hint))
  return true
end

-- Use while watching: the next channel, then off after the last one
function M.next(state, p, ctx)
  local idx = (p.tv and p.tv.idx or 0) + 1
  if idx > #M.received(state, p) then
    p.tv = false
    ctx.msg(state, p, "You switch the TV off.")
    return false
  end
  return M.tune(state, p, idx, ctx)
end

function M.current(state, p)
  if not p.tv then return nil end
  for _, ch in ipairs(M.channels()) do
    if ch.id == p.tv.ch then return ch end
  end
  return nil
end

function M.rows(state, p, ctx)
  local rows = {}
  for i, ch in ipairs(M.received(state, p)) do
    local _, d = M.source(state, ch, p.ship.pos)
    rows[#rows + 1] = { text = string.format("Watch %s (%s, %d km)", ch.name, ch.source, math.floor(d / 1000 + 0.5)),
      act = function(st, pl) M.tune(st, pl, i, ctx) end }
  end
  if #rows == 0 then rows[1] = { text = "No signal out here. Fly nearer a station or city.", enabled = false } end
  rows[#rows + 1] = { text = "Close", act = function(_, pl) pl.panel = false end }
  return rows
end

return M
