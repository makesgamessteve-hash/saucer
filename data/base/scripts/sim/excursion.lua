-- SPDX-License-Identifier: MIT
-- On-foot excursions in derelicts (OpenSpec add-on-foot-excursions, concept
-- §3.5 and §4). Set the Seat (or the Villa) down near a deck inside a
-- derelict and fold past the Seat: you step out, the saucer folds into your
-- hand as the Pocket coin (the milestone 5 configuration) and goes into your
-- pocket. On foot (p.mode = "foot", p.excursion) you walk, crouch through
-- 1 m crawlspaces the saucer cannot enter, jet-hop, carry up to four items in
-- your hands, turn hand-locks that open sealed doors for the saucer, and shut
-- a derelict's sentry grid down at its console. Your suit has its own Charge,
-- the only meter on foot: it drains outside (faster in crawlspaces and under
-- a Watcher's lock) and refills when you board. Deploy the saucer again (it
-- always comes back as the Seat, and needs a 2.2 m clearance sphere in front
-- of you) and you are aboard; whatever you carried goes into the hold.
--
-- Nothing is lethal. At zero Suit Charge the Lifeline fires: the screen
-- whites out, the saucer deploys at the newest point of your trail with
-- room for it, you wake up in the Seat, and what was in your hands stays
-- behind as a cache (on the radar) that you can come back for.
--
-- Everything lives in p.excursion / p.suit / p.hands and state.locks /
-- state.grids as plain data (saved, snapshotted, replayed).
local vec = require("lib.vec")
local data = require("lib.data")
local comfort = require("sim.comfort")
local configs = require("sim.config")
local shipm = require("sim.ship")
local items = require("sim.items")
local sm = saucer.math
local M = {}

function M.tune() return data.load("foot/excursion.lua") end
local function game() return require("sim.game") end
local function avatar() return require("sim.avatar") end

function M.pocket_size() return require("sim.visit").pocket_size() end
function M.seat_size() return M.pocket_size() - 1 end

function M.ensure(p)
  if p.suit == nil then p.suit = M.tune().suit.max end
  p.hands = p.hands or {}
  return p
end

function M.foot(ruin) return ruin and ruin.foot or nil end

local function key(site, id) return tostring(site) .. ":" .. tostring(id) end
M.key = key

function M.lock_open(state, site, id) return (state.locks or {})[key(site, id)] ~= nil end
function M.grid_down(state, site) return (state.grids or {})[tostring(site)] ~= nil end

-- body geometry: half height and the centre of the collision box
local function half(b) local T = M.tune().body return (b.crouch and T.crouch or T.stand) / 2 end
function M.center(b) return { b.pos[1], b.pos[2] + half(b), b.pos[3] } end
function M.eye(b)
  local T = M.tune().body
  return { b.pos[1], b.pos[2] + (b.crouch and T.crouch_eye or T.eye), b.pos[3] }
end
function M.viewpoint(p)
  local b = p.excursion.body
  return M.eye(b), b.yaw, b.pitch
end

local function in_box(bx, q, pad)
  pad = pad or 0
  return q[1] >= bx[1][1] - pad and q[1] <= bx[2][1] + pad and q[2] >= bx[1][2] - pad and q[2] <= bx[2][2] + pad
    and q[3] >= bx[1][3] - pad and q[3] <= bx[2][3] + pad
end
M.in_box = in_box

-- which part of the site the body is in: "crawl", "chamber", "strong" or "hall"
function M.area(state, p)
  local ex = p.excursion
  local f = M.foot(game().ruin(ex.site))
  if not f then return "hall" end
  local c = M.center(ex.body)
  if in_box(f.crawl, c) then return "crawl" end
  if in_box(f.chamber, c) then return "chamber" end
  if in_box(f.strong, c) then return "strong" end
  return "hall"
end

M.AREA_MSG = {
  crawl = "A crawlspace: too tight for any saucer. You crouch and crawl.",
  chamber = "A chamber behind the crawlspace. A coupling and a console glow on the walls.",
  strong = "The strongroom.",
}

-- where the person stands when they step out (feet), or nil, why
function M.stand_spot(state, p)
  local T = M.tune()
  local ship = p.ship
  local _, hh = shipm.dims(ship)
  local o = ship.pos
  local hit = saucer.physics.raycast(o, { 0, -1, 0 }, hh + T.stand_dist, 1)
  if not hit then return nil, "deck" end
  local feet = { o[1], o[2] - hit.t + 1e-6, o[3] }
  local B = T.body
  if saucer.physics.clearance({ feet[1], feet[2] + B.stand / 2, feet[3] }, B.radius, B.stand / 2, 0, 1) then
    return feet, nil, false
  end
  if saucer.physics.clearance({ feet[1], feet[2] + B.crouch / 2, feet[3] }, B.radius, B.crouch / 2, 0, 1) then
    return feet, nil, true
  end
  return nil, "room"
end

M.REASONS = {
  busy = "Hull is still reshaping",
  beam = "Let go of the beam first",
  charge = "Not enough Charge to fold into your pocket",
  deck = "No deck to stand on: set down within 2 m of a floor",
  room = "No room to stand here",
}

