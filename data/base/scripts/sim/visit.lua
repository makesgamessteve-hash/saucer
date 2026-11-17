-- SPDX-License-Identifier: MIT
-- Pocket saucer and station visits (OpenSpec add-pocket-station-visits).
--
-- Docked at a trader station you can reconfigure to the Pocket size: you step
-- out onto the arrival hangar's floor and the saucer shrinks into your hand,
-- a coin you then slip into your pocket. On foot (p.mode = "foot") you walk
-- the station (sim/stationgen.lua): the concourse, the market's stalls, the
-- bar and the hangars, and trade face to face with the folk there. A
-- pickpocket works the crowd: he can lift the coin (and the whole saucer, hold
-- and all) from your pocket, and you can run him down. In a hangar the coin
-- grows back into the Villa (or the Seat) on the pad and you are aboard at
-- that hangar's space door, ready to fly away.
--
-- Everything lives in p.station as plain data (saved, snapshotted, replayed);
-- the layout is rebuilt from its seed. Station-local meters, floor at y = 0.
local vec = require("lib.vec")
local comfort = require("sim.comfort")
local configs = require("sim.config")
local shipm = require("sim.ship")
local sg = require("sim.stationgen")
local items = require("sim.items")
local sm = saucer.math
local M = {}

M.EYE = 1.62
M.USE_R = 1.7       -- reach for a stall, the bar or a patron
M.HAND_TIME = 1.2   -- seconds the coin rests in your palm before you pocket it
M.FENCE_COOL = 120
M.CAUGHT_COOL = 90

local function folk() return sg.folk() end
local function tune() return folk().thief end
M.tune = tune
local function walk_speed() return require("sim.avatar").layout().walk_speed end

function M.pocket_size()
  for i, c in ipairs(configs.all()) do
    if c.pocket then return i end
  end
  return nil
end

function M.layout(state, p)
  local st = p.station
  return sg.get(st and st.seed or sg.seed_for(state, 1))
end

function M.area(state, p)
  local b = p.station.body
  return sg.area_at(M.layout(state, p), b.pos[1], b.pos[3])
end

local function trader_pos(state, idx)
  local list = state.sector.traders or { state.sector.trader }
  return (list[idx] or list[1]).pos
end

-- the two hangars' space doors in the world: the arrival hangar opens where
-- you docked, the far hangar on the opposite side of the station
function M.bays(state, ship, idx)
  local tp = trader_pos(state, idx)
  local K = sg.kit().walk
  local d = vec.sub(ship.pos, tp)
  local hz = sm.sqrt(d[1] * d[1] + d[3] * d[3])
  local dir = hz > 1e-6 and { d[1] / hz, 0, d[3] / hz } or { 0, 0, 1 }
  local out = function(v) return sm.atan2(v[1], v[3]) end
  local b2 = { tp[1] - dir[1] * K.bay_dist, ship.pos[2], tp[3] - dir[3] * K.bay_dist }
  return {
    { pos = vec.copy(ship.pos), yaw = out(dir) },
    { pos = b2, yaw = out({ -dir[1], 0, -dir[3] }) },
  }
end

-- can p pocket the saucer now? -> ok, why
function M.can_pocket(state, p, to)
  local ship = p.ship
  if not configs.get(to).pocket then return false, "range" end
  if ship.morph then return false, "busy" end
  if not require("sim.trade").docked_at(state, p) then return false, "dock" end
  if p.tractor then return false, "beam" end
  if ship.charge < shipm.cost(ship.size, to) then return false, "charge" end
  return true
end

M.REASONS = {
  dock = "The Pocket size only works docked at a station",
  busy = "Hull is still reshaping",
  charge = "Not enough Charge",
  beam = "Let go of the beam first",
}

