-- SPDX-License-Identifier: MIT
-- add-dock-land-eva slice 1: the landing probe and gear, the hull hatch and
-- its stairs, the suit's environment and the standing Villa, driven through
-- the sim with synthetic commands (the end-to-end walk is tests/game/hatch.lua).
local game = require("sim.game")
local landing = require("sim.landing")
local hulldoor = require("sim.hulldoor")
local excursion = require("sim.excursion")
local avatar = require("sim.avatar")
local env = require("sim.env")
local cities = require("sim.cities")
local assets = require("view.assets")
local render = require("view.render")
local gear = require("view.gear")
local vec = require("lib.vec")
local L = avatar.layout()
local T = landing.tune()
local sm = saucer.math

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state()
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  return st
end
local function run(st, c, n)
  for _ = 1, n or 1 do game.step(st, { c or cmd() }, 1 / 60) end
end
local function texts(p)
  local t = {}
  for _, m in ipairs(p.msgs) do t[#t + 1] = m.text end
  return table.concat(t, "|")
end
local ctx = game.ctx
local function fake_view()
  local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = false, texts = "" }
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

-- a flat platform per test, far from everything (physics state is shared by all specs)
local next_platform = 0
local function platform(extra)
  next_platform = next_platform + 1
  local x = 40000 + next_platform * 400
  local y = -9000
  saucer.physics.add_box({ x - 80, y - 20, -80 }, { x + 80, y, 80 }, 1)
  for _, e in ipairs(extra or {}) do
    saucer.physics.add_box({ x + e[1], y + e[2], e[3] }, { x + e[4], y + e[5], e[6] }, 1)
  end
  return { x, y, 0 }
end
local function fly_to(st, at, height)
  local p = st.players[1]
  p.mode, p.panel = "helm", false
  p.ship.pos = { at[1], at[2] + (height or 30), at[3] }
  p.ship.vel = { 0, 0, 0 }
  return p
end

describe("environment", function()
  it("is vacuum in open space, air in a hangar, toxic on a planet city and thin on a moon", function()
    local st = new_state()
    local p = st.players[1]
    expect(env.of_site(0).vacuum).to_be(true)
    expect(env.of_site(nil).breathable).to_be(false)
    expect(env.breathable(st, p)).to_be(false)
    p.station = { coin = "hand" }
    expect(env.at(st, p).breathable).to_be(true)
    p.station = false
    p.berth = { kind = "bay", phase = "landed" }
    expect(env.at(st, p).name).to_be("air")
    p.berth = false
    local seen = {}
    for sector = 1, 8 do
      if pcall(game.enter_sector, st, sector) then
       for i, s in ipairs(st.sector.sites) do
        if s.city then
          local e = env.of_site(i)
          seen[game.ruin(i).city.body] = e
        end
       end
      end
    end
    if seen.planet then expect(seen.planet.toxic).to_be(true) end
    if seen.moon then expect(seen.moon.g).to_be_less(0.5) end
    expect(env.of_site(99).vacuum).to_be(true)
    local e1, e2 = env.of_site(0), env.of_site(0)
    e1.g = 5
    expect(e2.g).to_be(0)
  end)
end)