-- can p step out of the saucer here? -> ok, why, feet, crouch
function M.can_step_out(state, p)
  local ship = p.ship
  if ship.morph then return false, "busy" end
  if p.tractor then return false, "beam" end
  if ship.charge < shipm.cost(ship.size, M.pocket_size()) then return false, "charge" end
  local feet, why, crouch = M.stand_spot(state, p)
  if not feet then return false, why end
  return true, nil, feet, crouch
end

-- step out: the saucer folds into your hand (Pocket), you stand on the deck
function M.step_out(state, p, ctx)
  local ok, why, feet, crouch = M.can_step_out(state, p)
  if not ok then
    ctx.msg(state, p, M.REASONS[why])
    ctx.fx(state, p, "denied")
    return false
  end
  M.ensure(p)
  local ship = p.ship
  local from, to = ship.size, M.pocket_size()
  local cfg = configs.get(to)
  local yaw = ship.yaw
  if p.mode == "walk" and p.body then yaw = ship.yaw + p.body.yaw end
  ship.charge = ship.charge - shipm.cost(from, to)
  ship.morph = { from = from, pos = vec.copy(ship.pos), yaw = ship.yaw, total = cfg.morph_time or 2.4,
                 eye = vec.copy(ship.pos), pocket = "fold" }
  ship.t_left = ship.morph.total
  ship.size = to
  ship.vel = { 0, 0, 0 }
  ship.bank = 0
  ship.pitch = 0
  p.excursion = {
    site = p.site, t = 0, coin = "fold", from = from, hand_t = 0, held = false,
    body = { pos = feet, yaw = sm.wrap(yaw), pitch = -0.1, vy = 0, crouch = crouch or false, ground = true },
    path = { vec.copy(feet) }, work = false, warned = 0, area = "hall", deploy = false,
  }
  p.mode = "foot"
  p.tractor, p.beam_console, p.panel = false, false, false
  p.tv, p.reading, p.cooking = false, false, false
  p.suit = M.tune().suit.max
  ship.pos = M.center(p.excursion.body)
  p.excursions = (p.excursions or 0) + 1
  ctx.msg(state, p, "You step out onto the deck. The saucer folds down into your hand...")
  ctx.fx(state, p, "shrink")
  saucer.events.emit({ type = "size_change", player = p.index, from = from, to = to })
  return true
end

-- the Seat's hull centre for a deploy at feet position q
local function deploy_center(q) return { q[1], q[2] + M.tune().deploy.lift, q[3] } end

function M.deploy_ok(state, p, center)
  local r = M.tune().deploy.clear / 2
  return not game().blocked(state, p, center, r, r, 0)
end

-- where the saucer would deploy right now -> centre or nil
function M.deploy_spot(state, p)
  local b = p.excursion.body
  local D = M.tune().deploy
  local f = vec.fwd(b.yaw)
  local ahead = deploy_center({ b.pos[1] + f[1] * D.ahead, b.pos[2], b.pos[3] + f[3] * D.ahead })
  if M.deploy_ok(state, p, ahead) then return ahead end
  -- facing a wall: it can unfold around you instead
  local here = deploy_center(b.pos)
  if M.deploy_ok(state, p, here) then return here end
  return nil, ahead
end

M.DEPLOY_REASONS = {
  busy = "Wait for the fold to finish",
  room = "No room to deploy",
  charge = "Not enough Charge to deploy",
}

function M.can_deploy(state, p)
  local ex = p.excursion
  if ex.coin ~= "pocket" and ex.coin ~= "hand" then return false, "busy" end
  if p.ship.morph then return false, "busy" end
  if p.ship.charge < shipm.cost(p.ship.size, M.seat_size()) then return false, "charge" end
  local c, ghost = M.deploy_spot(state, p)
  if not c then return false, "room", ghost end
  return true, nil, c
end

-- deploy: the coin grows into the Seat in front of you; you board when it is done
function M.deploy(state, p, ctx)
  local ok, why, c = M.can_deploy(state, p)
  if not ok then
    ctx.msg(state, p, M.DEPLOY_REASONS[why])
    ctx.fx(state, p, "denied")
    if why == "room" then p.ghost, p.ghost_size, p.ghost_pos = 45, M.seat_size(), c end
    return false
  end
  local ex = p.excursion
  local ship = p.ship
  local from, to = ship.size, M.seat_size()
  ship.charge = ship.charge - shipm.cost(from, to)
  ship.morph = { from = from, pos = vec.copy(c), yaw = ex.body.yaw, total = configs.get(from).unmorph_time or 2.2,
                 eye = vec.copy(c), pocket = "grow" }
  ship.t_left = ship.morph.total
  ship.size = to
  ship.pos = vec.copy(c)
  ship.yaw = ex.body.yaw
  ship.vel = { 0, 0, 0 }
  ex.coin = "grow"
  ex.deploy = { pos = vec.copy(c), hand = M.eye(ex.body) }
  ex.work = false
  ctx.msg(state, p, "You toss the coin ahead. The Seat unfolds...")
  ctx.fx(state, p, "grow")
  saucer.events.emit({ type = "size_change", player = p.index, from = from, to = to })
  return true
end