-- pocket(state, p, to, ctx): step out into the arrival hangar; the saucer
-- shrinks into your hand around where it hangs in front of you
function M.pocket(state, p, to, ctx)
  local ok, why = M.can_pocket(state, p, to)
  if not ok then
    ctx.msg(state, p, M.REASONS[why] or "Cannot pocket the saucer here")
    ctx.fx(state, p, "denied")
    return false
  end
  local ship = p.ship
  local trade = require("sim.trade")
  local idx = trade.docked_at(state, p)
  local from = ship.size
  local seed = sg.seed_for(state, idx)
  local L = sg.get(seed)
  local cfg = configs.get(to)
  ship.charge = ship.charge - shipm.cost(from, to)
  ship.morph = { from = from, pos = vec.copy(ship.pos), yaw = ship.yaw, total = cfg.morph_time or 2.4,
                 eye = vec.copy(ship.pos), pocket = "fold" }
  ship.t_left = ship.morph.total
  ship.size = to
  ship.vel = { 0, 0, 0 }
  ship.bank = 0
  local h = sg.hangars(L)[1]
  p.station = {
    trader = idx, seed = seed, t = 0, hand_t = 0, coin = "fold", from = from,
    body = { pos = { L.spawn.pos[1], 0, L.spawn.pos[3] }, yaw = L.spawn.yaw, pitch = -0.08 },
    bays = M.bays(state, ship, idx), area = h and h.id or 1, stolen = 0, caught = 0,
    thief = { pos = { L.thief.home[1], L.thief.home[2] }, yaw = 0, mode = "lurk", t = 0, cool = 0 },
  }
  p.mode = "foot"
  p.tractor, p.beam_console, p.panel = false, false, false
  p.tv, p.reading = false, false
  ctx.msg(state, p, "You step out onto the hangar floor. The saucer folds down into your hand...")
  ctx.fx(state, p, "shrink")
  saucer.events.emit({ type = "size_change", player = p.index, from = from, to = to })
  return true
end

-- can the coin grow back here? -> ok, why, hangar area
function M.can_unpocket(state, p, to)
  local st = p.station
  if st.coin ~= "pocket" and st.coin ~= "hand" then return false, st.coin == "fold" and "busy" or "gone" end
  if p.ship.morph then return false, "busy" end
  local a = M.area(state, p)
  if not a or (a.kind ~= "hangar" and a.kind ~= "open") then return false, "room" end
  if p.ship.charge < shipm.cost(p.ship.size, to) then return false, "charge" end
  local bay = st.bays[a.bay or 1] or st.bays[1]
  local r, hh = shipm.dims_of(to)
  if require("sim.game").blocked(state, p, bay.pos, r, hh, 0) then return false, "bay" end
  return true, nil, a
end

M.UNPOCKET_REASONS = {
  busy = "Wait for the fold to finish",
  gone = "Your saucer is not with you!",
  room = "No room to grow here: find a hangar",
  charge = "Not enough Charge to unfold",
  bay = "Something is parked outside that hangar's space door",
}

function M.unpocket(state, p, to, ctx)
  local ok, why, a = M.can_unpocket(state, p, to)
  if not ok then
    ctx.msg(state, p, M.UNPOCKET_REASONS[why])
    ctx.fx(state, p, "denied")
    return false
  end
  local st = p.station
  local ship = p.ship
  local bay = st.bays[a.bay or 1] or st.bays[1]
  local from = ship.size
  ship.charge = ship.charge - shipm.cost(from, to)
  ship.morph = { from = from, pos = vec.copy(bay.pos), yaw = bay.yaw, total = configs.get(from).unmorph_time or 2.2,
                 eye = vec.copy(bay.pos), pocket = "grow" }
  ship.t_left = ship.morph.total
  ship.size = to
  ship.pos = vec.copy(bay.pos)
  ship.yaw = bay.yaw
  ship.pitch = 0
  ship.vel = { 0, 0, 0 }
  st.coin = "grow"
  st.grow = { area = a.id, pad = { a.pad[1], a.pad[2] }, bay = a.bay or 1, to = to,
              from = { st.body.pos[1], st.body.pos[3] } }
  p.panel = false
  ctx.msg(state, p, string.format("You toss the coin onto the pad. The %s unfolds...", configs.get(to).name))
  ctx.fx(state, p, "grow")
  saucer.events.emit({ type = "size_change", player = p.index, from = from, to = to })
  return true
end

