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
local story = require("sim.story")
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
local megacity = require("sim.citymega") -- add-alien-cities-2
local planet = require("sim.planet") -- add-generated-planets
local requests = require("sim.requests")
local coop = require("sim.coop")
local adv = require("sim.advsentry")
local heart = require("sim.heart")
local decor = require("sim.decor")
-- add-playtest-recs
local upgrades = require("sim.upgrades")
local twin = require("sim.twin")
local cities = require("sim.cities")
local beamqueue = require("sim.beamqueue")
local claims = require("sim.claims")
-- add-dock-land-eva
local landing = require("sim.landing")
local hulldoor = require("sim.hulldoor")
local stealth = require("sim.stealth")
local lightsm = require("sim.lights")
local relic = require("sim.relic")
local M = {}

M.SITE_PAD = 30
M.MAX_MSGS = 8 -- add-playtest-recs: room for a tip next to a lock cycle
M.MAX_FX = 8

local rt = { ruins = {}, bounds = {}, sentries = {}, shutters = {}, seals = {}, gates = {}, fallen = {}, bridge_box = {},
             relic_locks = {} } -- derived, rebuilt on restore

function M.ruin(i) return rt.ruins[i] end
function M.site_bounds(i) return rt.bounds[i] end
function M.sentries(i) return rt.sentries[i] or {} end

-- add-wider-dark: civs come from the universe's generated list (sim/civs.lua)
local function civ_of(site)
  if site.relic_civ then return civs.by_id(nil, site.relic_civ) end -- add-relic-stations: the slice's Vyrr
  return civs.get(civs.current() or 0, site.civ)
end
M.civ_of = civ_of

-- extra static boxes { min, max } that survive a rebuild (tests build landing platforms here)
M.extra_solids = {}

function M.rebuild(state)
  M.state_ref = state
  saucer.physics.clear()
  for _, b in ipairs(M.extra_solids) do saucer.physics.add_box(b[1], b[2], 1) end
  -- add-dock-land-eva: every station's hangar bay
  for _, b in ipairs(require("sim.dock").solids(state)) do saucer.physics.add_box(b[1], b[2], 1) end
  -- add-huge-stations: the hulls the cells hang from (arms, hubs, rings, pods and arrays)
  for _, b in ipairs(require("sim.stationhull").world_solids(state)) do saucer.physics.add_box(b[1], b[2], 1) end
  civs.use(state.seed)
  rt.ruins, rt.bounds, rt.sentries, rt.shutters, rt.seals, rt.gates = {}, {}, {}, {}, {}, {}
  rt.fallen, rt.bridge_box, rt.relic_locks = {}, {}, {}
  for i, site in ipairs(state.sector.sites) do
    local r = ruinm.generate(site.seed, site.kit, civ_of(site), site.pos, nil, site.first, site.siblings)
    if site.relic then require("sim.relicloot").apply(site, r) end   -- add-relic-stations: the warrens' share
    -- add-relic-locks: the relic's foot pockets, its sealed chambers and their locks (a derived copy of the ruin)
    if r and r.relic then r = require("sim.relicfoot").derive(site, r, civ_of(site), state.seed) end
    rt.ruins[i] = r
    rt.sentries[i] = sentry.layout(site, r, civ_of(site))
    -- add-strategic-sentries: cover pillars and a guarded find in every Watcher hall (once per ruin)
    stealth.decorate(site, r, rt.sentries[i])
    local lo, hi = ruinm.bounds(r, site.pos, M.SITE_PAD)
    rt.bounds[i] = { lo, hi }
    for _, b in ipairs(r.walls) do saucer.physics.add_box(b[1], b[2], 1) end
    for _, b in ipairs(r.debris) do saucer.physics.add_box(b[1], b[2], 1) end
    -- relic-room-shapes: the solid round a shaped hall's floor (sim/relicshape.lua)
    for _, b in ipairs(r.fill or {}) do saucer.physics.add_box(b[1], b[2], 1) end
    rt.fallen[i], rt.bridge_box[i] = {}, {}
    local bridge_at = {}
    for _, bi in ipairs(r.city and r.city.bridges or {}) do bridge_at[bi] = true end
    for si, b in ipairs(r.solids or {}) do
      local id = saucer.physics.add_box(b[1], b[2], 1)
      if bridge_at[si] then rt.bridge_box[i][si] = id end
    end
    -- add-cities-2: a sky-bridge that has already torn loose (by the clock) is not rebuilt
    for si, id in pairs(rt.bridge_box[i]) do
      local ft = cities.fall_tick(r, r.solids[si])
      if ft and state.tick >= ft then
        saucer.physics.remove(id)
        rt.fallen[i][si] = true
      end
    end
    -- add-on-foot-excursions: sealed shutters stay solid until their hand-lock turns
    rt.shutters[i] = {}
    for _, sh in ipairs(r.foot and r.foot.shutters or {}) do
      if not excursion.lock_open(state, i, sh.id) then rt.shutters[i][sh.id] = saucer.physics.add_box(sh.min, sh.max, 1) end
    end
    -- add-relic-stations: a Seat-lock's shutter stays solid until the Seat turns its socket
    if r.relic then
      rt.relic_locks[i] = {}
      for _, l in ipairs(r.relic.locks) do
        if not relic.lock_open(state, i, l.id) then rt.relic_locks[i][l.id] = saucer.physics.add_box(l.box[1], l.box[2], 1) end
      end
    end
    -- add-cities: the gates of every dark district stay solid until its power coupling is restored
    rt.gates[i] = {}
    for _, g in ipairs(r.city and r.city.gates or {}) do
      if not cities.powered(state, i, r, g.district) then
        rt.gates[i][g.id] = { box = saucer.physics.add_box(g.box[1], g.box[2], 1), district = g.district }
      end
    end
  end
  -- add-alien-cities-2: the outer districts near a player are solid again (the physics world was just cleared)
  megacity.reset()
  M.mega_sync(state)
  -- add-generated-planets: the body's surface around the city
  planet.clear()
  planet.sync(state)
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

-- add-alien-cities-2: every city's outer districts within reach of a ship are solid (sim/citymega.lua)
local function station_ball(state)
  return function(idx)
    local c, rr = require("sim.stationhull").bounds(state, idx)
    return c, rr
  end
