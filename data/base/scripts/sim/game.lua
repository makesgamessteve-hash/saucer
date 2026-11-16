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
local avatar = require("sim.avatar")
local home = require("sim.home")
local panel = require("sim.panel")
local items = require("sim.items")
local lab = require("sim.lab")
local trade = require("sim.trade")
local sentry = require("sim.sentry")
local hull = require("sim.hull")
local clock = require("sim.clock")
local data = require("lib.data")
local M = {}

M.SITE_PAD = 30
M.MAX_MSGS = 4
M.MAX_FX = 8

local rt = { ruins = {}, bounds = {}, sentries = {} } -- derived, rebuilt on restore

function M.ruin(i) return rt.ruins[i] end
function M.site_bounds(i) return rt.bounds[i] end
function M.sentries(i) return rt.sentries[i] or {} end

local function civ_of(site) return data.load("civs/civs.lua")[site.civ] end

function M.rebuild(state)
  saucer.physics.clear()
  rt.ruins, rt.bounds, rt.sentries = {}, {}, {}
  for i, site in ipairs(state.sector.sites) do
    local r = ruinm.generate(site.seed, site.kit, civ_of(site), site.pos, nil, site.first)
    rt.ruins[i] = r
    rt.sentries[i] = sentry.layout(site, r, civ_of(site))
    local lo, hi = ruinm.bounds(r, site.pos, M.SITE_PAD)
    rt.bounds[i] = { lo, hi }
    for _, b in ipairs(r.walls) do saucer.physics.add_box(b[1], b[2], 1) end
    for _, b in ipairs(r.debris) do saucer.physics.add_box(b[1], b[2], 1) end
    for _, b in ipairs(r.solids or {}) do saucer.physics.add_box(b[1], b[2], 1) end
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

local ctx_fns = { msg = msg, fx = fx }
M.ctx = ctx_fns

-- A player is a person (body) living in their own saucer (ship). mode is
-- "wake" (just woke up, the title panel is open), "walk" (on foot inside the
-- Villa) or "helm" (seated, flying it; the Seat has room for nothing else).
function M.new_player(index, pos, yaw)
  local L = avatar.layout()
  local p = {
    index = index, record_index = index - 1,
    ship = shipm.new(pos, yaw, 1),
    mode = "walk", body = avatar.new(L, L.spawn.pos, L.spawn.yaw), doors = home.new_doors(L),
    hold = {}, credits = 0, banked_value = 0, looted = {}, lab = lab.new(), next_uid = 0, last_trader = 1,
    scan_ready = 0, jam_ready = 0, scan_until = 0, jam_flash = 0,
    site = 0, tractor = false, ghost = 0, cam = "first", help = false, panel = false,
    beam_console = false, hatch = 0,
    msgs = {}, fx = {},
  }
  home.wake(p)
  return p
end

