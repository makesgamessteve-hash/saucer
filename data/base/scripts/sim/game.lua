-- SPDX-License-Identifier: MIT
-- The deterministic simulation. All state lives in the table the engine owns
-- (snapshots, saves and hashes cover it). Derived data (ruin geometry,
-- physics boxes) is rebuilt from seeds in rebuild().
local vec = require("lib.vec")
local configs = require("sim.config")
local shipm = require("sim.ship")
local flight = require("sim.flight")
local ruinm = require("sim.ruin")
local sector = require("sim.sector")
local loot = require("sim.loot")
local mystery = require("sim.mystery")
local tractor = require("sim.tractor")
local data = require("lib.data")
local M = {}

M.SITE_PAD = 30
M.MAX_MSGS = 4
M.MAX_FX = 8

local rt = { ruins = {}, bounds = {} } -- derived, rebuilt on restore

function M.ruin(i) return rt.ruins[i] end
function M.site_bounds(i) return rt.bounds[i] end

local function civ_of(site) return data.load("civs/civs.lua")[site.civ] end

function M.rebuild(state)
  saucer.physics.clear()
  rt.ruins, rt.bounds = {}, {}
  for i, site in ipairs(state.sector.sites) do
    local r = ruinm.generate(site.seed, site.kit, civ_of(site), site.pos, nil, site.first)
    rt.ruins[i] = r
    local lo, hi = ruinm.bounds(r, site.pos, M.SITE_PAD)
    rt.bounds[i] = { lo, hi }
    for _, b in ipairs(r.walls) do saucer.physics.add_box(b[1], b[2], 1) end
    for _, b in ipairs(r.debris) do saucer.physics.add_box(b[1], b[2], 1) end
  end
end

