-- SPDX-License-Identifier: MIT
-- Playtest bot (docs/playtest/): plays long sessions through real command
-- frames and prints telemetry for tools/playtest/analyze.py. run.sh prepends
-- a header that sets CFG = { run = "run01", style = "...", limit = ticks, ... }.
-- Every player bot is a coroutine that yields once per tick; the scheduler
-- below steps them all, then the sim (so split-screen players act at once).
-- Lines: "PTE tick player kind detail" (events), "PTS ..." (samples every
-- second), "PTM tick player text" (in-game messages).
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ruinm = require("sim.ruin")
local tractor = require("sim.tractor")
local configs = require("sim.config")
local items = require("sim.items")
local mystery = require("sim.mystery")
local sentry = require("sim.sentry")
local galaxy = require("sim.galaxy")
local panel = require("sim.panel")
local vec = require("lib.vec")
local upgrades = require("sim.upgrades")
local trade = require("sim.trade")
local twin = require("sim.twin")

local LIMIT = CFG.limit or 108000
local NET = saucer.net and saucer.net.status and saucer.net.status() or nil
local DELAY = NET and NET.delay or 0

local function S() return T.state() end
local function P(i) return function() return S().players[i] end end
local function tick() return S().tick end
local function ev(pl, kind, detail)
  print(string.format("PTE %d %d %s %s", tick(), pl or 0, kind, detail or ""))
end

-- input API for the autopilot: waits yield the bot coroutine
local B = {}
B.state = T.state
local abort = {}
function B.wait(n)
  for _ = 1, (n or 1) do
    coroutine.yield()
    local co = coroutine.running()
    if abort[co] and abort[co]() then
      abort[co] = nil
      error({ abort = true })
    end
  end
end
-- run f() and bail out of it as soon as stop() turns true -> ok, aborted
function B.guard(stop, f)
  local co = coroutine.running()
  abort[co] = stop
  local ok, err = pcall(f)
  abort[co] = nil
  if ok then return true, false end
  if type(err) == "table" and err.abort then return false, true end
  error(err, 0)
end
function B.press(pl, a, ticks, nowait)
  T.press(pl, a, ticks or 1, true)
  -- one released tick after the hold, so the next press is a fresh edge
  if not nowait then B.wait((ticks or 1) + 1 + DELAY) end
end
function B.axis(pl, a, v, ticks, nowait)
  T.axis(pl, a, v, ticks or 1, true)
  if not nowait then B.wait(ticks or 1) end
end
function B.time_up() return tick() >= LIMIT end

-- with network input delay a menu flick lands DELAY ticks late
if DELAY > 0 then
  ap.pick = function(t, pl, get, prefix)
    for _ = 1, 60 do
      local p = get()
      if not p.panel then return false end
      local want = panel.find(t.state(), p, prefix)
      if not want then return false end
      if p.panel.sel == want then
        t.press(pl, "use")
        return true
      end
      t.axis(pl, "move_z", -1, 1, true)
      t.wait(DELAY + 2)
    end
    return false
  end
end