function M.init(state, ctx)
  local seed = ctx.seed
  state.version = 5   -- v5: true 3D sector and derelicts (add-true-3d-flight)
  state.seed = seed
  state.tick = 0
  state.sector = sector.generate(seed)
  state.mystery = mystery.generate(seed, "on", #state.sector.sites)
  state.players = {}
  -- milestone 3 world state: trader demand, Snatcher nests, Fold Retreat
  -- caches, the Resonant vault and the sim clock (all saved), plus the live
  -- sentries and stun bolts (reset on load)
  state.traders = trade.new_traders(state.sector)
  state.nests, state.caches = {}, {}
  state.vault = { pos = vec.copy(state.sector.vault.pos), taken = false }
  state.clock = clock.new()
  state.bolts = {}
  M.rebuild(state)
  state.sentries = {}
  for i = 1, #state.sector.sites do state.sentries[i] = sentry.new_state(rt.sentries[i]) end
  local site1 = state.sector.sites[1]
  local door = ruinm.entrance(rt.ruins[1], site1.pos)
  local n = ctx.players or 1
  for i = 1, n do
    local x = door[1] + (i - 1 - (n - 1) / 2) * 34
    state.players[i] = M.new_player(i, { x, door[2], door[3] - 120 }, 0)
  end
  for i = 1, n do msg(state, state.players[i], "You wake up in your saucer. Press Use to get up.") end
end

-- where this player's eyes are (world) and where they look: the tractor and
-- the camera both start here. On foot that is the body under the dome.
function M.viewpoint(p)
  local ship = p.ship
  if p.mode == "wake" then
    local L = avatar.layout()
    local e = avatar.rot(ship.yaw, L.wake.eye)
    return { ship.pos[1] + e[1], ship.pos[2] + e[2], ship.pos[3] + e[3] }, ship.yaw + L.wake.yaw, L.wake.pitch
  end
  if p.mode == "walk" and p.beam_console then
    -- in the Tractor Room's sling seat, out over the floor window
    local L = avatar.layout()
    local e = avatar.rot(ship.yaw, L.tractor.eye)
    return { ship.pos[1] + e[1], ship.pos[2] + e[2], ship.pos[3] + e[3] }, ship.yaw + L.tractor.yaw, p.body.pitch
  end
  if p.mode == "walk" then
    local L = avatar.layout()
    local e = avatar.rot(ship.yaw, avatar.eye(L, p.body))
    return { ship.pos[1] + e[1], ship.pos[2] + e[2], ship.pos[3] + e[3] }, ship.yaw + p.body.yaw, p.body.pitch
  end
  return shipm.eye_world(ship.pos, ship.yaw, ship.size), ship.yaw, ship.pitch
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

-- distance from pos to a site's (huge, 3D) bounding volume; 0 inside
function M.site_distance(i, pos)
  local b = rt.bounds[i]
  if not b then return math.huge end
  local q = {}
  for k = 1, 3 do q[k] = vec.clamp(pos[k], b[1][k], b[2][k]) end
  return vec.dist(q, pos)
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

-- reconfigure around the player: seated, the helm's eye point stays put; on
-- foot, the saucer folds down around wherever the player stands and looks
local function size_request(state, p, to)
  local ship = p.ship
  local from = ship.size
  local eye, yaw
  if p.mode == "walk" then eye, yaw = M.viewpoint(p) end
  local blocked = function(pos, r, hh, margin) return M.blocked(state, p, pos, r, hh, margin) end
  local ok, why, where = shipm.request(ship, to, blocked, eye, yaw)
  if ok then
    if p.mode == "walk" then ship.pitch = p.body.pitch end
    p.mode = "helm"
    p.tractor = false
    p.beam_console = false
    fx(state, p, to > from and "shrink" or "grow")
    saucer.events.emit({ type = "size_change", player = p.index, from = from, to = to })
  elseif REASONS[why] then
    msg(state, p, REASONS[why])
    fx(state, p, "denied")
    if why == "clearance" then p.ghost = 45; p.ghost_size = to; p.ghost_pos = where end
  end
end

-- add-tractor-beam: sit down at the beam console in the Tractor Room / get up
M.HATCH_ARMED = 0.7 -- how far the iris opens while the operator sits at the console
local function console_enter(state, p)
  local L = avatar.layout()
  p.beam_console = true
  p.body.pitch = L.tractor.pitch
  msg(state, p, "Beam console: look down through the glass. Stick trims, F pulls, Use gets up.")
end
home.USE.tractor = function(state, p) console_enter(state, p) end

local function console_leave(state, p)
  p.beam_console = false
  p.body.pitch = 0
  if p.tractor and p.tractor.console then
    p.tractor = false
    msg(state, p, "You left the console: the beam let go")
    fx(state, p, "denied")
  end
end

-- the Use button: take the helm, or stand up from it
local function use(state, p)
  local L = avatar.layout()
  local ship = p.ship
  if p.beam_console then
    console_leave(state, p)
    msg(state, p, "You get up from the beam console. The saucer holds station.")
    return
  end
  if p.mode == "helm" then
    if not configs.get(ship.size).interior or ship.morph then
      msg(state, p, "No room to stand up in the " .. configs.get(ship.size).name)
      fx(state, p, "denied")
      return
    end
    p.mode = "walk"
    p.tractor = false
    p.body = avatar.new(L, L.helm.stand, 0)
    p.body.pitch = ship.pitch
    msg(state, p, "You leave the helm. The saucer holds station.")
  elseif avatar.near_helm(L, p.body) then
    p.mode = "helm"
    ship.pitch = p.body.pitch
    msg(state, p, "At the helm: fly with move and look, Use to stand up.")
  elseif not home.use_station(state, p, ctx_fns) then
    msg(state, p, "Nothing to use here")
  end
end

local STILL = { axis = function() return 0 end, held = function() return false end,
                pressed = function() return false end }

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

-- add-tractor-beam: the belly beam (sim/tractor.lua has the alignment rule)
local function tractor_step(state, p, cmd, dt)
  local ship = p.ship
  if p.tractor then
    local t = p.tractor
    local ruin = t.site ~= 0 and rt.ruins[t.site] or nil
    local cand = tractor.by_key(state, p, t.site, ruin, t.key)
    local why
    if not cand then why = "Tractor lock lost"
    elseif t.size ~= ship.size or ship.morph then why = "The beam collapsed in the fold"
    elseif t.console and not p.beam_console then why = "You left the console: the beam let go"
    else
      -- the saucer drifted so far that the item fell out of the beam
      local b, m = tractor.beam_of(ship), tractor.measure(ship, t.from)
      if m.depth > b.range * tractor.SENSE or m.angle > b.half_angle * tractor.SENSE_ANGLE then why = "Tractor lock lost" end
    end
    if why then
      p.tractor = false
      msg(state, p, why)
      fx(state, p, "denied")
      return
    end
    t.t = t.t + dt
    if t.t >= t.total - 1e-9 then
      p.tractor = false
      M.pick_up(state, p, cand, t.site)
    end
    return
  end
  if not cmd:pressed("tractor") then return end
  local b = tractor.beam_of(ship)
  if b.console and not p.beam_console then
    if p.mode == "helm" then
      msg(state, p, "The beam runs from the Tractor Room below the lower deck. Line up, then go down: hover-hold keeps you here.")
    else
      msg(state, p, "Use the beam console in the Tractor Room (stairs down beside the engine).")
    end
    fx(state, p, "denied")
    return
  end
  local _, heading = M.viewpoint(p)
  local sc = tractor.scan(state, p, p.site, rt.ruins[p.site], heading)
  if not sc then
    msg(state, p, "Nothing under the beam")
    fx(state, p, "denied")
  elseif sc.status ~= "lock" then
    msg(state, p, "Beam: " .. sc.info.hint:lower())
    fx(state, p, "denied")
  elseif sc.cand.kind ~= "cache" and #p.hold >= configs.all().hold_slots then
    msg(state, p, "Hold is full")
    fx(state, p, "denied")
  else
    local cand = sc.cand
    p.tractor = { key = cand.key, site = p.site, t = 0, total = tractor.pull_time(ship, sc.info.depth),
                  from = vec.copy(cand.pos), size = ship.size, console = b.console, item_size = cand.item.size,
                  kind = cand.kind }
    msg(state, p, "Beam lock: pulling up " .. items.label(cand.item))
    fx(state, p, "tractor")
  end
end

-- a tractored target lands in the hold
function M.pick_up(state, p, cand, site_idx)
  local civ = site_idx ~= 0 and civ_of(state.sector.sites[site_idx]) or nil
  if cand.kind == "echo" then
    p.looted[cand.key] = true
    mystery.found(state.mystery, cand.echo, p.index)
    local it = items.stamp(p, cand.item, 1, civ and civ.id)
    it.hot = false -- Echoes are never lost
    p.hold[#p.hold + 1] = it
    local e = state.mystery.echoes[cand.echo]
    msg(state, p, string.format("Got %s. Decode it at your lab bench.", it.name))
    if e.role == "key" then msg(state, p, "A key fragment: it should open the Resonant vault") end
    fx(state, p, "echo")
  elseif cand.kind == "nest" then
    local n = table.remove(state.nests, cand.index)
    n.item.hot = true
    p.hold[#p.hold + 1] = n.item
    msg(state, p, "Recovered " .. items.label(n.item) .. " from the nest")
    fx(state, p, "pickup")
  elseif cand.kind == "cache" then
    local c = state.caches[cand.index]
    local got = 0
    while #c.items > 0 and #p.hold < configs.all().hold_slots do
      local it = table.remove(c.items, 1)
      it.hot = true
      p.hold[#p.hold + 1] = it
      got = got + 1
    end
    if #c.items == 0 then table.remove(state.caches, cand.index) end
    msg(state, p, string.format("Recovered %d item%s from your cache", got, got == 1 and "" or "s"))
    fx(state, p, "pickup")
  elseif cand.kind == "curio" then
    state.vault.taken = true
    local it = items.stamp(p, cand.item, 5, nil)
    it.hot = false
    p.hold[#p.hold + 1] = it
    msg(state, p, "You take the " .. it.name .. ".")
    msg(state, p, mystery.TEASER)
    fx(state, p, "echo")
  else
    p.looted[cand.key] = true
    local it = items.stamp(p, cand.item, cand.item.tier, civ and civ.id)
    it.hot = true
    p.hold[#p.hold + 1] = it
    msg(state, p, "Got " .. items.label(it))
    fx(state, p, "pickup")
    saucer.events.emit({ type = "loot", player = p.index, item = it.type })
  end
end

-- Scanner pulse and Jammer (concept §8.3); costs and cooldowns are data
local function scan(state, p)
  local t = sentry.tune().scanner
  if state.tick < p.scan_ready then
    msg(state, p, "Scanner recharging")
    fx(state, p, "denied")
    return
  end
  if p.ship.charge < t.charge then
    msg(state, p, "Not enough Charge to scan")
    fx(state, p, "denied")
    return
  end
  p.ship.charge = p.ship.charge - t.charge
  p.scan_ready = state.tick + math.floor(t.cooldown * 60)
  p.scan_until = state.tick + math.floor(t.reveal * 60)
  local site = p.site
  if site == 0 then
    local best, bd
    for i in ipairs(state.sector.sites) do
      local d = M.site_distance(i, p.ship.pos)
      if not bd or d < bd then best, bd = i, d end
    end
    site = best
  end
  local w, sn = sentry.summary(rt.sentries[site] or {})
  msg(state, p, string.format("Scan: site %d, danger %d, %d Watcher%s, %d Snatcher%s", site, site == 1 and 1 or 2, w,
    w == 1 and "" or "s", sn, sn == 1 and "" or "s"))
  fx(state, p, "scan")
end

local function jam(state, p)
  local t = sentry.tune().jammer
  if state.tick < p.jam_ready then
    msg(state, p, "Jammer recharging")
    fx(state, p, "denied")
    return
  end
  if p.ship.charge < t.charge then
    msg(state, p, "Not enough Charge to jam")
    fx(state, p, "denied")
    return
  end
  p.ship.charge = p.ship.charge - t.charge
  p.jam_ready = state.tick + math.floor(t.cooldown * 60)
  p.jam_flash = state.tick + 20
  local eye, yaw, pitch = M.viewpoint(p)
  local n = 0
  if p.site ~= 0 then n = sentry.jam(state, p.site, rt.sentries[p.site], eye, vec.aim(yaw, pitch), p) end
  msg(state, p, n > 0 and string.format("Jammer: %d sentr%s disabled for 12 s", n, n == 1 and "y" or "ies")
    or "Jammer pulse: nothing in range")
  fx(state, p, "jam")
end

local SIZE_KEYS = { "size1", "size2", "size3", "size4" }

-- what happens to a player's saucer every tick, whatever they are doing
local function trader_pos(state, p)
  local list = state.sector.traders or { state.sector.trader }
  return (list[p.last_trader or 1] or list[1]).pos
end

local function world_step(state, p, dt)
  local ship = p.ship
  local site = M.site_at(ship.pos)
  if site ~= p.site then
    if site == 0 then bank(state, p) else msg(state, p, "Entering derelict site " .. site) end
    p.site = site
  end
  if shipm.update(ship, dt, site == 0 and home.regen_factor(state, p)) == "done" then
    msg(state, p, "Configuration: " .. configs.get(ship.size).name)
  end
  if p.ghost > 0 then p.ghost = p.ghost - 1 end
  -- the belly hatch irises open while the beam pulls, and part way while the
  -- operator sits at the console so they can see down the beam (render reads p.hatch)
  local hw = p.tractor and 1 or (p.beam_console and M.HATCH_ARMED or 0)
  local hc = p.hatch or 0
  if hw > hc then p.hatch = math.min(hw, hc + 2.5 * dt) else p.hatch = math.max(hw, hc - 1.5 * dt) end
  home.doors_step(avatar.layout(), p, dt)
  -- milestone 3: docking, the lab bench, shields, Fold Retreat and the Resonant vault
  local docked = trade.docked_at(state, p)
  if docked and not p.docked then
    p.last_trader = docked
    msg(state, p, "Docked at the trader. Walk to the trade terminal to sell.")
    fx(state, p, "bank")
  end
  p.docked = docked or false
  lab.step(state, p, dt, ctx_fns)
  hull.regen(ship, dt)
  if ship.hull <= 0 then
    local from = p.site
    local cache = hull.retreat(state, p, trader_pos(state, p))
    p.site = M.site_at(ship.pos)
    msg(state, p, "FOLD RETREAT: the hull gave out and you folded back to the trader.")
    if cache then
      msg(state, p, string.format("%d hot item%s stayed behind as a cache at site %d.", #cache.items,
        #cache.items == 1 and "" or "s", from))
    end
    fx(state, p, "grow")
  end
  local m = state.mystery
  if p.site == 0 and m.vault_revealed and not m.vault_open and vec.dist(ship.pos, state.vault.pos) < 80 then
    for _, it in ipairs(p.hold) do
      if it.echo and m.echoes[it.echo].role == "key" then
        items.remove(p, it.uid)
        mystery.open_vault(m)
        msg(state, p, "The key fragment fits. The Resonant vault opens: inside rests the " .. m.curio .. ".")
        fx(state, p, "echo")
        break
      end
    end
  end
end

function M.step_player(state, p, cmd, dt)
  local ship = p.ship
  if cmd:pressed("camera") then p.cam = p.cam == "first" and "chase" or "first" end
  if cmd:pressed("menu") then p.help = not p.help end
  if cmd:pressed("mystery_mode") then
    state.mystery.mode = mystery.next_mode(state.mystery.mode)
    msg(state, p, "Mystery: " .. state.mystery.mode)
  end
  if p.panel then
    -- a menu is open: it takes the stick and Use; the saucer holds station
    panel.step(state, p, cmd)
    if state.players[p.index] ~= p then return end -- a save was loaded
    if p.mode == "wake" and not p.panel then home.get_up(state, p, ctx_fns) end
    flight.step(ship, STILL, dt, mover(state, p))
    world_step(state, p, dt)
    return
  end
  if p.mode == "wake" then home.get_up(state, p, ctx_fns) end
  if cmd:pressed("use") then use(state, p) end
  if cmd:pressed("scan") then scan(state, p) end
  if cmd:pressed("jam") then jam(state, p) end
  if cmd:pressed("shrink") then size_request(state, p, ship.size + 1)
  elseif cmd:pressed("grow") then size_request(state, p, ship.size - 1) end
  for i, k in ipairs(SIZE_KEYS) do
    if i <= configs.count() and cmd:pressed(k) and i ~= ship.size then size_request(state, p, i) end
  end
  if ship.morph then
    ship.vel = { 0, 0, 0 }
  elseif p.mode == "helm" then
    flight.step(ship, cmd, dt, mover(state, p))
  elseif p.beam_console then
    -- at the beam console: trim thrusters in the operator's frame, look to aim the view
    local L = avatar.layout()
    flight.trim(ship, { move_x = cmd:axis("move_x"), move_z = cmd:axis("move_z"), lift = cmd:axis("lift"),
                        turn = cmd:axis("turn") }, ship.yaw + L.tractor.yaw, dt, mover(state, p))
    p.body.pitch = vec.clamp(p.body.pitch + cmd:axis("look") * L.look * dt, -L.pitch_limit, L.pitch_limit)
  else
    -- nobody at the helm: the saucer brakes to a stop and holds station
    flight.step(ship, STILL, dt, mover(state, p))
    local L = avatar.layout()
    avatar.step(p.body, { move_x = cmd:axis("move_x"), move_z = cmd:axis("move_z"), turn = cmd:axis("turn"),
                          look = cmd:axis("look"), run = cmd:held("boost"), aim = cmd.aim }, dt, L, home.solids(L, p))
  end
  world_step(state, p, dt)
  tractor_step(state, p, cmd, dt)
end

function M.step(state, cmds, dt)
  state.tick = state.tick + 1
  for i = 1, #state.players do
    local p = state.players[i]
    if p and cmds[i] then M.step_player(state, p, cmds[i], dt) end
  end
  -- sentries act once per tick for everyone, then their stun bolts fly
  for i = 1, #state.sector.sites do sentry.step(state, i, rt.sentries[i], dt, ctx_fns) end
  sentry.step_bolts(state, dt)
end

home.register_panels(M, ctx_fns)

function M.on_event(ev, state)
  -- base keeps no extra bookkeeping; mods listen for "size_change"/"loot"
  return ev.type
end

return M
