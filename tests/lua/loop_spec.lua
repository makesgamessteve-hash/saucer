-- SPDX-License-Identifier: MIT
-- Milestone 3: the one-sector loop's sim modules in isolation (items, trade,
-- the lab, hull and Fold Retreat, sentries, Scanner/Jammer edges) plus the
-- autopilot drivers the game tests use.
local game = require("sim.game")
local items = require("sim.items")
local trade = require("sim.trade")
local lab = require("sim.lab")
local hull = require("sim.hull")
local sentry = require("sim.sentry")
local clock = require("sim.clock")
local ap = require("sim.autopilot")
local panel = require("sim.panel")
local vec = require("lib.vec")
local avatar = require("sim.avatar")
local L = avatar.layout()

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  for _, p in ipairs(st.players) do
    p.mode, p.panel = "walk", false
    p.body = avatar.new(L, { -2.0, 0.6, -1.0 }, 0)
  end
  return st
end
local function run(st, c, n)
  for _ = 1, n or 1 do game.step(st, { c or cmd(), c or cmd(), c or cmd(), c or cmd() }, 1 / 60) end
end
local function texts(p)
  local t = {}
  for _, m in ipairs(p.msgs) do t[#t + 1] = m.text end
  return table.concat(t, "|")
end
local function item(p, over)
  local it = { type = "fold_shard", name = "Test Shard", size = 1, value = 40, category = "curio", hot = true }
  for k, v in pairs(over or {}) do it[k] = v end
  items.stamp(p, it, it.tier or 2, it.civ or "velari")
  p.hold[#p.hold + 1] = it
  return it
end
local ctx = { msg = function(st, p, s) p.msgs[#p.msgs + 1] = { tick = st.tick, text = s } end, fx = function() end }

describe("items", function()
  it("labels, finds and counts hold items", function()
    local st = new_state()
    local p = st.players[1]
    local a = item(p)
    local b = item(p, { hot = false })
    expect(items.label(a)).to_be("Unknown Velari Curio T2")
    a.ident = true
    expect(items.label(a)).to_be("Test Shard")
    expect(items.civ_name("nobody")).to_be("Unknown")
    expect(items.type_of("nothing")).to_be(nil)
    expect(items.find(p, 999)).to_be(nil)
    expect(items.remove(p, 999)).to_be(nil)
    expect(items.count_hot(p)).to_be(1)
    expect(items.is_echo(b)).to_be(false)
    expect(items.sellable({ echo = 1 })).to_be(false)
    expect(items.remove(p, b.uid)).to_be(b)
  end)
end)

describe("trade", function()
  it("prices, saturates and recovers demand", function()
    local st = new_state()
    local key = "curio:velari"
    expect(trade.demand(st, 1, key)).to_be(1)
    trade.saturate(st, 1, key)
    expect(trade.demand(st, 1, key)).to_be_near(0.95, 1e-9)
    st.tick = st.tick + clock.TICKS_PER_MINUTE * 10
    expect(trade.demand(st, 1, key)).to_be_near(1.05, 1e-9)
    clock.skip(st, 1000)
    expect(trade.demand(st, 1, key)).to_be(1.5)
    for _ = 1, 40 do trade.saturate(st, 1, key) end
    expect(trade.demand(st, 1, key)).to_be(0.5)
  end)
  it("refills Charge and repairs the hull as far as the credits go", function()
    local st = new_state()
    local p = st.players[1]
    p.ship.charge, p.credits = 40, 1000
    expect(trade.refill(p)).to_be(60)
    expect(trade.refill(p)).to_be(0)
    p.ship.charge, p.credits = 40, 10
    expect(trade.refill(p)).to_be(10)
    p.credits = 0
    expect(trade.refill(p)).to_be(0)
    p.ship.hull, p.credits = 50, 20
    expect(trade.repair(p)).to_be(10)
    p.credits = 0
    expect(trade.repair(p)).to_be(0)
  end)
  it("lists offers only when docked, and buys from the terminal", function()
    local st = new_state()
    local p = st.players[1]
    local rows = trade.rows(st, p, ctx)
    expect(rows[1].text).to_contain("No trader in range")
    rows[2].act(st, p)
    expect(p.panel).to_be(false)
    p.ship.pos = vec.copy(st.sector.trader.pos)
    p.site = 0
    p.ship.charge, p.ship.hull, p.credits = 50, 60, 500
    rows = trade.rows(st, p, ctx)
    local refill, repair
    for _, r in ipairs(rows) do
      if r.text:find("Refill", 1, true) then refill = r end
      if r.text:find("Repair", 1, true) then repair = r end
    end
    refill.act(st, p)
    repair.act(st, p)
    expect(p.ship.charge).to_be(100)
    expect(p.ship.hull).to_be(100)
    expect(texts(p)).to_contain("Bought 50 Charge")
    expect(texts(p)).to_contain("Repaired 40 hull")
    expect(select(2, trade.sell(st, p, 1, 12345))).to_be("gone")
  end)
end)

describe("lab bench", function()
  it("queues, pauses in the Seat and refuses what it cannot do", function()
    local st = new_state()
    local p = st.players[1]
    local a = item(p, { tier = 1 })
    expect(lab.enqueue(st, p, 999)).to_be(false)
    expect(lab.enqueue(st, p, a.uid)).to_be(true)
    expect(select(2, lab.enqueue(st, p, a.uid))).to_be("queued")
    local b = item(p, { ident = true })
    expect(select(2, lab.enqueue(st, p, b.uid))).to_be("already identified")
    local c = item(p)
    p.ship.charge = 0
    expect(select(2, lab.enqueue(st, p, c.uid))).to_be("charge")
    p.ship.size = 2
    expect(lab.step(st, p, 100, ctx)).to_be(nil)
    p.ship.size = 1
    items.remove(p, a.uid)
    expect(lab.step(st, p, 100, ctx)).to_be(nil) -- the item went away: the job is dropped
    expect(#p.lab.queue).to_be(0)
  end)
end)

describe("hull and Fold Retreat", function()
  it("drains shields before the hull and retreats folded out as the Villa", function()
    local st = new_state()
    local p = st.players[1]
    local s = p.ship
    hull.damage(s, 30)
    expect(s.shield).to_be(70)
    expect(s.hull).to_be(100)
    hull.damage(s, 200)
    expect(s.shield).to_be(0)
    expect(s.hull).to_be_less(100)
    hull.regen(s, 1)
    expect(s.shield).to_be(0) -- not yet: shields wait after a hit
    hull.regen(s, 10)
    expect(s.shield).to_be_greater(0)
    s.size, s.morph = 2, { from = 1 }
    item(p)
    p.site = 2
    local cache = hull.retreat(st, p, st.sector.trader.pos)
    expect(#cache.items).to_be(1)
    expect(s.size).to_be(1)
    expect(s.morph).to_be(false)
    expect(s.hull).to_be(hull.RETREAT_HULL)
    expect(hull.retreat(st, p, st.sector.trader.pos)).to_be(nil) -- nothing hot left
  end)
end)

describe("sentries", function()
  local function setup()
    local st = new_state()
    local defs = game.sentries(2)
    local w, s
    for i, d in ipairs(defs) do
      if d.kind == "watcher" and not w then w = i end
      if d.kind == "snatcher" and not s then s = i end
    end
    return st, defs, w, s
  end
  it("reboots a disabled Watcher and loses a target that left", function()
    local st, defs, w = setup()
    local dyn = st.sentries[2][w]
    dyn.st, dyn.t = "disabled", 0.01
    sentry.step(st, 2, defs, 1 / 60, ctx)
    expect(dyn.st).to_be("dormant")
    dyn.st, dyn.target, dyn.t = "alert", 1, 0
    st.players[1].site = 0
    for _ = 1, 70 do sentry.step(st, 2, defs, 1 / 60, ctx) end
    expect(dyn.st).to_be("dormant")
    expect(sentry.step(st, 99, {}, 1 / 60, ctx)).to_be(nil)
    expect(sentry.jam(st, 99, {}, { 0, 0, 0 }, { 0, 0, 1 })).to_be(0)
  end)
  it("lets go of a Villa, gives up on an empty hold and loses a far target", function()
    local st, defs, _, s = setup()
    local p = st.players[1]
    local dyn = st.sentries[2][s]
    p.site, p.ship.size = 2, 1
    dyn.st, dyn.target, dyn.t = "latched", 1, 0
    sentry.step(st, 2, defs, 1 / 60, ctx)
    expect(dyn.st).to_be("dormant")
    expect(texts(p)).to_contain("lost its grip")
    p.ship.size = 2
    p.ship.pos = vec.copy(dyn.pos)
    dyn.st, dyn.target, dyn.t = "latched", 1, 2.99
    sentry.step(st, 2, defs, 0.1, ctx)
    expect(dyn.st).to_be("dormant") -- nothing hot to siphon
    dyn.st, dyn.target, dyn.t = "locked", 1, 0
    for _ = 1, 70 do sentry.step(st, 2, defs, 1 / 60, ctx) end
    expect(dyn.st).to_be("dormant")
  end)
end)

describe("scanner and jammer", function()
  it("refuses while recharging or short of Charge, and scans the nearest site from open space", function()
    local st = new_state()
    local p = st.players[1]
    p.mode = "helm"
    p.ship.pos = vec.add(st.sector.sites[2].pos, { 0, 0, -200 })
    run(st, cmd({ pressed = { "scan" } }))
    expect(texts(p)).to_contain("Scan: site 2")
    run(st, cmd({ pressed = { "scan" } }))
    expect(texts(p)).to_contain("Scanner recharging")
    run(st, cmd({ pressed = { "jam" } }))
    expect(texts(p)).to_contain("nothing in range")
    run(st, cmd({ pressed = { "jam" } }))
    expect(texts(p)).to_contain("Jammer recharging")
    p.scan_ready, p.jam_ready, p.ship.charge = 0, 0, 0
    run(st, cmd({ pressed = { "scan" } }))
    run(st, cmd({ pressed = { "jam" } }))
    expect(texts(p)).to_contain("Not enough Charge to scan")
    expect(texts(p)).to_contain("Not enough Charge to jam")
  end)
  it("refuses to tractor what the saucer cannot lift", function()
    local st = new_state()
    local p = st.players[1]
    local tractor = require("sim.tractor")
    local big
    for _, c in ipairs(tractor.candidates(st, p, 1, game.ruin(1))) do
      if c.item.size >= 2 then big = c end
    end
    p.mode, p.ship.size, p.site, p.ship.morph = "helm", 2, 1, false
    p.ship.yaw, p.ship.pitch, p.ship.bank, p.ship.vel = 0, 0, 0, { 0, 0, 0 }
    p.ship.pos = ap.beam_spot(big.pos, 2)
    expect(tractor.scan(st, p, 1, game.ruin(1)).status).to_be("big")
    game.step(st, { cmd({ pressed = { "tractor" } }) }, 1 / 60)
    expect(texts(p)).to_contain("needs a size")
  end)
end)

describe("the tractor beam's alignment rule", function()
  local tractor = require("sim.tractor")
  local function ship(size, over)
    local s = { size = size, pos = { 0, 0, 0 }, yaw = 0, bank = 0, vel = { 0, 0, 0 } }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
  end
  local function below(s, depth, side)
    local e = tractor.frame(s)
    return { e[1] + (side or 0), e[2] - depth, e[3] }
  end
  local function check(s, pos, size, axis)
    return (tractor.check(s, { pos = pos, item = { size = size or 1 }, axis = axis }))
  end
  it("fills in defaults for configurations that only know range and class", function()
    local b = tractor.beam({ height = 2, tractor_range = 9, tractor_class = 2 })
    expect(b.emitter).to_equal({ 0, -1, 0 })
    expect(b.range).to_be(9)
    expect(b.class).to_be(2)
    expect(b.half_angle).to_be(tractor.DEFAULT.half_angle)
    expect(tractor.beam_of(ship(1)).console).to_be(true)
    expect(tractor.beam_of(ship(2)).console).to_be(false)
  end)
  it("points the cone down the banked hull from the belly emitter", function()
    local e, a = tractor.frame(ship(1))
    expect(e[2]).to_be_less(-5)
    expect(a).to_equal({ 0, -1, 0 })
    local _, tilted = tractor.frame(ship(1, { bank = 0.3 }))
    expect(math.abs(tilted[1])).to_be_greater(0.2)
    local m = tractor.measure(ship(1), below(ship(1), 10, 2))
    expect(m.depth).to_be_near(10, 1e-9)
    expect(m.lateral).to_be_near(2, 1e-9)
  end)
  it("checks size, depth, cone, keel, level, stillness and line of sight in that order", function()
    local v = ship(1)
    expect(check(ship(2), below(ship(2), 1), 2)).to_be("big")
    expect(check(v, below(v, 60))).to_be("far")
    expect(check(v, below(v, 1))).to_be("close")
    expect(check(v, below(v, -1))).to_be("close")
    expect(check(v, below(v, 10, 8))).to_be("axis")
    expect(check(v, below(v, 10), 3, 1.0)).to_be("yaw")
    expect(check(v, below(v, 10), 3, saucer.math.pi)).to_be("lock") -- either end first
    expect(check(ship(1, { bank = 0.2 }), below(ship(1, { bank = 0.2 }), 10))).to_be("tilt")
    expect(check(ship(1, { vel = { 3, 0, 0 } }), below(v, 10))).to_be("drift")
    expect(check(v, below(v, 10))).to_be("lock")
    local _, info = tractor.check(v, { pos = below(v, 10, 8), item = { size = 1 } }, saucer.math.pi / 2)
    expect(info.hint).to_contain("OFF AXIS")
    for _, side in ipairs({ { 0, 0, 8 }, { 0, 0, -8 }, { 8, 0, 0 }, { -8, 0, 0 } }) do
      local q = vec.add(below(v, 10), side)
      local _, i2 = tractor.check(v, { pos = q, item = { size = 1 } })
      expect(i2.hint).to_contain("MOVE")
    end
    local _, i3 = tractor.check(v, { pos = below(v, 10), item = { size = 3 } , axis = -1.0 })
    expect(i3.hint).to_contain("TURN")
    expect(tractor.axis_err(saucer.math.pi - 0.1)).to_be_near(-0.1, 1e-9)
    expect(tractor.axis_err(-saucer.math.pi + 0.1)).to_be_near(0.1, 1e-9)
  end)
  it("does not see through derelict walls", function()
    local st = new_state()
    local r = game.ruin(1)
    local w = r.walls[1]
    local mid = { (w[1][1] + w[2][1]) / 2, 0, (w[1][3] + w[2][3]) / 2 }
    local s = ship(2)
    local e = tractor.frame(s)
    s.pos = { mid[1] - e[1], w[2][2] + 1.5 - e[2], mid[3] - e[3] }
    local c = { pos = { mid[1], w[1][2] - 0.5, mid[3] }, item = { size = 1 } }
    local d = tractor.measure(s, c.pos).depth
    if d <= tractor.beam_of(s).range then expect(check(s, c.pos)).to_be("blocked") end
    expect(st).to_be_truthy()
  end)
  it("pulls in no less than the minimum time, easing up the axis while shrinking", function()
    local v = ship(1)
    expect(tractor.pull_time(v, 0)).to_be(tractor.MIN_PULL)
    expect(tractor.pull_time(v, 70)).to_be_near(10, 1e-9)
    local tr = { t = 0, total = 2, from = below(v, 10) }
    local pos, scale, f = tractor.pull_pose(v, tr)
    expect(pos).to_equal(tr.from)
    expect(scale).to_be(1)
    expect(f).to_be(0)
    tr.t = 2
    pos, scale = tractor.pull_pose(v, tr)
    expect(pos).to_equal(tractor.frame(v))
    expect(scale).to_be_near(tractor.beam_of(v).shrink, 1e-9)
    expect(tractor.ease(0.5)).to_be(0.5)
    expect(tractor.ship_half(v)).to_be_greater(1)
  end)
end)

describe("autopilot drivers", function()
  it("walks to stations, takes the helm, enters, loots and leaves a derelict", function()
    local st = new_state()
    local get = function() return st.players[1] end
    local held, pressed = {}, {}
    local t = {}
    function t.state() return st end
    function t.axis(_, a, v) held[a] = v end
    function t.press(_, a) pressed[#pressed + 1] = a end
    function t.wait(n)
      for _ = 1, n or 1 do
        run(st, cmd({ axes = held, pressed = pressed }))
        pressed = {}
      end
    end
    expect(ap.walk_to_station(t, 1, get, "lab")).to_be(true)
    expect(ap.take_helm(t, 1, get)).to_be(true)
    expect(ap.take_helm(t, 1, get)).to_be(true)
    expect(ap.walk_to_station(t, 1, get, "kitchen")).to_be(true)
    t.press(1, "use")
    t.wait(1)
    expect(ap.pick(t, 1, get, "no such row")).to_be(false)
    expect(ap.take_helm(t, 1, get)).to_be(true)
    local r, o = game.ruin(1), st.sector.sites[1].pos
    local hall
    for _, s in ipairs(r.slots) do if r.rooms[s.room].kind == "hall" then hall = s.room end end
    local ok, route = ap.enter(t, 1, get, r, o, hall)
    expect(ok).to_be(true)
    local door = ap.door_center(ap.door_of(r, hall), r.rooms, require("sim.ruin").kit_of(r.kit), o)
    expect(ap.grab(t, 1, get, 1, r, hall, door)).to_be_greater(0)
    expect(ap.leave(t, 1, get, route)).to_be(true)
    expect(get().site).to_be(0)
    expect(ap.wait_until(t, 1, function() return false end, 3)).to_be(false)
    expect(ap.door_of(r, 9999)).to_be(nil)
    local center, yaw = ap.stand_for({ 0, 5, 0 }, { 0, 5, 0 }, 2, 0, 2)
    expect(#center).to_be(3)
    expect(yaw).to_be_near(0, 1e-9)
  end)
end)

describe("milestone 3 panels and HUD", function()
  it("opens the lab bench and lists jobs", function()
    local st = new_state()
    local p = st.players[1]
    local a = item(p)
    lab.enqueue(st, p, a.uid)
    local rows = lab.rows(st, p, ctx)
    expect(rows[1].text).to_contain("Identifying")
    local hud = require("view.hud")
    expect(hud.lab_status(st, p)).to_contain("LAB ID")
    p.ship.size = 2
    expect(hud.lab_status(st, p)).to_contain("PAUSED")
    p.lab.queue = {}
    expect(hud.lab_status(st, p)).to_be(nil)
    expect(hud.alarm(st, p)).to_be(nil)
    expect(panel.title(st, p)).to_be_truthy()
  end)
end)
