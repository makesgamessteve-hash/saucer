-- SPDX-License-Identifier: MIT
-- Milestone 7 (add-on-foot-excursions): the derelict's on-foot features
-- (crawlspace, chamber, strongroom, hand-lock, grid console), stepping out
-- and deploying, the Suit Charge, the four hand slots, the Lifeline, sentries
-- against a person on foot, saves, and the views.
local game = require("sim.game")
local ruinm = require("sim.ruin")
local footgen = require("sim.footgen")
local ex = require("sim.excursion")
local configs = require("sim.config")
local items = require("sim.items")
local sentry = require("sim.sentry")
local save = require("sim.save")
local vec = require("lib.vec")
local hud = require("view.hud")
local render = require("view.render")
local vex = require("view.excursion")
local sound = require("view.audio")
local xr = require("view.xr")

local function cmd(t) return saucer.input.command(t or {}) end
local function run(st, c, n)
  -- one frame per player in the game (a frame for an empty slot would join it)
  for _ = 1, n or 1 do
    local cs = {}
    for i = 1, #st.players do cs[i] = c or cmd() end
    game.step(st, cs, 1 / 60)
  end
end
local said = {}
local ctx = { msg = function(_, _, t) said[#said + 1] = t end, fx = function() end }
local function last() return said[#said] or "" end
local function heard(p, s)
  for _, m in ipairs(p.msgs) do if m.text:find(s, 1, true) then return true end end
  return false
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

-- the Seat at the helm, hovering at the crawlspace's mouth in derelict 1
local function at_mouth(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  local f = game.ruin(1).foot
  for _, p in ipairs(st.players) do
    p.mode, p.panel = "helm", false
    p.ship.size, p.ship.morph, p.ship.t_left = ex.seat_size(), false, 0
    local m = f.route[1]
    p.ship.pos = { m[1], m[2] + 1.3, m[3] }
    p.ship.vel = { 0, 0, 0 }
    local a = { 0, 0, 0 }
    a[f.channel.axis] = f.channel.sign
    p.ship.yaw = saucer.math.atan2(a[1], a[3])
    p.site = 1
  end
  return st, f
end
-- stepped out, the coin already in the pocket
local function out(n)
  local st, f = at_mouth(n)
  local p = st.players[1]
  expect(ex.step_out(st, p, ctx)).to_be(true)
  p.ship.morph, p.ship.t_left = false, 0
  p.excursion.coin = "pocket"
  return st, p, f
end
local function put(p, q, yaw)
  local b = p.excursion.body
  b.pos = vec.copy(q)
  b.yaw = yaw or b.yaw
  b.vy, b.ground = 0, true
  p.ship.pos = ex.center(b)
end
local function face(p, q)
  local b = p.excursion.body
  b.yaw = saucer.math.atan2(q[1] - b.pos[1], q[3] - b.pos[3])
  local e = ex.eye(b)
  b.pitch = saucer.math.atan2(q[2] - e[2], math.sqrt((q[1] - e[1]) ^ 2 + (q[3] - e[3]) ^ 2))
end

describe("the derelict's on-foot features", function()
  it("every derelict gets a crawlspace, a chamber and a sealed strongroom", function()
    local st = {}
    game.init(st, { seed = 42 })
    for i in ipairs(st.sector.sites) do
      local f = game.ruin(i).foot
      expect(f ~= nil).to_be(true)
      expect(#f.rooms).to_be(3)
      expect(#f.locks).to_be(1)
      expect(#f.consoles).to_be(1)
      expect(#f.delicates).to_be(1)
      expect(#f.shutters).to_be(1)
      expect(#f.route).to_be(4)
      expect(f.locks[1].opens).to_be(f.shutters[1].id)
      expect(game.ruin(i).slots[f.slot].strong).to_be(true)
      -- the crawlspace is 1 m: a person fits crouched, never a saucer
      local ch = f.channel
      expect(ch.w).to_be_less(1.05)
      expect(ch.h).to_be_less(1.05)
      local mid = vec.scale(vec.add(f.route[2], f.route[3]), 0.5)
      local B = ex.tune().body
      expect(saucer.physics.clearance({ mid[1], mid[2] + B.crouch / 2 + 0.01, mid[3] }, B.radius, B.crouch / 2, 0, 1)).to_be(true)
      expect(saucer.physics.clearance({ mid[1], mid[2] + B.stand / 2 + 0.01, mid[3] }, B.radius, B.stand / 2, 0, 1)).to_be(false)
      local pc = configs.get(ex.pocket_size() - 1)
      expect(saucer.physics.clearance({ mid[1], mid[2] + pc.height / 2 + 0.01, mid[3] }, pc.diameter / 2, pc.height / 2, 0, 1)).to_be(false)
      -- standing room in the chamber
      local k = f.route[4]
      expect(saucer.physics.clearance({ k[1], k[2] + B.stand / 2 + 0.01, k[3] }, B.radius, B.stand / 2, 0, 1)).to_be(true)
    end
  end)
  it("is deterministic and leaves the rest of the layout alone", function()
    local st = {}
    game.init(st, { seed = 42 })
    local s = st.sector.sites[2]
    local civ = game.civ_of(s)
    local a = ruinm.generate(s.seed, s.kit, civ, s.pos, nil, s.first)
    local b = ruinm.generate(s.seed, s.kit, civ, s.pos, nil, s.first)
    expect(a.foot.route).to_equal(b.foot.route)
    expect(a.layout_hash).to_be(b.layout_hash)
    for _, r in ipairs(a.foot.rooms) do expect(r.id > footgen.ID0).to_be(true) end
    expect(footgen.tune({}).crawl[1]).to_be(1.0)
  end)
  it("finds features for every kit across many seeds", function()
    local miss = 0
    local st = {}
    game.init(st, { seed = 42 })
    local civ = game.civ_of(st.sector.sites[1])
    for seed = 1, 30 do
      for _, kit in ipairs({ "starship", "station", "city" }) do
        local r = ruinm.generate(seed * 7919, kit, civ, { 0, 0, 0 })
        if not r.foot then miss = miss + 1 end
      end
    end
    expect(miss).to_be(0)
  end)
end)

describe("stepping out and deploying", function()
  it("folds the Seat into your hand on the deck; shrinking past the Seat steps out", function()
    local st, f = at_mouth()
    local p = st.players[1]
    local c0 = p.ship.charge
    run(st, cmd({ pressed = { "size3" } }))
    expect(p.mode).to_be("foot")
    expect(p.excursion.coin).to_be("fold")
    expect(configs.get(p.ship.size).pocket).to_be(true)
    expect(p.ship.charge).to_be_less(c0)
    expect(p.excursions).to_be(1)
    -- the view follows the person's eye; the HUD knows
    local eye = game.viewpoint(p)
    expect(eye[2]).to_be_near(p.excursion.body.pos[2] + ex.tune().body.eye, 1e-6)
    expect(select(2, ex.status(st, p))).to_contain("FOLDING")
    expect(ex.coin_text(p)).to_contain("FOLDING")
    -- the fold ends in your palm, then the pocket
    run(st, cmd(), 60 * 3)
    expect(p.excursion.coin == "hand" or p.excursion.coin == "pocket").to_be(true)
    run(st, cmd(), 90)
    expect(p.excursion.coin).to_be("pocket")
    expect(ex.coin_text(p)).to_contain("POCKET")
    -- F holds it in your fist and puts it back
    run(st, cmd({ pressed = { "tractor" } }))
    expect(p.excursion.coin).to_be("hand")
    expect(ex.coin_text(p)).to_contain("HAND")
    run(st, cmd(), 200)
    expect(p.excursion.coin).to_be("hand")
    run(st, cmd({ pressed = { "tractor" } }))
    expect(p.excursion.coin).to_be("pocket")
    run(st, cmd({ pressed = { "shrink" } }))
    expect(heard(p, "already as small")).to_be(true)
    -- shrink from the Seat steps out too (the fold keys on every device)
    local st2 = at_mouth()
    run(st2, cmd({ pressed = { "shrink" } }))
    expect(st2.players[1].mode).to_be("foot")
    expect(f.route[1] ~= nil).to_be(true)
  end)
  it("refuses with a reason: reshaping, beam, Charge, no deck, no room", function()
    local st = at_mouth()
    local p = st.players[1]
    p.ship.morph = { from = 1, total = 1 }
    expect(select(2, ex.can_step_out(st, p))).to_be("busy")
    p.ship.morph = false
    p.tractor = { key = "x" }
    expect(select(2, ex.can_step_out(st, p))).to_be("beam")
    p.tractor = false
    local c = p.ship.charge
    p.ship.charge = 0
    expect(ex.step_out(st, p, ctx)).to_be(false)
    expect(last()).to_contain("Charge")
    p.ship.charge = c
    local m = p.ship.pos
    p.ship.pos = { m[1], m[2] + 9, m[3] }
    expect(select(2, ex.can_step_out(st, p))).to_be("deck")
    -- in open space far from anything: no deck either
    p.ship.pos = { 0, 9000, 0 }
    expect(select(2, ex.can_step_out(st, p))).to_be("deck")
    expect(ex.REASONS.room).to_contain("room")
  end)
  it("stands crouched where there is no headroom, and a walking pilot keeps their heading", function()
    local st, f = at_mouth()
    local p = st.players[1]
    -- just inside the crawlspace mouth: only a crouch fits
    local q = vec.add(f.route[2], { 0, 0.05, 0 })
    p.ship.pos = q
    local saved = saucer.physics.raycast
    saucer.physics.raycast = function() return { t = 0.05 } end
    local ok, why, feet, crouch = ex.can_step_out(st, p)
    saucer.physics.raycast = saved
    expect(ok).to_be(true)
    expect(why).to_be(nil)
    expect(crouch).to_be(true)
    expect(feet[2]).to_be_near(q[2] - 0.05, 1e-3)
    -- buried in a wall: no room
    local w = game.ruin(1).walls[1]
    p.ship.pos = vec.scale(vec.add(w[1], w[2]), 0.5)
    saucer.physics.raycast = function() return { t = 0.01 } end
    local ok2, why2 = ex.can_step_out(st, p)
    saucer.physics.raycast = saved
    expect(ok2).to_be(false)
    expect(why2).to_be("room")
    local st3 = at_mouth()
    local p3 = st3.players[1]
    p3.mode, p3.body = "walk", { yaw = 0.5, pos = { 0, 0, 0 } }
    expect(ex.step_out(st3, p3, ctx)).to_be(true)
    expect(p3.excursion.body.yaw).to_be_near(saucer.math.wrap(p3.ship.yaw + 0.5), 1e-6)
  end)
  it("deploys the Seat where there is room, never in a crawlspace or mid-fold", function()
    local st, p, f = out()
    -- mid-fold
    p.excursion.coin = "fold"
    expect(select(2, ex.can_deploy(st, p))).to_be("busy")
    p.excursion.coin = "pocket"
    p.ship.morph = { from = 1, total = 1 }
    expect(select(2, ex.can_deploy(st, p))).to_be("busy")
    p.ship.morph = false
    local c = p.ship.charge
    p.ship.charge = 0
    expect(ex.deploy(st, p, ctx)).to_be(false)
    expect(last()).to_contain("Charge")
    p.ship.charge = c
    -- inside the crawlspace
    put(p, f.route[3])
    p.excursion.body.crouch = true
    expect(ex.deploy(st, p, ctx)).to_be(false)
    expect(last()).to_contain("No room")
    expect(p.ghost).to_be(45)
    -- back in the hall, facing the open hall: the Seat grows, you board, the suit refills
    put(p, f.route[1])
    p.excursion.body.crouch = false
    local a = { 0, 0, 0 }
    a[f.channel.axis] = -f.channel.sign
    p.excursion.body.yaw = saucer.math.atan2(a[1], a[3])
    p.hands = { items.stamp(p, { type = "coil", name = "Coil" }, 1, "velari") }
    p.suit = 40
    local h0 = #p.hold
    run(st, cmd({ pressed = { "grow" } }))
    expect(p.excursion.coin).to_be("grow")
    expect(p.ship.size).to_be(ex.seat_size())
    expect(select(2, ex.status(st, p))).to_contain("UNFOLDING")
    expect(ex.coin_text(p)).to_contain("DEPLOYING")
    run(st, cmd(), 60 * 3)
    expect(p.mode).to_be("helm")
    expect(p.excursion).to_be(false)
    expect(p.suit).to_be(ex.tune().suit.max)
    expect(#p.hold).to_be(h0 + 1)
    expect(#p.hands).to_be(0)
    -- size1/size2 deploy too
    local st2, p2 = out()
    local b = p2.excursion.body
    b.yaw = p2.excursion.body.yaw + saucer.math.pi
    run(st2, cmd({ pressed = { "size1" } }))
    expect(p2.excursion.coin == "grow" or heard(p2, "No room")).to_be(true)
  end)
  it("deploys around you when you face a wall, and stows into a full hold as a cache", function()
    local st, p, f = out()
    -- face the crawlspace mouth (a wall right ahead), open hall behind
    put(p, f.route[1])
    local a = { 0, 0, 0 }
    a[f.channel.axis] = f.channel.sign
    p.excursion.body.yaw = saucer.math.atan2(a[1], a[3])
    local c = ex.deploy_spot(st, p)
    expect(c ~= nil).to_be(true)
    p.hold = {}
    for i = 1, configs.all().hold_slots do p.hold[i] = items.stamp(p, { type = "coil", name = "Coil" }, 1, "velari") end
    p.hands = { items.stamp(p, { type = "lens", name = "Lens" }, 1, "velari") }
    local n0 = #(st.caches or {})
    local away = { 0, 0, 0 }
    away[f.channel.axis] = -f.channel.sign
    p.excursion.body.yaw = saucer.math.atan2(away[1], away[3])
    expect(ex.deploy(st, p, ctx)).to_be(true)
    run(st, cmd(), 60 * 3)
    expect(p.mode).to_be("helm")
    expect(#st.caches).to_be(n0 + 1)
    expect(heard(p, "hold is full")).to_be(true)
  end)
end)

describe("on foot", function()
  it("walks, crouches into the crawlspace on its own and stands up after it", function()
    local st, p, f = out()
    put(p, f.route[1])
    face(p, f.route[2])
    p.excursion.body.pitch = 0
    local d0 = vec.dist(p.excursion.body.pos, f.route[3])
    run(st, cmd({ axes = { move_z = 1 } }), 120)
    expect(vec.dist(p.excursion.body.pos, f.route[3])).to_be_less(d0)
    expect(p.excursion.body.crouch).to_be(true)
    expect(p.excursion.area).to_be("crawl")
    expect(select(1, ex.status(st, p))).to_contain("CRAWLSPACE")
    -- crawling drains faster
    local S = ex.tune().suit
    expect(ex.drain(st, p)).to_be_near(S.drain * S.crawl, 1e-9)
    -- into the chamber: stands up again
    put(p, f.route[4])
    p.excursion.body.crouch = true
    run(st, cmd({ axes = { move_x = 0.01 } }), 2)
    expect(p.excursion.body.crouch).to_be(false)
    run(st, cmd(), 1)
    expect(p.excursion.area).to_be("chamber")
    expect(ex.area(st, p)).to_be("chamber")
    -- holding crouch keeps you down; hop needs Suit; boosting runs
    run(st, cmd({ axes = { lift = -1 } }), 2)
    expect(p.excursion.body.crouch).to_be(true)
    run(st, cmd(), 2)
    local s0 = p.suit
    run(st, cmd({ axes = { lift = 1 } }), 1)
    expect(p.suit).to_be_less(s0 - ex.tune().suit.hop + 0.1)
    expect(p.excursion.body.vy).to_be_greater(0)
    run(st, cmd(), 120)
    expect(p.excursion.body.ground).to_be(true)
    local b = p.excursion.body
    local x0 = vec.copy(b.pos)
    run(st, cmd({ axes = { move_z = 1 }, buttons = { "boost" } }), 10)
    expect(vec.dist(b.pos, x0) > 0).to_be(true)
  end)
  it("the suit drains, warns at 30% and 10%, and drains faster under a lock", function()
    local st, p = out()
    p.suit = 31
    run(st, cmd(), 120)
    expect(heard(p, "SUIT CHARGE 30%")).to_be(true)
    p.suit = 10.2
    run(st, cmd(), 60)
    expect(heard(p, "SUIT CHARGE 10%")).to_be(true)
    local saved = sentry.locked_on
    sentry.locked_on = function() return true end
    local S = ex.tune().suit
    expect(ex.drain(st, p)).to_be_near(S.drain * S.locked, 1e-9)
    sentry.locked_on = saved
    ex.bolt(st, p)
    expect(p.suit).to_be_greater(-1e-9)
    local q = { }
    ex.ensure(q)
    expect(q.suit).to_be(S.max)
  end)
  it("takes loot into four hand slots; too big or full hands are refused", function()
    local st, p, f = out()
    local d = f.delicates[1]
    put(p, f.route[4])
    face(p, d.pos)
    -- the lock or console might be closer; take the delicate directly
    local cand
    for _, c in ipairs(ex.candidates(st, p)) do if c.kind == "delicate" then cand = c end end
    expect(cand ~= nil).to_be(true)
    expect(cand.item.delicate).to_be(true)
    expect(ex.grab(st, p, cand, ctx)).to_be(1)
    expect(p.hands[1].delicate).to_be(true)
    expect(p.hands[1].name).to_contain("Delicate")
    for _, c in ipairs(ex.candidates(st, p)) do expect(c.kind ~= "delicate").to_be(true) end
    -- too big for hands
    expect(ex.grab(st, p, { kind = "slot", item = { size = 3 } }, ctx)).to_be(0)
    expect(last()).to_contain("Too big")
    -- full hands
    for i = 2, 4 do p.hands[i] = items.stamp(p, { type = "coil", name = "Coil" }, 1, "velari") end
    expect(ex.grab(st, p, cand, ctx)).to_be(0)
    expect(last()).to_contain("hands are full")
    -- a ruin slot by hand goes through the beam's pick-up into your hands
    p.hands = {}
    local any
    for _, c in ipairs(require("sim.tractor").candidates(st, p, 1, game.ruin(1))) do
      if (c.item.size or 1) <= ex.tune().carry and c.kind == "slot" then any = c break end
    end
    if any then
      local h0 = #p.hold
      expect(ex.grab(st, p, any, ctx)).to_be(1)
      expect(#p.hands).to_be(1)
      expect(#p.hold).to_be(h0)
    end
    -- the HUD line names what Use takes, and full hands
    put(p, d.pos)
    p.excursion.body.pos[2] = d.pos[2] - 1.2
    p.looted = {}
    p.hands = {}
    local _, line = ex.status(st, p)
    expect(line ~= nil).to_be(true)
    for i = 1, 4 do p.hands[i] = items.stamp(p, { type = "coil", name = "Coil" }, 1, "velari") end
    st.locks["1:1"] = 1
    st.grids["1"] = { by = 9, tick = 0 }
    local _, line2 = ex.status(st, p)
    expect(line2).to_contain("HANDS FULL")
    st.locks, st.grids = {}, {}
    -- nothing within reach far away
    put(p, f.route[1])
    p.excursion.body.pitch = 1.5
    p.excursion.body.pos = { 0, 9000, 0 }
    expect(ex.use(st, p, ctx)).to_be(false)
    expect(last()).to_contain("Nothing within reach")
  end)
  it("turns the hand-lock (the shutter opens) and shuts the grid at its console", function()
    local st, p, f = out()
    local lock = f.locks[1]
    put(p, lock.stand)
    face(p, lock.pos)
    expect(ex.reach(st, p).kind).to_be("lock")
    expect(select(2, ex.status(st, p))).to_contain("HAND-LOCK")
    expect(game.shutter_closed(1, lock.opens)).to_be(true)
    run(st, cmd({ pressed = { "use" } }))
    expect(p.excursion.work.kind).to_be("lock")
    expect(select(2, ex.status(st, p))).to_contain("COUPLING")
    -- moving lets go
    run(st, cmd({ axes = { move_z = 1 } }))
    expect(p.excursion.work).to_be(false)
    put(p, lock.stand)
    face(p, lock.pos)
    run(st, cmd({ pressed = { "use" } }))
    -- Use again lets go too
    expect(ex.use(st, p, ctx)).to_be(false)
    expect(last()).to_contain("let go")
    run(st, cmd({ pressed = { "use" } }))
    run(st, cmd(), 60 * ex.tune().lock_time + 2)
    expect(ex.lock_open(st, 1, lock.id)).to_be(true)
    expect(game.shutter_closed(1, lock.opens)).to_be(false)
    expect(game.open_shutter(1, lock.opens)).to_be(false)
    expect(game.open_shutter(99, 1)).to_be(false)
    expect(heard(p, "shutter grinds open")).to_be(true)
    -- the console
    local con = f.consoles[1]
    put(p, con.stand)
    face(p, con.pos)
    expect(ex.reach(st, p).kind).to_be("console")
    expect(select(2, ex.status(st, p))).to_contain("SENTRY GRID")
    run(st, cmd({ pressed = { "use" } }))
    expect(select(2, ex.status(st, p))).to_contain("GRID DOWN")
    run(st, cmd(), 60 * ex.tune().console_time + 2)
    expect(ex.grid_down(st, 1)).to_be(true)
    -- a rebuild (restore) keeps the opened shutter open
    game.rebuild(st)
    expect(game.shutter_closed(1, lock.opens)).to_be(false)
    -- the folding coin blocks Use
    p.excursion.coin = "fold"
    expect(ex.use(st, p, ctx)).to_be(false)
  end)
  it("the Grapple reels you to what it hooks; the Cutter opens a shutter (add-home-among-stars)", function()
    local tools = require("sim.tools")
    local st, p, f = out()
    local b = p.excursion.body
    put(p, f.route[1])
    -- look straight up: the ceiling is close; reel up to it
    b.pitch = 1.4
    local y0 = b.pos[2]
    p.suit = 50
    run(st, cmd({ pressed = { "grapple" } }))
    expect(p.excursion.grapple ~= nil).to_be(true)
    expect(heard(p, "Grapple hooked")).to_be(true)
    expect(p.suit).to_be_less(50)
    expect(tools.grapple_fire(st, p, ctx)).to_be(false) -- one line at a time
    local top = y0
    for _ = 1, 200 do
      run(st, cmd())
      top = math.max(top, p.excursion.body.pos[2])
    end
    expect(p.excursion.grapple).to_be(nil)
    expect(p.grapples).to_be(1)
    expect(top).to_be_greater(y0 + 0.5) -- reeled up toward the ceiling
    -- nothing in range, or no suit charge
    put(p, f.route[1])
    p.excursion.body.pos = { 0, 90000, 0 }
    expect(tools.grapple_fire(st, p, ctx)).to_be(false)
    expect(last()).to_contain("nothing to hook")
    p.suit = 1
    expect(tools.grapple_fire(st, p, ctx)).to_be(false)
    expect(last()).to_contain("not enough suit charge")
    expect(tools.grapple_step(st, p, 1 / 60)).to_be(false)
    -- a grapple that cannot get anywhere lets go
    put(p, f.route[1])
    p.excursion.grapple = { to = vec.add(ex.eye(p.excursion.body), { 0, -30, 0 }), t = 0 }
    for _ = 1, 400 do if not tools.grapple_step(st, p, 1 / 60) then break end end
    expect(p.excursion.grapple).to_be(nil)
    -- the Cutter at the strongroom shutter
    local lock = f.locks[1]
    local sh
    for _, s2 in ipairs(f.shutters) do if s2.id == lock.opens then sh = s2 end end
    local c = { (sh.min[1] + sh.max[1]) / 2, (sh.min[2] + sh.max[2]) / 2, (sh.min[3] + sh.max[3]) / 2 }
    p.suit = 50
    p.excursion.body.pos = { 0, 90000, 0 }
    expect(tools.cut_target(st, p)).to_be(nil)
    -- stand next to it (eye within reach of the box), settled on the floor
    local e = ex.tune().body.eye
    local mn, mx = sh.min, sh.max
    local thin = 1
    for k = 2, 3 do if (mx[k] - mn[k]) < (mx[thin] - mn[thin]) then thin = k end end
    local found = false
    for _, side in ipairs({ -1, 1 }) do
      for _, off in ipairs({ 0.6, 1.0, 1.5, 2.0 }) do
        if not found then
          local q = { c[1], mn[2] + 0.05, c[3] }
          q[thin] = (side < 0 and mn[thin] or mx[thin]) + side * off
          put(p, q)
          run(st, cmd(), 20)
          local tg = tools.cut_target(st, p)
          if tg and tg.kind == "shutter" and ex.area(st, p) ~= "strong" then found = true end
        end
      end
    end
    expect(found).to_be(true)
    expect(e).to_be_greater(0)
    expect(tools.cut_target(st, p).kind).to_be("shutter")
    p.suit = 3
    expect(tools.cut_step(st, p, true, 1 / 60, ctx)).to_be(true)
    expect(last()).to_contain("not enough suit charge")
    p.suit = 50
    run(st, cmd({ pressed = { "spike" }, buttons = { "spike" } }))
    expect(p.cut ~= nil).to_be(true)
    run(st, cmd({ buttons = { "spike" } }), 60)
    run(st, cmd({ buttons = { "spike" } }), 60 * tools.tune().cutter.time + 2)
    expect(game.shutter_closed(1, sh.id)).to_be(false)
    expect(ex.lock_open(st, 1, sh.id)).to_be(true)
    expect(p.cuts).to_be(1)
    expect(p.suit).to_be_less(50)
    run(st, cmd())
    expect(p.cut).to_be(nil)
    expect(tools.cut_target({ sentries = {} }, { mode = "walk" })).to_be(nil)
  end)
  it("Hardcore: the Lifeline loses what was in your hands for good (add-home-among-stars)", function()
    local st, p, f = out()
    st.hardcore = true
    put(p, f.route[1])
    p.hands = { items.stamp(p, { type = "coil", name = "Coil" }, 1, "velari") }
    p.suit = 0.001
    run(st, cmd())
    expect(p.mode).to_be("helm")
    expect(p.lost_for_good).to_be(1)
    for _, c in ipairs(st.caches or {}) do expect(c.lifeline).to_be(nil) end
  end)
  it("the Lifeline: whiteout, the Seat on your trail, the hands left as a cache", function()
    local st, p, f = out()
    -- walk a little to lay a trail, then run dry
    put(p, f.route[1])
    local a = { 0, 0, 0 }
    a[f.channel.axis] = -f.channel.sign
    p.excursion.body.yaw = saucer.math.atan2(a[1], a[3])
    run(st, cmd({ axes = { move_z = 1 } }), 120)
    expect(#p.excursion.path).to_be_greater(1)
    p.hands = { items.stamp(p, { type = "coil", name = "Coil" }, 1, "velari"),
                items.stamp(p, { type = "idol", name = "Echo" }, 1, "velari") }
    p.hands[2].echo = true
    local fell = vec.copy(p.excursion.body.pos)
    p.suit = 0.001
    run(st, cmd())
    expect(p.mode).to_be("helm")
    expect(p.lifelines).to_be(1)
    expect(p.lifeline.tick ~= nil).to_be(true)
    expect(p.suit).to_be(ex.tune().suit.max)
    expect(p.ship.size).to_be(ex.seat_size())
    local cache
    for _, c in ipairs(st.caches) do if c.lifeline then cache = c end end
    expect(#cache.items).to_be(1)
    expect(vec.dist(cache.pos, fell)).to_be_less(1.5)
    -- the Echo stayed with you (into the hold)
    local echo = false
    for _, it in ipairs(p.hold) do if it.echo then echo = true end end
    expect(echo).to_be(true)
    -- the whiteout is drawn, then fades
    local v = fake_view()
    expect(hud.lifeline(v, st, p)).to_be(true)
    st.tick = st.tick + 1000
    expect(hud.lifeline(fake_view(), st, p)).to_be(false)
    p.lifeline = nil
    expect(hud.lifeline(fake_view(), st, p)).to_be(false)
    -- empty hands: no cache; a long trail is thinned
    local st2, p2 = out()
    for i = 1, 300 do p2.excursion.path[i + 1] = vec.add(p2.excursion.path[1], { 0, 0, 0 }) end
    p2.excursion.path = { p2.excursion.path[1] }
    p2.suit = 0
    expect(ex.lifeline(st2, p2, ctx)).to_be(nil)
    -- recover a cache by hand
    local st3, p3, f3 = out()
    st3.caches = { { site = 1, pos = vec.add(f3.route[1], { 0, 0.9, 0 }), owner = p3.record_index, lifeline = true,
                     items = { items.stamp(p3, { type = "coil", name = "Coil" }, 1, "velari") } } }
    put(p3, f3.route[1])
    face(p3, st3.caches[1].pos)
    local t = ex.reach(st3, p3)
    expect(t.cand.kind).to_be("cache")
    expect(select(2, ex.status(st3, p3))).to_contain("CACHE")
    expect(ex.use(st3, p3, ctx)).to_be(true)
    expect(#p3.hands).to_be(1)
    expect(#st3.caches).to_be(0)
  end)
end)

describe("sentries against a person on foot", function()
  it("Watchers see you regardless of size band; bolts bite the suit", function()
    local st, p = out()
    p.ship.pos = { 0, 9000, 0 }
    local T = sentry.tune()
    local def = { site = 1, pos = { 0, 9000, -10 }, band = { 9, 9 }, pitch = 0 }
    local dyn = { yaw = 0, pitch = 0 }
    expect(sentry.watcher_sees(def, dyn, p, 0, T)).to_be(true)
    def.pos = { 0, 9000, -100 }
    expect(sentry.watcher_sees(def, dyn, p, 0, T)).to_be(false)
    def.site = 2
    expect(sentry.watcher_sees(def, dyn, p, 0, T)).to_be(false)
    st.bolts = { { site = 1, pos = { 0, 9000, -0.5 }, vel = { 0, 0, 30 }, life = 1 } }
    local s0 = p.suit
    sentry.step_bolts(st, 1 / 60)
    expect(p.suit).to_be_near(s0 - ex.tune().suit.bolt, 1e-6)
    expect(#st.bolts).to_be(0)
  end)
  it("Snatchers want hot items in your hands, latch onto you and take them", function()
    local st, p = out()
    local T = sentry.tune()
    local def = { site = 1, pos = vec.copy(p.ship.pos) }
    local dyn = { pos = vec.add(p.ship.pos, { 0, 0, 5 }) }
    expect(sentry.snatcher_wants(def, dyn, p, T)).to_be(false)
    local it = items.stamp(p, { type = "coil", name = "Coil" }, 1, "velari")
    it.hot = true
    p.hands = { it }
    expect(#sentry.losable(p)).to_be(1)
    expect(sentry.snatcher_wants(def, dyn, p, T)).to_be(true)
    dyn.pos = vec.add(p.ship.pos, { 0, 0, T.snatcher.foot_sense + 1 })
    expect(sentry.snatcher_wants(def, dyn, p, T)).to_be(false)
    -- latched: it tears the item out of your hands
    local defs = { { kind = "snatcher", site = 1, id = 1, pos = vec.copy(p.ship.pos), patrol = { vec.copy(p.ship.pos) } } }
    st.sentries[1] = { { st = "latched", t = 0, target = 1, pos = vec.copy(p.ship.pos), lost = 0, wp = 1 } }
    sentry.step(st, 1, defs, T.snatcher.latch_time + 0.1, ctx)
    expect(#p.hands).to_be(0)
    expect(last()).to_contain("out of your hands")
  end)
  it("the grid console holds a site's sentries down until you leave; jamming costs suit", function()
    local st, p = out()
    local T = sentry.tune()
    st.sentries[1] = { { st = "latched", t = 0, target = 1, pos = { 0, 0, 0 }, lost = 0, wp = 1 }, { st = "alert", t = 0, target = 1 } }
    p.latched_by = { site = 1 }
    expect(ex.shut_grid(st, p, 1, ctx)).to_be(2)
    expect(p.latched_by).to_be(nil)
    expect(last()).to_contain("2 sentries")
    st.sentries[1][1].st = "dormant"
    sentry.step(st, 1, {}, 1 / 60, ctx)
    expect(st.sentries[1][1].st).to_be("disabled")
    -- another player leaving does nothing; you leaving wakes it
    expect(ex.left_site(st, { index = 2 }, 1, ctx)).to_be(false)
    expect(ex.left_site(st, p, 1, ctx)).to_be(true)
    expect(ex.grid_down(st, 1)).to_be(false)
    expect(ex.left_site(st, p, 1, ctx)).to_be(false)
    st.sentries[1] = { { st = "dormant" } }
    expect(ex.shut_grid(st, p, 1, ctx)).to_be(1)
    expect(last()).to_contain("1 sentry")
    st.sentries[1] = {}
    expect(ex.shut_grid(st, p, 1, ctx)).to_be(0)
    expect(last()).to_contain("Nothing on this grid")
    expect(sentry.grid_up(st, 77)).to_be(0)
    -- the Jammer on foot spends Suit Charge
    p.jam_ready = 0
    local s0 = p.suit
    run(st, cmd({ pressed = { "jam" } }))
    expect(p.suit).to_be_less(s0 - T.jammer.suit + 0.1)
    p.jam_ready = 0
    p.suit = 5
    run(st, cmd({ pressed = { "jam" } }))
    expect(heard(p, "Not enough Suit Charge")).to_be(true)
    run(st, cmd({ pressed = { "scan" } }))
  end)
  it("walking out of the site wakes the grid you shut", function()
    local st, p = out()
    ex.shut_grid(st, p, 1, ctx)
    p.excursion.body.pos = { 0, 9000, 0 }
    p.ship.pos = { 0, 9000, 0 }
    run(st, cmd())
    expect(ex.grid_down(st, 1)).to_be(false)
  end)
end)

describe("saves and the views", function()
  it("a save made on foot loads back on foot with the locks and grids", function()
    local st, p, f = out()
    st.locks["1:1"] = 5
    st.grids["1"] = { by = 1, tick = 5 }
    p.hands = { items.stamp(p, { type = "coil", name = "Coil" }, 1, "velari") }
    p.suit = 55
    local rec = save.record(st)
    local st2 = { players = { {} } }
    save.apply(st2, rec, game)
    local q = st2.players[1]
    expect(q.mode).to_be("foot")
    expect(q.excursion.site).to_be(1)
    expect(q.suit).to_be(55)
    expect(#q.hands).to_be(1)
    expect(st2.locks["1:1"]).to_be(5)
    expect(st2.grids["1"].by).to_be(1)
    expect(game.shutter_closed(1, f.shutters[1].id)).to_be(false)
    expect(st2.version).to_be(game.VERSION)
  end)
  it("renders the props, the hand, the coin, the fold and the HUD without touching the state", function()
    local st, f = at_mouth(2)
    local p = st.players[1]
    ex.step_out(st, p, ctx)
    local o = st.players[2]
    ex.step_out(st, o, ctx)
    local before = require("lib.meshkit").copy(st)
    local v = fake_view()
    render.render(v, saucer.util.readonly(st), 1)
    expect(v.calls.mesh).to_be_greater(10)
    expect(v.texts).to_contain("SUIT")
    expect(v.texts).to_contain("FOLDING")
    expect(st).to_equal(before)
    -- the fold: big at the start, in your hand at the end
    local eye, yaw, pitch = ex.viewpoint(p)
    local hand = vex.hand_pose(eye, yaw, pitch)
    local a = vex.morph_pose(p, hand)
    expect(a.scale).to_be_near(1, 1e-6)
    p.ship.t_left = 0.0001
    local b = vex.morph_pose(p, hand)
    expect(b.scale).to_be_less(0.05)
    expect(vec.dist(b.pos, hand)).to_be_less(0.05)
    p.ship.morph = false
    expect(vex.morph_pose(p, hand)).to_be(nil)
    -- coin in hand, items in hands, chase camera, low suit, work, caches, shutter sliding
    p.excursion.coin = "hand"
    p.hands = { items.stamp(p, { type = "coil", name = "Coil" }, 1, "velari") }
    p.hands[2] = items.stamp(p, { type = "lens", name = "Lens" }, 1, "velari")
    p.hands[2].delicate = true
    p.suit = 8
    p.excursion.work = { kind = "lock", id = 1, t = 1, total = 2 }
    st.caches = { { site = 1, owner = p.record_index, pos = vec.add(p.excursion.body.pos, { 0, 0, 5 }), items = {} },
                  { site = 1, owner = p.record_index, pos = vec.add(p.excursion.body.pos, { 0, 0, -5 }), items = {} },
                  { site = 1, owner = p.record_index, pos = vec.add(p.excursion.body.pos, { 5, 0, 0 }), items = {} } }
    st.locks["1:1"] = st.tick - 30
    st.grids["1"] = { by = 1, tick = 0 }
    v = fake_view()
    render.render(v, st, 1)
    expect(v.texts).to_contain("CRITICAL")
    expect(v.texts).to_contain("CACHE")
    expect(vex.shutter_open(st, 1, 1, st.tick)).to_be_greater(0)
    expect(vex.shutter_open(st, 1, 2, st.tick)).to_be(0)
    p.suit = 25
    p.cam = "chase"
    p.excursion.body.crouch = true
    v = fake_view()
    render.render(v, st, 1)
    expect(v.texts).to_contain("LOW")
    local cam = render.camera(p, false)
    expect(cam.pos[2]).to_be_greater(p.excursion.body.pos[2])
    p.excursion.body.crouch = false
    expect(vex.chase(p).pos[2]).to_be_greater(cam.pos[2])
    -- XR: no 2D text, the wrist shows the suit
    v = fake_view({ xr = true })
    render.render(v, st, 1)
    expect(v.calls.text).to_be(nil)
    local bars = xr.wrist(p, nil)
    expect(bars[1][1]).to_be_near(0.25, 1e-6)
    expect(bars[2][1]).to_be_near(0.5, 1e-6)
    expect(bars[3][1]).to_be_near(0.5, 1e-6)
    p.excursion.work = false
    p.suit = 80
    bars = xr.wrist(p, nil)
    expect(bars[3][1]).to_be(0)
    -- growing back into the Seat
    p.excursion.coin = "pocket"
    put(p, f.route[1])
    local away = { 0, 0, 0 }
    away[f.channel.axis] = -f.channel.sign
    p.excursion.body.yaw = saucer.math.atan2(away[1], away[3])
    expect(ex.deploy(st, p, ctx)).to_be(true)
    local g = vex.morph_pose(p, hand)
    expect(g.scale).to_be_less(0.05)
    v = fake_view()
    render.render(v, st, 1)
    p.ship.t_left = 0.0001
    expect(vex.morph_pose(p, hand).scale).to_be_near(1, 1e-3)
    p.excursion.coin = "weird"
    expect(vex.morph_pose(p, hand)).to_be(nil)
    -- audio plays the derelict on foot
    local lv = sound.levels(st, o)
    expect(lv.derelict).to_be_greater(0.5)
    expect(lv.engine).to_be(0)
    sound.events(st, o)
    -- a player in the world sees the other on foot
    o.excursion.body.crouch = true
    local cnt = fake_view({ player = 2 })
    render.render(cnt, st, 2)
    expect(cnt.calls.mesh).to_be_greater(3)
  end)
end)