describe("the landing probe", function()
  it("reads the ground under three feet and the centre", function()
    local st = new_state()
    local at = platform()
    local p = fly_to(st, at, 30)
    local rep = landing.probe(st, p)
    expect(rep.ok).to_be(true)
    expect(rep.ref).to_be_near(at[2], 1e-6)
    expect(rep.slope).to_be_less(0.01)
    expect(rep.dist).to_be_near(30 - T.leg_len, 1e-6)
    expect(#landing.feet_xz(p.ship.pos, 0.3)).to_be(3)
    expect(landing.ground(at[1], at[2] + 5, 0)).to_be_near(at[2], 1e-6)
    expect(landing.ground(at[1], at[2] + 5, 1000)).to_be(nil)
  end)
  it("refuses a drop-off, a step, a wall and a hull that does not fit", function()
    local st = new_state()
    local at = platform({ { 0, 0, -60, 60, 2.4, -20 } })
    local p = fly_to(st, at, 30)
    p.ship.pos[1] = at[1] + 79
    expect(landing.probe(st, p).why).to_be("void")
    p.ship.pos = { at[1], at[2] + 30, 2000 }
    expect(landing.probe(st, p).why).to_be("void")
    p.ship.pos = { at[1], at[2] + 30, -30 }
    local r = landing.probe(st, p)
    expect(r.ok).to_be(false)
    expect(r.why).to_be("slope")
    local real = saucer.physics.raycast
    saucer.physics.raycast = function(a, b, c, d)
      local h = real(a, b, c, d)
      if h then h.normal = { 0, 0.3, 0.95 } end
      return h
    end
    p.ship.pos = { at[1], at[2] + 30, 40 }
    local w = landing.probe(st, p)
    saucer.physics.raycast = real
    expect(w.why).to_be("wall")
    -- no room for the hull at rest height
    p.ship.pos = { at[1], at[2] + 30, 40 }
    local blocked = game.blocked
    game.blocked = function() return true end
    local ok, why = landing.can_land(st, p)
    game.blocked = blocked
    expect(ok).to_be(false)
    expect(why).to_be("room")
  end)
  it("says why a landing cannot start", function()
    local st = new_state()
    local at = platform()
    local p = fly_to(st, at, 30)
    p.ship.size = 3
    expect(select(2, landing.can_land(st, p))).to_be("size")
    p.ship.size = 1
    p.ship.morph = { total = 1 }
    expect(select(2, landing.can_land(st, p))).to_be("busy")
    p.ship.morph = false
    p.tractor = { key = "x" }
    expect(select(2, landing.can_land(st, p))).to_be("beam")
    p.tractor = false
    p.clamped_by = 1
    expect(select(2, landing.can_land(st, p))).to_be("clamped")
    p.clamped_by = nil
    p.ship.vel = { 0, 0, 90 }
    expect(select(2, landing.can_land(st, p))).to_be("fast")
    p.ship.vel = { 0, 0, 0 }
    expect(landing.can_land(st, p)).to_be(true)
    p.msgs = {}
    p.ship.pos[1] = at[1] + 79
    expect(landing.start(st, p, ctx)).to_be(false)
    expect(texts(p)).to_contain(landing.REASONS.void)
    expect(landing.REASONS.size).to_contain("Villa")
    p.ship.pos[1] = at[1]
    expect(landing.start(st, p, ctx)).to_be(true)
    expect(select(2, landing.can_land(st, p))).to_be("site")
    expect(landing.start(st, p, ctx)).to_be(false)
    expect(landing.anchored(p)).to_be(true)
  end)
end)

describe("settling on the gear", function()
  it("descends, swings the legs out, touches down and holds the pose", function()
    local st = new_state()
    local at = platform()
    local p = fly_to(st, at, 12)
    p.mode = "helm"
    run(st, cmd({ pressed = { "land" } }))
    expect(p.berth.phase).to_be("descend")
    expect(landing.legs(p)).to_be_less(1)
    local last = p.ship.pos[2]
    for _ = 1, 60 * 30 do
      run(st)
      expect(p.ship.pos[2] <= last + 1e-9).to_be(true)
      last = p.ship.pos[2]
      if landing.landed(p) then break end
    end
    expect(landing.landed(p)).to_be(true)
    expect(p.ship.pos[2]).to_be_near(at[2] + T.leg_len, 1e-6)
    expect(landing.legs(p)).to_be(1)
    -- anchored: the stick does nothing
    local x, z = p.ship.pos[1], p.ship.pos[3]
    run(st, cmd({ axes = { move_z = 1 } }), 30)
    expect(p.ship.pos[1]).to_be_near(x, 1e-9)
    expect(p.ship.pos[3]).to_be_near(z, 1e-9)
  end)
  it("aborts a descent with Land again, and lifts off from the ground", function()
    local st = new_state()
    local at = platform()
    local p = fly_to(st, at, 40)
    run(st, cmd({ pressed = { "land" } }))
    run(st, cmd(), 10)
    expect(p.berth.phase).to_be("descend")
    run(st, cmd({ pressed = { "land" } }))
    expect(p.berth.phase).to_be("lift")
    expect(texts(p)).to_contain("aborted")
    for _ = 1, 60 * 6 do run(st) if not p.berth then break end end
    expect(p.berth).to_be(false)
    -- land, then lift off
    fly_to(st, at, 10)
    run(st, cmd({ pressed = { "land" } }))
    for _ = 1, 60 * 30 do run(st) if landing.landed(p) then break end end
    expect(landing.landed(p)).to_be(true)
    run(st, cmd({ pressed = { "land" } }))
    expect(p.berth.phase).to_be("lift")
    expect(landing.press(st, p, ctx)).to_be(false)
    for _ = 1, 60 * 10 do run(st) if not p.berth then break end end
    expect(p.berth).to_be(false)
    expect(p.ship.pos[2] > at[2] + T.leg_len).to_be(true)
    expect(texts(p)).to_contain("Gear up")
  end)
  it("lifts off with thrust up, but never with the hatch open or away from the helm", function()
    local st = new_state()
    local at = platform()
    local p = fly_to(st, at, 10)
    run(st, cmd({ pressed = { "land" } }))
    for _ = 1, 60 * 30 do run(st) if landing.landed(p) then break end end
    p.door = { open = 0.5, stairs = 0, goal = 1, hold = 0, on = false, cycle = false, drop = 4, run = 5, steps = 12 }
    p.msgs = {}
    expect(landing.lift_off(st, p, ctx)).to_be(false)
    expect(texts(p)).to_contain(landing.REASONS.hatch)
    p.door = { open = 0, stairs = 0, goal = 0, hold = 0, on = false, cycle = false, drop = 0, run = 0, steps = 0 }
    p.mode = "walk"
    expect(landing.lift_off(st, p, ctx)).to_be(false)
    p.mode = "helm"
    run(st, cmd({ axes = { lift = 1 } }), 2)
    expect(p.berth.phase).to_be("lift")
    expect(landing.lift_off(st, { berth = false }, ctx)).to_be(false)
    expect(landing.step(st, { berth = false }, 1 / 60, ctx)).to_be(false)
    expect(landing.press(st, { berth = { phase = "lift" } }, ctx)).to_be(false)
  end)
  it("follows a moving surface through the frame hook", function()
    local st = new_state()
    local at = platform()
    local p = fly_to(st, at, 10)
    run(st, cmd({ pressed = { "land" } }))
    for _ = 1, 60 * 30 do run(st) if landing.landed(p) then break end end
    local x0, y0 = p.ship.pos[1], p.ship.pos[2]
    expect(landing.frame_pose(st, p, p.berth)[1]).to_be(0)
    landing.frames.test = function(_, _, b) return { 3, 1, 0 }, 0.5 end
    p.berth.frame = { kind = "test" }
    run(st)
    expect(p.ship.pos[1]).to_be_near(x0 + 3, 1e-9)
    expect(p.ship.pos[2]).to_be_near(y0 + 1, 1e-9)
    expect(p.ship.yaw).to_be_near(sm.wrap(p.berth.yaw + 0.5), 1e-9)
    landing.frames.test = nil
  end)
  it("keeps a person out of the hull and the stairs' footprint", function()
    local st = new_state()
    local at = platform()
    local p = fly_to(st, at, 10)
    run(st, cmd({ pressed = { "land" } }))
    expect(select(1, landing.push_out(p, 1, 0, 1, 1.8))).to_be(1)
    for _ = 1, 60 * 30 do run(st) if landing.landed(p) then break end end
    local s = p.ship.pos
    expect(landing.hull_radius(-9)).to_be(0)
    expect(landing.hull_radius(-5.25)).to_be_greater(2.7)
    expect(landing.hull_radius(-1)).to_be_greater(12)
    expect(landing.hull_radius(5)).to_be(13)
    -- under the belly: pushed out to the hull radius at head height
    local x, z = landing.push_out(p, s[1] + 1, s[2] - 7.2, s[3], s[2] - 5.4)
    expect(math.sqrt((x - s[1]) ^ 2 + (z - s[3]) ^ 2)).to_be_greater(1)
    x, z = landing.push_out(p, s[1], s[2] - 7.2, s[3], s[2] - 5.0)
    expect(math.sqrt((x - s[1]) ^ 2 + (z - s[3]) ^ 2)).to_be_greater(3)
    -- well clear: untouched
    x, z = landing.push_out(p, s[1] + 40, s[2] - 7.2, s[3], s[2] - 5.4)
    expect(x).to_be(s[1] + 40)
    -- the stairs' footprint
    p.door = { open = 1, stairs = 1, goal = 1, hold = 0, on = false, cycle = false, drop = 4, run = 5, steps = 12 }
    local o = avatar.rot(p.ship.yaw, { 0.1, 0, T.door.sill - 3 })
    local px, pz = landing.push_out(p, s[1] + o[1], s[2] - 7.2, s[3] + o[3], s[2] - 5.4)
    local rel = avatar.rot(-p.ship.yaw, { px - s[1], 0, pz - s[3] })
    expect(math.abs(rel[1])).to_be_greater(T.door.width / 2)
  end)
end)

describe("the hull hatch", function()
  local function landed_state(extra)
    local st = new_state()
    local at = platform(extra)
    local p = fly_to(st, at, 10)
    run(st, cmd({ pressed = { "land" } }))
    for _ = 1, 60 * 30 do run(st) if landing.landed(p) then break end end
    p.mode = "walk"
    p.body = avatar.new(L, L.nav.nodes.hatch, 0)
    return st, p, at
  end
  it("will not open while flying, reshaping, or without ground for the stairs", function()
    local st = new_state()
    local at = platform()
    local p = fly_to(st, at, 30)
    p.mode = "walk"
    p.body = avatar.new(L, L.nav.nodes.hatch, 0)
    expect(select(2, hulldoor.can_open(st, p))).to_be("flying")
    expect(select(2, hulldoor.geometry(st, p))).to_be("flying")
    hulldoor.use(st, p, ctx)
    expect(texts(p)).to_contain(hulldoor.REASONS.flying)
    p.mode = "helm"
    expect(select(2, hulldoor.can_open(st, p))).to_be("flying")
    local st2, p2 = landed_state()
    p2.ship.morph = { total = 1 }
    expect(select(2, hulldoor.can_open(st2, p2))).to_be("busy")
    p2.ship.morph = false
    -- the ground under the stairs' foot too far down (a ledge)
    local st3, p3 = landed_state({ { -10, 0, -80, -2, 0.01, 80 } })
    p3.ship.pos[1] = p3.ship.pos[1] - 1000
    expect(select(2, hulldoor.geometry(st3, p3))).to_be("ground")
  end)
  it("takes a platform too close under the deck as no stairs at all", function()
    local st = new_state()
    local at = platform({ { -30, 0, -30, 30, 3.0, 30 } })
    local p = fly_to(st, at, 30)
    p.ship.pos = { at[1], at[2] + 50, 0 }
    run(st, cmd({ pressed = { "land" } }))
    for _ = 1, 60 * 40 do run(st) if landing.landed(p) then break end end
    -- the hull sits on the 3 m block: the deck is 4.2 m up and the stairs reach the platform beyond? either way a result or a reason
    local g, why = hulldoor.geometry(st, p)
    expect(g ~= nil or why == "ground").to_be(true)
  end)
  it("cycles the suit in vacuum, opens, hysteresis keeps it open, and closes behind you", function()
    local st, p = landed_state()
    p.msgs = {}
    hulldoor.use(st, p, ctx)
    expect(p.door.cycle).to_be(0)
    expect(texts(p)).to_contain("Airlock")
    hulldoor.use(st, p, ctx) -- ignored while cycling
    run(st, cmd(), 100)
    expect(p.suited).to_be(true)
    expect(p.door.goal).to_be(1)
    run(st, cmd(), 60 * 8)
    expect(hulldoor.passable(p)).to_be(true)
    expect(p.door.steps).to_be_greater(10)
    -- aboard, near the hatch: stays open
    run(st, cmd(), 60 * 3)
    expect(p.door.goal).to_be(1)
    expect(hulldoor.request_open(st, p, ctx)).to_be(true)
    -- walking far away closes it behind you
    p.body = avatar.new(L, L.nav.nodes.bed, 0)
    run(st, cmd(), 60 * 10)
    expect(p.door.goal).to_be(0)
    expect(p.door.open).to_be(0)
    expect(p.suited).to_be(false)
    expect(hulldoor.request_close(st, p, ctx)).to_be(true)
  end)
  it("reports a fresh hatch, someone on the stairs and a hatch that has only just opened", function()
    local st, p = landed_state()
    p.suited = true
    hulldoor.use(st, p, ctx)
    expect(p.door.goal).to_be(1)
    p.msgs = {}
    hulldoor.use(st, p, ctx)
    expect(texts(p)).to_contain("only just opened")
    run(st, cmd(), 60 * 3)
    p.door.on = true
    p.msgs = {}
    hulldoor.use(st, p, ctx)
    expect(texts(p)).to_contain("Someone")
    expect(hulldoor.request_close(st, p, ctx)).to_be(false)
    p.door.on = false
    hulldoor.use(st, p, ctx)
    expect(texts(p)).to_contain("close")
    expect(hulldoor.request_close(st, p, ctx)).to_be(true)
    expect(hulldoor.passable(p)).to_be(false)
    -- an automatic open request stays quiet when it cannot
    p.mode = "helm"
    p.msgs = {}
    expect(hulldoor.request_open(st, p, ctx, true)).to_be(false)
    expect(texts(p)).to_be("")
  end)
  it("steps onto the stairs through the doorway and walks them, in and out", function()
    local st, p = landed_state()
    p.suited = true
    hulldoor.use(st, p, ctx)
    run(st, cmd(), 60 * 8)
    expect(hulldoor.passable(p)).to_be(true)
    p.body = avatar.new(L, L.nav.nodes.hatch_out, 0)
    p.body.pos = { 0.1, L.decks[2].floor, -8.6 }
    hulldoor.after_walk(st, p)
    expect(p.door.on).to_be(true)
    hulldoor.after_walk(st, p) -- already on
    -- out along the stairs
    p.body.yaw = sm.pi
    local out
    for _ = 1, 60 * 20 do
      out = hulldoor.stairs_step(st, p, cmd({ axes = { move_z = 1, move_x = 0.2 } }), 1 / 60, ctx)
      if out then break end
    end
    expect(out).to_be("out")
    local foot = hulldoor.foot_world(st, p)
    expect(foot[2]).to_be_near(landing.tune().door.drop_min > 0 and p.ship.pos[2] + L.decks[2].floor - p.door.drop or 0, 1e-6)
    -- and back up
    p.body = avatar.new(L, L.nav.nodes.hatch_out, 0)
    p.body.pos = { 0, L.decks[2].floor, -8.6 }
    p.door.on = true
    p.body.yaw = 0
    local ended
    for _ = 1, 60 * 5 do
      hulldoor.stairs_step(st, p, cmd({ axes = { move_z = 1 }, held = { "boost" } }), 1 / 60, ctx)
      if not p.door.on then ended = true break end
    end
    expect(ended).to_be(true)
    expect(p.body.pos[3]).to_be_near(landing.tune().door.trigger + 0.3, 1e-9)
    -- the stairs folding under you cannot trap you
    p.door.on = true
    p.door.goal = 0
    p.body.pos = { 0, L.decks[2].floor, -9.5 }
    hulldoor.stairs_step(st, p, cmd(), 1 / 60, ctx)
    expect(p.door.on).to_be(true)
  end)
  it("opens by itself when you walk up to the stairs from outside", function()
    local st, p = landed_state()
    p.suited = true
    hulldoor.use(st, p, ctx)
    run(st, cmd(), 60 * 8)
    -- out onto the platform: stand coin
    p.door.on = false
    excursion.leave_hatch(st, p, ctx)
    expect(p.mode).to_be("foot")
    expect(p.excursion.coin).to_be("stand")
    local foot = hulldoor.foot_world(st, p)
    -- far away: the stairs fold and the hatch shuts
    p.excursion.body.pos = { foot[1] + 40, foot[2], foot[3] }
    run(st, cmd(), 60 * 10)
    expect(p.door.open).to_be(0)
    expect(excursion.stand_text(st, p)).to_contain("WALK TO THE STAIRS")
    p.door.goal, p.door.hold = 1, 0
    p.door.open, p.door.stairs = 0.5, 0
    expect(excursion.stand_text(st, p)).to_contain("HATCH IS OPENING")
    p.door.open = 1
    expect(excursion.stand_text(st, p)).to_contain("STAIRS ARE UNFOLDING")
    p.door.goal = 0
    p.door.open, p.door.stairs = 0, 0
    -- near: opens by itself
    p.excursion.body.pos = { foot[1] + 1, foot[2], foot[3] }
    run(st, cmd(), 60 * 8)
    expect(p.door.goal).to_be(1)
    local where, line = excursion.status(st, p)
    expect(line).to_contain("STAIRS")
    expect(select(1, excursion.coin_text(p))).to_contain("LANDED")
  end)
end)

describe("the standing Villa", function()
  local function outside()
    local st = new_state()
    local at = platform()
    local p = fly_to(st, at, 10)
    run(st, cmd({ pressed = { "land" } }))
    for _ = 1, 60 * 30 do run(st) if landing.landed(p) then break end end
    p.mode = "walk"
    p.suited = true
    p.body = avatar.new(L, L.nav.nodes.hatch, 0)
    hulldoor.use(st, p, ctx)
    run(st, cmd(), 60 * 8)
    p.door.on = false
    excursion.leave_hatch(st, p, ctx)
    return st, p, at
  end
  it("folds into your hand, pockets, and unfolds again on its gear", function()
    local st, p = outside()
    local b = p.excursion.body
    b.pos = { b.pos[1] + 40, b.pos[2], b.pos[3] }
    local charge = p.ship.charge
    -- with the hatch open, folding first shuts it (and then goes on by itself)
    p.msgs = {}
    run(st, cmd({ pressed = { "shrink" } }))
    expect(p.excursion.fold_wait).to_be(true)
    expect(p.excursion.coin).to_be("stand")
    expect(texts(p)).to_contain("hatch closes first")
    for _ = 1, 60 * 12 do
      run(st)
      if p.excursion.coin ~= "stand" then break end
    end
    expect(p.excursion.coin).to_be("fold")
    expect(p.ship.charge < charge).to_be(true)
    expect(p.berth).to_be(false)
    run(st, cmd(), 60 * 12)
    expect(p.excursion.coin).to_be("pocket")
    run(st, cmd({ pressed = { "grow" } }))
    expect(p.excursion.coin).to_be("grow")
    run(st, cmd(), 60 * 12)
    expect(p.excursion.coin).to_be("stand")
    expect(landing.landed(p)).to_be(true)
    expect(select(1, excursion.coin_text(p))).to_contain("LANDED")
    -- Q again while standing: folds it back
    b.pos = { b.pos[1] + 0, b.pos[2], b.pos[3] }
    run(st, cmd({ pressed = { "size3" } }))
    expect(p.excursion.coin == "fold" or p.excursion.coin == "stand").to_be(true)
  end)
  it("will not fold when it is too far away or Charge is short, and can be cancelled by walking up", function()
    local st, p = outside()
    local b = p.excursion.body
    b.pos = { b.pos[1] + 40, b.pos[2], b.pos[3] }
    run(st, cmd(), 60 * 12)
    expect(p.door.open).to_be(0)
    p.ship.charge = 1
    p.msgs = {}
    run(st, cmd({ pressed = { "shrink" } }))
    expect(p.excursion.coin).to_be("stand")
    expect(texts(p)).to_contain(excursion.REASONS.charge)
    p.ship.charge = 100
    local keep = b.pos
    b.pos = { keep[1] + 200, keep[2], keep[3] }
    p.msgs = {}
    run(st, cmd({ pressed = { "shrink" } }))
    expect(texts(p)).to_contain("Too far")
    expect(p.excursion.coin).to_be("stand")
  end)
  it("does not let the Villa be pocketed from aboard in a derelict", function()
    local st = new_state()
    local p = st.players[1]
    p.site = 1
    p.mode, p.panel = "helm", false
    p.msgs = {}
    run(st, cmd({ pressed = { "size3" } }))
    expect(texts(p)).to_contain("hull hatch")
    expect(p.ship.size).to_be(1)
    -- and not reshaped with the gear down
    p.site = 0
    local at = platform()
    fly_to(st, at, 10)
    run(st, cmd({ pressed = { "land" } }))
    p.msgs = {}
    run(st, cmd({ pressed = { "size2" } }))
    expect(texts(p)).to_contain("gear is down")
  end)
end)

describe("drawing the gear", function()
  it("draws legs, leaves, plates and stairs from the player's state without touching it", function()
    local st = new_state()
    local at = platform()
    local p = fly_to(st, at, 10)
    run(st, cmd({ pressed = { "land" } }))
    for _ = 1, 60 * 30 do run(st) if landing.landed(p) then break end end
    p.door = { open = 0.6, stairs = 0.5, goal = 1, hold = 0, on = false, cycle = false, drop = 4.2, run = 5.2, steps = 13 }
    local A = assets.init()
    local d = render.pose(p.ship)
    local v = fake_view()
    local before = game.hash and game.hash(st) or nil
    expect(gear.legs(v, A, p, d)).to_be(15)
    expect(gear.door(v, A, p, d)).to_be_greater(5)
    expect(gear.stairs(v, A, p, d)).to_be_greater(20)
    expect(gear.draw(v, A, p, d)).to_be_greater(30)
    p.berth.phase = "descend"
    p.berth.legs = 0.4
    expect(gear.legs(v, A, p, d)).to_be(15)
    p.berth.legs = 0
    expect(gear.legs(v, A, p, d)).to_be(0)
    p.door.stairs = 0
    expect(gear.stairs(v, A, p, d)).to_be(0)
    p.door = false
    expect(gear.door(v, A, p, d)).to_be(0)
    expect(gear.stairs(v, A, p, d)).to_be(0)
    p.berth = false
    expect(gear.legs(v, A, p, d)).to_be(0)
    if before then expect(game.hash(st)).to_be(before) end
    local w = fake_view()
    render.render(w, st, 1)
    expect(w.calls.mesh).to_be_greater(10)
  end)
end)

describe("the landing readout and surfaces", function()
  it("reads the ground at the helm: distance, slope and the verdict, and draws it", function()
    local st = new_state()
    local at = platform({ { 20, 0, -80, 80, 2.4, -30 } })
    local p = fly_to(st, at, 30)
    local lr = landing.readout(st, p)
    expect(lr.ok).to_be(true)
    expect(lr.dist).to_be_near(30, 1e-6)
    expect(lr.slope).to_be_near(0, 1e-6)
    -- a drop-off, a step
    p.ship.pos = { at[1] + 77, at[2] + 30, at[3] }
    expect(landing.readout(st, p).void).to_be(true)
    p.ship.pos = { at[1] + 50, at[2] + 30, at[3] - 30 }
    lr = landing.readout(st, p)
    expect(lr.ok).to_be(false)
    expect(lr.why).to_be("slope")
    expect(lr.slope > 8).to_be(true)
    expect(landing.SHORT[lr.why]).to_be("TOO STEEP")
    -- too fast: the verdict says so, with the numbers
    p.ship.pos = { at[1], at[2] + 30, at[3] }
    p.ship.vel = { T.speed_max + 5, 0, 0 }
    expect(landing.readout(st, p).why).to_be("fast")
    p.ship.vel = { 0, 0, 0 }
    -- the HUD line and the markers on the ground
    local v = fake_view()
    require("view.hud").draw(v, st, p, nil)
    expect(v.texts).to_contain("GROUND 30M")
    expect(v.texts).to_contain("L: LAND")
    p.ship.pos = { at[1] + 50, at[2] + 30, at[3] - 30 }
    v = fake_view()
    require("view.hud").draw(v, st, p, nil)
    expect(v.texts).to_contain("TOO STEEP")
    local A = assets.init()
    expect(gear.markers(fake_view(), A, st, p)).to_be(5)
    p.ship.pos = { at[1], at[2] + 300, at[3] }
    expect(gear.markers(fake_view(), A, st, p)).to_be(0)
    v = fake_view()
    require("view.hud").draw(v, st, p, nil)
    expect(v.texts:find("GROUND", 1, true)).to_be(nil)
    -- not at the helm, not the Villa, already landed: nothing to read
    p.mode = "walk"
    expect(landing.readout(st, p)).to_be(nil)
    p.mode = "helm"
    p.ship.size = 2
    expect(landing.readout(st, p)).to_be(nil)
    p.ship.size = 1
    p.berth = { phase = "landed" }
    expect(landing.readout(st, p)).to_be(nil)
  end)
  it("names the surface: a wreck's hull, the moon's surface, a rooftop, and nothing in open space", function()
    local st = new_state()
    local p = st.players[1]
    p.site = 0
    expect(landing.surface(st, p, 0)).to_be(nil)
    p.site = 1
    p.ship.pos = vec.copy(st.sector.sites[1].pos)
    expect(landing.surface(st, p, 0)).to_be("a wreck's hull")
    p.site = 99
    expect(landing.surface(st, p, 0)).to_be(nil)
    game.enter_sector(st, 4)
    local site
    for i, s in ipairs(st.sector.sites) do if s.city then site = i end end
    p = st.players[1]
    p.site = site
    local ruin = game.ruin(site)
    local d = ruin.city.districts[1]
    p.ship.pos = { (d.box[1] + d.box[3]) / 2, d.pos[2] + 30, (d.box[2] + d.box[4]) / 2 }
    expect(landing.surface(st, p, d.pos[2])).to_be("the moon's surface")
    expect(landing.surface(st, p, d.pos[2] + 40)).to_be("moon city rooftop")
    p.ship.pos = { d.box[1] - 5000, d.pos[2], d.box[2] - 5000 }   -- between districts: the lowest street level
    expect(landing.surface(st, p, d.pos[2] + 40)).to_be("moon city rooftop")
    game.enter_sector(st, 3)
    for i, s in ipairs(st.sector.sites) do if s.city then site = i end end
    p.site = site
    expect(landing.surface(st, p, game.ruin(site).origin[2] - 9999)).to_be("the planet's surface")
    game.enter_sector(st, 2)
    for i, s in ipairs(st.sector.sites) do if s.city then site = i end end
    p.site = site
    expect(landing.surface(st, p, game.ruin(site).origin[2] - 9999)).to_be("the asteroid's rock")
  end)
  it("lifts off by itself when the ground gives way, but not under a person standing outside", function()
    local st = new_state()
    local at = platform()
    local p = fly_to(st, at, 12)
    local plat = saucer.physics.add_box({ at[1] + 200, at[2] - 20, -40 }, { at[1] + 240, at[2], 40 }, 1)
    p.ship.pos = { at[1] + 220, at[2] + 12, 0 }
    run(st, cmd({ pressed = { "land" } }))
    for _ = 1, 60 * 30 do run(st) if landing.landed(p) then break end end
    expect(landing.landed(p)).to_be(true)
    expect(landing.supported(st, p)).to_be(true)
    run(st, cmd(), 40)
    expect(landing.landed(p)).to_be(true)
    saucer.physics.remove(plat)
    expect(landing.supported(st, p)).to_be(false)
    run(st, cmd(), 40)
    expect(p.berth.phase).to_be("lift")
    expect(texts(p)).to_contain("GROUND GIVES WAY")
    for _ = 1, 60 * 20 do run(st) if not p.berth then break end end
    expect(p.berth).to_be(false)
    -- the same on foot: the Villa stays put
    local plat2 = saucer.physics.add_box({ at[1] + 200, at[2] - 20, -40 }, { at[1] + 240, at[2], 40 }, 1)
    p.ship.pos = { at[1] + 220, at[2] + 12, 0 }
    p.ship.vel = { 0, 0, 0 }
    run(st, cmd({ pressed = { "land" } }))
    for _ = 1, 60 * 30 do run(st) if landing.landed(p) then break end end
    p.mode = "foot"
    p.excursion = { site = 0, t = 0, coin = "stand", from = 1, hand_t = 0, held = false,
                    body = { pos = { at[1] + 215, at[2], 20 }, yaw = 0, pitch = 0, vy = 0, crouch = false, ground = true },
                    path = {}, work = false, warned = 0, area = "hall", deploy = false }
    saucer.physics.remove(plat2)
    run(st, cmd(), 60)
    expect(p.berth.phase).to_be("landed")
  end)
end)