-- the coin has grown: you are aboard, at the hangar's space door
local function board(state, p, ctx)
  local st = p.station
  local bay = st.grow and st.grow.bay or 1
  p.station = false
  p.mode = "helm"
  p.ship.pitch = 0
  local avatar = require("sim.avatar")
  local L = avatar.layout()
  p.body = avatar.new(L, L.helm.stand, 0)
  ctx.msg(state, p, string.format("Aboard the %s at the %s's space door. Fly out when ready.",
    configs.get(p.ship.size).name, bay == 1 and "arrival hangar" or "far hangar"))
  ctx.fx(state, p, "bank")
end

-- where the player's eyes are, in station-local meters -> pos, yaw, pitch
function M.viewpoint(p)
  local b = p.station.body
  return { b.pos[1], b.pos[2] + M.EYE, b.pos[3] }, b.yaw, b.pitch
end

-- walk the body: like the Villa's decks, axis by axis against the layout
function M.walk(L, body, cmd, dt)
  local A = require("sim.avatar").layout()
  body.yaw = comfort.yaw(body.yaw, cmd, A.turn, dt)
  body.pitch = vec.clamp(body.pitch + cmd:axis("look") * A.look * dt, -A.pitch_limit, A.pitch_limit)
  local mx, mz = cmd:axis("move_x"), cmd:axis("move_z")
  if mx == 0 and mz == 0 then return 0 end
  local heading = body.yaw + require("sim.avatar").head_yaw(cmd.aim)
  local f, r = vec.fwd(heading), vec.right(heading)
  local speed = A.walk_speed * (cmd:held("boost") and A.run_factor or 1)
  local blocked = 0
  for _, i in ipairs({ 1, 3 }) do
    local d = (f[i] * mz + r[i] * mx) * speed * dt
    if d ~= 0 then
      local np = { body.pos[1], 0, body.pos[3] }
      np[i] = np[i] + d
      if sg.free(L, np[1], np[3]) then body.pos = np else blocked = blocked + 1 end
    end
  end
  return blocked
end

local function dist2(a, b)
  local dx, dz = a[1] - b[1], a[2] - b[2]
  return sm.sqrt(dx * dx + dz * dz)
end

local function body_xz(p) return { p.station.body.pos[1], p.station.body.pos[3] } end

-- move a point toward a target at speed; -> new point, arrived
local function toward(q, target, speed, dt)
  local d = dist2(q, target)
  local stepd = speed * dt
  if d <= stepd or d < 1e-6 then return { target[1], target[2] }, true end
  local k = stepd / d
  return { q[1] + (target[1] - q[1]) * k, q[2] + (target[2] - q[2]) * k }, false
end

local function face(th, target)
  local dx, dz = target[1] - th.pos[1], target[2] - th.pos[2]
  if dx * dx + dz * dz > 1e-6 then th.yaw = sm.atan2(dx, dz) end
end

-- the pickpocket's next stop while running: the neighbour of his node that
-- takes him furthest from you (never straight back unless it is a dead end)
local function flee_next(L, th, you)
  local adj = L.nav.adj[th.node] or {}
  local best, bd
  for _, n in ipairs(adj) do
    local q = L.nav.nodes[n]
    local d = dist2(q, you)
    if n == th.prev and #adj > 1 then d = d - 1000 end
    if not bd or d > bd then best, bd = n, d end
  end
  return best or th.node
end

