-- SPDX-License-Identifier: MIT
-- add-dock-land-eva slice 4: the EVA kit's numbers, edge cases and drawing (the end-to-end walk is
-- tests/game/eva.lua).
local game = require("sim.game")
local eva = require("sim.eva")
local env = require("sim.env")
local excursion = require("sim.excursion")
local hud = require("view.hud")
local xr = require("view.xr")
local render = require("view.render")
local vec = require("lib.vec")

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
local function fake_view(o)
  local v = { calls = {}, texts = {}, width = 480, height = 270, player = 1, index = 1, xr = o and o.xr or false }
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "image" }) do
    v[m] = function(self) self.calls[m] = (self.calls[m] or 0) + 1 return 0 end
  end
  v.text = function(self, _, _, s) self.calls.text = (self.calls.text or 0) + 1 self.texts[#self.texts + 1] = s return 0 end
  return v
end
-- a person 50 m from a Villa that is folded in the pocket, in open space
local function outside()
  local st = new_state()
  local p = st.players[1]
  local pos = { 50, -500, 0 }
  p.mode, p.site, p.panel, p.suited = "foot", 0, false, true
  p.ship.size = excursion.pocket_size()
  p.excursion = { site = 0, t = 0, coin = "pocket", from = 1, hand_t = 0, held = false, work = false, warned = 0,
                  area = "hall", deploy = false, path = { vec.copy(pos) }, home = { pos = { 0, -500, 0 }, yaw = 0 },
                  body = { pos = pos, yaw = 0, pitch = 0, vy = 0, crouch = false, ground = true } }
  p.hands = {}
  eva.ensure(p)
  return st, p
end

describe("the EVA kit", function()
  it("is only for a Villa expedition", function()
    local st, p = outside()
    expect(eva.active(p)).to_be(true)
    p.excursion.home = nil
    expect(eva.active(p)).to_be(false)
    p.mode = "helm"
    expect(eva.active(p)).to_be(false)
    expect(eva.move(st, p, cmd(), 1 / 60, game.ctx)).to_be(false)
    expect(eva.step(st, p, cmd(), 1 / 60, game.ctx)).to_be(nil)
  end)
  it("drains oxygen in vacuum, not in air, and works the helmet", function()
    local st, p = outside()
    run(st, cmd(), 2)
    expect(p.eva.o2 < 100).to_be(true)
    local s = eva.status(st, p)
    expect(s.helmet and not s.breathable and s.dist > 49 and s.loot == 0).to_be(true)
    local at = env.at
    env.at = function(state, pl) local e = at(state, pl) e.breathable, e.vacuum, e.g = true, false, 1 return e end
    local o2 = p.eva.o2
    run(st, cmd(), 60)
    env.at = at
    expect(p.eva.o2).to_be(o2)
    expect(texts(p)).to_contain("Helmet off")
    run(st, cmd(), 2)
    expect(p.suited).to_be(true)
  end)
  it("damages the suit with radiation and cold, and warns", function()
    local st, p = outside()
    p.eva.integrity = 30.2
    p.eva.o2 = 100
    local of_site = env.of_site
    env.of_site = function(site) local e = of_site(site) e.rad, e.temp = 5, -300 return e end
    run(st, cmd(), 60)
    env.of_site = of_site
    expect(p.eva.integrity < 30.2).to_be(true)
    expect(texts(p)).to_contain("SUIT INTEGRITY LOW")
    p.eva.integrity = 14
    run(st, cmd(), 2)
    expect(texts(p)).to_contain("SUIT INTEGRITY CRITICAL")
  end)
  it("teleports home when the suit fails, and loses half of what you carry", function()
    local st, p = outside()
    p.eva.integrity = 0.0001
    p.hands = { { name = "A" }, { name = "B" }, { name = "C" }, { name = "D", unique = true } }
    local n0 = #(st.caches or {})
    run(st, cmd(), 3)
    expect(texts(p)).to_contain("SUIT FAILURE")
    expect(#st.caches).to_be(n0 + 1)
    expect(#p.hands).to_be(2)
    expect(p.excursion.coin).to_be("stand")
    expect(p.eva.cool > 200).to_be(true)
    expect(vec.dist(p.excursion.body.pos, p.ship.pos) < 30).to_be(true)
  end)
  it("loses carried loot for good in Hardcore", function()
    local st, p = outside()
    st.hardcore = true
    p.hands = { { name = "A" }, { name = "B" } }
    p.eva.o2 = 0.0001
    local n0 = #(st.caches or {})
    run(st, cmd(), 3)
    local hc = require("sim.hardcore")
    if hc.on(st) then
      expect(#(st.caches or {})).to_be(n0)
      expect(p.lost_for_good).to_be(1)
    end
    expect(#p.hands).to_be(1)
  end)
  it("charges, cancels, refuses on cooldown and during a fold", function()
    local st, p = outside()
    run(st, cmd({ pressed = { "home" } }))
    expect(p.eva.tele).to_be_greater(-1)
    expect(texts(p)).to_contain("charging")
    run(st, cmd({ pressed = { "home" } }))
    expect(p.eva.tele).to_be(false)
    expect(texts(p)).to_contain("cancelled")
    p.eva.cool = 100
    p.msgs = {}
    run(st, cmd({ pressed = { "home" } }))
    expect(texts(p)).to_contain("recharging")
    p.eva.cool = 0
    p.excursion.coin = "fold"
    p.ship.morph = { from = 1, pos = vec.copy(p.ship.pos), yaw = 0, total = 5, eye = vec.copy(p.ship.pos) }
    p.ship.t_left = 5
    p.msgs = {}
    run(st, cmd({ pressed = { "home" } }))
    expect(texts(p)).to_contain("finish folding")
    expect(p.eva.tele).to_be(false)
  end)
  it("lets the assist fly you home, hand back control, run out of fuel and give up when stuck", function()
    local st, p = outside()
    p.eva.fuel = 0
    run(st, cmd({ pressed = { "assist" } }))
    expect(p.eva.assist).to_be(false)
    expect(texts(p)).to_contain("no fuel")
    p.eva.fuel = 100
    run(st, cmd({ pressed = { "assist" } }))
    expect(p.eva.assist).to_be(true)
    run(st, cmd(), 30)
    expect(p.excursion.body.pos[1] < 50).to_be(true)
    -- the stick takes over
    run(st, cmd({ axes = { move_x = 1 } }))
    expect(p.eva.assist).to_be(false)
    expect(texts(p)).to_contain("you have the controls")
    -- toggle off
    run(st, cmd({ pressed = { "assist" } }))
    run(st, cmd({ pressed = { "assist" } }))
    expect(p.eva.assist).to_be(false)
    -- empty tank
    run(st, cmd({ pressed = { "assist" } }))
    p.eva.fuel = 0
    run(st, cmd())
    expect(p.eva.assist).to_be(false)
    expect(texts(p)).to_contain("out of fuel")
    -- blocked
    p.eva.fuel = 100
    run(st, cmd({ pressed = { "assist" } }))
    local wall = { { p.excursion.body.pos[1] - 8, p.excursion.body.pos[2] - 20, p.excursion.body.pos[3] - 60 },
                   { p.excursion.body.pos[1] - 4, p.excursion.body.pos[2] + 20, p.excursion.body.pos[3] + 60 } }
    game.extra_solids[#game.extra_solids + 1] = wall
    saucer.physics.add_box(wall[1], wall[2], 1)
    run(st, cmd(), 200)
    expect(p.eva.assist).to_be(false)
    game.extra_solids[#game.extra_solids] = nil
    game.rebuild(st)
  end)
  it("flies in six directions in zero-g, brakes, pushes off the deck and lands", function()
    local st, p = outside()
    run(st, cmd({ axes = { lift = 1 } }), 40)
    expect(p.excursion.body.ground).to_be(false)
    expect(p.eva.jet).to_be(true)
    expect(p.eva.vel[2] > 0).to_be(true)
    run(st, cmd({ axes = { move_z = 1, move_x = 1, lift = -0.2 } }), 40)
    expect(vec.len(p.eva.vel) <= eva.tune().jet_speed + 1e-6).to_be(true)
    run(st, cmd(), 300)
    expect(vec.len(p.eva.vel)).to_be(0)
    -- empty: no thrust, you drift and brake
    p.eva.fuel = 0
    p.eva.vel = { 1, 0, 0 }
    run(st, cmd({ axes = { move_z = 1 } }), 3)
    expect(p.eva.vel[1] < 1).to_be(true)
    -- down to a deck
    local deck = { { 0, -560, -100 }, { 100, -540, 100 } }
    game.extra_solids[#game.extra_solids + 1] = deck
    saucer.physics.add_box(deck[1], deck[2], 1)
    p.excursion.body.pos = { 50, -538, 0 }
    p.eva.fuel, p.eva.vel = 100, { 0, -3, 0 }
    run(st, cmd({ axes = { lift = -0.4 } }), 240)
    run(st, cmd(), 30)
    expect(p.excursion.body.ground).to_be(true)
    expect(p.eva.jet).to_be(false)
    game.extra_solids[#game.extra_solids] = nil
    game.rebuild(st)
  end)
  it("boosts, hovers and descends in a pull and takes fall damage", function()
    local st, p = outside()
    local of_site = env.of_site
    env.of_site = function(site) local e = of_site(site) e.g = 1.2 return e end
    local y0 = p.excursion.body.pos[2]
    -- hop and keep thrusting
    run(st, cmd({ axes = { lift = 1 } }), 30)
    expect(p.excursion.body.pos[2] > y0 + 1).to_be(true)
    expect(p.eva.jet).to_be(true)
    local f0 = p.eva.fuel
    run(st, cmd(), 20)
    expect(p.eva.fuel < f0 or p.eva.fuel >= 100).to_be(true)
    run(st, cmd({ axes = { lift = -1 } }), 10)
    -- out of fuel: the pack cuts out and you fall
    p.eva.fuel = 0
    p.excursion.body.vy = 0
    run(st, cmd(), 5)
    expect(p.eva.jet).to_be(false)
    -- a big drop onto the deck
    local deck = { { 0, -560, -100 }, { 100, -540, 100 } }
    game.extra_solids[#game.extra_solids + 1] = deck
    saucer.physics.add_box(deck[1], deck[2], 1)
    local b = p.excursion.body
    b.pos, b.ground, b.vy, p.eva.integrity = { 50, -480, 0 }, false, -40, 100
    run(st, cmd(), 300)
    env.of_site = of_site
    expect(b.ground).to_be(true)
    expect(p.eva.integrity < 100 or texts(p):find("HARD LANDING", 1, true)).to_be_truthy()
    game.extra_solids[#game.extra_solids] = nil
    game.rebuild(st)
  end)
  it("refills at a standing Villa and warns on low oxygen, calling the assist at critical", function()
    local st, p = outside()
    p.eva.o2 = 29
    run(st, cmd(), 2)
    expect(texts(p)).to_contain("OXYGEN LOW")
    p.eva.o2 = 14
    run(st, cmd(), 2)
    expect(texts(p)).to_contain("OXYGEN CRITICAL")
    expect(p.eva.assist).to_be(true)
    -- the Villa stands: refill beside it
    p.eva.assist = false
    p.excursion.coin = "stand"
    p.berth = { phase = "landed", kind = "surface", clamp = 0, legs = 1, t = 0, ref = -500, feet = {}, at = { 40, -490, 0 }, yaw = 0, site = 0 }
    p.ship.pos = { 40, -490, 0 }
    p.ship.size = 1
    require("sim.hulldoor").ensure(p)
    run(st, cmd(), 20)
    expect(p.eva.refill).to_be(true)
    expect(texts(p)).to_contain("Refilling")
    expect(p.eva.o2 > 14).to_be(true)
    local s = eva.status(st, p)
    expect(s.refill).to_be(true)
    local _, standing = eva.target(st, p)
    expect(standing).to_be(true)
  end)
  it("has a Suit Charge that never drains under the kit, and gamepad bindings", function()
    local st, p = outside()
    run(st, cmd(), 60)
    expect(p.suit).to_be(excursion.tune().suit.max)
    local bind = require("lib.data").load("input/default.lua")
    local has = function(list, s) for _, b in ipairs(list) do if b == s then return true end end return false end
    expect(has(bind.buttons.home, "pad:back")).to_be(true)
    expect(has(bind.buttons.home, "key:Backspace")).to_be(true)
    expect(has(bind.buttons.assist, "pad:rightstick")).to_be(true)
  end)
  it("draws the helmet, the HUD and the wrist", function()
    local st, p = outside()
    run(st, cmd(), 2)
    local v = fake_view()
    expect(hud.helmet(v, st, p) > 0).to_be(true)
    p.eva.o2 = 10
    expect(hud.helmet(v, st, p) > 0).to_be(true)
    p.eva.tele = 0.5
    p.eva.integrity = 20
    render.render(v, st, 1)
    local joined = table.concat(v.texts, "|")
    expect(joined).to_contain("O2")
    expect(joined).to_contain("VILLA")
    p.eva.tele, p.eva.integrity, p.eva.o2 = false, 100, 100
    p.eva.cool = 30
    p.eva.flash = st.tick
    p.eva.jet, p.eva.assist = true, true
    v = fake_view()
    hud.eva(v, st, p)
    expect(table.concat(v.texts, "|")).to_contain("ASSIST")
    p.eva.cool = 0
    v = fake_view()
    hud.eva(v, st, p)
    expect(table.concat(v.texts, "|")).to_contain("HOME READY")
    -- the wrist: oxygen, integrity, fuel, the teleport
    local bars = xr.wrist(p, nil)
    expect(#bars).to_be(4)
    p.eva.o2, p.eva.integrity, p.eva.tele = 10, 10, 0.4
    bars = xr.wrist(p, nil)
    expect(bars[1][1]).to_be_near(0.1, 1e-6)
    expect(bars[4][1]).to_be_near(0.4, 1e-6)
    p.eva.tele, p.eva.cool = false, 120
    bars = xr.wrist(p, nil)
    expect(bars[4][1]).to_be_near(0.5, 1e-6)
    -- air and an idle pack
    local at = env.at
    env.at = function(state, pl) local e = at(state, pl) e.breathable, e.vacuum = true, false return e end
    p.eva.jet, p.eva.assist, p.suited, p.eva.o2 = false, false, false, 100
    v = fake_view()
    render.render(v, st, 1)
    env.at = at
    expect(table.concat(v.texts, "|")).to_contain("AIR OK")
  end)
end)