-- hands -> hold; what does not fit stays as a cache where you stand
local function stow(state, p, ctx, where)
  local cap = require("sim.upgrades").hold_slots(p)
  local left = {}
  local n = 0
  for _, it in ipairs(p.hands or {}) do
    if #p.hold < cap then
      p.hold[#p.hold + 1] = it
      n = n + 1
    else
      left[#left + 1] = it
    end
  end
  p.hands = {}
  if #left > 0 then
    state.caches = state.caches or {}
    state.caches[#state.caches + 1] = { site = p.site, pos = vec.copy(where), owner = p.record_index, items = left }
    ctx.msg(state, p, string.format("The hold is full: %d item%s left as a cache", #left, #left == 1 and "" or "s"))
  end
  return n
end

local function aboard(state, p)
  local A = avatar()
  local L = A.layout()
  p.mode = "helm"
  p.excursion = false
  p.suit = M.tune().suit.max
  p.body = A.new(L, L.helm.stand, 0)
  p.ship.pitch = 0
end

-- the Seat has grown: climb in, stow what you carry
local function board(state, p, ctx)
  local where = vec.copy(p.excursion.body.pos)
  aboard(state, p)
  local n = stow(state, p, ctx, where)
  ctx.msg(state, p, n > 0 and string.format("Aboard the Seat. %d item%s from your hands into the hold.", n, n == 1 and "" or "s")
    or "Aboard the Seat. Suit recharged.")
  ctx.fx(state, p, "bank")
end

-- ---- add-dock-land-eva: the saucer stands on its gear beside you (coin = "stand") ----

-- came down the hull stairs: the Villa stands behind you
function M.leave_hatch(state, p, ctx)
  M.ensure(p)
  local hd = require("sim.hulldoor")
  local ship = p.ship
  local feet = hd.foot_world(state, p)
  local o = avatar().rot(ship.yaw, { 0, 0, -1.0 })
  feet = { feet[1] + o[1], feet[2], feet[3] + o[3] }
  local yaw = sm.wrap(ship.yaw + (p.body and p.body.yaw or sm.pi))
  p.excursion = {
    site = p.site, t = 0, coin = "stand", from = ship.size, hand_t = 0, held = false,
    body = { pos = feet, yaw = yaw, pitch = -0.05, vy = 0, crouch = false, ground = true },
    path = { vec.copy(feet) }, work = false, warned = 0, area = "hall", deploy = false,
  }
  p.mode = "foot"
  require("sim.eva").set_home(p)
  p.door.on = false
  p.panel = false
  p.tractor, p.beam_console = false, false
  p.suited = not require("sim.env").breathable(state, p)
  p.excursions = (p.excursions or 0) + 1
  ctx.msg(state, p, p.suited and "Helmet on. You step off the stairs. The Villa stands on its gear behind you."
    or "You step off the stairs. The Villa stands on its gear behind you.")
  ctx.fx(state, p, "door")
  return true
end

-- walked back to the stairs' foot with the hatch open: up you go, first person
function M.board_hatch(state, p, ctx)
  local ex = p.excursion
  local hd = require("sim.hulldoor")
  local A = avatar()
  local L = A.layout()
  local n = stow(state, p, ctx, ex.body.pos)
  local yaw_local = 0
  p.mode = "walk"
  p.excursion = false
  p.door.on = true
  local loc = hd.local_at(p, hd.total(p), 0)
  p.body = { pos = loc, yaw = yaw_local, pitch = 0 }
  p.suit = M.tune().suit.max
  ctx.msg(state, p, n > 0 and string.format("You climb the stairs. %d item%s from your hands into the hold.", n, n == 1 and "" or "s")
    or "You climb the stairs into the Villa.")
  ctx.fx(state, p, "door")
  return true
end

M.FOLD_REACH = 60
M.TETHER = 150

function M.stairs_ready(p)
  local d = p.door
  return d and d.open >= 0.95 and d.stairs >= 0.95 and d.goal == 1
end

-- is the body within r of the stairs' foot?
function M.near_foot(state, p, r)
  local f = require("sim.hulldoor").foot_world(state, p)
  local b = p.excursion.body
  local dx, dz = b.pos[1] - f[1], b.pos[3] - f[3]
  return sm.sqrt(dx * dx + dz * dz) <= r and math.abs(b.pos[2] - f[2]) < 1.5
end

-- fold the standing saucer into your hand (it needs its hatch shut first)
function M.fold_stand(state, p, ctx)
  local ex = p.excursion
  local ship = p.ship
  local d = p.door
  if d and (d.open > 0 or d.goal == 1) then
    d.goal, d.hold = 0, 0
    ex.fold_wait = true
    ctx.msg(state, p, "The stairs fold away and the hatch closes first...")
    return false
  end
  local to = M.pocket_size()
  if ship.charge < shipm.cost(ship.size, to) then
    ctx.msg(state, p, M.REASONS.charge)
    ctx.fx(state, p, "denied")
    return false
  end
  if vec.dist(ship.pos, M.center(ex.body)) > M.FOLD_REACH then
    ctx.msg(state, p, "Too far from the Villa to fold it: walk back toward it")
    ctx.fx(state, p, "denied")
    return false
  end
  local from = ship.size
  local cfg = configs.get(to)
  ship.charge = ship.charge - shipm.cost(from, to)
  ship.morph = { from = from, pos = vec.copy(ship.pos), yaw = ship.yaw, total = cfg.morph_time or 2.4,
                 eye = vec.copy(ship.pos), pocket = "fold" }
  ship.t_left = ship.morph.total
  ship.size = to
  ship.vel = { 0, 0, 0 }
  ship.bank, ship.pitch = 0, 0
  p.berth = false
  ex.coin, ex.fold_wait = "fold", false
  ctx.msg(state, p, "The Villa folds down, gear and all, into your hand...")
  ctx.fx(state, p, "shrink")
  saucer.events.emit({ type = "size_change", player = p.index, from = from, to = to })
  return true
end

-- where a Villa deployed now would stand: ahead of you, on level ground -> pose, report
M.VILLA_AHEAD = 20
function M.villa_spot(state, p)
  local b = p.excursion.body
  local f = vec.fwd(b.yaw)
  local landing = require("sim.landing")
  local pos = { b.pos[1] + f[1] * M.VILLA_AHEAD, b.pos[2] + 4, b.pos[3] + f[3] * M.VILLA_AHEAD }
  local rep = landing.probe(state, p, pos, b.yaw)
  return pos, rep
end

M.VILLA_REASONS = {
  void = "No room to unfold the Villa: there is no ground ahead of you",
  wall = "No room to unfold the Villa: the ground ahead is not level",
  slope = "No room to unfold the Villa: the ground ahead is too steep",
  room = "No room to unfold the Villa: it needs about 27 m clear and 12 m of headroom",
  busy = "Wait for the fold to finish",
  charge = "Not enough Charge to unfold",
}

-- can the Villa grow ahead of you? -> ok, why, rest pose, ghost pos
function M.can_deploy_villa(state, p)
  local ex = p.excursion
  if ex.coin ~= "pocket" and ex.coin ~= "hand" then return false, "busy" end
  if p.ship.morph then return false, "busy" end
  if p.ship.charge < shipm.cost(p.ship.size, 1) then return false, "charge" end
  local pos, rep = M.villa_spot(state, p)
  if not rep.ok then return false, rep.why, nil, pos end
  local rest = { pos[1], rep.target, pos[3] }
  local r, hh = shipm.dims_of(1)
  if game().blocked(state, p, rest, r, hh, 0) then return false, "room", nil, rest end
  return true, nil, rest, rest
end

function M.deploy_villa(state, p, ctx)
  local ok, why, rest, ghost = M.can_deploy_villa(state, p)
  if not ok then
    ctx.msg(state, p, M.VILLA_REASONS[why] or M.VILLA_REASONS.room)
    ctx.fx(state, p, "denied")
    if ghost and why ~= "busy" and why ~= "charge" then p.ghost, p.ghost_size, p.ghost_pos = 45, 1, ghost end
    return false, why
  end
  local ex = p.excursion
  local ship = p.ship
  local from, to = ship.size, 1
  ship.charge = ship.charge - shipm.cost(from, to)
  ship.morph = { from = from, pos = vec.copy(rest), yaw = ex.body.yaw, total = configs.get(from).unmorph_time or 2.2,
                 eye = vec.copy(rest), pocket = "grow" }
  ship.t_left = ship.morph.total
  ship.size = to
  ship.pos = vec.copy(rest)
  ship.yaw = ex.body.yaw
  ship.vel = { 0, 0, 0 }
  ex.coin = "grow"
  ex.deploy = { pos = vec.copy(rest), hand = M.eye(ex.body), villa = true }
  ex.work = false
  ctx.msg(state, p, "You toss the coin ahead. The Villa unfolds onto its gear...")
  ctx.fx(state, p, "grow")
  saucer.events.emit({ type = "size_change", player = p.index, from = from, to = to })
  return true
end

-- the Villa has grown and stands on its gear: you stay outside, beside it
function M.stand_up(state, p, ctx)
  local ex = p.excursion
  local landing = require("sim.landing")
  local ship = p.ship
  local rep = landing.probe(state, p, ship.pos, ship.yaw)
  local bay = require("sim.dock").inside(state, ship.pos)
  p.berth = { phase = "landed", kind = bay and "bay" or "surface", bay = bay, clamp = 0, legs = 1, t = 0, ref = rep.ref or ship.pos[2] - landing.tune().leg_len,
              feet = rep.feet or {}, at = vec.copy(ship.pos), yaw = ship.yaw, site = p.site }
  ex.coin, ex.deploy = "stand", false
  require("sim.hulldoor").ensure(p)
  require("sim.eva").set_home(p)
  ctx.msg(state, p, "The Villa stands on its gear. Walk to the foot of the stairs to board.")
  ctx.fx(state, p, "bank")
end

-- the HUD/prompt for the standing saucer
function M.stand_text(state, p)
  local hd = require("sim.hulldoor")
  local d = p.door
  if d and d.goal == 1 and d.open < 1 then return "THE HATCH IS OPENING" end
  if d and d.goal == 1 and d.stairs < 1 then return "THE STAIRS ARE UNFOLDING" end
  return "WALK TO THE STAIRS TO BOARD  /  Q FOLDS THE VILLA INTO YOUR HAND"
end

-- the Lifeline: suit at zero. Whiteout, the Seat deploys on your trail, the
-- hands drop as a cache where you fell. -> the cache (or nil)
function M.lifeline(state, p, ctx)
  local ex = p.excursion
  local b = ex.body
  local cache = { site = ex.site, pos = { b.pos[1], b.pos[2] + 0.9, b.pos[3] }, owner = p.record_index, items = {},
                  lifeline = true }
  local keep = {}
  for _, it in ipairs(p.hands or {}) do
    if it.echo or it.unique then keep[#keep + 1] = it else cache.items[#cache.items + 1] = it end
  end
  p.hands = keep
  if #cache.items > 0 and require("sim.hardcore").on(state) then
    -- add-home-among-stars: Hardcore keeps no cache
    p.lost_for_good = (p.lost_for_good or 0) + #cache.items
    cache = nil
  elseif #cache.items > 0 then
    state.caches = state.caches or {}
    state.caches[#state.caches + 1] = cache
  else
    cache = nil
  end
  local spot
  for i = #ex.path, 1, -1 do
    local c = deploy_center(ex.path[i])
    if M.deploy_ok(state, p, c) then
      spot = c
      break
    end
  end
  spot = spot or deploy_center(ex.path[1])
  local ship = p.ship
  local yaw = b.yaw
  local from = ship.size
  ship.size = M.seat_size()
  ship.morph, ship.t_left = false, 0
  ship.pos, ship.yaw, ship.vel, ship.pitch, ship.bank = spot, yaw, { 0, 0, 0 }, 0, 0
  aboard(state, p)
  stow(state, p, ctx, spot)
  p.lifeline = { tick = state.tick }
  p.lifelines = (p.lifelines or 0) + 1
  p.latched_by = nil
  ctx.msg(state, p, "LIFELINE: your suit gave out. The saucer deployed on your trail and pulled you aboard.")
  if cache then
    ctx.msg(state, p, string.format("%d item%s dropped where you fell: a cache, marked on your radar.", #cache.items,
      #cache.items == 1 and "" or "s"))
  end
  ctx.fx(state, p, "grow")
  saucer.events.emit({ type = "size_change", player = p.index, from = from, to = ship.size })
  return cache
end

-- loot within reach of your hands: slots, finds, Echoes, nests, caches and
-- (on foot only) Delicate finds -> list of tractor-style candidates
function M.candidates(state, p)
  local ex = p.excursion
  local ruin = game().ruin(ex.site)
  local out = {}
  for _, c in ipairs(require("sim.tractor").candidates(state, p, ex.site, ruin)) do out[#out + 1] = c end
  local f = M.foot(ruin)
  for _, d in ipairs(f and f.delicates or {}) do
    local k = "delicate:" .. key(ex.site, d.id)
    if not p.looted[k] then out[#out + 1] = { key = k, kind = "delicate", pos = d.pos, item = M.delicate_item(state, p, d) } end
  end
  return out
end

function M.delicate_item(state, p, d)
  local it = require("sim.loot").roll(require("sim.loot").instance_seed(d.seed, p.record_index), 1, 2)
  it.delicate = true
  it.value = math.floor(it.value * M.tune().delicate_value)
  it.name = "Delicate " .. it.name
  return it
end

-- what Use would do right now -> { kind = "lock"|"console"|"item", ... } or nil
function M.reach(state, p)
  local ex = p.excursion
  local eye = M.eye(ex.body)
  local T = M.tune()
  local f = M.foot(game().ruin(ex.site))
  local best, bd
  local function consider(t, d)
    if d <= T.reach and (not bd or d < bd) then best, bd = t, d end
  end
  if f then
    for _, l in ipairs(f.locks) do
      if not M.lock_open(state, ex.site, l.id) then consider({ kind = "lock", def = l }, vec.dist(eye, l.pos)) end
    end
    for _, c in ipairs(f.consoles) do
      if not M.grid_down(state, ex.site) then consider({ kind = "console", def = c }, vec.dist(eye, c.pos)) end
    end
  end
  for _, c in ipairs(M.candidates(state, p)) do consider({ kind = "item", cand = c }, vec.dist(eye, c.pos) - 0.3) end
  return best
end

-- take a candidate into your hands -> number of items taken
function M.grab(state, p, cand, ctx)
  local T = M.tune()
  local room = T.hands - #p.hands
  if room <= 0 then
    ctx.msg(state, p, "Your hands are full (4): deploy the saucer to stow them")
    ctx.fx(state, p, "denied")
    return 0
  end
  if cand.kind ~= "cache" and (cand.item.size or 1) > T.carry then
    ctx.msg(state, p, "Too big to carry by hand: bring the saucer's beam")
    ctx.fx(state, p, "denied")
    return 0
  end
  local site = p.excursion.site
  if cand.kind == "cache" then
    local c = state.caches[cand.index]
    local got = 0
    while #c.items > 0 and got < room do
      local it = table.remove(c.items, 1)
      it.hot = true
      p.hands[#p.hands + 1] = it
      got = got + 1
    end
    if #c.items == 0 then table.remove(state.caches, cand.index) end
    ctx.msg(state, p, string.format("You gather %d item%s from your cache", got, got == 1 and "" or "s"))
    ctx.fx(state, p, "pickup")
    return got
  end
  if cand.kind == "delicate" then
    p.looted[cand.key] = true
    local civ = game().civ_of(state.sector.sites[site])
    local it = items.stamp(p, cand.item, 2, civ and civ.id)
    it.hot = true
    p.hands[#p.hands + 1] = it
    ctx.msg(state, p, "You lift " .. items.label(it) .. " (Delicate: a beam would crush it)")
    ctx.fx(state, p, "pickup")
    return 1
  end
  -- everything else is what the beam would take: reuse its pick-up into the hands
  local hold = p.hold
  p.hold = p.hands
  game().pick_up(state, p, cand, site)
  p.hands = p.hold
  p.hold = hold
  return 1
end

-- start working a hand-lock or a grid console
local function start_work(state, p, t, ctx)
  local T = M.tune()
  p.excursion.work = { kind = t.kind, id = t.def.id, t = 0, total = t.kind == "lock" and T.lock_time or T.console_time }
  ctx.msg(state, p, t.kind == "lock" and "You set both hands to the coupling and heave..." or
    "You wake the grid console and start the shutdown...")
  ctx.fx(state, p, "click")
end

function M.use(state, p, ctx)
  local ex = p.excursion
  if ex.coin == "fold" or ex.coin == "grow" then return false end
  if ex.work then
    ex.work = false
    ctx.msg(state, p, "You let go.")
    return false
  end
  local t = M.reach(state, p)
  if not t then
    ctx.msg(state, p, "Nothing within reach")
    return false
  end
  if t.kind == "item" then return M.grab(state, p, t.cand, ctx) > 0 end
  start_work(state, p, t, ctx)
  return true
end

-- a hand-lock turns: its shutter slides open for the saucer
function M.open_lock(state, p, site, id, ctx)
  state.locks = state.locks or {}
  state.locks[key(site, id)] = state.tick
  game().open_shutter(site, id)
  ctx.msg(state, p, "The coupling locks home. Out in the hall a shutter grinds open: the strongroom is clear for the Seat.")
  ctx.fx(state, p, "door")
end

-- the grid console: every sentry of the site powers down until you leave
function M.shut_grid(state, p, site, ctx)
  state.grids = state.grids or {}
  state.grids[tostring(site)] = { by = p.index, tick = state.tick }
  local n = require("sim.sentry").grid_down(state, site)
  ctx.msg(state, p, n > 0 and string.format("Grid down: %d sentr%s in this derelict sleep until you leave it.", n,
    n == 1 and "y" or "ies") or "Grid down. Nothing on this grid was awake anyway.")
  for _, d in ipairs(require("sim.game").sentries(site)) do
    if d.kind == "warden" then
      ctx.msg(state, p, "The Warden runs on its own power: it keeps patrolling, slower now.")
      break
    end
  end
  ctx.fx(state, p, "jam")
  return n
end

-- the grid wakes when the player who shut it leaves the site
function M.left_site(state, p, site, ctx)
  local g = state.grids and state.grids[tostring(site)]
  if not g or g.by ~= p.index then return false end
  state.grids[tostring(site)] = nil
  require("sim.sentry").grid_up(state, site)
  ctx.msg(state, p, "Behind you the derelict's grid hums back to life.")
  return true
end

local function work_step(state, p, cmd, dt, ctx)
  local ex = p.excursion
  local w = ex.work
  local moving = math.abs(cmd:axis("move_x")) > 0.3 or math.abs(cmd:axis("move_z")) > 0.3
  local t = M.reach(state, p)
  if moving or not t or t.kind ~= w.kind or t.def.id ~= w.id then
    ex.work = false
    ctx.msg(state, p, w.kind == "lock" and "You let go of the coupling." or "You step away from the console.")
    return
  end
  w.t = w.t + dt
  if w.t >= w.total - 1e-9 then
    ex.work = false
    if w.kind == "lock" then M.open_lock(state, p, ex.site, w.id, ctx) else M.shut_grid(state, p, ex.site, ctx) end
  end
end

-- walk, crouch, crawl, jet-hop and fall against the derelict's boxes
function M.move(state, p, cmd, dt, ctx)
  local T = M.tune()
  if ctx and require("sim.eva").move(state, p, cmd, dt, ctx) then return 0 end
  local B = T.body
  local A = avatar().layout()
  local b = p.excursion.body
  b.yaw = comfort.yaw(b.yaw, cmd, A.turn, dt)
  b.pitch = vec.clamp(b.pitch + cmd:axis("look") * A.look * dt, -A.pitch_limit, A.pitch_limit)
  local lift = cmd:axis("lift")
  local r = B.radius
  -- crouch while lift is held down; stand back up when there is headroom
  if lift < -0.5 then
    b.crouch = true
  elseif b.crouch then
    local q = { b.pos[1], b.pos[2] + B.stand / 2 + 1e-6, b.pos[3] }
    if saucer.physics.clearance(q, r, B.stand / 2, 0, 1) then b.crouch = false end
  end
  -- jet-hop
  local kit = require("sim.eva").active(p) -- the jetpack's own fuel pays for it
  if lift > 0.5 and b.ground and (kit or p.suit > T.suit.hop) and not b.crouch then
    b.vy = B.hop
    b.ground = false
    if not kit then p.suit = p.suit - T.suit.hop end
  end
  -- vertical: the mag-boots' pull, a capped fall
  b.vy = math.max(-B.max_fall, (b.vy or 0) - B.gravity * dt)
  local hh = half(b)
  local c = { b.pos[1], b.pos[2] + hh + 1e-6, b.pos[3] }
  local np, bl = saucer.physics.move(c, r, hh, { 0, b.vy * dt, 0 }, 1)
  if bl > 0 then
    b.ground = b.vy < 0
    b.vy = 0
  else
    b.ground = false
  end
  if b.ground then
    local hit = saucer.physics.raycast(np, { 0, -1, 0 }, hh + 0.2, 1)
    if hit then np[2] = np[2] - hit.t + hh end
  end
  b.pos = { np[1], np[2] - hh, np[3] }
  -- horizontal
  local mx, mz = cmd:axis("move_x"), cmd:axis("move_z")
  if mx == 0 and mz == 0 then return 0 end
  local heading = b.yaw + avatar().head_yaw(cmd.aim)
  local f, rt = vec.fwd(heading), vec.right(heading)
  local speed = b.crouch and B.crawl_speed or A.walk_speed * (cmd:held("boost") and A.run_factor or 1)
  local d = { (f[1] * mz + rt[1] * mx) * speed * dt, 0, (f[3] * mz + rt[3] * mx) * speed * dt }
  c = M.center(b)
  local moved, blocked = saucer.physics.move({ c[1], c[2] + 1e-6, c[3] }, r, hh, d, 1)
  if blocked > 0 and not b.crouch then
    -- a low opening: duck into it
    local ch = B.crouch / 2
    local q, bq = saucer.physics.move({ b.pos[1], b.pos[2] + ch + 1e-6, b.pos[3] }, r, ch, d, 1)
    local gain = function(z) return (z[1] - b.pos[1]) ^ 2 + (z[3] - b.pos[3]) ^ 2 end
    if gain(q) > gain(moved) + 1e-6 then
      b.crouch = true
      moved, blocked = q, bq
    end
  end
  b.pos = { moved[1], b.pos[2], moved[3] }
  if p.berth then
    -- add-dock-land-eva: you cannot walk through the standing Villa or under its stairs
    local hy = B.stand
    local x, z = require("sim.landing").push_out(p, b.pos[1], b.pos[2], b.pos[3], b.pos[2] + hy)
    b.pos = { x, b.pos[2], z }
  end
  return blocked
end

-- the Lifeline trail: points where the Seat would fit, newest last
local function record_path(state, p)
  local T = M.tune()
  local ex = p.excursion
  local b = ex.body
  if state.tick % T.path_every ~= 0 or not b.ground then return end
  local last = ex.path[#ex.path]
  local dx, dz = b.pos[1] - last[1], b.pos[3] - last[3]
  if dx * dx + dz * dz < 1 and math.abs(b.pos[2] - last[2]) < 1 then return end
  if not M.deploy_ok(state, p, deploy_center(b.pos)) then return end
  ex.path[#ex.path + 1] = vec.copy(b.pos)
  if #ex.path > T.path_max then
    local half_path = { ex.path[1] }
    for i = 3, #ex.path, 2 do half_path[#half_path + 1] = ex.path[i] end
    ex.path = half_path
  end
end

-- Suit Charge per second right now
function M.drain(state, p)
  local S = M.tune().suit
  -- add-dock-land-eva: with the Villa standing within reach the suit rides its field
  if p.excursion.coin == "stand" and vec.dist(p.ship.pos, M.center(p.excursion.body)) <= M.TETHER then return 0 end
  if require("sim.eva").active(p) then return 0 end -- the EVA kit has its own gauges
  local k = 1
  if p.excursion.area == "crawl" then k = k * S.crawl end
  if require("sim.sentry").locked_on(state, p) then k = k * S.locked end
  return S.drain * k
end

-- a stun bolt bites the suit (sim/sentry.lua)
function M.bolt(state, p)
  p.suit = math.max(0, (p.suit or 0) - M.tune().suit.bolt)
end

-- one tick on foot
function M.step(state, p, cmd, dt, ctx)
  local ex = p.excursion
  local ship = p.ship
  local T = M.tune()
  M.ensure(p)
  ex.t = ex.t + dt
  if ex.coin == "grow" then
    if not ship.morph then
      if ex.deploy and ex.deploy.villa then M.stand_up(state, p, ctx) else board(state, p, ctx) return end
    else
      return
    end
  end
  if ex.coin == "fold" and not ship.morph then
    ex.coin, ex.hand_t = "hand", 0
    ctx.msg(state, p, "The saucer rests in your palm. Explore on foot; E (or 2) deploys it again.")
  end
  if ex.coin == "hand" and not ex.held then
    ex.hand_t = ex.hand_t + dt
    if ex.hand_t >= T.hand_time then
      ex.coin = "pocket"
      ctx.msg(state, p, "You slip it into your pocket.")
    end
  end
  -- the suit
  p.suit = math.max(0, p.suit - M.drain(state, p) * dt)
  for i, w in ipairs(T.suit.warn) do
    if p.suit <= w and (ex.warned or 0) < i then
      ex.warned = i
      ctx.msg(state, p, string.format("SUIT CHARGE %d%%: get back to the saucer (E deploys it)", w))
      ctx.fx(state, p, "alert")
    end
  end
  if p.suit <= 0 then
    M.lifeline(state, p, ctx)
    return
  end
  if require("sim.eva").step(state, p, cmd, dt, ctx) then return end
  if cmd:pressed("use") then M.use(state, p, ctx) end
  if cmd:pressed("tractor") and (ex.coin == "pocket" or ex.coin == "hand") then
    if ex.coin == "pocket" then
      ex.coin, ex.held = "hand", true
      ctx.msg(state, p, "You hold the saucer in your fist. F puts it away.")
    else
      ex.coin, ex.held = "pocket", false
      ctx.msg(state, p, "Back into your pocket.")
    end
  end
  local ps = M.pocket_size()
  if ex.coin == "stand" then
    -- add-dock-land-eva: the Villa stands beside you
    local d = p.door
    if d and M.stairs_ready(p) and M.near_foot(state, p, require("sim.hulldoor").tune().enter) then
      M.board_hatch(state, p, ctx)
      return
    end
    if cmd:pressed("shrink") or cmd:pressed("size3") or (ex.fold_wait and (not d or (d.open == 0 and d.stairs == 0))) then
      M.fold_stand(state, p, ctx)
    end
    if cmd:pressed("grow") or cmd:pressed("size1") or cmd:pressed("size2") then
      ctx.msg(state, p, "The Villa is already standing here: walk to the stairs, or Q folds it into your hand")
    end
  else
    if cmd:pressed("shrink") then
      ctx.msg(state, p, "The saucer is already as small as it gets")
      ctx.fx(state, p, "denied")
    end
    local want, which = cmd:pressed("grow"), nil
    if cmd:pressed("size1") then want, which = true, "villa" end
    if cmd:pressed("size2") then want, which = true, "seat" end
    if want then
      if which ~= "seat" and (ex.coin == "pocket" or ex.coin == "hand") then
        local ok, why = M.can_deploy_villa(state, p)
        if ok then
          M.deploy_villa(state, p, ctx)
          return
        elseif which == "villa" then
          M.deploy_villa(state, p, ctx) -- says why (and shows the ghost)
          return
        elseif why ~= "busy" and why ~= "charge" then
          ctx.msg(state, p, M.VILLA_REASONS[why] .. ": unfolding the Seat instead")
        end
      end
      if M.deploy(state, p, ctx) then return end
    end
  end
  if ex.grapple and require("sim.tools").grapple_step(state, p, dt) then
    -- add-home-among-stars: reeling in on the Grapple line
    ex.body.yaw = comfort.yaw(ex.body.yaw, cmd, avatar().layout().turn, dt)
  elseif ex.work then
    work_step(state, p, cmd, dt, ctx)
    local STILL = { axis = function(_, a) return (a == "turn" or a == "look") and cmd:axis(a) or 0 end,
                    held = function() return false end, pressed = function(_, k) return cmd:pressed(k) end, aim = cmd.aim }
    M.move(state, p, STILL, dt)
  elseif ex.coin ~= "fold" then
    M.move(state, p, cmd, dt, ctx)
  else
    M.move(state, p, { axis = function(_, a) return (a == "turn" or a == "look") and cmd:axis(a) or 0 end,
                       held = function() return false end, pressed = function() return false end, aim = cmd.aim }, dt)
  end
  if ex.coin ~= "stand" and not (ex.coin == "grow" and ex.deploy and ex.deploy.villa) then ship.pos = M.center(ex.body) end
  local a = M.area(state, p)
  if a ~= ex.area then
    ex.area = a
    if M.AREA_MSG[a] then ctx.msg(state, p, M.AREA_MSG[a]) end
  end
  record_path(state, p)
end

-- the HUD's line: where you are and what Use does
function M.status(state, p)
  local ex = p.excursion
  local names = { crawl = "CRAWLSPACE", chamber = "CHAMBER", strong = "STRONGROOM", hall = "HALL" }
  local where = ex.site == 0 and "ON FOOT: STATION BAY" or string.format("ON FOOT: DERELICT %d %s", ex.site, names[ex.area] or "HALL")
  if ex.coin == "fold" then return where, "THE SAUCER IS FOLDING INTO YOUR HAND" end
  if ex.coin == "grow" then return where, "STAND BACK: THE SEAT IS UNFOLDING" end
  if ex.work then
    return where, ex.work.kind == "lock" and "TURNING THE COUPLING... (MOVE LETS GO)" or "SHUTTING THE GRID DOWN..."
  end
  local t = M.reach(state, p)
  if t then
    if t.kind == "lock" then return where, "USE: TURN THE HAND-LOCK" end
    if t.kind == "console" then return where, "USE: SHUT THE SENTRY GRID DOWN" end
    if #p.hands >= M.tune().hands and t.cand.kind ~= "cache" then return where, "HANDS FULL: E DEPLOYS THE SEAT" end
    return where, "USE: TAKE " .. (t.cand.kind == "cache" and "YOUR CACHE" or items.label(t.cand.item):upper())
  end
  if ex.coin == "stand" then return where, M.stand_text(state, p) end
  if ex.site == 0 then return where, "THE DOOR IN THE BACK WALL LEADS INTO THE STATION" end
  return where, nil
end

-- the coin's state for the HUD
function M.coin_text(p)
  local c = p.excursion.coin
  if c == "pocket" then return "SAUCER: IN YOUR POCKET", "ok" end
  if c == "hand" then return "SAUCER: IN YOUR HAND", "ok" end
  if c == "fold" then return "SAUCER: FOLDING", "busy" end
  if c == "stand" then return "SAUCER: LANDED, ON ITS GEAR", "ok" end
  return "SAUCER: DEPLOYING", "busy"
end

-- 0..1 through the current fold into the hand / growth out of it
function M.morph_t(p)
  local ship = p.ship
  if not ship.morph then return 1 end
  return vec.clamp(1 - ship.t_left / ship.morph.total, 0, 1)
end

return M