function M.thief_step(state, p, dt, ctx)
  local st = p.station
  local th = st.thief
  local T = tune()
  local L = M.layout(state, p)
  local ws = walk_speed()
  local you = body_xz(p)
  if th.cool > 0 then th.cool = math.max(0, th.cool - dt) end
  local d = dist2(th.pos, you)
  if th.mode == "lurk" then
    -- drift back to his haunt, then wait for a mark
    local home = L.thief.home
    if dist2(th.pos, home) > 0.2 then
      local path = sg.route(L, th.pos, home)
      th.pos = toward(th.pos, path[1], ws * 0.8, dt)
      face(th, path[1])
    end
    if st.t >= T.after and th.cool <= 0 and st.coin == "pocket" and d <= T.notice then
      th.mode = "stalk"
      th.t = 0
    end
  elseif th.mode == "stalk" then
    th.t = th.t + dt
    local path = sg.route(L, th.pos, you)
    th.pos = toward(th.pos, path[1], ws * T.stalk, dt)
    face(th, path[1])
    d = dist2(th.pos, you)
    -- spotted: you turn and look straight at him
    local b = st.body
    local dir = sm.atan2(th.pos[1] - you[1], th.pos[2] - you[2])
    if d <= T.spot_dist and math.abs(sm.wrap(dir - b.yaw)) <= T.spot_angle then
      th.mode, th.cool = "lurk", T.cooldown
      ctx.msg(state, p, "A hooded figure was right behind you. He melts back into the crowd.")
      return
    end
    if st.coin ~= "pocket" or d > T.notice * 2 then
      th.mode, th.cool = "lurk", T.cooldown
      return
    end
    if d <= T.reach then
      st.coin = "thief"
      st.stolen = (st.stolen or 0) + 1
      th.mode, th.t = "flee", 0
      th.node = sg.nearest(L, th.pos) or 1
      th.prev = nil
      th.target = flee_next(L, th, you)
      p.panel = false
      ctx.msg(state, p, "Your pocket is light! A pickpocket has your saucer - catch him! (hold Shift to sprint)")
      ctx.fx(state, p, "denied")
    end
  elseif th.mode == "flee" then
    th.t = th.t + dt
    -- a head start: right after the lift he darts off and cannot be grabbed
    if d <= T.catch and th.t >= T.head_start then
      M.catch(state, p, ctx)
      return
    end
    if th.t >= T.escape then
      th.mode, th.cool = "lurk", M.FENCE_COOL
      th.pos = { L.thief.home[1], L.thief.home[2] }
      st.coin = "fence"
      ctx.msg(state, p, "The pickpocket got away. The bartender at The Drift fences stolen goods...")
      ctx.fx(state, p, "denied")
      return
    end
    local q = L.nav.nodes[th.target]
    local arrived
    th.pos, arrived = toward(th.pos, q, ws * (th.t < T.head_start and T.burst or T.flee), dt)
    face(th, q)
    if arrived then
      th.prev, th.node = th.node, th.target
      th.target = flee_next(L, th, you)
    end
  end
end

-- you grab the fleeing pickpocket: the coin comes back to your hand
function M.catch(state, p, ctx)
  local st = p.station
  local th = st.thief
  if th.mode ~= "flee" then return false end
  th.mode, th.cool = "lurk", M.CAUGHT_COOL
  st.coin, st.hand_t, st.held = "hand", 0, false
  st.caught = (st.caught or 0) + 1
  ctx.msg(state, p, "You catch the thief by the hood. He hands back your saucer and slinks off.")
  ctx.fx(state, p, "pickup")
  return true
end