-- pick the first enabled panel row whose text starts with prefix
local function pick_enabled(pl, prefix, contains)
  local get = P(pl)
  for _ = 1, 60 do
    local p = get()
    if not p.panel then return false end
    local want
    for i, r in ipairs(panel.rows(S(), p)) do
      if r.enabled ~= false and r.text:sub(1, #prefix) == prefix and (not contains or r.text:find(contains, 1, true)) then
        want = i
        break
      end
    end
    if not want then return false end
    if p.panel.sel == want then
      B.press(pl, "use")
      return true
    end
    B.axis(pl, "move_z", want > p.panel.sel and -1 or 1, 1, true)
    B.wait(1 + DELAY)
    B.axis(pl, "move_z", 0, 1, true)
    B.wait(1 + DELAY)
  end
  return false
end

-- print the open panel's rows (what a player would read)
local function dump_panel(pl, tag)
  local p = P(pl)()
  if not p.panel then return end
  local out = {}
  for _, r in ipairs(panel.rows(S(), p)) do out[#out + 1] = (r.enabled == false and "~" or "") .. r.text end
  ev(pl, "panel", (tag or p.panel.kind) .. ": " .. table.concat(out, " || "))
end

-- walk to a station node, press Use, expect a panel
local function station(pl, node)
  local get = P(pl)
  if get().panel then ap.pick(B, pl, get, "Close") end
  if get().mode == "helm" and get().ship.size ~= 1 then ap.resize(B, pl, get, 1) end
  if not ap.walk_to_station(B, pl, get, node) then ev(pl, "fail", "walk to " .. node) return false end
  B.press(pl, "use")
  if get().panel then dump_panel(pl, node) end
  return get().panel ~= false
end

-- log every failed beam-up (where the bot could not line up or pull)
local beam_up0 = ap.beam_up
ap.beam_up = function(t, pl, get, cand, depth)
  local t0 = tick()
  local ok = beam_up0(t, pl, get, cand, depth)
  if not ok then
    ev(pl, "beam_fail", string.format("%s %s size %s room %s after %d ticks ship size %d", cand.kind, cand.key,
      tostring(cand.item and cand.item.size), tostring(cand.room), tick() - t0, get().ship.size))
  end
  return ok
end

local SHOTS = {}
local function shot(name)
  SHOTS[#SHOTS + 1] = name
  B.wait(2)
  T.screenshot(CFG.shots .. CFG.run .. "_" .. name .. ".png")
  ev(0, "shot", name)
  B.wait(1)
end

-- scheduler ---------------------------------------------------------------
local bots = {}
local function spawn(pl, name, fn)
  bots[#bots + 1] = { co = coroutine.create(fn), pl = pl, name = name }
end

local seen = {}
local function sample()
  local st = S()
  for i, p in ipairs(st.players) do
    local last = seen[i] or -1
    for _, m in ipairs(p.msgs or {}) do
      if m.tick > last then print(string.format("PTM %d %d %s", m.tick, i, m.text)) end
    end
    if p.msgs and #p.msgs > 0 then seen[i] = p.msgs[#p.msgs].tick end
    if st.tick % 60 == 0 then
      local hot = 0
      for _, it in ipairs(p.hold) do if it.hot then hot = hot + 1 end end
      local s = p.ship
      print(string.format("PTS %d %d %s %d %d %d %d %.0f %.0f %.0f %.1f %d %d %s %d %.0f", st.tick, i,
        p.mode .. (p.beam_console and "+console" or "") .. (p.panel and ("+" .. p.panel.kind) or ""),
        p.site, p.credits or 0, #p.hold, hot, s.charge, s.hull, s.shield, vec.len(s.vel), s.size,
        st.sector_id or 1, sentry.locked_on(st, p) and "L" or "-", p.banked_value or 0, p.suit or 100))
    end
    -- reflex: jam a Snatcher that latched on (the HUD says "jam it!")
    local latched = false
    for _, m in ipairs(p.msgs or {}) do
      if m.tick == st.tick and m.text:find("latched on", 1, true) then latched = true end
    end
    if CFG.jam and latched and p.mode == "helm" then
      T.press(i, "jam", 1, true)
      ev(i, "jam", "snatcher latched, charge " .. math.floor(p.ship.charge))
    end
    -- a Clamp on the hull: hold Boost to shake it off (what the message says)
    for _, m in ipairs(p.msgs or {}) do
      if CFG.jam and m.tick == st.tick and m.text:find("CLAMPED", 1, true) and p.mode == "helm" then
        T.press(i, "boost", 150, true)
        ev(i, "shake", "boost against a Clamp")
      end
    end
  end
end

local function run_all()
  while true do
    local alive = 0
    for _, b in ipairs(bots) do
      if coroutine.status(b.co) ~= "dead" then
        alive = alive + 1
        local ok, err = coroutine.resume(b.co)
        if not ok then ev(b.pl, "boterror", tostring(err):gsub("\n", " | ")) end
      end
    end
    if alive == 0 then break end
    T.wait(1)
    sample()
    local st = CFG.shot_ticks and CFG.shot_ticks[tick()]
    if st then T.screenshot(CFG.shots .. CFG.run .. "_" .. st .. ".png") ev(0, "shot", st) end
    if tick() > LIMIT + 60 * 600 then
      ev(0, "hardstop", "bots still running 10 min past the limit")
      break
    end
  end
end

-- helpers -----------------------------------------------------------------
local function kit_of(site) return ruinm.kit_of(game.ruin(site).kit) end

-- the strongroom behind an excursion shutter is not a beam target until the
-- shutter is open (hand-lock on foot, or the cutter)
local function sealed(site, c)
  if c.kind ~= "slot" then return false end
  local id = tonumber(c.key:match(":(%d+)$"))
  local s = id and game.ruin(site).slots[id]
  -- (the generic dive leaves strongrooms alone; run08 flies into them)
  return s and s.strong and true or false
end
-- twin vault parts (anchor, vault) are only for the co-op twin routine below
local function twin_part(c) return c.kind == "anchor" or c.kind == "twin" end
local function open_filter(site, want, twin_ok)
  return function(c)
    if twin_part(c) and (not twin_ok or c.sealed) then return false end
    return not sealed(site, c) and (not want or want(c))
  end
end

local function cands(pl, site, twin_ok)
  local p = P(pl)()
  local out = {}
  for _, c in ipairs(tractor.candidates(S(), p, site, game.ruin(site))) do
    if not sealed(site, c) and (not twin_part(c) or (twin_ok and not c.sealed)) then out[#out + 1] = c end
  end
  return out
end

-- rooms with something this player could take, by room id
local function rooms_with_loot(pl, site, want, twin_ok)
  local by = {}
  for _, c in ipairs(cands(pl, site, twin_ok)) do
    if c.room and (not want or want(c)) then
      by[c.room] = by[c.room] or { n = 0, big = 0, value = 0, echo = false }
      local r = by[c.room]
      r.n = r.n + 1
      if (c.item.size or 1) > 1 then r.big = r.big + 1 end
      r.value = r.value + (c.item.value or 0)
      if c.kind == "echo" then r.echo = true end
    end
  end
  return by
end

local function needs_seat(ruin, origin, room)
  for _, w in ipairs(ap.route(ruin, origin, room)) do if w.size ~= 1 then return true end end
  return false
end

-- waypoints from room a (0 = outside) to room b inside a site
local function path_between(ruin, origin, a, b, min_size)
  local rb = ap.route(ruin, origin, b, min_size)
  if a == 0 then return rb end
  local ra = ap.route(ruin, origin, a, min_size)
  local ca, cb = ap.chain(ruin, a), ap.chain(ruin, b)
  local k = 0
  while k < #ca and k < #cb and ca[k + 1] == cb[k + 1] do k = k + 1 end
  local out = {}
  if k == 0 then
    for i = #ra, 1, -1 do out[#out + 1] = { pos = ra[i].pos, tol = ra[i].tol } end
    for i = 1, #rb do out[#out + 1] = rb[i] end
    return out
  end
  for i = #ra, 3 * k, -1 do out[#out + 1] = { pos = ra[i].pos, tol = ra[i].tol } end
  for i = 3 * k + 1, #rb do out[#out + 1] = rb[i] end
  return out
end

local function out_of(ruin, origin, a, min_size)
  local ra = ap.route(ruin, origin, a, min_size)
  local out = {}
  for i = #ra, 1, -1 do out[#out + 1] = { pos = ra[i].pos, tol = ra[i].tol } end
  return out
end

local function hold_free(pl) return upgrades.hold_slots(P(pl)()) - #P(pl)().hold end

-- the bot watches for a Fold Retreat while it flies a dive
-- (the tick of the newest FOLD RETREAT message: a count would miss a new
-- retreat when an old one drops out of the message list at the same time)
local function retreats(pl)
  local n = 0
  for _, m in ipairs(P(pl)().msgs) do if m.text:find("FOLD RETREAT", 1, true) then n = math.max(n, m.tick) end end
  return n
end

local function ensure_helm(pl)
  local get = P(pl)
  if get().panel then ap.pick(B, pl, get, "Close") end
  if get().holo_run or get().tv or get().reading then B.press(pl, "use") end
  return ap.take_helm(B, pl, get)
end

-- get unstuck: probe which way the hull can move and back off that way,
-- then climb or drop (logged: a stuck bot is not always a game bug)
local function unstick(pl)
  local get = P(pl)
  local s = get().ship
  local shipm = require("sim.ship")
  ev(pl, "unstick", string.format("site %d size %d pos %.0f,%.0f,%.0f", get().site, s.size, s.pos[1], s.pos[2], s.pos[3]))
  local r, hh = shipm.dims(s)
  local best, bd
  for _, d in ipairs({ { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }) do
    local np = saucer.physics.move(s.pos, r, hh, vec.scale(d, 15), 1)
    local moved = vec.dist(np, s.pos)
    if not bd or moved > bd then best, bd = d, moved end
  end
  ap.fly(B, pl, get, vec.add(get().ship.pos, vec.scale(best, math.max(4, bd))), 1.5, 600)
  for _, d in ipairs({ { 0, 8, 0 }, { 0, -8, 0 } }) do
    local np = saucer.physics.move(get().ship.pos, r, hh, d, 1)
    if vec.dist(np, get().ship.pos) > 4 then ap.fly(B, pl, get, np, 1.5, 400) break end
  end
end

-- long flights: the autopilot's sky lane, or under every site when that fails
local function travel(pl, pos, tol, max_ticks)
  local get = P(pl)
  if ap.travel(B, pl, get, pos, tol, max_ticks) then return true end
  ev(pl, "stuck", string.format("travel to %.0f,%.0f,%.0f", pos[1], pos[2], pos[3]))
  unstick(pl)
  local low = math.huge
  for i = 1, #S().sector.sites do
    local b = game.site_bounds(i)
    if b and b[1][2] < low then low = b[1][2] end
  end
  low = low - 40
  local sp = get().ship.pos
  if ap.fly(B, pl, get, { sp[1], low, sp[3] }, 4, max_ticks) and ap.fly(B, pl, get, { pos[1], low, pos[3] }, 4, max_ticks) then
    return ap.fly(B, pl, get, pos, tol or 4, max_ticks)
  end
  return ap.travel(B, pl, get, pos, tol, max_ticks)
end

-- dive(pl, site, opts) -> number of items beamed up
-- opts.seat: everything from the Seat (careful in guarded sites)
-- opts.villa_only: skip duct rooms
-- opts.want: candidate filter
local claims = {}
local function dive(pl, site, opts)
  opts = opts or {}
  local key = (S().sector_id or 1) .. ":" .. site
  local function busy()
    for o, k in pairs(claims) do if o ~= pl and k == key then return true end end
    return false
  end
  if busy() then
    local tw = tick()
    ap.wait_until(B, pl, function() return not busy() end, 60 * 600)
    ev(pl, "wait_claim", string.format("site %d waited %d ticks for the other player", site, tick() - tw))
  end
  claims[pl] = key
  local get = P(pl)
  local st = S()
  local ruin, origin = game.ruin(site), st.sector.sites[site].pos
  local guarded = #game.sentries(site) > 0
  local rooms = rooms_with_loot(pl, site, opts.want, opts.twin)
  local villa_rooms, seat_rooms = {}, {}
  for id, r in pairs(rooms) do
    local seat = needs_seat(ruin, origin, id)
    if opts.seat then
      if r.n - r.big > 0 then seat_rooms[#seat_rooms + 1] = id end
    elseif seat then
      if not opts.villa_only and r.n - r.big > 0 then seat_rooms[#seat_rooms + 1] = id end
    else
      villa_rooms[#villa_rooms + 1] = id
    end
  end
  table.sort(villa_rooms)
  table.sort(seat_rooms)
  ev(pl, "dive_start", string.format("site %d kit %s guarded %s villa_rooms %d seat_rooms %d sentries %d",
    site, ruin.kit, tostring(guarded), #villa_rooms, #seat_rooms, #game.sentries(site)))
  if #villa_rooms + #seat_rooms == 0 then return 0 end
  if not ensure_helm(pl) then ev(pl, "fail", "no helm") return 0 end
  local r0 = retreats(pl)
  local retreated = false
  local function fell() if retreats(pl) > r0 then retreated = true end return retreated end
  local got, cur = 0, 0
  local t0 = tick()
  local first = (#villa_rooms > 0) and villa_rooms[1] or seat_rooms[1]
  local size0 = (#villa_rooms > 0) and 1 or 2
  if not ap.resize(B, pl, get, 1) then ev(pl, "fail", "could not unfold for the trip") end
  local entry = ap.route(ruin, origin, first, size0 == 2 and 2 or nil)[1].pos
  local t_travel = tick()
  if not travel(pl, entry, 4, 60 * 240) then
    ev(pl, "stuck", "gave up travelling to site " .. site)
    claims[pl] = nil
    return 0
  end
  ev(pl, "arrived", string.format("site %d after %d ticks", site, tick() - t_travel))
  local function visit(list, size)
    for _, room in ipairs(list) do
      if B.time_up() or (hold_free(pl) <= 0 and not opts.twin) or fell() then return false end
      local wps = path_between(ruin, origin, cur, room, size)
      local tf = tick()
      local ok, leg = ap.follow(B, pl, get, wps, 1500)
      ev(pl, "path", string.format("site %d room %d wps %d ticks %d ok %s", site, room, #wps, tick() - tf, tostring(ok)))
      if fell() then return false end
      if not ok then
        ev(pl, "stuck", string.format("site %d room %d leg %s/%d size %d", site, room, tostring(leg), #wps, get().ship.size))
        unstick(pl)
        ok = ap.follow(B, pl, get, wps, 1500)
        if not ok then
          -- give up on this room: try to get back to the last good room
          local back = path_between(ruin, origin, room, cur == 0 and room or cur, size)
          ap.follow(B, pl, get, back, 900)
          if cur == 0 then return false end
          goto continue
        end
      end
      cur = room
      do
        local before = #get().hold
        local tg = tick()
        local n = ap.grab(B, pl, get, site, ruin, room, nil, open_filter(site, opts.want, opts.twin))
        ev(pl, "grab", string.format("site %d room %d n %d ticks %d", site, room, n, tick() - tg))
        got = got + n
        ev(pl, "room", string.format("site %d room %d size %d got %d hold %d", site, room, get().ship.size, n, #get().hold))
        if n > 0 and CFG.shot_room and not CFG.shot_room_done then
          CFG.shot_room_done = true
          shot("first_haul")
        end
        if n == 0 and before == #get().hold then ev(pl, "nothing", string.format("site %d room %d", site, room)) end
      end
      ::continue::
    end
    return true
  end
  B.guard(function() return fell() end, function()
    local okv = visit(villa_rooms, nil)
    if okv and #seat_rooms > 0 and not fell() then
      if get().ship.size ~= 2 then
        if not ap.resize(B, pl, get, 2) then ev(pl, "fail", "could not fold to the Seat (charge " .. get().ship.charge // 1 .. ")") end
      end
      if get().ship.size == 2 then visit(seat_rooms, 2) end
    end
  end)
  if opts.hold_until and not fell() then
    -- co-op twin vault: hover by the anchor (claim released so the partner can come in)
    claims[pl] = nil
    opts.hold_until()
  end
  if fell() then
    ev(pl, "retreat", string.format("site %d hull gave out, hold %d", site, #get().hold))
  elseif cur ~= 0 then
    local ok = ap.follow(B, pl, get, out_of(ruin, origin, cur, get().ship.size == 2 and 2 or nil), 1500)
    if not ok then
      ev(pl, "stuck", "leaving site " .. site)
      unstick(pl)
      ap.follow(B, pl, get, out_of(ruin, origin, cur, get().ship.size == 2 and 2 or nil), 1500)
    end
    local o = get().ship.pos
    -- clear of the site's volume
    for _ = 1, 6 do
      if get().site == 0 then break end
      ap.fly(B, pl, get, { o[1], o[2], o[3] - 80 }, 3, 1200)
      o = get().ship.pos
    end
    if get().site ~= 0 then ev(pl, "stuck", "still inside site " .. site .. " after leaving") end
  end
  if get().ship.size ~= 1 and get().site == 0 then ap.resize(B, pl, get, 1) end
  claims[pl] = nil
  ev(pl, "dive_end", string.format("site %d got %d ticks %d hold %d banked %d retreat %s", site, got, tick() - t0,
    #get().hold, get().banked_value, tostring(fell())))
  return got
end

-- lab: identify everything unidentified (Charge permitting) and decode Echoes
local function lab(pl, wait_done)
  local get = P(pl)
  if not ensure_helm(pl) then return end
  if get().ship.size ~= 1 and not ap.resize(B, pl, get, 1) then return end
  if not ap.walk_to_station(B, pl, get, "lab") then ev(pl, "fail", "walk to lab") return end
  B.press(pl, "use")
  local q = 0
  for _ = 1, 14 do
    if get().ship.charge < 10 then break end
    if ap.pick(B, pl, get, "Decode ") then q = q + 1
    elseif ap.pick(B, pl, get, "Identify ") then q = q + 1
    else break end
  end
  ap.pick(B, pl, get, "Close")
  ev(pl, "lab", string.format("queued %d charge %.0f", q, get().ship.charge))
  if wait_done and q > 0 then
    ap.wait_until(B, pl, function() return #get().lab.queue == 0 end, 60 * 60 * 3)
    ev(pl, "lab_done", "")
  end
  return q
end

local function trader_idx_pos(pl)
  local st = S()
  local list = st.sector.traders or { st.sector.trader }
  local best, bi
  for i, t in ipairs(list) do
    local d = vec.dist(t.pos, P(pl)().ship.pos)
    if not best or d < best then best, bi = d, i end
  end
  return bi, list[bi].pos
end

-- dock, deliver requests, sell, buy what the style wants, refill, repair
local story_logged = {}
local function trade_run(pl, policy)
  policy = policy or {}
  local get = P(pl)
  if not ensure_helm(pl) then return end
  if get().ship.size ~= 1 then ap.resize(B, pl, get, 1) end
  local _, tp = trader_idx_pos(pl)
  local t0 = tick()
  if not get().docked then
    -- co-op: each saucer has its own berth (two 26 m Villas on one spot block each other)
    travel(pl, { tp[1] + 50 + (pl - 1) * 45, tp[2] + (pl - 1) * 20, tp[3] + 50 }, 6, 60 * 240)
  end
  if not get().docked then ev(pl, "fail", "not docked") return end
  ev(pl, "docked", string.format("after %d ticks", tick() - t0))
  if not ap.walk_to_station(B, pl, get, "trade") then ev(pl, "fail", "walk to trade terminal") return end
  B.press(pl, "use")
  local c0 = get().credits
  local delivered, sold = 0, 0
  for _ = 1, 6 do
    local before = #get().hold
    if not pick_enabled(pl, "Request: ") or #get().hold >= before then break end
    delivered = delivered + 1
  end
  -- co-op party requests: everyone brings part of the order
  for _ = 1, 3 do
    local before = #get().hold
    if not pick_enabled(pl, "Party request: ", " - bring ") or #get().hold >= before then break end
    delivered = delivered + 1
    ev(pl, "party_request", "delivered")
  end
  for _ = 1, 14 do
    local p = get()
    local sellable
    for _, it in ipairs(p.hold) do
      -- the bot heeds the story-item sale warning (data cores, modules, programs)
      local story = trade.story_warning(it)
      if story and not story_logged[pl] then story_logged[pl] = true ev(pl, "sell_warning", items.label(it)) end
      if items.sellable(it) and not it.home and not story and not (policy.keep and policy.keep(it)) then sellable = it break end
    end
    if not sellable then break end
    local before = #p.hold
    if not ap.pick(B, pl, get, "Sell " .. items.label(sellable)) then break end
    if #get().hold >= before then break end
    sold = sold + 1
  end
  if policy.fold and pick_enabled(pl, "Fold Core tier") then ev(pl, "fold_upgrade", "tier " .. (get().fold_tier or 1)) end
  -- saucer upgrades, cheapest first, keeping a reserve for refills and tow bills
  if policy.upgrades ~= false then
    for _ = 1, 4 do
      local best
      for _, d in ipairs(upgrades.list()) do
        local ok, _, price = upgrades.can_buy(get(), d)
        if ok and get().credits - price >= (policy.reserve or 150) and (not best or price < best.price) then
          best = { id = d.id, name = d.name, price = price }
        end
      end
      if not best or not pick_enabled(pl, "Upgrade " .. best.name) then break end
      ev(pl, "upgrade", string.format("%s %d c level %d", best.id, best.price, upgrades.level(get(), best.id)))
    end
  end
  for _, b in ipairs(policy.buy or {}) do
    if get().credits >= (b.min or 0) and pick_enabled(pl, "Buy " .. b.name) then ev(pl, "bought", b.name) end
  end
  ap.pick(B, pl, get, "Refill Charge")
  ap.pick(B, pl, get, "Repair hull")
  ap.pick(B, pl, get, "Close")
  ev(pl, "trade", string.format("sold %d requests %d credits %d -> %d tier %d", sold, delivered, c0, get().credits,
    get().fold_tier or 1))
end

local function sleep(pl)
  local get = P(pl)
  ensure_helm(pl)
  if get().ship.size ~= 1 then ap.resize(B, pl, get, 1) end
  if not ap.walk_to_station(B, pl, get, "bed") then return end
  B.press(pl, "use")
  ap.pick(B, pl, get, "Sleep")
  ev(pl, "sleep", "")
  B.wait(30)
  if get().mode == "wake" then ap.wake(B, pl, get) end
end

-- co-op: agree to someone else's fold jump proposal, then wait for it
local function agree_if_asked(pl)
  local get = P(pl)
  local j = S().jump
  if not j or j.yes[tostring(get().index)] then return false end
  local to, from = j.to, S().sector_id
  ensure_helm(pl)
  if get().ship.size ~= 1 then ap.resize(B, pl, get, 1) end
  B.press(pl, "map")
  local ok = pick_enabled(pl, "Agree: ")
  if get().panel then ap.pick(B, pl, get, "Close") end
  ev(pl, "agree", string.format("to %d ok %s", to, tostring(ok)))
  local t0 = tick()
  ap.wait_until(B, pl, function() return S().sector_id ~= from or not S().jump end, 60 * 300)
  ev(pl, "agree_done", string.format("sector %d waited %d", S().sector_id, tick() - t0))
  return true
end

-- co-op twin vaults (add-playtest-recs): a site of this sector whose twin vault is still shut
local function twin_site()
  local st = S()
  if not twin.on(st) then return nil end
  for i = 1, #st.sector.sites do
    local L = twin.layout(game.ruin(i))
    local e = st.twins and st.twins[twin.key(i)]
    if L and not (e and e.done) then return i, L end
  end
  return nil
end

-- the holder: beam the shutter anchor and hover by it until the partner has the vault (or gives up)
local function twin_hold(pl, max_wait)
  local site, L = twin_site()
  if not site then return false end
  local get = P(pl)
  ev(pl, "twin_hold", "site " .. site)
  local t0 = tick()
  -- (the anchor and the vault sit on loot slots: what lies on them comes up first)
  dive(pl, site, { twin = true, want = function(c) return c.kind ~= "twin" and (c.kind == "anchor" or c.room == L.anchor.room) end,
    hold_until = function()
      if twin.holder(S(), site) ~= get() then ev(pl, "twin_hold_fail", "site " .. site) return end
      ev(pl, "twin_holding", "site " .. site)
      ap.wait_until(B, pl, function()
        local e = S().twins and S().twins[twin.key(site)]
        return (e and e.done) or twin.holder(S(), site) ~= get()
      end, max_wait or 60 * 600)
    end })
  local e = S().twins and S().twins[twin.key(site)]
  ev(pl, "twin_hold_end", string.format("site %d done %s ticks %d", site, tostring(e and e.done), tick() - t0))
  return e and e.done
end

-- the beamer: a partner holds an anchor open -> go and beam the vault
local function twin_take(pl)
  local site = twin_site()
  if not site then return false end
  local h = twin.holder(S(), site)
  if not h or h == P(pl)() then return false end
  local _, L = twin_site()
  local got = dive(pl, site, { twin = true, want = function(c) return c.kind ~= "anchor" and (c.kind == "twin" or c.room == L.vault.room) end })
  ev(pl, "twin_take", string.format("site %d got %d twins %d", site, got, P(pl)().twins or 0))
  local e = S().twins and S().twins[twin.key(site)]
  if e and e.done then shot("twin_vault") end
  return e and e.done
end

-- co-op: say "I'm ready to fold" from the party panel
local function ready_fold(pl, on)
  local get = P(pl)
  if (get().ready_fold == true) == (on ~= false) then return true end
  ensure_helm(pl)
  B.press(pl, "map")
  local ok = ap.pick(B, pl, get, "Party")
  ok = ok and pick_enabled(pl, on == false and "Not ready to fold" or "I'm ready to fold")
  if get().panel then ap.pick(B, pl, get, "Close") end
  if get().panel then ap.pick(B, pl, get, "Close") end
  ev(pl, "ready_fold", tostring(get().ready_fold))
  return ok
end

-- fold jump: open the map and pick the sector by name (co-op: wait for the others)
local function jump(pl, to)
  local get = P(pl)
  local g = galaxy.generate(S().seed)
  if S().jump then
    if S().jump.to == to then return agree_if_asked(pl) or S().sector_id == to end
    agree_if_asked(pl)
    return S().sector_id == to
  end
  ensure_helm(pl)
  if get().ship.size ~= 1 then ap.resize(B, pl, get, 1) end
  local tw = tick()
  ap.wait_until(B, pl, function() return get().ship.charge >= galaxy.core(get()).charge + 5 end, 60 * 90)
  if tick() - tw > 60 then ev(pl, "charge_wait", string.format("%d ticks before the jump", tick() - tw)) end
  B.press(pl, "map")
  local ok = ap.pick(B, pl, get, g.sectors[to].name)
  if ok and get().panel and get().panel.kind == "fold_warn" then
    local lines = galaxy.warning(S(), get(), to)
    ev(pl, "fold_warn", string.format("danger %d lines %d: %s", g.sectors[to].danger, #lines, table.concat(lines, " | ")))
    shot("fold_warn")
    ok = ap.pick(B, pl, get, "Fold anyway")
  end
  if get().panel then ap.pick(B, pl, get, "Close") end
  if not ok then ev(pl, "fail", "map pick " .. g.sectors[to].name) return false end
  local done = ap.wait_until(B, pl, function() return S().sector_id == to end, 60 * (#S().players > 1 and 400 or 60))
  ev(pl, "jump", string.format("to %d %s danger %d ok %s", to, g.sectors[to].name, g.sectors[to].danger, tostring(done)))
  return done
end

-- sites of this sector, nearest first, with loot left for this player
local function site_order(pl)
  local st = S()
  local list = {}
  local taken = {}
  for o, k in pairs(claims) do if o ~= pl then taken[k] = true end end
  for i = 1, #st.sector.sites do
    local n = 0
    for _ in pairs(rooms_with_loot(pl, i)) do n = n + 1 end
    if n > 0 and not taken[(st.sector_id or 1) .. ":" .. i] then
      list[#list + 1] = { i = i, d = game.site_distance(i, P(pl)().ship.pos), guarded = #game.sentries(i) > 0 }
    end
  end
  table.sort(list, function(a, b) return a.d < b.d end)
  return list
end

-- mystery: fetch any unlocked Echo in this sector, decode, open the vault
local function mystery_step(pl)
  local get = P(pl)
  local st = S()
  local did = false
  for i = 1, #st.sector.sites do
    if mystery.echo_at(st.mystery, i, st.sector_id) then
      ev(pl, "echo_hunt", "site " .. i)
      local guarded = #game.sentries(i) > 0
      dive(pl, i, { want = function(c) return c.kind == "echo" end, seat = guarded })
      did = true
    end
  end
  for _, it in ipairs(get().hold) do
    if it.echo and mystery.decodable(st.mystery, it.echo) and not st.mystery.echoes[it.echo].decoded then
      lab(pl, true)
      did = true
      break
    end
  end
  local m = st.mystery
  if m.vault_revealed and not m.vault_open then
    local has_key = false
    for _, it in ipairs(get().hold) do if it.echo and m.echoes[it.echo].role == "key" then has_key = true end end
    if has_key then
      ensure_helm(pl)
      local vp = st.vault.pos
      travel(pl, { vp[1], vp[2] + 2, vp[3] - 40 }, 4, 60 * 200)
      ap.wait_until(B, pl, function() return m.vault_open end, 240)
      ev(pl, "vault", "open " .. tostring(m.vault_open))
      did = true
    end
  end
  if m.vault_open and not st.vault.taken then
    for _, c in ipairs(tractor.candidates(st, get(), 0, nil)) do
      if c.kind == "curio" then
        local ok = ap.beam_up(B, pl, get, c)
        ap.back_to_helm(B, pl, get)
        ev(pl, "curio", tostring(ok and st.vault.taken))
        if ok then shot("curio") end
      end
    end
  end
  return did
end

return {
  T = T, B = B, S = S, P = P, ev = ev, shot = shot, spawn = spawn, run_all = run_all, dive = dive, lab = lab,
  trade_run = trade_run, sleep = sleep, jump = jump, site_order = site_order, mystery_step = mystery_step,
  twin_hold = twin_hold, twin_take = twin_take, twin_site = twin_site, ready_fold = ready_fold,
  ensure_helm = ensure_helm, rooms_with_loot = rooms_with_loot, hold_free = hold_free, tick = tick, LIMIT = LIMIT,
  sealed = sealed, open_filter = open_filter, NET = NET, DELAY = DELAY, unstick = unstick, pick_enabled = pick_enabled, agree_if_asked = agree_if_asked, dump_panel = dump_panel, station = station, travel = travel,
}
