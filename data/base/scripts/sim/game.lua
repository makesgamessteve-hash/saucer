-- SPDX-License-Identifier: MIT
-- The deterministic simulation. All state lives in the table the engine owns
-- (snapshots, saves and hashes cover it). Derived data (ruin geometry,
-- physics boxes) is rebuilt from seeds in rebuild().
local vec = require("lib.vec")
local comfort = require("sim.comfort")
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
-- add-holodeck-home-life
local holo = require("sim.holo")
local kitchen = require("sim.kitchen")
local books = require("sim.books")
local tv = require("sim.tv")
local finds = require("sim.finds")
local buffs = require("sim.buffs")
-- add-pocket-station-visits
local visit = require("sim.visit")
-- add-on-foot-excursions
local excursion = require("sim.excursion")
-- add-wider-dark
local civs = require("sim.civs")
local galaxy = require("sim.galaxy")
local archive = require("sim.archive")
local requests = require("sim.requests")
local coop = require("sim.coop")
local adv = require("sim.advsentry")
local heart = require("sim.heart")
local decor = require("sim.decor")
local M = {}

M.SITE_PAD = 30
M.MAX_MSGS = 4
M.MAX_FX = 8

local rt = { ruins = {}, bounds = {}, sentries = {}, shutters = {}, seals = {} } -- derived, rebuilt on restore

function M.ruin(i) return rt.ruins[i] end
function M.site_bounds(i) return rt.bounds[i] end
function M.sentries(i) return rt.sentries[i] or {} end

-- add-wider-dark: civs come from the universe's generated list (sim/civs.lua)
local function civ_of(site) return civs.get(civs.current() or 0, site.civ) end
M.civ_of = civ_of

function M.rebuild(state)
  M.state_ref = state
  saucer.physics.clear()
  civs.use(state.seed)
  rt.ruins, rt.bounds, rt.sentries, rt.shutters, rt.seals = {}, {}, {}, {}, {}
  for i, site in ipairs(state.sector.sites) do
    local r = ruinm.generate(site.seed, site.kit, civ_of(site), site.pos, nil, site.first)
    rt.ruins[i] = r
    rt.sentries[i] = sentry.layout(site, r, civ_of(site))
    local lo, hi = ruinm.bounds(r, site.pos, M.SITE_PAD)
    rt.bounds[i] = { lo, hi }
    for _, b in ipairs(r.walls) do saucer.physics.add_box(b[1], b[2], 1) end
    for _, b in ipairs(r.debris) do saucer.physics.add_box(b[1], b[2], 1) end
    for _, b in ipairs(r.solids or {}) do saucer.physics.add_box(b[1], b[2], 1) end
    -- add-on-foot-excursions: sealed shutters stay solid until their hand-lock turns
    rt.shutters[i] = {}
    for _, sh in ipairs(r.foot and r.foot.shutters or {}) do
      if not excursion.lock_open(state, i, sh.id) then rt.shutters[i][sh.id] = saucer.physics.add_box(sh.min, sh.max, 1) end
    end
  end
  -- add-wider-dark: doors a Lockdown node holds sealed right now
  for i, list in pairs(state.sentries or {}) do
    for k, dyn in ipairs(list) do
      local def = rt.sentries[i] and rt.sentries[i][k]
      if def and def.kind == "lockdown" and dyn.sealed and #dyn.sealed > 0 then
        local keep = dyn.sealed
        dyn.sealed = {}
        M.seal(def, dyn, true, keep)
      end
    end
  end
end