-- what is within reach: a stall, the bar, a patron, a stroller, the thief
function M.reach(state, p)
  local L = M.layout(state, p)
  local you = body_xz(p)
  local th = p.station.thief
  if th.mode == "flee" and th.t >= tune().head_start and dist2(th.pos, you) <= tune().catch * 1.6 then
    return { kind = "thief" }
  end
  for _, s in ipairs(L.stalls) do
    if dist2(s.spot, you) <= M.USE_R then return { kind = "stall", stall = s } end
  end
  if L.bar and dist2(L.bar.spot, you) <= M.USE_R then return { kind = "bar" } end
  for i, q in ipairs(L.bar and L.bar.patrons or {}) do
    if dist2(q.pos, you) <= M.USE_R then return { kind = "patron", line = q.line, species = q.species, i = i } end
  end
  for i, w in ipairs(L.walkers) do
    local x, z = sg.walker_at(w, state.tick)
    if dist2({ x, z }, you) <= M.USE_R then
      return { kind = "patron", line = (i * 3 + (state.seed or 0)) % #folk().chatter + 1, species = w.species, i = i }
    end
  end
  return nil
end

-- the Use button on foot
function M.use(state, p, ctx)
  local st = p.station
  if st.coin == "fold" or st.coin == "grow" then return false end
  local r = M.reach(state, p)
  if not r then
    local a = M.area(state, p)
    if a and a.kind == "hangar" then
      ctx.msg(state, p, "A hangar: unfold the saucer here (E, or 1 for the Villa)")
    else
      ctx.msg(state, p, "Nothing to use here")
    end
    return false
  end
  if r.kind == "thief" then return M.catch(state, p, ctx) end
  if r.kind == "patron" then
    local sp = folk().species[r.species] or {}
    ctx.msg(state, p, string.format("A %s says: \"%s\"", sp.id or "stranger", folk().chatter[r.line] or "..."))
    return true
  end
  if st.coin == "hand" then
    st.coin = "pocket"
    ctx.msg(state, p, "You pocket the saucer to keep both hands free for haggling.")
  end
  local panel = require("sim.panel")
  if r.kind == "stall" then panel.open(p, "vendor", r.stall.id) else panel.open(p, "bar") end
  return true
end

-- one tick on foot
function M.step(state, p, cmd, dt, ctx)
  local st = p.station
  local ship = p.ship
  st.t = st.t + dt
  if st.coin == "grow" and not ship.morph then
    board(state, p, ctx)
    return
  end
  if st.coin == "fold" and not ship.morph then
    st.coin, st.hand_t = "hand", 0
    ctx.msg(state, p, "The saucer rests in your palm, warm as a big coin.")
  end
  if st.coin == "hand" then
    st.hand_t = st.hand_t + dt
    if st.hand_t >= M.HAND_TIME and not st.held then
      st.coin = "pocket"
      ctx.msg(state, p, "You slip it into your pocket. Explore the station: market, bar, hangars.")
    end
  end
  local L = M.layout(state, p)
  if cmd:pressed("use") then M.use(state, p, ctx) end
  if cmd:pressed("tractor") and (st.coin == "pocket" or st.coin == "hand") then
    -- F: hold the coin out (nobody can lift it from your hand) or put it away
    if st.coin == "pocket" then
      st.coin, st.held = "hand", true
      ctx.msg(state, p, "You hold the saucer in your fist. F puts it away.")
    else
      st.coin, st.held = "pocket", false
      ctx.msg(state, p, "Back into your pocket.")
    end
  end
  local ps = M.pocket_size()
  local want
  if cmd:pressed("grow") then want = ps - 1 end
  for i, k in ipairs({ "size1", "size2" }) do
    if cmd:pressed(k) and i < ps then want = i end
  end
  if want and want >= 1 then
    M.unpocket(state, p, want, ctx)
    if p.mode ~= "foot" or st.coin == "grow" then return end
  end
  if st.coin ~= "fold" and st.coin ~= "grow" then
    M.walk(L, st.body, cmd, dt)
  else
    -- reshaping: you can look around, not walk
    local A = require("sim.avatar").layout()
    st.body.yaw = comfort.yaw(st.body.yaw, cmd, A.turn, dt)
    st.body.pitch = vec.clamp(st.body.pitch + cmd:axis("look") * A.look * dt, -A.pitch_limit, A.pitch_limit)
  end
  local a = M.area(state, p)
  if a and a.id ~= st.area then
    st.area = a.id
    ctx.msg(state, p, a.name)
  end
  M.thief_step(state, p, dt, ctx)
end

-- a menu is open on foot (haggling at a stall, the bar): you stand still,
-- but the station goes on, pickpocket included
function M.panel_step(state, p, dt, ctx)
  p.station.t = p.station.t + dt
  M.thief_step(state, p, dt, ctx)
end

-- the HUD's status: where you are, what Use does
function M.status(state, p)
  local st = p.station
  local a = M.area(state, p)
  local where = "STATION: " .. (a and a.name:upper() or "CONCOURSE")
  if st.coin == "fold" then return where, "THE SAUCER IS FOLDING INTO YOUR HAND" end
  if st.coin == "grow" then return where, "STAND BACK: THE SAUCER IS UNFOLDING" end
  local r = M.reach(state, p)
  if r then
    if r.kind == "thief" then return where, "USE: GRAB THE THIEF" end
    if r.kind == "stall" then return where, "USE: TRADE WITH THE " .. r.stall.name:upper() end
    if r.kind == "bar" then return where, "USE: THE BARTENDER" end
    return where, "USE: TALK"
  end
  if a and a.kind == "hangar" then
    if st.coin == "pocket" or st.coin == "hand" then return where, "E: UNFOLD HERE (1: VILLA  2: SEAT)" end
  end
  return where, nil
end

-- the coin's state for the HUD
function M.coin_text(p)
  local c = p.station.coin
  if c == "pocket" then return "SAUCER: IN YOUR POCKET", "ok" end
  if c == "hand" then return "SAUCER: IN YOUR HAND", "ok" end
  if c == "thief" then return "SAUCER: STOLEN - CATCH THE THIEF!", "alarm" end
  if c == "fence" then return "SAUCER: WITH THE FENCE AT THE BAR", "alarm" end
  return "SAUCER: RESHAPING", "busy"
end

-- the thief's world... station position and how close he is (HUD and view)
function M.thief_info(p)
  local th = p.station.thief
  return th.pos, dist2(th.pos, body_xz(p)), th.mode
end

-- 0..1 how far the fold / unfold animation is (1 when idle)
function M.morph_t(p)
  return shipm.progress(p.ship)
end

-- vendor and bar panels -------------------------------------------------

function M.stall(state, p, id)
  return M.layout(state, p).stalls[id]
end

local function vendor_def(id)
  for _, v in ipairs(folk().vendors) do if v.id == id then return v end end
  return nil
end
M.vendor_def = vendor_def

-- what a vendor pays for an item (nil: not for sale)
function M.vendor_offer(state, p, vendor, item)
  local trade = require("sim.trade")
  if not vendor.buys then return nil end
  local base = trade.offer(state, p.station.trader, item)
  if not base then return nil end
  local k = vendor.buys[item.category or "curio"] or vendor.other or 1
  return math.floor(base * k + 0.5)
end

function M.vendor_rows(state, p, ctx)
  local trade = require("sim.trade")
  local panel = p.panel
  local s = M.stall(state, p, panel and panel.ctx or 1)
  local v = s and vendor_def(s.vendor)
  local close = { text = "Close", act = function(_, pl) pl.panel = false end }
  if not v or not p.station then return { close } end
  local rows = { { text = string.format("Credits: %d c", p.credits or 0), enabled = false } }
  if v.buys then
    local any = false
    for _, it in ipairs(p.hold) do
      local price = M.vendor_offer(state, p, v, it)
      local uid = it.uid
      if price then
        any = true
        rows[#rows + 1] = { text = string.format("Sell %s - %d c", items.label(it), price), act = function(st2, pl)
          local item = items.find(pl, uid)
          if not item then return end
          local got = M.vendor_offer(st2, pl, v, item)
          items.remove(pl, uid)
          pl.credits = (pl.credits or 0) + got
          pl.sold = (pl.sold or 0) + 1
          pl.sold_on_foot = (pl.sold_on_foot or 0) + 1
          trade.saturate(st2, pl.station.trader, trade.key(item))
          local saved = require("sim.save").write(st2)
          ctx.msg(st2, pl, string.format("The %s pays %d c for the %s%s", v.name:lower(), got, items.label(item),
            saved and " (saved)" or ""))
          ctx.fx(st2, pl, "bank")
        end }
      end
    end
    if not any then rows[#rows + 1] = { text = "(nothing in your hold they want)", enabled = false } end
  end
  if v.sells then
    for _, e in ipairs(trade.shop()) do
      if v.sells[e.kind] then
        local ok, why = trade.can_buy(p, e)
        local entry = e
        rows[#rows + 1] = { text = string.format("Buy %s - %d c%s", trade.shop_name(e), e.price,
          why == "owned" and " (owned)" or ""), enabled = ok, act = function(st2, pl)
          if trade.buy(pl, entry) then
            pl.bought_on_foot = (pl.bought_on_foot or 0) + 1
            local saved = require("sim.save").write(st2)
            ctx.msg(st2, pl, string.format("Bought %s%s", trade.shop_name(entry), saved and " (saved)" or ""))
            ctx.fx(st2, pl, "bank")
          end
        end }
      end
    end
  end
  if v.services then
    local rc, hc = trade.refill_cost(p), trade.repair_cost(p)
    rows[#rows + 1] = { text = string.format("Top up the coin's Charge - %d c", rc),
      enabled = rc > 0 and (p.credits or 0) > 0, act = function(st2, pl)
        local n = trade.refill(pl)
        ctx.msg(st2, pl, string.format("The chandler taps %d Charge into your coin", math.floor(n + 0.5)))
        require("sim.save").write(st2)
      end }
    rows[#rows + 1] = { text = string.format("Patch the hull - %d c", hc), enabled = hc > 0 and (p.credits or 0) > 0,
      act = function(st2, pl)
        local n = trade.repair(pl)
        ctx.msg(st2, pl, string.format("Repaired %d hull", n))
        require("sim.save").write(st2)
      end }
  end
  rows[#rows + 1] = close
  return rows
end

function M.vendor_title(state, p)
  local s = p.station and M.stall(state, p, p.panel and p.panel.ctx or 1)
  return s and s.name or "Stall"
end

-- the fence's price for your saucer
function M.fence_price(state, p)
  local trade = require("sim.trade")
  local T = tune()
  local v = 0
  for _, it in ipairs(p.hold) do v = v + (trade.offer(state, p.station.trader, it) or 0) end
  return math.max(T.fence_min, math.floor(v * T.fence_frac + 0.5))
end

-- the most valuable thing in the hold the fence would take instead of credits
function M.fence_item(state, p)
  local trade = require("sim.trade")
  local best, bv
  for _, it in ipairs(p.hold) do
    local v = trade.offer(state, p.station.trader, it)
    if v and (not bv or v > bv) then best, bv = it, v end
  end
  return best
end

function M.bar_rows(state, p, ctx)
  local close = { text = "Close", act = function(_, pl) pl.panel = false end }
  if not p.station then return { close } end
  local rows = { { text = string.format("Credits: %d c", p.credits or 0), enabled = false } }
  if p.station.coin == "fence" then
    local price = M.fence_price(state, p)
    rows[#rows + 1] = { text = string.format("Buy back your saucer - %d c", price), enabled = (p.credits or 0) >= price,
      act = function(st2, pl)
        pl.credits = pl.credits - price
        pl.station.coin, pl.station.hand_t = "hand", 0
        ctx.msg(st2, pl, string.format("The bartender slides your saucer across the counter. %d c poorer.", price))
        ctx.fx(st2, pl, "bank")
      end }
    local it = M.fence_item(state, p)
    if it then
      local uid = it.uid
      rows[#rows + 1] = { text = "Trade the " .. items.label(it) .. " for it", act = function(st2, pl)
        local got = items.find(pl, uid)
        if got then items.remove(pl, uid) end
        pl.station.coin, pl.station.hand_t = "hand", 0
        ctx.msg(st2, pl, "The bartender pockets the " .. items.label(got or it) .. " and hands back your saucer.")
        ctx.fx(st2, pl, "denied")
      end }
    elseif (p.credits or 0) < price then
      rows[#rows + 1] = { text = "Plead (you have nothing to trade)", act = function(st2, pl)
        pl.station.coin, pl.station.hand_t = "hand", 0
        ctx.msg(st2, pl, "\"Keep it. Next round's on you.\" The bartender returns your saucer.")
      end }
    end
  end
  for _, d in ipairs(folk().drinks) do
    local drink = d
    rows[#rows + 1] = { text = string.format("%s - %d c", d.name, d.price), enabled = (p.credits or 0) >= d.price,
      act = function(st2, pl)
        pl.credits = pl.credits - drink.price
        require("sim.buffs").give(st2, pl, drink.buff, drink.minutes)
        pl.drinks = (pl.drinks or 0) + 1
        local def = require("sim.buffs").defs()[drink.buff]
        ctx.msg(st2, pl, string.format("%s. You feel %s.", drink.name, (def and def.name or drink.buff):lower()))
        ctx.fx(st2, pl, "bank")
      end }
  end
  rows[#rows + 1] = { text = "Ask about rumours", act = function(st2, pl)
    local site = require("sim.books").next_echo_site(st2.mystery)
    pl.leads = pl.leads or {}
    pl.leads[tostring(site)] = true
    ctx.msg(st2, pl, string.format("\"Something hums out at site %d. Folk say it's old.\" (lead marked)", site))
  end }
  rows[#rows + 1] = close
  return rows
end

function M.register_panels(ctx)
  local panel = require("sim.panel")
  panel.register("vendor", { title = M.vendor_title, rows = function(state, p) return M.vendor_rows(state, p, ctx) end })
  panel.register("bar", { title = "The Drift: bartender", rows = function(state, p) return M.bar_rows(state, p, ctx) end })
end

return M