local function msg(state, p, text)
  local list = p.msgs
  list[#list + 1] = { tick = state.tick, text = text }
  while #list > M.MAX_MSGS do table.remove(list, 1) end
end
M.msg = msg

local function fx(state, p, sound)
  local list = p.fx
  list[#list + 1] = { tick = state.tick, sound = sound }
  while #list > M.MAX_FX do table.remove(list, 1) end
end

function M.new_player(index, pos, yaw)
  return {
    index = index, record_index = index - 1,
    ship = shipm.new(pos, yaw, 1),
    hold = {}, credits = 0, banked_value = 0, looted = {},
    site = 0, tractor = false, ghost = 0, cam = "cockpit", help = false,
    msgs = {}, fx = {},
  }
end

function M.init(state, ctx)
  local seed = ctx.seed
  state.version = 1
  state.seed = seed
  state.tick = 0
  state.sector = sector.generate(seed)
  state.mystery = mystery.generate(seed, "on", #state.sector.sites)
  state.players = {}
  M.rebuild(state)
  local site1 = state.sector.sites[1]
  local door = ruinm.entrance(rt.ruins[1], site1.pos)
  local n = ctx.players or 1
  for i = 1, n do
    local x = door[1] + (i - 1 - (n - 1) / 2) * 34
    state.players[i] = M.new_player(i, { x, door[2], door[3] - 120 }, 0)
  end
  for i = 1, n do msg(state, state.players[i], "Derelict ahead. Shrink to fit its hangar door.") end
end

-- hull blocked by walls or by other players' saucers?
function M.blocked(state, self, pos, r, hh, margin)
  if not saucer.physics.clearance(pos, r, hh, margin, 1) then return true end
  for _, o in ipairs(state.players) do
    if o ~= self then
      local orr, ohh = shipm.dims(o.ship)
      if vec.hulls_overlap(pos, r, hh, o.ship.pos, orr, ohh, margin) then return true end
    end
  end
  return false
end

local function mover(state, p)
  return function(ship, delta)
    local r, hh = shipm.dims(ship)
    local np, blocked = saucer.physics.move(ship.pos, r, hh, delta, 1)
    for _, o in ipairs(state.players) do
      if o ~= p then
        local orr, ohh = shipm.dims(o.ship)
        if vec.hulls_overlap(np, r, hh, o.ship.pos, orr, ohh, 0) then return vec.copy(ship.pos), blocked + 1 end
      end
    end
    return np, blocked
  end
end

local function inside(b, pos)
  return pos[1] >= b[1][1] and pos[1] <= b[2][1] and pos[2] >= b[1][2] and pos[2] <= b[2][2]
    and pos[3] >= b[1][3] and pos[3] <= b[2][3]
end

function M.site_at(pos)
  for i, b in ipairs(rt.bounds) do
    if inside(b, pos) then return i end
  end
  return 0
end

local REASONS = {
  charge = "Not enough Charge",
  clearance = "No room to grow here",
  busy = "Hull is still reshaping",
}

local function size_request(state, p, to)
  local ship = p.ship
  local ok, why = shipm.request(ship, to, function(s, r, hh, margin) return M.blocked(state, p, s.pos, r, hh, margin) end)
  if ok then
    fx(state, p, to > ship.size and "shrink" or "grow")
    saucer.events.emit({ type = "size_change", player = p.index, from = ship.size, to = to })
  elseif REASONS[why] then
    msg(state, p, REASONS[why])
    fx(state, p, "denied")
    if why == "clearance" then p.ghost = 45; p.ghost_size = to end
  end
end

local function bank(state, p)
  local n, v = 0, 0
  for _, it in ipairs(p.hold) do
    if it.hot then
      it.hot = false
      n = n + 1
      v = v + it.value
    end
  end
  if n > 0 then
    p.banked_value = p.banked_value + v
    msg(state, p, string.format("Banked %d item%s (%d c)", n, n == 1 and "" or "s", v))
    fx(state, p, "bank")
  end
end

local function tractor_step(state, p, cmd, dt)
  local ship = p.ship
  if p.tractor then
    local t = p.tractor
    local ruin = rt.ruins[t.site]
    local cand
    for _, c in ipairs(tractor.candidates(state, p, t.site, ruin)) do
      if c.key == t.key then cand = c end
    end
    local c = configs.get(ship.size)
    if not cand or vec.dist(cand.pos, ship.pos) > c.tractor_range * 1.25 or not tractor.can_lift(ship, cand.item) then
      p.tractor = false
      msg(state, p, "Tractor lock lost")
      return
    end
    t.left = t.left - dt
    if t.left <= 1e-9 then
      p.tractor = false
      if cand.echo then
        p.looted[cand.key] = true
        local solved = mystery.found(state.mystery, cand.echo, p.index)
        msg(state, p, state.mystery.echoes[cand.echo].text)
        if solved then msg(state, p, "The chain is complete: the Resonant vault is revealed.") end
        fx(state, p, "echo")
      else
        p.looted[cand.key] = true
        local it = cand.item
        it.hot = true
        p.hold[#p.hold + 1] = it
        msg(state, p, "Got " .. it.name .. " (" .. it.value .. " c)")
        fx(state, p, "pickup")
        saucer.events.emit({ type = "loot", player = p.index, item = it.type })
      end
    end
    return
  end
  if not cmd:pressed("tractor") then return end
  if p.site == 0 then
    msg(state, p, "Nothing in tractor range")
    fx(state, p, "denied")
    return
  end
  local cand = tractor.find(state, p, p.site, rt.ruins[p.site])
  if not cand then
    msg(state, p, "Nothing in tractor range")
    fx(state, p, "denied")
  elseif not tractor.can_lift(ship, cand.item) then
    msg(state, p, cand.item.name .. " needs a size " .. loot.size_name(cand.item.size) .. " tractor")
    fx(state, p, "denied")
  elseif not cand.echo and #p.hold >= configs.all().hold_slots then
    msg(state, p, "Hold is full")
    fx(state, p, "denied")
  else
    p.tractor = { key = cand.key, site = p.site, left = tractor.LOCK_TIME }
    fx(state, p, "tractor")
  end
end

local SIZE_KEYS = { "size1", "size2", "size3", "size4" }

function M.step_player(state, p, cmd, dt)
  local ship = p.ship
  if cmd:pressed("camera") then p.cam = p.cam == "cockpit" and "chase" or "cockpit" end
  if cmd:pressed("menu") then p.help = not p.help end
  if cmd:pressed("mystery_mode") then
    state.mystery.mode = mystery.next_mode(state.mystery.mode)
    msg(state, p, "Mystery: " .. state.mystery.mode)
  end
  if cmd:pressed("shrink") then size_request(state, p, (ship.target or ship.size) + 1)
  elseif cmd:pressed("grow") then size_request(state, p, (ship.target or ship.size) - 1) end
  for i, k in ipairs(SIZE_KEYS) do
    if cmd:pressed(k) and i ~= ship.size then size_request(state, p, i) end
  end
  flight.step(ship, cmd, dt, mover(state, p))
  local site = M.site_at(ship.pos)
  if site ~= p.site then
    if site == 0 then bank(state, p) else msg(state, p, "Entering derelict site " .. site) end
    p.site = site
  end
  if shipm.update(ship, dt, site == 0) == "done" then
    msg(state, p, "Configuration: " .. configs.get(ship.size).name)
  end
  if p.ghost > 0 then p.ghost = p.ghost - 1 end
  tractor_step(state, p, cmd, dt)
end

function M.step(state, cmds, dt)
  state.tick = state.tick + 1
  for i, p in ipairs(state.players) do
    if cmds[i] then M.step_player(state, p, cmds[i], dt) end
  end
end

function M.on_event(ev, state)
  -- base keeps no extra bookkeeping; mods listen for "size_change"/"loot"
  return ev.type
end

return M