-- add-wider-dark: a Lockdown node seals (on) or opens its hall's big doors.
-- Doors with a hull in the way stay open. dyn.sealed lists the sealed ones.
function M.seal(def, dyn, on, only)
  local key = def.site .. ":" .. def.id
  local live = rt.seals[key] or {}
  rt.seals[key] = live
  if on then
    local list = only or {}
    if not only then for k = 1, #def.boxes do list[#list + 1] = k end end
    for _, k in ipairs(list) do
      local b = def.boxes[k]
      local free = M.state_ref == nil or not M.box_has_hull(M.state_ref, b)
      if b and free and not live[k] then
        live[k] = saucer.physics.add_box(b[1], b[2], 1)
        dyn.sealed[#dyn.sealed + 1] = k
      end
    end
  else
    for k, box in pairs(live) do
      saucer.physics.remove(box)
      live[k] = nil
    end
    dyn.sealed = {}
  end
end

-- live seal barriers of a Lockdown node (tests and the view)
function M.sealed_count(def)
  local n = 0
  for _ in pairs(rt.seals[def.site .. ":" .. def.id] or {}) do n = n + 1 end
  return n
end

function M.box_has_hull(state, b)
  for _, p in ipairs(state.players) do
    local r, hh = shipm.dims(p.ship)
    local pos = p.ship.pos
    if pos[1] + r >= b[1][1] and pos[1] - r <= b[2][1] and pos[2] + hh >= b[1][2] and pos[2] - hh <= b[2][2]
        and pos[3] + r >= b[1][3] and pos[3] - r <= b[2][3] then return true end
  end
  return false
end

-- a hand-lock turned: its shutter stops being solid
function M.open_shutter(site, id)
  local list = rt.shutters[site]
  local box = list and list[id]
  if not box then return false end
  saucer.physics.remove(box)
  list[id] = nil
  return true
end
function M.shutter_closed(site, id) return rt.shutters[site] ~= nil and rt.shutters[site][id] ~= nil end

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

local ctx_fns = { msg = msg, fx = fx, seal = function(def, dyn, on) M.seal(def, dyn, on) end }
sentry.seal_fn = ctx_fns.seal
M.ctx = ctx_fns

-- A player is a person (body) living in their own saucer (ship). mode is
-- "wake" (just woke up, the title panel is open), "walk" (on foot inside the
-- Villa), "helm" (seated, flying it; the Seat has room for nothing else) or
-- "foot" (walking a trader station with the saucer in your pocket: p.station).
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
    -- add-holodeck-home-life: what a running program, the TV, an open book
    -- or the stove are doing right now (transient), and the home itself
    holo_run = false, tv = false, reading = false, cooking = false,
    buffs = {}, trails = {}, leads = {},
    msgs = {}, fx = {},
    -- add-on-foot-excursions: the suit (the only meter on foot) and 4 hand slots
    excursion = false, suit = 100, hands = {},
    -- add-wider-dark: Fold Core tier, tools, reputation, Xenoarchive, per
    -- sector memories, a dome visit
    fold_tier = 1, decoys = sentry.tune().decoy.start, shroud = false, shake = 0, spike = false,
    rep = {}, archive = {}, met = {}, archive_rewards = {}, away = {}, visiting = false,
  }
  holo.ensure(p)
  kitchen.ensure(p)
  books.ensure(p)
  home.wake(p)
  return p
end