end
function M.mega_sync(state) megacity.sync(state, M.ruin, station_ball(state)) end
-- the outer-district plan of city site i (nil for any other site)
function M.mega_plan(state, i)
  local site = state.sector.sites[i]
  if not (site and site.city) then return nil end
  return megacity.get_plan(rt.ruins[i], state.sector, i, station_ball(state))
end
-- the city whose megacity footprint (plus pad m) holds pos -> site index, ruin, plan
function M.mega_city_at(state, pos, pad)
  for i, site in ipairs(state.sector.sites) do
    local p = site.city and M.mega_plan(state, i)
    if p then
      local h = p.span / 2 + (pad or 0)
      if math.abs(pos[1] - p.frame.cx) <= h and math.abs(pos[3] - p.frame.cz) <= h then return i, rt.ruins[i], p end
    end
  end
  return nil
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

-- add-relic-stations: a Seat-lock turned: its shutter stops being solid
function M.open_relic_lock(site, id)
  local list = rt.relic_locks[site]
  local box = list and list[id]
  if not box then return false end
  saucer.physics.remove(box)
  list[id] = nil
  return true
end
function M.relic_lock_closed(site, id) return rt.relic_locks[site] ~= nil and rt.relic_locks[site][id] ~= nil end

-- a hand-lock turned: its shutter stops being solid
function M.open_shutter(site, id)
  local list = rt.shutters[site]
  local box = list and list[id]
  if not box then return false end
  saucer.physics.remove(box)
  list[id] = nil
  return true
end
-- add-cities: a district's power came back: its gates stop being solid
function M.open_gates(site, district)
  local n = 0
  for id, g in pairs(rt.gates[site] or {}) do
    if g.district == district then
      saucer.physics.remove(g.box)
      rt.gates[site][id] = nil
      n = n + 1
    end
  end
  return n
end
function M.gates(site) return rt.gates[site] or {} end
-- add-cities-2: has this sky-bridge (solid index) torn loose?
function M.bridge_fallen(site, si) return rt.fallen[site] ~= nil and rt.fallen[site][si] == true end
function M.gates_closed(site, district)
  local n = 0
  for _, g in pairs(rt.gates[site] or {}) do if district == nil or g.district == district then n = n + 1 end end
  return n
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
    lights = { head = lightsm.DEFAULT.head, flood = lightsm.DEFAULT.flood, cabin = lightsm.DEFAULT.cabin },
    hold = {}, credits = 0, banked_value = 0, looted = {}, lab = lab.new(), next_uid = 0, last_trader = 1,
    scan_ready = 0, jam_ready = 0, scan_until = 0, jam_flash = 0,
    site = 0, tractor = false, ghost = 0, cam = "first", help = false, panel = false,
    beam_console = false, hatch = 0,
    -- add-holodeck-home-life: what a running program, the TV, an open book
    -- or the stove are doing right now (transient), and the home itself
    holo_run = false, tv = false, reading = false, cooking = false,
    buffs = {}, trails = {}, leads = {},
    msgs = {}, fx = {},
    -- add-fun-fixes: the helm beam relay comes fitted (small finds pull from the helm)
    upgrades = { beam_relay = 1 },
    -- add-on-foot-excursions: the suit (the only meter on foot) and 4 hand slots
    excursion = false, suit = 100, hands = {},
    -- add-wider-dark: Fold Core tier, tools, reputation, Xenoarchive, per
    -- sector memories, a dome visit
    fold_tier = 1, decoys = sentry.tune().decoy.start, shroud = false, shake = 0, spike = false,
    rep = {}, archive = {}, met = {}, archive_rewards = {}, away = {}, visiting = false,
    -- add-dock-land-eva: the saucer's berth (landed or docked), the hull door and the helmet
    berth = false, door = false, suited = false, dock_off = false,
  }
  holo.ensure(p)
  kitchen.ensure(p)
  books.ensure(p)
  home.wake(p)
  return p
end

M.VERSION = 22 -- state version; saves made by a newer game are refused

