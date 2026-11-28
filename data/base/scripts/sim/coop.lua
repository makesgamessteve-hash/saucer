-- SPDX-License-Identifier: MIT
-- Local co-op (concept §3.6; OpenSpec add-wider-dark): up to four players,
-- each in their own saucer, share one sector.
--   * Join: a command frame for a player slot that is not in the game yet
--     joins it on its first button press (the engine claims a gamepad on A,
--     the right half of the keyboard on F2). The new saucer arrives beside
--     player 1 (or at the sector's arrival point) and its pilot wakes up.
--   * Gifting: eject an item from your hold under your belly, for one player
--     or for anyone. It is beamed up like loot; whoever beams it up owns it
--     (hot if they are inside a site).
--   * Docking and dome visits: two Villas in open space within DOCK_RANGE
--     dock when both agree. A guest then walks into the host's dome (the host's
--     doors open for them) and can hand items over at the gift table, but
--     cannot use the host's lab, helm, bed or terminal. Undocking (or a fold
--     jump) sends every guest back to their own helm.
-- Plain data in the state: p.visiting, p.vbody, state.docks, state.gifts.
local vec = require("lib.vec")
local items = require("sim.items")
local avatar = require("sim.avatar")
local configs = require("sim.config")
local M = {}

M.DOCK_RANGE = 90
M.JOIN_BUTTONS = { "use", "menu", "tractor", "grow", "shrink" }

local function game() return require("sim.game") end

function M.wants_join(cmd)
  for _, b in ipairs(M.JOIN_BUTTONS) do
    if cmd:pressed(b) then return true end
  end
  return false
end