function M.init(state, ctx)
  M.state_ref = state
  local seed = ctx.seed
  state.version = 9   -- v9: the wider dark (add-wider-dark); v8: on-foot excursions; v7: station visits
  state.seed = seed
  state.tick = 0
  civs.use(seed)
  state.sector_id = 1
  state.sector = sector.generate(seed)
  local g = galaxy.generate(seed)
  state.mystery = mystery.generate(seed, "on", #state.sector.sites, g)
  -- the Witness's translation gate is the civ of the site it waits in
  for _, e in ipairs(state.mystery.echoes) do
    if e.gate then
      local fs = sector.generate(seed, e.sector, g.sectors[e.sector])
      local c = fs.sites[e.site] and civs.get(seed, fs.sites[e.site].civ)
      e.gate_civ = c and c.id or nil
    end
  end
  state.visited, state.overrides, state.decoys, state.gifts, state.docks = {}, {}, {}, {}, {}
  state.jump = false
  state.players = {}
  -- milestone 3 world state: trader demand, Snatcher nests, Fold Retreat
  -- caches, the Resonant vault and the sim clock (all saved), plus the live
  -- sentries and stun bolts (reset on load)
  state.traders = trade.new_traders(state.sector)
  state.nests, state.caches = {}, {}
  state.vault = { pos = vec.copy(state.sector.vault.pos), taken = false }
  state.clock = clock.new()
  state.bolts = {}
  state.locks, state.grids = {}, {} -- add-on-foot-excursions: turned hand-locks, grids shut down
  M.rebuild(state)
  state.sentries = {}
  for i = 1, #state.sector.sites do state.sentries[i] = sentry.new_state(rt.sentries[i], state) end
  local site1 = state.sector.sites[1]
  local door = ruinm.entrance(rt.ruins[1], site1.pos)
  local n = ctx.players or 1
  for i = 1, n do
    local x = door[1] + (i - 1 - (n - 1) / 2) * 34
    state.players[i] = M.new_player(i, { x, door[2], door[3] - 120 }, 0)
  end
  for i = 1, n do msg(state, state.players[i], "You wake up in your saucer. Press Use to get up.") end
  requests.ensure(state)
end

-- add-wider-dark: (re)generate sector `sid` into state.sector and its
-- derived data; sentries start fresh (as after a load)
function M.load_sector(state, sid)
  local g = galaxy.generate(state.seed)
  state.sector_id = sid
  state.sector = sector.generate(state.seed, sid, g.sectors[sid])
  state.bolts = {}
  state.sentries = {}
  M.rebuild(state)
  for i = 1, #state.sector.sites do state.sentries[i] = sentry.new_state(rt.sentries[i], state) end
  requests.ensure(state)
end

-- the party's fold jump lands: stash this sector, bring up the next one and
-- set every saucer down in formation at its arrival point
function M.enter_sector(state, to)
  coop.undock_all(state, ctx_fns)
  galaxy.stash(state)
  local g = galaxy.generate(state.seed)
  local info = g.sectors[to]
  local next_sector = sector.generate(state.seed, to, info)
  local fresh = { traders = trade.new_traders(next_sector), nests = {}, caches = {}, locks = {}, grids = {},
                  vault = to == 1 and { pos = vec.copy(next_sector.vault.pos), taken = false } or false,
                  decoys = {}, gifts = {}, lockdowns = {} }
  galaxy.unstash(state, to, fresh)
  M.load_sector(state, to)
  local n = #state.players
  for i, p in ipairs(state.players) do
    local ship = p.ship
    ship.charge = math.max(0, ship.charge - galaxy.core(p).charge)
    ship.pos = galaxy.formation(state.sector, i, n)
    local d = vec.sub(state.sector.trader.pos, ship.pos)
    ship.yaw = saucer.math.atan2(d[1], d[3])
    ship.vel, ship.bank = { 0, 0, 0 }, 0
    p.site, p.docked, p.tractor, p.last_trader = 0, false, false, 1
    p.latched_by, p.clamped_by, p.shake = nil, nil, 0
    p.sectors = p.sectors or {}
    p.sectors[tostring(to)] = true
    local names = {}
    for _, ci in ipairs(info.civs) do names[#names + 1] = civs.get(state.seed, ci).name end
    msg(state, p, string.format("Fold jump complete: %s, danger %d (%s)", info.name, info.danger, table.concat(names, ", ")))
    if info.heart and mystery.active(state.mystery) then msg(state, p, "The Heart site looms ahead. Its core waits for the Heart Key.") end
    fx(state, p, "grow")
  end
  saucer.events.emit({ type = "fold_jump", to = to })
end

-- where this player's eyes are (world) and where they look: the tractor and
-- the camera both start here. On foot that is the body under the dome.
function M.viewpoint(p, state)
  if p.visiting and p.vbody then
    state = state or M.state_ref
    if state and state.players[p.visiting] then return coop.viewpoint(state, p) end
  end
  local ship = p.ship
  if p.mode == "wake" then
    local L = avatar.layout()
    local e = avatar.rot(ship.yaw, L.wake.eye)
    return { ship.pos[1] + e[1], ship.pos[2] + e[2], ship.pos[3] + e[3] }, ship.yaw + L.wake.yaw, L.wake.pitch
  end
  if p.holo_run then return holo.viewpoint(nil, p) end
  if p.mode == "foot" and p.station then return visit.viewpoint(p) end
  if p.mode == "foot" and p.excursion then return excursion.viewpoint(p) end
  local L0 = avatar.layout()
  local seat = (p.mode == "walk") and ((p.tv and L0.sofa) or (p.reading and L0.shelf) or (p.cooking and L0.stove))
  if seat then
    local e = avatar.rot(ship.yaw, seat.eye)
    return { ship.pos[1] + e[1], ship.pos[2] + e[2], ship.pos[3] + e[3] }, ship.yaw + seat.yaw, seat.pitch
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
  -- add-wider-dark: a Clamp on the hull blocks every reconfiguration
  if p.clamped_by then
    msg(state, p, "Clamped: hold Boost to shake it off, or Jam it")
    fx(state, p, "denied")
    return
  end
  -- add-pocket-station-visits: the coin size steps you out into the station
  local tc = configs.get(to)
  if tc and tc.pocket then
    -- add-on-foot-excursions: inside a derelict the Pocket means stepping out
    if p.site ~= 0 then excursion.step_out(state, p, ctx_fns) else visit.pocket(state, p, to, ctx_fns) end
    return
  end
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
  -- add-holodeck-home-life: inside a program, on the sofa, in a book, at the stove
  if p.holo_run then
    holo.use(state, p, ctx_fns)
    return
  end
  if p.tv then
    tv.next(state, p, ctx_fns)
    return
  end
  if p.reading then
    books.turn(state, p)
    return
  end
  if p.cooking then return end
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
  local unpack = {}
  for _, it in ipairs(p.hold) do
    if it.hot then
      it.hot = false
      n = n + 1
      v = v + it.value
      if it.home then unpack[#unpack + 1] = it end
    end
  end
  if n > 0 then
    p.banked_value = p.banked_value + v
    msg(state, p, string.format("Banked %d item%s (%d c)", n, n == 1 and "" or "s", v))
    fx(state, p, "bank")
  end
  -- add-holodeck-home-life: books onto the shelf, ingredients into the pantry
  for _, it in ipairs(unpack) do
    if finds.unpack(state, p, it, ctx_fns) then items.remove(p, it.uid) end
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
  if site_idx ~= 0 then M.record_trail(state, p, site_idx, cand.pos) end
  if cand.kind == "echo" then
    p.looted[cand.key] = true
    mystery.found(state.mystery, cand.echo, p.index)
    local it = items.stamp(p, cand.item, 1, civ and civ.id)
    it.hot = false -- Echoes are never lost
    p.hold[#p.hold + 1] = it
    local e = state.mystery.echoes[cand.echo]
    if e.role == "heart_key" then
      msg(state, p, string.format("Got %s. Carry it to the core of the Heart.", it.name))
    else
      msg(state, p, string.format("Got %s. Decode it at your lab bench.", it.name))
    end
    if e.role == "key" then msg(state, p, "A key fragment: it should open the Resonant vault") end
    fx(state, p, "echo")
  elseif cand.kind == "gift" then
    coop.receive(state, p, cand.index, ctx_fns)
    fx(state, p, "pickup")
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
  elseif cand.kind == "find" then
    -- add-holodeck-home-life: a data core, a module, a book or an ingredient crate
    p.looted[cand.key] = true
    local it = items.stamp(p, cand.item, 1, civ and civ.id)
    it.hot = true
    p.hold[#p.hold + 1] = it
    msg(state, p, "Got " .. items.label(it))
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
  p.scan_ready = state.tick + math.floor(t.cooldown * buffs.factor(state, p, "scan_cooldown") * 60)
  p.scan_until = state.tick + math.floor(t.reveal * buffs.factor(state, p, "scan_reveal") * 60)
  local site = p.site
  if site == 0 then
    local best, bd
    for i in ipairs(state.sector.sites) do
      local d = M.site_distance(i, p.ship.pos)
      if not bd or d < bd then best, bd = i, d end
    end
    site = best
  end
  local w, sn, cl, ld = sentry.summary(rt.sentries[site] or {})
  local danger = (state.sector_id or 1) == 1 and (site == 1 and 1 or 2) or (state.sector.sites[site].danger or 2) + 1
  msg(state, p, string.format("Scan: site %d, danger %d, %d Watcher%s, %d Snatcher%s%s", site, danger, w,
    w == 1 and "" or "s", sn, sn == 1 and "" or "s",
    (cl + ld > 0) and string.format(", %d Clamp%s, %d Lockdown", cl, cl == 1 and "" or "s", ld) or ""))
  fx(state, p, "scan")
end

local function jam(state, p)
  local t = sentry.tune().jammer
  if state.tick < p.jam_ready then
    msg(state, p, "Jammer recharging")
    fx(state, p, "denied")
    return
  end
  local on_foot = p.mode == "foot" and p.excursion
  if on_foot and (p.suit or 0) <= (t.suit or 15) then
    msg(state, p, "Not enough Suit Charge to jam")
    fx(state, p, "denied")
    return
  end
  if not on_foot and p.ship.charge < t.charge then
    msg(state, p, "Not enough Charge to jam")
    fx(state, p, "denied")
    return
  end
  if on_foot then p.suit = p.suit - (t.suit or 15) else p.ship.charge = p.ship.charge - t.charge end
  p.jam_ready = state.tick + math.floor(t.cooldown * buffs.factor(state, p, "jam_cooldown") * 60)
  p.jam_flash = state.tick + 20
  local eye, yaw, pitch = M.viewpoint(p)
  local n = 0
  if p.site ~= 0 then n = sentry.jam(state, p.site, rt.sentries[p.site], eye, vec.aim(yaw, pitch), p) end
  if p.clamped_by then
    -- the Jammer always reaches a Clamp on your own hull
    local list, defs = state.sentries[p.clamped_by.site], rt.sentries[p.clamped_by.site]
    local dyn, def = list and list[p.clamped_by.id], defs and defs[p.clamped_by.id]
    if dyn and def then
      adv.jammed(state, def, dyn, sentry.tune(), ctx_fns.seal)
      n = n + 1
    end
  end
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
    if p.site ~= 0 then excursion.left_site(state, p, p.site, ctx_fns) end
    if site == 0 then bank(state, p) else msg(state, p, "Entering derelict site " .. site) end
    p.site = site
    -- add-wider-dark: entering a site files its civ in your Xenoarchive
    if site ~= 0 and archive.meet(p, civ_of(state.sector.sites[site])) then
      msg(state, p, "New civilization: the " .. civ_of(state.sector.sites[site]).name .. " (Xenoarchive)")
    end
  end
  if site ~= 0 then M.record_trail(state, p, site) end
  if shipm.update(ship, dt, site == 0 and home.regen_factor(state, p)) == "done" then
    msg(state, p, "Configuration: " .. configs.get(ship.size).name)
  end
  if p.ghost > 0 then p.ghost = p.ghost - 1 end
  -- the belly hatch irises open while the beam pulls, and part way while the
  -- operator sits at the console so they can see down the beam (render reads p.hatch)
  local hw = p.tractor and 1 or (p.beam_console and M.HATCH_ARMED or 0)
  local hc = p.hatch or 0
  if hw > hc then p.hatch = math.min(hw, hc + 2.5 * dt) else p.hatch = math.max(hw, hc - 1.5 * dt) end
  home.doors_step(avatar.layout(), p, dt, coop.guests(state, p))
  -- add-wider-dark: the Shroud drains Charge while it is up
  if p.shroud then
    if p.mode == "foot" or ship.charge <= 0 then
      p.shroud = false
      msg(state, p, "Shroud down")
    else
      ship.charge = math.max(0, ship.charge - sentry.tune().shroud.drain * dt)
    end
  end
  -- milestone 3: docking, the lab bench, shields, Fold Retreat and the Resonant vault
  local docked = trade.docked_at(state, p)
  if docked and not p.docked then
    p.last_trader = docked
    msg(state, p, "Docked at the trader. Walk to the trade terminal to sell.")
    fx(state, p, "bank")
  end
  p.docked = docked or false
  lab.step(state, p, dt, ctx_fns)
  kitchen.step(state, p, dt, ctx_fns)
  hull.regen(ship, dt * buffs.factor(state, p, "hull_regen"))
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
  if p.site == 0 and m.vault_revealed and not m.vault_open and state.vault and vec.dist(ship.pos, state.vault.pos) < 80 then
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

-- add-wider-dark: launch a Decoy flare ahead of you (inside a site)
function M.decoy(state, p)
  local t = sentry.tune().decoy
  if p.site == 0 then
    msg(state, p, "No sentries to fool out here")
    fx(state, p, "denied")
    return false
  end
  if (p.decoys or 0) <= 0 then
    msg(state, p, "No Decoy flares left (traders sell them)")
    fx(state, p, "denied")
    return false
  end
  local eye, yaw, pitch = M.viewpoint(p, state)
  local dir = vec.aim(yaw, pitch)
  local reach = t.ahead
  local hit = saucer.physics.raycast(eye, vec.scale(dir, reach), 1, 1)
  if hit then reach = math.max(0.5, reach * hit.t - 0.5) end
  p.decoys = p.decoys - 1
  state.decoys = state.decoys or {}
  state.decoys[#state.decoys + 1] = { site = p.site, pos = vec.add(eye, vec.scale(dir, reach)), life = t.life, by = p.index }
  msg(state, p, string.format("Decoy flare out: sentries track it for %d s (%d left)", t.life // 1, p.decoys))
  fx(state, p, "scan")
  return true
end

-- add-wider-dark: the Shroud (saucer utility) on or off
function M.shroud(state, p)
  if p.mode == "foot" then
    msg(state, p, "The Shroud is a saucer utility")
    fx(state, p, "denied")
    return false
  end
  p.shroud = not p.shroud
  msg(state, p, p.shroud and "Shroud up: hover still and Watchers can't see you (drains Charge)" or "Shroud down")
  fx(state, p, p.shroud and "scan" or "click")
  return p.shroud
end

-- add-wider-dark: hold the Override spike in a Disabled sentry (or a Lockdown node)
function M.spike_step(state, p, cmd, dt)
  local t = sentry.tune().spike
  if not cmd:held("spike") then
    p.spike = false
    return
  end
  local idx = adv.spike_target(state, p, sentry.tune())
  if not idx then
    if cmd:pressed("spike") then
      msg(state, p, "Override spike: get within 3 m of a Disabled sentry or a Lockdown node")
      fx(state, p, "denied")
    end
    p.spike = false
    return
  end
  if not p.spike or p.spike.idx ~= idx or p.spike.site ~= p.site then
    p.spike = { site = p.site, idx = idx, t = 0 }
    msg(state, p, "Override spike in: hold for 3 s")
  end
  p.spike.t = p.spike.t + dt
  if p.spike.t < t.time then return end
  local def, dyn = rt.sentries[p.site][idx], state.sentries[p.site][idx]
  if def.kind == "lockdown" and #(dyn.sealed or {}) > 0 then M.seal(def, dyn, false) end
  if dyn.st == "clamped" then adv.release(state, dyn) end
  dyn.st, dyn.t, dyn.target = "off", 0, 0
  state.overrides = state.overrides or {}
  state.overrides[adv.key(def)] = state.tick
  p.spike = false
  local core = items.stamp(p, adv.core_item(), 2, nil)
  core.hot = true
  if #(p.hands or {}) < 4 then p.hands[#p.hands + 1] = core else p.hold[#p.hold + 1] = core end
  msg(state, p, "Override complete: the " .. def.kind .. " is shut down for good. Sentry core in hand.")
  fx(state, p, "bank")
end

function M.step_player(state, p, cmd, dt)
  local ship = p.ship
  -- add-wider-dark: the sector map, shaking off a Clamp
  if cmd:held("boost") and p.clamped_by then p.shake = (p.shake or 0) + dt end
  if cmd:pressed("map") and p.mode ~= "wake" then
    local k = p.panel and p.panel.kind
    if k == "map" or k == "party" or k == "archive" then p.panel = false
    elseif not p.panel then panel.open(p, "map") end
  end
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
    if p.mode ~= "foot" then flight.step(ship, STILL, dt, mover(state, p))
    elseif p.station then visit.panel_step(state, p, dt, ctx_fns) end
    world_step(state, p, dt)
    return
  end
  if p.mode == "wake" then home.get_up(state, p, ctx_fns) end
  -- add-wider-dark: a guest walking a docked friend's dome
  if p.visiting then
    coop.step_visit(state, p, cmd, dt, ctx_fns)
    flight.step(ship, STILL, dt, mover(state, p))
    world_step(state, p, dt)
    return
  end
  -- add-pocket-station-visits: on foot in a station the saucer is a coin in
  -- your pocket; walking, trading and the pickpocket live in sim/visit.lua
  if p.mode == "foot" and p.station then
    visit.step(state, p, cmd, dt, ctx_fns)
    world_step(state, p, dt)
    return
  end
  -- add-on-foot-excursions: on foot in a derelict (sim/excursion.lua); the
  -- Scanner and the Jammer go with you
  if p.mode == "foot" and p.excursion then
    if cmd:pressed("scan") then scan(state, p) end
    if cmd:pressed("jam") then jam(state, p) end
    if cmd:pressed("decoy") then M.decoy(state, p) end
    M.spike_step(state, p, cmd, dt)
    excursion.step(state, p, cmd, dt, ctx_fns)
    world_step(state, p, dt)
    return
  end
  -- add-holodeck-home-life: inside a holodeck program the stick moves you
  -- through the simulated space (or flies the simulated Seat); the saucer
  -- holds station meanwhile. On the sofa, in a book or at the stove you sit still.
  if p.holo_run then
    if cmd:pressed("use") then use(state, p) end
    if p.holo_run then holo.step(state, p, cmd, dt, ctx_fns) end
    flight.step(ship, STILL, dt, mover(state, p))
    world_step(state, p, dt)
    return
  end
  if p.tv or p.reading or p.cooking then
    if cmd:pressed("use") then use(state, p) end
    local moving = math.abs(cmd:axis("move_x")) > 0.5 or math.abs(cmd:axis("move_z")) > 0.5
    if moving and not p.cooking then
      if p.tv then msg(state, p, "You get up from the sofa.") end
      p.tv, p.reading = false, false
    end
    flight.step(ship, STILL, dt, mover(state, p))
    world_step(state, p, dt)
    return
  end
  if cmd:pressed("use") then use(state, p) end
  if cmd:pressed("scan") then scan(state, p) end
  if cmd:pressed("jam") then jam(state, p) end
  if cmd:pressed("decoy") then M.decoy(state, p) end
  if cmd:pressed("shroud") then M.shroud(state, p) end
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
    ship.yaw = saucer.math.wrap(ship.yaw + comfort.snap(cmd))
    p.body.pitch = vec.clamp(p.body.pitch + cmd:axis("look") * L.look * dt, -L.pitch_limit, L.pitch_limit)
  else
    -- nobody at the helm: the saucer brakes to a stop and holds station
    flight.step(ship, STILL, dt, mover(state, p))
    local L = avatar.layout()
    avatar.step(p.body, { move_x = cmd:axis("move_x"), move_z = cmd:axis("move_z"), turn = cmd:axis("turn"),
                          look = cmd:axis("look"), run = cmd:held("boost"), aim = cmd.aim }, dt, L, home.solids(L, p))
    p.body.yaw = saucer.math.wrap(p.body.yaw + comfort.snap(cmd))
  end
  world_step(state, p, dt)
  tractor_step(state, p, cmd, dt)
end

-- add-holodeck-home-life: every second inside a derelict the saucer's
-- position joins that site's trail (the holodeck replays it); pick-ups are marked
M.TRAIL_EVERY = 60
M.TRAIL_MAX = 240
local function q1(x) return math.floor(x * 10 + 0.5) / 10 end
function M.record_trail(state, p, site, mark)
  p.trails = p.trails or {}
  local key = tostring(site)
  local t = p.trails[key]
  if not t then
    t = { pts = {}, marks = {} }
    p.trails[key] = t
  end
  local pos = p.ship.pos
  if mark then
    t.marks[#t.marks + 1] = { q1(mark[1]), q1(mark[2]), q1(mark[3]) }
    return t
  end
  if state.tick % M.TRAIL_EVERY ~= 0 and #t.pts > 0 then return t end
  t.pts[#t.pts + 1] = { q1(pos[1]), q1(pos[2]), q1(pos[3]) }
  if #t.pts > M.TRAIL_MAX then
    -- keep the whole route at half the resolution
    local half = {}
    for i = 1, #t.pts, 2 do half[#half + 1] = t.pts[i] end
    t.pts = half
  end
  return t
end

function M.step(state, cmds, dt)
  M.state_ref = state
  state.tick = state.tick + 1
  -- add-wider-dark: a player slot that is not in the game yet joins on its
  -- first button press (slots fill in order)
  for i = #state.players + 1, math.min(#cmds, 4) do
    if cmds[i] and coop.wants_join(cmds[i]) then coop.join(state, i, ctx_fns) else break end
  end
  for i = 1, #state.players do
    local p = state.players[i]
    if p and cmds[i] then M.step_player(state, p, cmds[i], dt) end
  end
  -- sentries act once per tick for everyone, then their stun bolts fly
  for i = 1, #state.sector.sites do sentry.step(state, i, rt.sentries[i], dt, ctx_fns) end
  sentry.step_bolts(state, dt)
  -- add-wider-dark: decoys burn out; docks, the Heart and the party's fold jump
  local keep = {}
  for _, d in ipairs(state.decoys or {}) do
    d.life = d.life - dt
    if d.life > 0 then keep[#keep + 1] = d end
  end
  state.decoys = keep
  coop.step(state, ctx_fns)
  heart.step(state, ctx_fns)
  galaxy.step(state, dt, ctx_fns, M.enter_sector)
end

home.register_panels(M, ctx_fns)
decor.register(home, ctx_fns)
visit.register_panels(ctx_fns)
-- add-wider-dark panels
panel.register("map", { title = "SECTOR MAP", rows = function(state, p) return galaxy.rows(state, p, ctx_fns) end })
panel.register("party", { title = "PARTY", rows = function(state, p) return coop.rows(state, p, ctx_fns) end })
panel.register("archive", { title = "XENOARCHIVE", rows = function(state, p) return archive.rows(state, p) end })
panel.register("heart", { title = "THE HEART", rows = function(state, p) return heart.rows(state, p) end })
panel.register("gift_table", { title = "GIFT TABLE", rows = function(state, p) return coop.gift_rows(state, p, ctx_fns) end })

function M.on_event(ev, state)
  -- base keeps no extra bookkeeping; mods listen for "size_change"/"loot"
  return ev.type
end

return M
