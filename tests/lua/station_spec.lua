-- SPDX-License-Identifier: MIT
-- Milestone 5 (add-pocket-station-visits): the station layout generator, the
-- Pocket configuration, walking on foot, trading face to face, the
-- pickpocket and the fence, unfolding in a hangar, saves, and the views.
local game = require("sim.game")
local sg = require("sim.stationgen")
local visit = require("sim.visit")
local configs = require("sim.config")
local items = require("sim.items")
local save = require("sim.save")
local panel = require("sim.panel")
local vec = require("lib.vec")
local hud = require("view.hud")
local render = require("view.render")
local vstation = require("view.station")

local function cmd(t) return saucer.input.command(t or {}) end
local function run(st, c, n)
  for _ = 1, n or 1 do game.step(st, { c or cmd(), c or cmd() }, 1 / 60) end
end
local said = {}
local ctx = { msg = function(_, _, t) said[#said + 1] = t end, fx = function() end }
local function last() return said[#said] or "" end
local function lastp(p)
  local t = {}
  for _, m in ipairs(p.msgs) do t[#t + 1] = m.text end
  return table.concat(t, " / ")
end
local function fake_view(opts)
  local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = false, texts = "" }
  for k, x in pairs(opts or {}) do v[k] = x end
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image" }) do
    v[m] = function(self, ...)
      self.calls[m] = (self.calls[m] or 0) + 1
      if m == "text" then
        local s = select(3, ...)
        self.texts = self.texts .. s .. "|"
        return #s * 8
      end
    end
  end
  return v
end
local function row(rows, prefix)
  for _, r in ipairs(rows) do if r.text:sub(1, #prefix) == prefix then return r end end
  return nil
end
local function stamp(p, t, tier)
  local it = items.stamp(p, { type = t, name = t }, tier or 1, "velari")
  it.hot = true
  p.hold[#p.hold + 1] = it
  return it
end

-- a player docked at the trader, standing at the helm
local function docked(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  for _, p in ipairs(st.players) do
    p.mode, p.panel = "helm", false
    local tp = st.sector.trader.pos
    p.ship.pos = { tp[1] + 60 + 30 * (p.index - 1), tp[2], tp[3] + 60 }
    p.site = 0
  end
  return st
end
-- docked and already on foot with the coin in the pocket
local function on_foot()
  local st = docked()
  local p = st.players[1]
  expect(visit.pocket(st, p, visit.pocket_size(), ctx)).to_be(true)
  p.ship.morph, p.ship.t_left = false, 0
  p.station.coin = "pocket"
  return st, p, visit.layout(st, p)
end
local function place(p, x, z, yaw)
  p.station.body.pos = { x, 0, z }
  p.station.body.yaw = yaw or 0
end

describe("station layout", function()
  it("is deterministic per seed and differs between seeds", function()
    local a, b = sg.generate(11), sg.generate(11)
    expect(a.hash).to_be(b.hash)
    local seen = {}
    for s = 1, 12 do seen[sg.generate(s).hash] = true end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    expect(n).to_be_greater(8)
    expect(sg.get(11)).to_be(sg.get(11))
  end)
  it("has two hangars, a market with stalls, a bar, a concourse and passages", function()
    for s = 1, 16 do
      local L = sg.generate(s)
      local kinds = {}
      for _, a in ipairs(L.areas) do kinds[a.kind] = (kinds[a.kind] or 0) + 1 end
      expect(kinds.hangar).to_be(2)
      expect(kinds.market).to_be(1)
      expect(kinds.bar).to_be(1)
      expect(kinds.corridor).to_be_greater(1)
      expect(#L.stalls >= 4).to_be(true)
      local h = sg.hangars(L)
      expect(h[1].name).to_be("Arrival hangar")
      expect(h[2].bay).to_be(2)
      -- big enough for the Villa to unfold on the pad
      for _, a in ipairs(h) do
        expect(a.box[3] - a.box[1] >= 30 and a.box[4] - a.box[2] >= 30 and a.h >= 14).to_be(true)
        expect(a.mouth ~= nil).to_be(true)
      end
      -- every nav link is walkable and the graph is connected
      for _, l in ipairs(L.nav.links) do
        expect(sg.clear(L, L.nav.nodes[l[1]], L.nav.nodes[l[2]])).to_be(true)
      end
      for i = 1, #L.nav.nodes do expect(sg.node_path(L, 1, i) ~= nil).to_be(true) end
      -- the spawn, every stall spot and the bar spot can be stood on and reached
      expect(sg.free(L, L.spawn.pos[1], L.spawn.pos[3])).to_be(true)
      for _, s2 in ipairs(L.stalls) do expect(sg.free(L, s2.spot[1], s2.spot[2])).to_be(true) end
      expect(sg.free(L, L.bar.spot[1], L.bar.spot[2])).to_be(true)
    end
  end)
  it("collides with walls and solids, finds areas and routes around corners", function()
    local L = sg.generate(42)
    expect(sg.free(L, 0, 10)).to_be(true)
    expect(sg.free(L, 0, -1000)).to_be(false)
    local crate
    for _, s in ipairs(L.solids) do if s.look == "crate" then crate = s end end
    local cx, cz = (crate.box[1] + crate.box[3]) / 2, (crate.box[2] + crate.box[4]) / 2
    expect(sg.free(L, cx, cz)).to_be(false)
    local tank
    for _, s in ipairs(L.solids) do if s.look == "tank" then tank = s end end
    expect(sg.free(L, tank.c[1], tank.c[2])).to_be(false)
    expect(sg.area_at(L, 0, 10).name).to_be("Concourse")
    expect(sg.area_at(L, 0, -10).kind).to_be("hangar")
    expect(sg.area_at(L, 500, 500)).to_be(nil)
    -- a doorway's walk box counts as the area it leads into
    local d = L.doors[1]
    local dc = sg.door_center(d)
    expect(sg.area_at(L, dc[1], dc[2]) ~= nil).to_be(true)
    local bar = L.bar.spot
    local route = sg.route(L, { 0, -6 }, bar)
    expect(#route).to_be_greater(1)
    expect(route[#route][1]).to_be(bar[1])
    expect(#sg.route(L, { 0, 5 }, { 0, 10 })).to_be(1)
    expect(sg.node_path(L, nil, 1)).to_be(nil)
    local x, z, yaw = sg.walker_at(L.walkers[1], 0)
    expect(x).to_be(L.walkers[1].x)
    expect(z >= L.walkers[1].z0 and z <= L.walkers[1].z1).to_be(true)
    local _, _, yaw2 = sg.walker_at(L.walkers[1], 60 * 600)
    expect(type(yaw) == "number" and type(yaw2) == "number").to_be(true)
  end)
end)

describe("the Pocket configuration", function()
  it("only works docked, not mid-fold, not mid-beam and not when out of Charge", function()
    local st = {}
    game.init(st, { seed = 42, players = 1 })
    local p = st.players[1]
    p.mode = "helm"
    local ps = visit.pocket_size()
    expect(select(2, visit.can_pocket(st, p, 1))).to_be("range")
    expect(select(2, visit.can_pocket(st, p, ps))).to_be("dock")
    said = {}
    expect(visit.pocket(st, p, ps, ctx)).to_be(false)
    expect(last()).to_contain("docked")
    st = docked()
    p = st.players[1]
    p.ship.morph = { from = 1, total = 1 }
    expect(select(2, visit.can_pocket(st, p, ps))).to_be("busy")
    p.ship.morph = false
    p.tractor = { key = "x" }
    expect(select(2, visit.can_pocket(st, p, ps))).to_be("beam")
    p.tractor = false
    p.ship.charge = 5
    expect(select(2, visit.can_pocket(st, p, ps))).to_be("charge")
    p.ship.charge = 100
    expect(visit.can_pocket(st, p, ps)).to_be(true)
  end)
  it("folds into your hand in the arrival hangar, then you pocket it", function()
    local st = docked()
    local p = st.players[1]
    run(st, cmd({ pressed = { "size3" } }))
    expect(p.mode).to_be("foot")
    expect(p.ship.size).to_be(visit.pocket_size())
    expect(p.station.coin).to_be("fold")
    expect(p.ship.charge).to_be(70)
    expect(visit.area(st, p).name).to_be("Arrival hangar")
    -- the viewpoint is in the station; the world draws no saucer for you
    local eye = game.viewpoint(p)
    expect(eye[2]).to_be_near(visit.EYE, 1e-9)
    run(st, cmd({ axes = { move_z = 1 } }), 60 * 3)
    expect(p.station.coin).to_be("hand")
    run(st, cmd(), 80)
    expect(p.station.coin).to_be("pocket")
    -- F takes the coin into your fist and back
    run(st, cmd({ pressed = { "tractor" } }))
    expect(p.station.coin).to_be("hand")
    run(st, cmd(), 120)
    expect(p.station.coin).to_be("hand")
    run(st, cmd({ pressed = { "tractor" } }))
    expect(p.station.coin).to_be("pocket")
  end)
  it("pockets from the Seat too, and the fold keys reach it on every device", function()
    local st = docked()
    local p = st.players[1]
    p.ship.size = 2
    run(st, cmd({ pressed = { "shrink" } }))
    expect(p.mode).to_be("foot")
    expect(p.station.from).to_be(2)
  end)
  it("walks on foot with collision and turns with the look axes", function()
    local st, p, L = on_foot()
    place(p, 0, 10, 0)
    run(st, cmd({ axes = { move_z = 1 } }), 60)
    expect(p.station.body.pos[3]).to_be_greater(12)
    local z = p.station.body.pos[3]
    run(st, cmd({ axes = { move_z = 1 }, buttons = { "boost" } }), 30)
    expect(p.station.body.pos[3] - z).to_be_greater(2.2)
    -- walk sideways into the concourse wall: it stops you
    for _ = 1, 600 do run(st, cmd({ axes = { move_x = 1 } })) end
    expect(math.abs(p.station.body.pos[1]) < 4).to_be(true)
    local y0 = p.station.body.yaw
    run(st, cmd({ axes = { turn = 1, look = 1 } }), 10)
    expect(p.station.body.yaw ~= y0 and p.station.body.pitch > 0).to_be(true)
    -- XR: the head direction steers where the stick walks
    place(p, 0, 20, 0)
    local c = cmd({ axes = { move_z = 1 } })
    c.aim = { 0, 0, -32767 }
    run(st, c, 30)
    expect(p.station.body.pos[3]).to_be_less(20)
  end)
  it("unfolds only in a hangar, with the coin and enough Charge", function()
    local st, p, L = on_foot()
    place(p, 0, 10)
    run(st, cmd({ pressed = { "size1" } }))
    expect(lastp(p)).to_contain("find a hangar")
    expect(p.mode).to_be("foot")
    local far = sg.hangars(L)[2]
    place(p, far.pad[1], far.pad[2])
    p.station.coin = "thief"
    expect(select(2, visit.can_unpocket(st, p, 1))).to_be("gone")
    p.station.coin = "fold"
    expect(select(2, visit.can_unpocket(st, p, 1))).to_be("busy")
    p.station.coin = "pocket"
    p.ship.morph = { from = 1, total = 1 }
    expect(select(2, visit.can_unpocket(st, p, 1))).to_be("busy")
    p.ship.morph = false
    p.ship.charge = 1
    expect(select(2, visit.can_unpocket(st, p, 1))).to_be("charge")
    p.ship.charge = 100
    expect(visit.can_unpocket(st, p, 1)).to_be(true)
    -- the Seat: E grows one step
    run(st, cmd({ pressed = { "grow" } }))
    expect(p.station.coin).to_be("grow")
    expect(p.ship.size).to_be(2)
    expect(vec.dist(p.ship.pos, p.station.bays[2].pos)).to_be_near(0, 1e-9)
    run(st, cmd(), 200)
    expect(p.mode).to_be("helm")
    expect(p.station).to_be(false)
    expect(lastp(p)).to_contain("far hangar")
  end)
  it("unfolds the Villa at the arrival hangar's door where you docked", function()
    local st, p, L = on_foot()
    local dock = vec.copy(p.station.bays[1].pos)
    local h = sg.hangars(L)[1]
    place(p, h.pad[1] + 3, h.pad[2])
    run(st, cmd({ pressed = { "size1" } }))
    expect(p.ship.size).to_be(1)
    run(st, cmd(), 200)
    expect(p.mode).to_be("helm")
    expect(vec.dist(p.ship.pos, dock)).to_be_near(0, 1e-9)
  end)
  it("refuses a hangar whose space door is blocked by another saucer", function()
    local st = docked(2)
    local p, o = st.players[1], st.players[2]
    expect(visit.pocket(st, p, visit.pocket_size(), ctx)).to_be(true)
    p.ship.morph = false
    p.station.coin = "pocket"
    local L = visit.layout(st, p)
    o.ship.pos = vec.copy(p.station.bays[2].pos)
    local far = sg.hangars(L)[2]
    place(p, far.pad[1], far.pad[2])
    expect(select(2, visit.can_unpocket(st, p, 1))).to_be("bay")
  end)
end)

describe("trading on foot", function()
  it("sells at a stall for the vendor's price, with a bonus for their trade", function()
    local st, p, L = on_foot()
    local scrap
    for _, s in ipairs(L.stalls) do if s.vendor == "scrap" then scrap = s end end
    local plate = stamp(p, "plate", 1)
    local lens = stamp(p, "lens", 1)
    local v = visit.vendor_def("scrap")
    local trade = require("sim.trade")
    expect(visit.vendor_offer(st, p, v, plate)).to_be(math.floor(trade.offer(st, 1, plate) * 1.25 + 0.5))
    expect(visit.vendor_offer(st, p, v, lens)).to_be(math.floor(trade.offer(st, 1, lens) * 0.95 + 0.5))
    expect(visit.vendor_offer(st, p, visit.vendor_def("grocer"), lens)).to_be(nil)
    place(p, scrap.spot[1], scrap.spot[2])
    expect(visit.reach(st, p).kind).to_be("stall")
    expect(select(2, visit.status(st, p))).to_contain("SCRAP DEALER")
    p.station.coin = "hand"
    run(st, cmd({ pressed = { "use" } }))
    expect(p.panel.kind).to_be("vendor")
    expect(p.station.coin).to_be("pocket")
    expect(panel.title(st, p)).to_be("Scrap dealer")
    local rows = panel.rows(st, p)
    local r = row(rows, "Sell Unknown Velari Material")
    expect(r ~= nil).to_be(true)
    local c0 = p.credits
    r.act(st, p, r)
    expect(p.credits).to_be_greater(c0)
    expect(p.sold_on_foot).to_be(1)
    expect(#p.hold).to_be(1)
    -- an empty hold says so
    items.remove(p, lens.uid)
    expect(row(panel.rows(st, p), "(nothing") ~= nil).to_be(true)
    row(panel.rows(st, p), "Close").act(st, p)
    expect(p.panel).to_be(false)
  end)
  it("buys from the grocer and the archivist, and the chandler tops up and patches", function()
    local st, p, L = on_foot()
    p.credits = 500
    for _, id in ipairs({ "grocer", "archive", "outfit", "chandler", "curio" }) do
      panel.open(p, "vendor", 1)
      for i, s in ipairs(L.stalls) do if s.vendor == id then p.panel.ctx = i end end
      local rows = panel.rows(st, p)
      expect(#rows).to_be_greater(1)
    end
    -- stock straight from the data (whether or not this market has that stall)
    local grocer = { id = "g", vendor = "grocer", name = "Grocer" }
    local shop_rows = {}
    L.stalls[#L.stalls + 1] = grocer
    panel.open(p, "vendor", #L.stalls)
    local b = row(panel.rows(st, p), "Buy 2 ")
    expect(b ~= nil).to_be(true)
    b.act(st, p, b)
    expect(p.bought_on_foot).to_be(1)
    L.stalls[#L.stalls] = { vendor = "archive", name = "Archivist" }
    local bk = row(panel.rows(st, p), "Buy ")
    bk.act(st, p, bk)
    L.stalls[#L.stalls] = { vendor = "chandler", name = "Chandler" }
    p.ship.charge, p.ship.hull = 40, 60
    local top = row(panel.rows(st, p), "Top up")
    top.act(st, p, top)
    expect(p.ship.charge).to_be(configs.all().max_charge)
    local fix = row(panel.rows(st, p), "Patch the hull")
    fix.act(st, p, fix)
    expect(p.ship.hull).to_be(100)
    L.stalls[#L.stalls] = { vendor = "nobody", name = "Nobody" }
    expect(#panel.rows(st, p)).to_be(1)
    table.remove(L.stalls)
    expect(visit.vendor_title(st, p) ~= nil).to_be(true)
  end)
  it("the bar pours drinks for buffs and sells rumours", function()
    local st, p, L = on_foot()
    p.credits = 20
    place(p, L.bar.spot[1], L.bar.spot[2])
    expect(visit.reach(st, p).kind).to_be("bar")
    run(st, cmd({ pressed = { "use" } }))
    expect(p.panel.kind).to_be("bar")
    expect(panel.title(st, p)).to_contain("bartender")
    local r = row(panel.rows(st, p), "Spark fizz")
    r.act(st, p, r)
    expect(require("sim.buffs").active(st, p, "keen")).to_be(true)
    expect(p.credits).to_be(14)
    local q = row(panel.rows(st, p), "Ask about rumours")
    q.act(st, p, q)
    local any = false
    for _ in pairs(p.leads) do any = true end
    expect(any).to_be(true)
  end)
  it("patrons and strollers talk; elsewhere Use has nothing to do", function()
    local st, p, L = on_foot()
    local q = L.bar.patrons[1]
    place(p, q.pos[1] + 0.5, q.pos[2])
    run(st, cmd({ pressed = { "use" } }))
    expect(lastp(p)).to_contain("says")
    expect(select(2, visit.status(st, p))).to_be("USE: TALK")
    local w = L.walkers[1]
    local x, z = sg.walker_at(w, st.tick + 1)
    place(p, x + 0.4, z)
    expect(visit.use(st, p, ctx)).to_be(true)
    place(p, 0, 30)
    for _, w2 in ipairs(L.walkers) do w2.z0, w2.z1 = 1000, 1001 end
    expect(visit.use(st, p, ctx)).to_be(false)
    expect(last()).to_contain("Nothing to use")
    place(p, 0, -10)
    visit.use(st, p, ctx)
    expect(last()).to_contain("unfold the saucer here")
    expect(select(2, visit.status(st, p))).to_contain("UNFOLD")
    p.station.coin = "fold"
    expect(visit.use(st, p, ctx)).to_be(false)
    expect(select(2, visit.status(st, p))).to_contain("FOLDING")
    p.station.coin = "grow"
    expect(select(2, visit.status(st, p))).to_contain("UNFOLDING")
    -- re-generated layout for the next tests
    for _, w2 in ipairs(L.walkers) do w2.z0, w2.z1 = 3, 20 end
  end)
end)

describe("the pickpocket", function()
  local T = visit.tune()
  it("stalks you, is spooked when you look at him, and lifts the coin from behind", function()
    local st, p, L = on_foot()
    local th = p.station.thief
    p.station.t = T.after + 1
    place(p, th.pos[1], th.pos[2] + 4, 0)  -- facing away from him
    visit.thief_step(st, p, 1 / 60, ctx)
    expect(th.mode).to_be("stalk")
    -- turn round and look straight at him: he melts away
    p.station.body.yaw = saucer.math.pi
    said = {}
    visit.thief_step(st, p, 1 / 60, ctx)
    expect(th.mode).to_be("lurk")
    expect(th.cool).to_be_greater(0)
    expect(last()).to_contain("hooded figure")
    -- cooled down, back turned: he gets the coin
    th.cool = 0
    p.station.body.yaw = 0
    for _ = 1, 600 do
      visit.thief_step(st, p, 1 / 60, ctx)
      if p.station.coin == "thief" then break end
    end
    expect(p.station.coin).to_be("thief")
    expect(th.mode).to_be("flee")
    expect(last()).to_contain("pocket is light")
    expect(visit.coin_text(p)).to_contain("STOLEN")
    -- he has a head start: you cannot grab him at once
    expect(visit.reach(st, p) == nil or visit.reach(st, p).kind ~= "thief").to_be(true)
  end)
  it("leaves you alone while you hold the coin, or when you walk far off", function()
    local st, p, L = on_foot()
    local th = p.station.thief
    p.station.t = T.after + 1
    place(p, th.pos[1], th.pos[2] + 4, 0)
    visit.thief_step(st, p, 1 / 60, ctx)
    expect(th.mode).to_be("stalk")
    p.station.coin = "hand"
    visit.thief_step(st, p, 1 / 60, ctx)
    expect(th.mode).to_be("lurk")
    -- he drifts back to his haunt
    th.pos = { th.pos[1] + 1, th.pos[2] }
    th.cool = 0
    p.station.coin = "pocket"
    place(p, 0, -20, 0)
    for _ = 1, 120 do visit.thief_step(st, p, 1 / 60, ctx) end
    expect(th.mode).to_be("lurk")
    expect(vec.dist({ th.pos[1], 0, th.pos[2] }, { L.thief.home[1], 0, L.thief.home[2] })).to_be_less(0.5)
  end)
  it("can be run down and grabbed: the saucer comes back", function()
    local st, p, L = on_foot()
    local th = p.station.thief
    p.station.coin = "thief"
    th.mode, th.t, th.node = "flee", 0, 1
    th.target = 2
    place(p, th.pos[1], th.pos[2] + 0.5)
    visit.thief_step(st, p, 1 / 60, ctx)
    expect(th.mode).to_be("flee")
    th.t = T.head_start
    place(p, th.pos[1], th.pos[2] + 0.5)
    expect(visit.reach(st, p).kind).to_be("thief")
    expect(select(2, visit.status(st, p))).to_be("USE: GRAB THE THIEF")
    said = {}
    run(st, cmd({ pressed = { "use" } }))
    expect(p.station.coin == "hand" or p.station.coin == "pocket").to_be(true)
    expect(p.station.caught).to_be(1)
    expect(lastp(p)).to_contain("catch the thief")
  end)
  it("runs along the walk graph away from you and escapes to the fence", function()
    local st, p, L = on_foot()
    local th = p.station.thief
    p.station.coin = "thief"
    th.mode, th.t = "flee", 0
    th.node = sg.nearest(L, th.pos)
    th.target = L.nav.adj[th.node][1]
    place(p, 0, -10)
    local moved = false
    local start = { th.pos[1], th.pos[2] }
    for _ = 1, 60 * 4 do
      visit.thief_step(st, p, 1 / 60, ctx)
      if th.pos[1] ~= start[1] or th.pos[2] ~= start[2] then moved = true end
    end
    expect(moved).to_be(true)
    th.t = T.escape
    visit.thief_step(st, p, 1 / 60, ctx)
    expect(p.station.coin).to_be("fence")
    expect(visit.coin_text(p)).to_contain("FENCE")
    expect(th.mode).to_be("lurk")
    -- the fence: buy it back, trade loot for it, or plead
    panel.open(p, "bar")
    p.credits = 0
    local plead = row(panel.rows(st, p), "Plead")
    expect(plead ~= nil).to_be(true)
    plead.act(st, p, plead)
    expect(p.station.coin).to_be("hand")
    p.station.coin = "fence"
    local idol = stamp(p, "idol", 2)
    local price = visit.fence_price(st, p)
    expect(price >= T.fence_min).to_be(true)
    local tr = row(panel.rows(st, p), "Trade the")
    tr.act(st, p, tr)
    expect(items.find(p, idol.uid)).to_be(nil)
    expect(p.station.coin).to_be("hand")
    p.station.coin = "fence"
    p.credits = 1000
    local buy = row(panel.rows(st, p), "Buy back")
    buy.act(st, p, buy)
    expect(p.credits).to_be(1000 - visit.fence_price(st, p))
    expect(p.station.coin).to_be("hand")
    expect(visit.catch(st, p, ctx)).to_be(false)
  end)
end)

describe("saves and the views", function()
  it("a save made on foot loads back on foot with the same station", function()
    local st, p, L = on_foot()
    place(p, 0, 12, 0.5)
    local rec = save.record(st)
    expect(rec.players[1].station.coin).to_be("pocket")
    local st2 = { players = { {} } }
    save.apply(st2, rec, game)
    local q = st2.players[1]
    expect(q.mode).to_be("foot")
    expect(q.station.body.pos[3]).to_be(12)
    expect(visit.layout(st2, q).hash).to_be(L.hash)
    run(st2, cmd({ axes = { move_z = 1 } }), 10)
    expect(q.station.body.pos[3]).to_be_greater(12)
  end)
  it("renders the station, the folk, the coin and the fold without touching the state", function()
    local st = docked(2)
    local p = st.players[1]
    visit.pocket(st, p, visit.pocket_size(), ctx)
    local o = st.players[2]
    visit.pocket(st, o, visit.pocket_size(), ctx)
    local before = require("lib.meshkit").copy(st)
    local v = fake_view()
    render.render(v, saucer.util.readonly(st), 1)
    expect(v.calls.mesh).to_be_greater(10)
    expect(v.texts).to_contain("POCKET")
    expect(v.texts).to_contain("RESHAPING")
    expect(st).to_equal(before)
    local L = visit.layout(st, p)
    local ms = vstation.meshes(L)
    expect(ms.nshell).to_be_greater(20)
    expect(ms.ndetail).to_be_greater(200)
    expect(vstation.meshes(L)).to_be(ms)
    -- fold pose: big at the start, tiny at the end, in your hand
    local eye, yaw, pitch = visit.viewpoint(p)
    local hand = vstation.hand_pose(eye, yaw, pitch)
    local a = vstation.morph_pose(st, p, L, hand)
    expect(a.scale).to_be_near(1, 1e-6)
    p.ship.t_left = 0.0001
    local b = vstation.morph_pose(st, p, L, hand)
    expect(b.scale).to_be_less(0.01)
    expect(vec.dist(b.pos, hand)).to_be_less(0.05)
    -- coin in hand, and the thief running with it
    p.ship.morph = false
    p.station.coin = "hand"
    expect(vstation.morph_pose(st, p, L, hand)).to_be(nil)
    v = fake_view()
    render.render(v, st, 1)
    p.station.coin = "thief"
    p.station.thief.mode, p.station.thief.t = "flee", 3
    v = fake_view()
    render.render(v, st, 1)
    expect(v.texts).to_contain("THIEF")
    p.station.thief.mode = "stalk"
    p.station.thief.pos = { p.station.body.pos[1], p.station.body.pos[3] - 2 }
    v = fake_view()
    render.render(v, st, 1)
    expect(v.texts).to_contain("CROWDING")
    -- unfolding: small at the start, full size on the pad at the end
    p.station.coin = "pocket"
    local far = sg.hangars(L)[2]
    place(p, far.pad[1], far.pad[2] - 5)
    visit.unpocket(st, p, 1, ctx)
    local g = vstation.morph_pose(st, p, L, hand)
    expect(g.scale).to_be_less(0.01)
    v = fake_view({ xr = true })
    render.render(v, st, 1)
    expect(v.calls.text).to_be(nil)
    p.ship.t_left = 0.0001
    expect(vstation.morph_pose(st, p, L, hand).scale).to_be_near(1, 1e-3)
    p.station.coin = "weird"
    expect(vstation.morph_pose(st, p, L, hand)).to_be(nil)
    expect(select(1, visit.coin_text(p))).to_contain("RESHAPING")
    -- the panel sits low on foot
    p.station.coin = "pocket"
    p.ship.morph = false
    panel.open(p, "bar")
    v = fake_view()
    expect(hud.panel(v, st, p)).to_be_greater(2)
    -- the world view of a player whose partner is pocketed draws no saucer for them
    o.mode = "helm"
    local cnt = fake_view({ player = 2 })
    render.render(cnt, st, 1)
    expect(cnt.calls.mesh).to_be_greater(3)
  end)
end)