-- a clear spot for a new saucer beside player 1
function M.spawn_spot(state, idx)
  local g = game()
  local p1 = state.players[1]
  local r, hh = require("sim.ship").dims_of(1)
  local base = p1 and p1.site == 0 and p1.mode ~= "foot" and p1.ship.pos or nil
  if base then
    for k = 1, 12 do
      local a = (idx - 1) * 1.7 + k * 0.9
      local d = 40 + (k // 4) * 25
      local pos = { base[1] + saucer.math.sin(a) * d, base[2], base[3] + saucer.math.cos(a) * d }
      if not g.blocked(state, nil, pos, r, hh, 2) then return pos, p1.ship.yaw end
    end
  end
  return require("sim.galaxy").formation(state.sector, idx, 4), 0
end

-- join(state, idx) -> the new player
function M.join(state, idx, ctx)
  local g = game()
  local pos, yaw = M.spawn_spot(state, idx)
  local p = g.new_player(idx, pos, yaw)
  state.players[idx] = p
  require("sim.requests").ensure(state) -- add-playtest-recs: the party request
  ctx.msg(state, p, string.format("Player %d: you wake up in your own saucer. Press Use to get up.", idx))
  for _, o in ipairs(state.players) do
    if o ~= p then ctx.msg(state, o, string.format("Player %d joined in their own saucer", idx)) end
  end
  saucer.events.emit({ type = "join", player = idx })
  return p
end

-- ---------- gifting ----------
-- eject(state, p, uid, for_index) -> ok, why. for_index 0 = anyone
function M.eject(state, p, uid, to, ctx)
  local it = items.find(p, uid)
  if not it then return false, "gone" end
  if it.echo then return false, "echo" end
  if p.mode == "foot" then return false, "on foot" end
  items.remove(p, uid)
  local _, hh = require("sim.ship").dims(p.ship)
  local pos = { p.ship.pos[1], p.ship.pos[2] - hh - 6, p.ship.pos[3] }
  state.gifts = state.gifts or {}
  state.gifts[#state.gifts + 1] = { pos = pos, item = it, to = to or 0, from = p.index, site = p.site }
  ctx.msg(state, p, string.format("Ejected %s for %s", items.label(it), (to or 0) == 0 and "anyone" or ("P" .. to)))
  ctx.fx(state, p, "grow")
  return true
end

-- gifts p may beam up here (tractor candidates)
function M.candidates(state, p, site_idx)
  local out = {}
  for i, gf in ipairs(state.gifts or {}) do
    if gf.site == site_idx and gf.from ~= p.index and (gf.to == 0 or gf.to == p.index) then
      out[#out + 1] = { key = "gift:" .. i, kind = "gift", index = i, pos = gf.pos, item = gf.item }
    end
  end
  return out
end

-- a gift was beamed up: ownership moves to p
function M.receive(state, p, index, ctx)
  if not (state.gifts or {})[index] then return nil end
  local gf = table.remove(state.gifts, index)
  local it = gf.item
  p.next_uid = (p.next_uid or 0) + 1
  it.uid = p.next_uid
  it.hot = p.site ~= 0 and not it.echo
  p.hold[#p.hold + 1] = it
  ctx.msg(state, p, string.format("Gift from P%d: %s", gf.from, items.label(it)))
  local from = state.players[gf.from]
  if from then ctx.msg(state, from, string.format("P%d took your gift", p.index)) end
  return it
end

-- hand an item straight over (docked: the gift table)
function M.give(state, p, q, uid, ctx)
  local it = items.find(p, uid)
  if not it or not q then return false end
  if #q.hold >= require("sim.upgrades").hold_slots(q) then
    ctx.msg(state, p, "P" .. q.index .. "'s hold is full")
    return false
  end
  items.remove(p, uid)
  q.next_uid = (q.next_uid or 0) + 1
  it.uid = q.next_uid
  it.hot = false
  q.hold[#q.hold + 1] = it
  ctx.msg(state, p, string.format("You put %s on the gift table for P%d", items.label(it), q.index))
  ctx.msg(state, q, string.format("P%d left you %s on the gift table", p.index, items.label(it)))
  ctx.fx(state, q, "pickup")
  return true
end

-- ---------- docking and visits ----------
function M.can_dock(state, a, b)
  if not a or not b or a == b then return false end
  for _, p in ipairs({ a, b }) do
    if p.site ~= 0 or p.ship.size ~= 1 or p.ship.morph or p.mode == "foot" then return false end
  end
  return vec.dist(a.ship.pos, b.ship.pos) <= M.DOCK_RANGE
end

local function pair_key(a, b) return math.min(a, b) .. "-" .. math.max(a, b) end

function M.docked(state, a, b)
  local d = (state.docks or {})[pair_key(a.index, b.index)]
  return d ~= nil and d.ok == true
end

-- request or accept a dock between p and q
function M.dock(state, p, q, ctx)
  if not M.can_dock(state, p, q) then
    ctx.msg(state, p, "Docking needs both Villas in open space, close together")
    ctx.fx(state, p, "denied")
    return false
  end
  state.docks = state.docks or {}
  local k = pair_key(p.index, q.index)
  local d = state.docks[k]
  if d and not d.ok and d.by ~= p.index then
    d.ok = true
    ctx.msg(state, p, "Docked with P" .. q.index)
    ctx.msg(state, q, "Docked with P" .. p.index .. ": you can visit each other's domes")
    ctx.fx(state, p, "bank")
    ctx.fx(state, q, "bank")
    return true
  end
  if not d then
    state.docks[k] = { by = p.index, ok = false }
    ctx.msg(state, p, "Dock request sent to P" .. q.index)
    ctx.msg(state, q, "P" .. p.index .. " asks to dock: open your map (Tab), Party, to accept")
  end
  return false
end

function M.return_home(state, p, ctx)
  if not p.visiting then return false end
  p.visiting, p.vbody = false, nil
  p.mode = "helm"
  if ctx then ctx.msg(state, p, "Back at your own helm") end
  return true
end

function M.undock(state, p, q, ctx)
  local k = pair_key(p.index, q.index)
  if not (state.docks or {})[k] then return false end
  state.docks[k] = nil
  for _, x in ipairs({ p, q }) do
    local other = x == p and q or p
    if x.visiting == other.index then M.return_home(state, x, ctx) end
    ctx.msg(state, x, "Undocked")
  end
  return true
end

function M.undock_all(state, ctx)
  for k in pairs(state.docks or {}) do
    local a, b = k:match("^(%d+)-(%d+)$")
    local p, q = state.players[tonumber(a)], state.players[tonumber(b)]
    if p and q then M.undock(state, p, q, ctx) else state.docks[k] = nil end
  end
end

-- visit q's dome (docked only): your body appears at q's dock hatch
function M.visit(state, p, q, ctx)
  if not M.docked(state, p, q) then return false end
  local L = avatar.layout()
  p.visiting = q.index
  p.vbody = avatar.new(L, L.spawn.pos, L.spawn.yaw)
  p.mode = "walk"
  p.panel = false
  ctx.msg(state, p, string.format("You step into P%d's dome. Use: home life, or the gift table. Map (Tab) to go home.", q.index))
  ctx.msg(state, q, string.format("P%d is visiting your dome", p.index))
  return true
end

-- guests in p's dome -> list of bodies
function M.guests(state, p)
  local out = {}
  for _, o in ipairs(state.players) do
    if o.visiting == p.index and o.vbody then out[#out + 1] = o.vbody end
  end
  return out
end

-- one tick of a guest walking the host's dome
function M.step_visit(state, p, cmd, dt, ctx)
  local host = state.players[p.visiting]
  if not host or not M.docked(state, p, host) then
    M.return_home(state, p, ctx)
    return
  end
  local layout = require("sim.layout")
  local homeedit = require("sim.homeedit")
  local L = layout.of(host)
  avatar.step(p.vbody, { move_x = cmd:axis("move_x"), move_z = cmd:axis("move_z"), turn = cmd:axis("turn"),
                         look = cmd:axis("look"), run = cmd:held("boost"), aim = cmd.aim }, dt, L,
    require("sim.home").solids(L, host, { p.vbody }))
  if homeedit.step(state, p, cmd, ctx) then
    -- pick, place, cancel or undo
  elseif cmd:pressed("use") then
    -- Use at a display still admires what's on it; then the station opens so
    -- a guest can also rearrange, cook, harvest, and so on.
    local st = avatar.station(L, p.vbody)
    if st and st.kind == "display" then
      require("sim.decor").admire(state, p, host, st.slot, ctx)
    end
    local used = require("sim.home").use_station(state, p, ctx)
    if not used then
      require("sim.panel").open(p, "gift_table")
    end
  end
end

-- the guest's eyes, in the host's saucer
function M.viewpoint(state, p)
  local host = state.players[p.visiting]
  local L = require("sim.layout").of(host)
  local ship = host.ship
  local e = avatar.rot(ship.yaw, avatar.eye(L, p.vbody))
  return { ship.pos[1] + e[1], ship.pos[2] + e[2], ship.pos[3] + e[3] }, ship.yaw + p.vbody.yaw, p.vbody.pitch
end

-- docked saucers hold station; drifting apart breaks the dock
function M.step(state, ctx)
  for k, d in pairs(state.docks or {}) do
    local a, b = k:match("^(%d+)-(%d+)$")
    local p, q = state.players[tonumber(a)], state.players[tonumber(b)]
    if not p or not q or (d.ok and (vec.dist(p.ship.pos, q.ship.pos) > M.DOCK_RANGE * 1.5 or p.site ~= 0 or q.site ~= 0)) then
      if p and q then M.undock(state, p, q, ctx) else state.docks[k] = nil end
    end
  end
end

-- ---------- add-playtest-recs: "ready to fold" ----------
-- each player's fold readiness for the HUD and the party panel:
-- { {index, ok, why, flagged} } in player order. flagged: they said so
function M.readiness(state)
  local galaxy = require("sim.galaxy")
  local out = {}
  for _, o in ipairs(state.players) do
    local ok, why = galaxy.ready(state, o)
    out[#out + 1] = { index = o.index, ok = ok, why = why, flagged = o.ready_fold == true }
  end
  return out
end

-- say (or take back) "I'm ready to fold"
function M.set_ready(state, p, on, ctx)
  p.ready_fold = on and true or false
  for _, o in ipairs(state.players) do
    if o ~= p then
      ctx.msg(state, o, on and string.format("P%d is ready to fold (TAB: map)", p.index)
        or string.format("P%d is not ready to fold after all", p.index))
    end
  end
  return p.ready_fold
end

-- ---------- the party panel (from the sector map) ----------
function M.rows(state, p, ctx)
  local rows = {}
  for _, q in ipairs(state.players) do
    if q ~= p then
      local k = pair_key(p.index, q.index)
      local d = (state.docks or {})[k]
      if p.visiting == q.index then
        rows[#rows + 1] = { text = "Return to your own saucer", act = function(st, pl) M.return_home(st, pl, ctx) end }
      elseif d and d.ok then
        rows[#rows + 1] = { text = "Visit P" .. q.index .. "'s dome", act = function(st, pl) M.visit(st, pl, q, ctx) end }
        rows[#rows + 1] = { text = "Undock from P" .. q.index, act = function(st, pl) M.undock(st, pl, q, ctx) end }
      elseif d and d.by ~= p.index then
        rows[#rows + 1] = { text = "Accept dock with P" .. q.index, act = function(st, pl) M.dock(st, pl, q, ctx) end }
      elseif not d then
        rows[#rows + 1] = { text = "Dock with P" .. q.index, enabled = M.can_dock(state, p, q),
          act = function(st, pl) M.dock(st, pl, q, ctx) end }
      else
        rows[#rows + 1] = { text = "Dock with P" .. q.index .. ": waiting", enabled = false }
      end
    end
  end
  if p.mode ~= "foot" and not p.visiting then
    for _, it in ipairs(p.hold) do
      if not it.echo then
        local uid = it.uid
        rows[#rows + 1] = { text = "Eject for anyone: " .. items.label(it),
          act = function(st, pl) M.eject(st, pl, uid, 0, ctx) end }
        for _, q in ipairs(state.players) do
          if q ~= p then
            local qi = q.index
            rows[#rows + 1] = { text = string.format("Eject for P%d: %s", qi, items.label(it)),
              act = function(st, pl) M.eject(st, pl, uid, qi, ctx) end }
          end
        end
      end
    end
  end
  -- add-playtest-recs: fold readiness and "I'm ready to fold"
  if #state.players > 1 then
    local parts = {}
    for _, r in ipairs(M.readiness(state)) do
      parts[#parts + 1] = string.format("P%d %s", r.index, r.flagged and "READY" or (r.ok and "can fold" or r.why))
    end
    rows[#rows + 1] = { text = "Fold: " .. table.concat(parts, ", "), enabled = false }
    rows[#rows + 1] = { text = p.ready_fold and "Not ready to fold yet" or "I'm ready to fold",
      act = function(st, pl) M.set_ready(st, pl, not pl.ready_fold, ctx) end }
  end
  if #rows == 0 then rows[1] = { text = "Nobody else is here. Join with a gamepad (A) or F2.", enabled = false } end
  rows[#rows + 1] = { text = "Close", act = function(_, pl) pl.panel = false end }
  return rows
end

-- the gift table in a host's dome
function M.gift_rows(state, p, ctx)
  local rows = {}
  local host = state.players[p.visiting or 0]
  if host then
    for _, it in ipairs(p.hold) do
      if not it.echo then
        local uid = it.uid
        rows[#rows + 1] = { text = "Leave for P" .. host.index .. ": " .. items.label(it),
          act = function(st, pl) M.give(st, pl, host, uid, ctx) end }
      end
    end
  end
  if #rows == 0 then rows[1] = { text = "Nothing to leave on the gift table", enabled = false } end
  rows[#rows + 1] = { text = "Close", act = function(_, pl) pl.panel = false end }
  return rows
end

return M