function M.init(state, ctx)
  M.state_ref = state
  local seed = ctx.seed
  state.version = M.VERSION  -- v21: styled relics use non-rectangular room-plan patterns (vary-relic-room-plans); v20: relics in far sectors, guarded, with their explored rooms and scans remembered (add-relic-stations, plan phase 8); v19: alien stations, bigger, move the trader, the far hangar and grow an alien wing inside (add-alien-stations); v18: realistic lighting (add-realistic-lighting); v17: suspicion meters, site alarms, guarded finds, cover, power cells, Spotters (add-strategic-sentries); v16: the fun fixes (add-fun-fixes); v15: megastructure stations move the trader and the far hangar (add-huge-stations); v14: landing gear, the hull hatch and the suit (add-dock-land-eva); v13: the run story (add-run-story); v12: sliding doors keep a goal and a hold timer (fix-bedroom-door); v11: seed-plus-diff saves (save format 3); v10: playtest recommendations (add-playtest-recs); v9: the wider dark (add-wider-dark); v8: on-foot excursions; v7: station visits
  state.seed = seed
  state.tick = 0
  civs.use(seed)
  state.sector_id = 1
  state.sector = sector.generate(seed)
  local g = galaxy.generate(seed)
  state.mystery = mystery.generate(seed, "on", #state.sector.sites, g)
  -- add-run-story: the story of this run, a pure function of the seed (progress is saved, the text is not)
  state.story = story.generate(seed, state.mystery, g)
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
  state.alarm = {} -- add-strategic-sentries: site alarms (live, like the sentries)
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
  if ctx.hardcore then state.hardcore = true end
  requests.ensure(state)
  -- add-relic-stations: the debug entry adds the Vyrr relic and starts the party at its maw
  if ctx.relic_slice then relic.spawn_slice(state) end
end

-- add-wider-dark: (re)generate sector `sid` into state.sector and its
-- derived data; sentries start fresh (as after a load)
function M.load_sector(state, sid)
  local g = galaxy.generate(state.seed)
  state.sector_id = sid
  state.sector = sector.generate(state.seed, sid, g.sectors[sid])
  state.bolts = {}
  state.sentries = {}
  state.alarm = {}
  M.rebuild(state)
  for i = 1, #state.sector.sites do state.sentries[i] = sentry.new_state(rt.sentries[i], state) end
  requests.ensure(state)
end

-- the party's fold jump lands: stash this sector, bring up the next one and
-- set every saucer down in formation at its arrival point
-- relic-room-shapes: while the Fold Core spools, each tick draws one relic of the sector ahead (sim/relicgen.lua warm;
-- generation is pure and memoized), so the jump's tick finds its relics drawn. A relic kept unlike its species'
-- earlier relics draws those as well, more than one tick's instruction budget would hold. Never on the jump's own
-- tick; derived data only (nothing in the state changes)
local warm = { key = false }
function M.warm_jump(state, dt)
  local j = state.jump
  if not j or not j.spool or j.spool < 0 or j.spool - dt <= 1e-9 then return end
  local key = tostring(state.seed) .. ":" .. tostring(j.to)
  if warm.key ~= key then warm.key, warm.sites, warm.done = key, false, false end
  if warm.done then return end
  if not warm.sites then
    warm.sites = sector.generate(state.seed, j.to, galaxy.generate(state.seed).sectors[j.to]).sites
    return
  end
  local gen = require("sim.relicgen")
  for _, site in ipairs(warm.sites) do
    if site.relic and not gen.warm(site.seed, ruinm.kit_of(site.kit), civ_of(site), site.pos, site.siblings) then
      return
    end
  end
  warm.done = true
end

function M.enter_sector(state, to)
  coop.undock_all(state, ctx_fns)
  galaxy.stash(state)
  local g = galaxy.generate(state.seed)
  local info = g.sectors[to]
  local next_sector = sector.generate(state.seed, to, info)
  local fresh = { traders = trade.new_traders(next_sector), nests = {}, caches = {}, locks = {}, grids = {},
                  vault = to == 1 and { pos = vec.copy(next_sector.vault.pos), taken = false } or false,
                  decoys = {}, gifts = {}, lockdowns = {}, twins = {} }
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
    p.braved = math.max(p.braved or 1, info.danger)
    p.ready_fold = false
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

-- add-multiplayer-foundation 1.4 (anti-blocking fold-phase): two saucers that are already overlapping
-- (a spawn, a fold) or that one of them is folding pass through each other instead of pinning the pair,
-- and a player who pushes into another saucer for PUSH_SECONDS without getting anywhere phases through
-- that saucer for PHASE_SECONDS. state.phase[<low>:<high>] = { n = ticks pushed, last = tick, untl = tick }
-- exists only once two saucers have actually bumped, so a game without co-op contact is unchanged.
M.PUSH_SECONDS = 2
M.PHASE_SECONDS = 3
local function pair_key(a, b) return math.min(a.index, b.index) .. ":" .. math.max(a.index, b.index) end
function M.phased(state, a, b)
  if a.ship.morph or b.ship.morph then return true end
  -- the party has agreed to a fold jump: nobody's hull may hold the others' fold back
  if state.jump and state.jump ~= false and galaxy.agreed(state) then return true end
  local e = state.phase and state.phase[pair_key(a, b)]
  return e ~= nil and (e.untl or 0) > state.tick
end
local function pushed(state, p, o)
  state.phase = state.phase or {}
  local k = pair_key(p, o)
  local e = state.phase[k] or { n = 0, last = 0, untl = 0 }
  state.phase[k] = e
  if e.last ~= state.tick then
    e.n = (e.last == state.tick - 1) and e.n + 1 or 1
    e.last = state.tick
  end
  if e.n >= M.PUSH_SECONDS * 60 then
    e.n, e.untl = 0, state.tick + M.PHASE_SECONDS * 60
    msg(state, p, string.format("You have been pushing P%d for a while: your saucers phase through each other for %d s", o.index, M.PHASE_SECONDS))
    msg(state, o, string.format("P%d is stuck against you: your saucers phase through each other for %d s", p.index, M.PHASE_SECONDS))
    fx(state, p, "grow")
  end
end

-- hull blocked by walls or by other players' saucers?
function M.blocked(state, self, pos, r, hh, margin)
  if not saucer.physics.clearance(pos, r, hh, margin, 1) then return true end
  for _, o in ipairs(state.players) do
    if o ~= self then
      local orr, ohh = shipm.dims(o.ship)
      if vec.hulls_overlap(pos, r, hh, o.ship.pos, orr, ohh, margin) and not (self and M.phased(state, self, o)) then
        return true
      end
    end
  end
  return false
end

local function mover(state, p)
  return function(ship, delta)
    local r, hh = shipm.dims(ship)
    local np, blocked = saucer.physics.move(ship.pos, r, hh, delta, 1)
    -- fix-station-hull: the trader stations' spinning layer (halos, helices, shells) pushes the hull out
    local spun, hit = require("sim.stationhull").spin_push(state, np, r)
    if hit > 0 then np, blocked = spun, blocked + 1 end
    -- add-generated-planets: don't sink through the body
    local lifted = planet.clamp(np, hh)
    if lifted[2] ~= np[2] then np, blocked = lifted, blocked + 1 end
    for _, o in ipairs(state.players) do
      if o ~= p then
        local orr, ohh = shipm.dims(o.ship)
        if vec.hulls_overlap(np, r, hh, o.ship.pos, orr, ohh, 0) then
          -- already inside each other (a spawn, a fold) or phasing: nothing to collide with
          if not (M.phased(state, p, o) or vec.hulls_overlap(ship.pos, r, hh, o.ship.pos, orr, ohh, 0)) then
            pushed(state, p, o)
            return vec.copy(ship.pos), blocked + 1
          end
        end
      end
    end
    return np, blocked
  end
end

-- (specs move a ship through the same collision as flight)
function M.move_for_test(state, p, delta)
  p.ship.pos = vec.copy(p.ship.pos)
  return mover(state, p)(p.ship, delta)
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
    -- add-dock-land-eva: the Villa no longer pops you out into a derelict: land, walk out through the
    -- hull hatch and fold it from outside; at a station the tractor beam tows it into the bay first. (The
    -- one-seat Seat has no stairs and still steps out.)
    if configs.get(from).interior then
      msg(state, p, p.site ~= 0 and "Land (L at the helm), leave through the hull hatch aft of the engine room, then fold the Villa from outside"
        or "Dock in a station's bay (its tractor beam tows you in), leave through the hull hatch, then fold the Villa from outside")
      fx(state, p, "denied")
      return
    end
    if p.site ~= 0 then excursion.step_out(state, p, ctx_fns) else visit.pocket(state, p, to, ctx_fns) end
    return
  end
  -- add-dock-land-eva: no reconfiguring on the ground with the gear down
  if p.berth then
    msg(state, p, "The gear is down: lift off before reshaping the hull")
    fx(state, p, "denied")
    return
  end
  local eye, yaw
  if p.mode == "walk" then eye, yaw = M.viewpoint(p) end
  local blocked = function(pos, r, hh, margin) return M.blocked(state, p, pos, r, hh, margin) end
  -- add-relic-stations: growing back in a relic's cradle bay is free
  local free = relic.free_regrow(state, p, to)
  local ok, why, where = shipm.request(ship, to, blocked, eye, yaw, free)
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
    -- add-relic-stations: at a Seat-lock's socket, Use turns it (held: sim/relic.lua)
    if relic.socket_near(state, p) then
      msg(state, p, "Seat-lock: hold Use to turn it")
      return
    end
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
    elseif t.kind == "cell" and sentry.locked_on(state, p) then why = "Caught at the power cell: the beam let go"
    elseif t.shaken then why = "A bolt hit shook the beam loose"
    elseif cand.guarded and sentry.guard_on(state, t.site, M.sentries(t.site), p, cand.guarded) then
      why = "The guard saw the beam: the find dropped back"
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
      local owner = claims.is_shared(cand.kind) and claims.claimed_by(state, t.site, t.key) or nil
      if owner and owner ~= p.index then
        msg(state, p, string.format("P%d already claimed that", owner))
        fx(state, p, "denied")
      else
        M.pick_up(state, p, cand, t.site)
      end
    end
    return
  end
  local b = tractor.beam_of(ship)
  local _, heading = M.viewpoint(p)
  local ruin = rt.ruins[p.site]
  -- add-tractor-beam (gameplay gaps): a queued find that comes into lock is pulled by itself, by whoever
  -- may pull it from where they are (the console for any size, the helm for what the relay lifts)
  local function may(cand)
    if not b.console then return true end
    if p.beam_console then return true end
    return p.mode == "helm" and upgrades.relay(p, cand.item)
  end
  if not cmd:pressed("tractor") then
    if p.beam_queue then
      local qc, qi = beamqueue.next(state, p, ruin, heading, may)
      if qc then
        if #p.hold >= upgrades.hold_slots(p) and qc.kind ~= "cache" and qc.kind ~= "anchor" and qc.kind ~= "coupling" and qc.kind ~= "clue" and qc.kind ~= "story" then
          if not p.beam_queue.warned then
            p.beam_queue.warned = true
            msg(state, p, "Hold is full: the beam queue waits")
          end
        else
          beamqueue.remove(p, qc.key)
          local relay = b.console and not p.beam_console and p.mode == "helm" and upgrades.relay(p, qc.item) or nil
          p.tractor = { key = qc.key, site = p.site, t = 0,
                        total = tractor.pull_time(ship, qi.depth, qc.kind) * upgrades.pull_factor(p),
                        from = vec.copy(qc.pos), size = ship.size, console = b.console and not relay, item_size = qc.item.size,
                        kind = qc.kind, relay = relay }
          msg(state, p, "Queued find in lock: pulling up " .. items.label(qc.item))
          fx(state, p, "tractor")
        end
      end
    end
    return
  end
  local sc = tractor.scan(state, p, p.site, ruin, heading)
  -- add-playtest-recs: with the helm beam relay the helm pulls small finds itself
  local relay = b.console and not p.beam_console and p.mode == "helm" and sc and upgrades.relay(p, sc.cand.item)
  -- a find that is not in lock yet, or that needs the Tractor Room's console, joins the queue
  local locked_here = sc and sc.status == "lock" and (not b.console or p.beam_console or relay)
  if sc and not locked_here and (p.beam_console or p.mode == "helm") and sc.status ~= "big" and sc.status ~= "sealed"
      and (b.console or sc.status ~= "lock") then
    local what = beamqueue.toggle(p, sc.cand.key, items.label(sc.cand.item))
    if what == "added" then
      local where = (b.console and not p.beam_console)
          and " The beam runs from the Tractor Room below the lower deck: go down and it takes the find when it is in lock."
          or " The beam takes it when it is in lock."
      msg(state, p, string.format("%sQueued %s (%d/%d).%s",
        sc.status ~= "lock" and ("Beam: " .. sc.info.hint:lower() .. ". ") or "", items.label(sc.cand.item),
        #beamqueue.keys(p), beamqueue.MAX, where))
      fx(state, p, "scan")
    elseif what == "removed" then
      msg(state, p, "Took " .. items.label(sc.cand.item) .. " off the beam queue")
    else
      msg(state, p, string.format("The beam queue is full (%d)", beamqueue.MAX))
      fx(state, p, "denied")
    end
    return
  end
  if b.console and not p.beam_console and not relay then
    if p.mode == "helm" and sc and sc.status == "lock" and upgrades.level(p, "beam_relay") > 0 then
      msg(state, p, "Too big for the helm relay: pull it from the Tractor Room console.")
    elseif p.mode == "helm" then
      msg(state, p, "The beam runs from the Tractor Room below the lower deck. Line up, then go down: hover-hold keeps you here.")
    else
      msg(state, p, "Use the beam console in the Tractor Room (stairs down beside the engine).")
    end
    fx(state, p, "denied")
    return
  end
  if not sc then
    msg(state, p, "Nothing under the beam")
    fx(state, p, "denied")
  elseif sc.status ~= "lock" then
    msg(state, p, "Beam: " .. sc.info.hint:lower())
    fx(state, p, "denied")
  elseif sc.cand.kind ~= "cache" and sc.cand.kind ~= "anchor" and sc.cand.kind ~= "coupling" and sc.cand.kind ~= "clue" and sc.cand.kind ~= "story" and #p.hold >= upgrades.hold_slots(p) then
    msg(state, p, "Hold is full")
    fx(state, p, "denied")
  else
    local cand = sc.cand
    beamqueue.remove(p, cand.key)
    p.tractor = { key = cand.key, site = p.site, t = 0,
                  total = tractor.pull_time(ship, sc.info.depth, sc.cand.kind) * upgrades.pull_factor(p),
                  from = vec.copy(cand.pos), size = ship.size, console = b.console and not relay, item_size = cand.item.size,
                  kind = cand.kind, relay = relay or nil }
    msg(state, p, (relay and "Helm relay lock: pulling up " or "Beam lock: pulling up ") .. items.label(cand.item))
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
  elseif cand.kind == "anchor" then
    -- add-playtest-recs: the anchor stays put; the beam latches the shutter open
    if twin.hold(state, p, site_idx, ctx_fns) then fx(state, p, "tractor") end
  elseif cand.kind == "twin" then
    twin.take(state, p, site_idx, ctx_fns)
  elseif cand.kind == "coupling" then
    -- add-cities: the coupling is beamed home: the district wakes and its gates open
    local r = rt.ruins[site_idx]
    if not cities.powered(state, site_idx, r, cand.district) then
      cities.restore(state, site_idx, cand.district)
      local n = M.open_gates(site_idx, cand.district)
      local on, total = cities.grid(state, site_idx, r)
      msg(state, p, string.format("Power restored: %s district live (%d gate%s open), grid %d/%d", r.city.districts[cand.district].label,
        n, n == 1 and "" or "s", on, total))
      for _, o in ipairs(state.players) do
        if o ~= p and o.site == site_idx then msg(state, o, string.format("P%d restored the %s district", p.index, r.city.districts[cand.district].label)) end
      end
      for _, o in ipairs(state.players) do
        if o.site == site_idx then fx(state, o, "gridon") end
      end
    end
  elseif cand.kind == "clue" then
    -- add-cities-2: an archive record is read in place
    p.looted[cand.key] = true
    msg(state, p, cities.clue_text(state, site_idx, rt.ruins[site_idx], cand.district))
    fx(state, p, "echo")
  elseif cand.kind == "story" then
    -- add-run-story: a wreck log, a mural or an archive record is read in place
    story.read(state, cand.story, p, ctx_fns)
  elseif cand.kind == "cell" then
    -- add-strategic-sentries: the turret's power cell is out: dark for good, and the cell sells
    local def = cand.def
    local dyn = state.sentries[site_idx] and state.sentries[site_idx][def.id]
    if dyn then dyn.st, dyn.t, dyn.target, dyn.meter = "off", 0, 0, 0 end
    state.overrides = state.overrides or {}
    state.overrides[adv.key(def)] = state.tick
    local it = items.stamp(p, cand.item, 2, nil)
    it.hot = true
    p.hold[#p.hold + 1] = it
    p.sabotaged = (p.sabotaged or 0) + 1
    msg(state, p, "Power cell out: the Watcher goes dark for good. Got " .. items.label(it))
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
    while #c.items > 0 and #p.hold < upgrades.hold_slots(p) do
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
  p.scan_until = state.tick + math.floor(t.reveal * buffs.factor(state, p, "scan_reveal") * shipm.mult(p.ship, "scan_range") * 60)
  local site = p.site
  if site == 0 then
    local best, bd
    for i in ipairs(state.sector.sites) do
      local d = M.site_distance(i, p.ship.pos)
      if not bd or d < bd then best, bd = i, d end
    end
    site = best
  end
  local w, sn, cl, ld, wd, sp = sentry.summary(rt.sentries[site] or {})
  local danger = (state.sector_id or 1) == 1 and (site == 1 and 1 or 2) or (state.sector.sites[site].danger or 2) + 1
  msg(state, p, string.format("Scan: site %d, danger %d, %d Watcher%s, %d Snatcher%s%s%s%s", site, danger, w,
    w == 1 and "" or "s", sn, sn == 1 and "" or "s",
    (cl + ld > 0) and string.format(", %d Clamp%s, %d Lockdown", cl, cl == 1 and "" or "s", ld) or "",
    wd > 0 and ", A WARDEN" or "", (sp or 0) > 0 and string.format(", %d Spotter%s", sp, sp == 1 and "" or "s") or ""))
  -- add-strategic-sentries: the guarded finds (under a Watcher's sweep) and the alarm
  local g = #stealth.guarded(rt.ruins[site], p, site)
  if g > 0 then
    msg(state, p, string.format("Scan: %d GUARDED find%s in Watcher sweeps (worth %.1fx); cones and cells marked",
      g, g == 1 and "" or "s", stealth.tune().guard.premium))
  end
  local lv = stealth.level(state, site)
  if lv > 0 then msg(state, p, string.format("Scan: site alarm %d/%d", lv, stealth.tune().alarm_max)) end
  local n, best = M.scan_finds(state, p, site)
  if n > 0 then
    msg(state, p, string.format("Scan: %d find%s left; the best, %s (~%d c), lies in room %d", n, n == 1 and "" or "s",
      items.label(best.item), best.item.value or 0, best.room or 0))
  elseif n == 0 then
    msg(state, p, "Scan: nothing left to find here")
  end
  fx(state, p, "scan")
end

-- add-fun-fixes: the Scanner's job: how many finds are left at a site and where the best one lies
-- (nil for a city, whose slots are rolled only near the saucer)
function M.scan_finds(state, p, site)
  local ruin = rt.ruins[site]
  if not ruin or ruin.city then return nil end
  local n, best = 0, nil
  for _, s in ipairs(ruin.slots or {}) do
    if not p.looted[site .. ":" .. s.id] then
      n = n + 1
      local item = loot.roll(loot.instance_seed(s.seed, p.record_index), s.max_size, s.tier)
      if s.premium then item.value = math.floor(item.value * s.premium) end
      if not best or item.value > best.item.value then best = { item = item, room = s.room } end
    end
  end
  return n, best
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

-- add-playtest-recs (recommendation 4): entering a guarded site in the Villa
-- says that Watchers are about and the Seat slips past them
function M.entry_text(state, p, site)
  local cr = rt.ruins[site]
  if cities.is_city(cr) then
    local g = cities.gravity(cr)
    return string.format("Entering a %s city (grid %s): %s", cr.city.body, select(2, cities.summary(state, site, cr)),
      g > 1 and string.format("%.1f g, hovering costs Charge - the hangar refills it", g) or "free flight")
  end
  local w = sentry.summary(rt.sentries[site] or {})
  if w > 0 and p.ship.size == 1 then
    return string.format("Entering derelict site %d: %d Watcher%s here lock on to a Villa - the Seat slips past beyond %d m", site, w,
      w == 1 and "" or "s", sentry.tune().watcher.small_range or 0)
  end
  return "Entering derelict site " .. site
end

local function world_step(state, p, dt)
  local ship = p.ship
  local site = M.site_at(ship.pos)
  if site ~= p.site then
    if p.site ~= 0 then excursion.left_site(state, p, p.site, ctx_fns) end
    if site == 0 then bank(state, p) else msg(state, p, M.entry_text(state, p, site)) end
    -- add-playtest-recs: a Seat dive counts toward the fold warning's soft gate
    if site ~= 0 and ship.size == 2 then p.seat_dives = (p.seat_dives or 0) + 1 end
    p.site = site
    -- add-wider-dark: entering a site files its civ in your Xenoarchive
    if site ~= 0 and archive.meet(p, civ_of(state.sector.sites[site])) then
      msg(state, p, "New civilization: the " .. civ_of(state.sector.sites[site]).name .. " (Xenoarchive)")
    end
  end
  if site ~= 0 then M.record_trail(state, p, site) end
  -- add-cities: a body's pull above 1 g costs Charge to hover against (the spaceport hangar is free
  -- and refills it); with the Charge gone the hull settles at a walking pace - never a trap
  local cr = site ~= 0 and rt.ruins[site] or nil
  local hangar = cities.is_city(cr) and cities.in_hangar(cr, ship.pos)
  if cities.is_city(cr) and not hangar and not ship.morph and p.mode ~= "foot" and not p.berth then
    local cost, sink = cities.pull(cr, ship.charge, dt)
    ship.charge = ship.charge - cost
    if sink then ship.pos = mover(state, p)(ship, { 0, -cities.SINK * dt, 0 }) end
  end
  -- add-cities-2: a storm over a planet city pushes the saucer about in the open (never inside a room)
  if cities.is_city(cr) and not hangar and not ship.morph and p.mode ~= "foot" and not p.berth then
    local wx, wz, wk = cities.wind(cr, state.tick)
    if wk > 0 and not cities.sheltered(cr, ship.pos) then ship.pos = mover(state, p)(ship, { wx * dt, 0, wz * dt }) end
  elseif site == 0 and not ship.morph and p.mode ~= "foot" and not p.berth then
    -- add-alien-cities-5: the storm blows over the outer ring too (not in an organ's hall or a warren)
    local mi, mr, mp = M.mega_city_at(state, ship.pos)
    if mi and mr and megacity.in_air(mp, ship.pos) then
      local wx, wz, wk = cities.wind(mr, state.tick)
      if wk > 0 and not megacity.sheltered(mp, ship.pos) then ship.pos = mover(state, p)(ship, { wx * dt, 0, wz * dt }) end
    end
  end
  -- add-relic-stations: a Villa resting in a relic's cradle bay refills at half the open-space rate
  local regen = (site == 0 or hangar) and home.regen_factor(state, p) or (site ~= 0 and relic.cradle_regen(state, p))
  if shipm.update(ship, dt, regen) == "done" then
    msg(state, p, "Configuration: " .. configs.get(ship.size).name)
  end
  if p.ghost > 0 then p.ghost = p.ghost - 1 end
  -- the belly hatch irises open while the beam pulls, and part way while the
  -- operator sits at the console so they can see down the beam (render reads p.hatch)
  local hw = p.tractor and 1 or (p.beam_console and M.HATCH_ARMED or 0)
  local hc = p.hatch or 0
  if hw > hc then p.hatch = math.min(hw, hc + 2.5 * dt) else p.hatch = math.max(hw, hc - 1.5 * dt) end
  home.doors_step(avatar.layout(), p, dt, coop.guests(state, p))
  hulldoor.step(state, p, dt, ctx_fns)
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
    local tr = (state.sector.traders or {})[docked]
    msg(state, p, string.format("Docked at the %s. Walk to the trade terminal to sell.", tr and tr.outpost and "city outpost" or "trader"))
    fx(state, p, "bank")
  end
  p.docked = docked or false
  lab.step(state, p, dt, ctx_fns)
  kitchen.step(state, p, dt, ctx_fns)
  hull.regen(ship, dt * buffs.factor(state, p, "hull_regen"), p.site == 0)
  if ship.hull <= 0 then
    local from = p.site
    local cache = hull.retreat(state, p, trader_pos(state, p))
    p.site = M.site_at(ship.pos)
    msg(state, p, "FOLD RETREAT: the hull gave out and you folded back to the trader.")
    if (p.retreat_lost or 0) > 0 then
      msg(state, p, string.format("The fold tore away %d hot item%s for good.", p.retreat_lost, p.retreat_lost == 1 and "" or "s"))
    end
    if cache then
      msg(state, p, string.format("%d hot item%s stayed behind as a cache at site %d.", #cache.items,
        #cache.items == 1 and "" or "s", from))
    elseif require("sim.hardcore").on(state) and (p.lost_for_good or 0) > 0 then
      msg(state, p, "HARDCORE: the cargo in your hold is lost for good.")
    end
    if p.last_bill then
      local b = p.last_bill
      msg(state, p, b.charge > 0 and string.format("Tow bill %d c: you paid %d c and %d Charge.", b.bill, b.paid, b.charge // 1)
        or string.format("Tow bill: %d c for the fold-back at danger %d.", b.bill, galaxy.sector(state.seed, state.sector_id or 1).danger))
    end
    msg(state, p, "The hull mends slowly in open space; the trade terminal repairs it at once.")
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
  story.notice(state, p, ctx_fns)
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
    msg(state, p, "The Shroud is a saucer utility (on foot, Y fires the grapple)")
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
    p.cut = nil
    return
  end
  local idx = adv.spike_target(state, p, sentry.tune())
  -- add-home-among-stars: no sentry to spike - the same tool cuts shutters and seals
  if not idx and require("sim.tools").cut_step(state, p, cmd:pressed("spike"), dt, ctx_fns) then
    p.spike = false
    return
  end
  if not idx then
    if cmd:pressed("spike") then
      msg(state, p, "Override spike: get within 3 m of a Disabled sentry or a Lockdown node (or a shutter to cut)")
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

-- add-fun-fixes: a tool press that changes nothing still answers (the "denied" sound, and
-- once in a while a line saying why), so no button is ever silently dead
M.TOOL_BUTTONS = { "jam", "decoy", "shroud", "spike", "scan", "grapple", "land", "home", "assist", "shrink", "grow",
                   "size1", "size2", "size3" }
M.DENY_WHY = {
  jam = "Jammer: only at the helm or on foot", decoy = "Decoy: only at the helm, inside a derelict",
  shroud = "Shroud: only at the helm", spike = "Spike: hold it on a Disabled sentry",
  scan = "Scanner: only at the helm or on foot", grapple = "Grapple: on foot only",
  land = "Land: at the helm, over flat ground", home = "Emergency teleport: on foot only",
  assist = "Return assist: on foot only", shrink = "Fold: at the helm", grow = "Fold: at the helm",
  size1 = "Fold: at the helm", size2 = "Fold: at the helm", size3 = "The Pocket: docked at a station only",
}
local function react_sig(p)
  local s, e = p.ship, p.eva
  return table.concat({ tostring(p.mode), p.panel and (p.panel.kind .. ":" .. tostring(p.panel.sel)) or "-",
    tostring(s.size), tostring(s.morph and true or false), tostring(p.tractor and true or false), tostring(#p.hold),
    tostring(p.decoys), tostring(p.shroud), tostring(p.spike and true or false), tostring(p.scan_ready),
    tostring(p.jam_ready), tostring(p.beam_console), tostring(p.berth and true or false), tostring(p.excursion and true or false),
    tostring(e and e.tele), tostring(e and e.assist), tostring(e and e.jet), tostring(p.landing and true or false),
    tostring(p.grapple and true or false), tostring(p.hatch), tostring(p.door and true or false),
    tostring(p.station and true or false), tostring(p.holo_run and true or false) }, "|")
end
M.react_sig = react_sig
local step_player_inner
function M.step_player(state, p, cmd, dt)
  local pressed
  if p.mode ~= "wake" then
    for _, a in ipairs(M.TOOL_BUTTONS) do
      if cmd:pressed(a) then pressed = a break end
    end
  end
  if not pressed then return step_player_inner(state, p, cmd, dt) end
  local sig, lfx, lmsg = react_sig(p), p.fx[#p.fx], p.msgs[#p.msgs]
  step_player_inner(state, p, cmd, dt)
  if p.fx[#p.fx] ~= lfx or p.msgs[#p.msgs] ~= lmsg then return end
  if react_sig(p) ~= sig then return end
  fx(state, p, "denied")
  p.denied = p.denied or {}
  if (p.denied[pressed] or -9999) + 600 <= state.tick then
    p.denied[pressed] = state.tick
    msg(state, p, M.DENY_WHY[pressed])
  end
end

step_player_inner = function(state, p, cmd, dt)
  local ship = p.ship
  -- add-wider-dark: the sector map, shaking off a Clamp
  if cmd:held("boost") and p.clamped_by then p.shake = (p.shake or 0) + dt end
  if cmd:pressed("map") and p.mode ~= "wake" then
    local k = p.panel and p.panel.kind
    if k == "map" or k == "citymap" or k == "party" or k == "archive" or k == "fold_warn" then p.panel = false
    elseif not p.panel then
      local cr = p.site ~= 0 and rt.ruins[p.site] or nil
      panel.open(p, cities.is_city(cr) and "citymap" or "map")
    end
  end
  if cmd:pressed("camera") then p.cam = p.cam == "first" and "chase" or "first" end
  if cmd:pressed("menu") then p.help = not p.help end
  -- add-realistic-lighting: the saucer's headlights, floods and cabin lamps (sim/lights.lua)
  lightsm.step(state, p, cmd, ctx_fns)
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
    -- add-playtest-recs: the Grapple has its own key (Y, D-pad up, GRP);
    -- the Shroud key on foot only says what it is
    if cmd:pressed("grapple") then require("sim.tools").grapple_fire(state, p, ctx_fns) end
    if cmd:pressed("shroud") then M.shroud(state, p) end
    M.spike_step(state, p, cmd, dt)
    if p.berth then landing.step(state, p, dt, ctx_fns) end
    excursion.step(state, p, cmd, dt, ctx_fns)
    if p.excursion and p.site == 0 then require("sim.dock").door_step(state, p, ctx_fns) end
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
  if p.mode == "helm" then relic.lock_step(state, p, cmd, dt, ctx_fns) end
  relic.play_step(state, p, ctx_fns)
  if cmd:pressed("scan") then scan(state, p) end
  if cmd:pressed("jam") then jam(state, p) end
  if cmd:pressed("decoy") then M.decoy(state, p) end
  if cmd:pressed("shroud") then M.shroud(state, p) end
  if cmd:pressed("shrink") then size_request(state, p, ship.size + 1)
  elseif cmd:pressed("grow") then size_request(state, p, ship.size - 1) end
  for i, k in ipairs(SIZE_KEYS) do
    if i <= configs.count() and cmd:pressed(k) and i ~= ship.size then size_request(state, p, i) end
  end
  -- add-dock-land-eva: the helm's Land button; thrust up lifts a landed saucer off
  if p.mode == "helm" and cmd:pressed("land") and not ship.morph then landing.press(state, p, ctx_fns) end
  if p.mode == "helm" and p.berth and p.berth.phase == "landed" and cmd:axis("lift") > 0.5 then
    landing.lift_off(state, p, ctx_fns)
  end
  if p.mode == "helm" and not p.berth and not ship.morph then require("sim.dock").auto(state, p, dt, ctx_fns) end
  require("sim.dock").watch(state, p, cmd, dt, ctx_fns)
  local berthed = p.berth and not ship.morph and landing.step(state, p, dt, ctx_fns)
  if ship.morph then
    ship.vel = { 0, 0, 0 }
  elseif berthed and p.mode == "helm" then
    -- the gear holds the saucer; the stick does nothing until it lifts off
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
    if not berthed then flight.step(ship, STILL, dt, mover(state, p)) end
    local L = avatar.layout()
    if p.door and p.door.on then
      -- add-dock-land-eva: on the hull stairs
      if hulldoor.stairs_step(state, p, cmd, dt, ctx_fns) == "out" then excursion.leave_hatch(state, p, ctx_fns) end
    else
      avatar.step(p.body, { move_x = cmd:axis("move_x"), move_z = cmd:axis("move_z"), turn = cmd:axis("turn"),
                            look = cmd:axis("look"), run = cmd:held("boost"), aim = cmd.aim }, dt, L, home.solids(L, p))
      p.body.yaw = saucer.math.wrap(p.body.yaw + comfort.snap(cmd))
      hulldoor.after_walk(state, p)
    end
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

-- add-cities-2: the sky-bridges of the city a player is in tear loose by the clock (see sim/cities.lua):
-- the box leaves the physics, the players there are told, and a bridge in its fall costs the hull it hits
function M.city_step(state)
  for i = 1, #state.sector.sites do
    local r = rt.ruins[i]
    if cities.is_city(r) and #(r.city.bridges or {}) > 0 then
      local here = {}
      for _, p in ipairs(state.players) do if p.site == i then here[#here + 1] = p end end
      if #here > 0 then
        for _, si in ipairs(r.city.bridges) do
          local id = rt.bridge_box[i][si]
          local s = r.solids[si]
          local ft = cities.fall_tick(r, s)
          if ft and state.tick >= ft and not rt.fallen[i][si] then
            saucer.physics.remove(id)
            rt.fallen[i][si] = true
            for _, p in ipairs(here) do
              msg(state, p, cities.storm(r, state.tick) > 0 and "The storm tears a sky-bridge loose - it falls" or "A tremor shakes a sky-bridge loose - it falls")
            end
          end
          local mn, mx = cities.fall_box(r, s, state.tick)
          if mn then
            for _, p in ipairs(here) do
              local ship = p.ship
              local rr = configs.get(ship.size).diameter / 2
              local key = i .. ":hit" .. si .. ":" .. p.index
              if p.mode ~= "foot" and not (state.locks and state.locks[key])
                  and ship.pos[1] > mn[1] - rr and ship.pos[1] < mx[1] + rr and ship.pos[2] > mn[2] - rr and ship.pos[2] < mx[2] + rr
                  and ship.pos[3] > mn[3] - rr and ship.pos[3] < mx[3] + rr then
                state.locks = state.locks or {}
                state.locks[key] = state.tick
                hull.damage(ship, cities.BRIDGE_DAMAGE)
                p.fx[#p.fx + 1] = { tick = state.tick, sound = "hit" }
                msg(state, p, "A falling sky-bridge clips the hull")
              end
            end
          end
        end
      end
    end
  end
end

function M.step(state, cmds, dt)
  M.state_ref = state
  state.tick = state.tick + 1
  -- add-wider-dark: a player slot that is not in the game yet joins on its
  -- first button press (slots fill in order)
  for i = #state.players + 1, math.min(#cmds, 4) do
    if cmds[i] and coop.wants_join(cmds[i]) then coop.join(state, i, ctx_fns) else break end
  end
  claims.resolve(state, dt, ctx_fns)
  M.mega_sync(state)
  planet.sync(state)
  for i = 1, #state.players do
    local p = state.players[i]
    if p and cmds[i] then M.step_player(state, p, cmds[i], dt) end
  end
  -- sentries act once per tick for everyone, then their stun bolts fly
  for i = 1, #state.sector.sites do sentry.step(state, i, rt.sentries[i], dt, ctx_fns) end
  sentry.step_bolts(state, dt)
  stealth.step_alarm(state, dt, ctx_fns)
  M.city_step(state)
  -- add-wider-dark: decoys burn out; docks, the Heart and the party's fold jump
  local keep = {}
  for _, d in ipairs(state.decoys or {}) do
    d.life = d.life - dt
    if d.life > 0 then keep[#keep + 1] = d end
  end
  state.decoys = keep
  coop.step(state, ctx_fns)
  twin.step(state, ctx_fns)
  heart.step(state, ctx_fns)
  M.warm_jump(state, dt)
  galaxy.step(state, dt, ctx_fns, M.enter_sector)
end

home.register_panels(M, ctx_fns)
decor.register(home, ctx_fns)
visit.register_panels(ctx_fns)
-- add-wider-dark panels
panel.register("citymap", { title = function(state, p) return "CITY MAP" end,
  rows = function(state, p) return cities.panel_rows(state, p, p.site, rt.ruins[p.site], panel) end })
panel.register("map", { title = "SECTOR MAP", rows = function(state, p) return galaxy.rows(state, p, ctx_fns) end })
panel.register("fold_warn", { title = "FOLD WARNING", rows = function(state, p) return galaxy.warn_rows(state, p, ctx_fns) end })
panel.register("party", { title = "PARTY", rows = function(state, p) return coop.rows(state, p, ctx_fns) end })
panel.register("archive", { title = "XENOARCHIVE", rows = function(state, p) return archive.rows(state, p) end })
panel.register("story", { title = "HOLOTABLE: THE STORY", rows = function(state, p) return story.rows(state, p, ctx_fns) end })
panel.register("heart", { title = "THE HEART", rows = function(state, p) return heart.rows(state, p) end })
panel.register("gift_table", { title = "GIFT TABLE", rows = function(state, p) return coop.gift_rows(state, p, ctx_fns) end })

function M.on_event(ev, state)
  -- base keeps no extra bookkeeping; mods listen for "size_change"/"loot"
  return ev.type
end

return M
