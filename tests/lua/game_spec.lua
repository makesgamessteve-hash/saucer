-- SPDX-License-Identifier: MIT
-- The simulation driven with synthetic command frames.
local game = require("sim.game")
local ship = require("sim.ship")
local tractor = require("sim.tractor")
local ap = require("sim.autopilot")
local input_setup = require("input_setup")

local avatar = require("sim.avatar")
local L = avatar.layout()

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state(players)
  local st = {}
  game.init(st, { seed = 42, players = players or 1 })
  return st
end
local function run(st, c, n)
  for _ = 1, n or 1 do game.step(st, { c, c, c, c }, 1 / 60) end
end
-- put player p at the helm inside the room of candidate c, eyes facing it:
-- the Villa in a great hall, the Seat in a duct
local function park(st, p, c)
  local ruinm = require("sim.ruin")
  local r = game.ruin(1)
  local room = r.rooms[c.room]
  local mn, mx = ruinm.room_box(room, ruinm.kit_of(r.kit), st.sector.sites[1].pos)
  p.ship.size = room.class >= 4 and 1 or 2
  p.ship.morph = false
  p.mode = "helm"
  local eye = { (mn[1] + mx[1]) / 2, c.pos[2] + 0.3, (mn[3] + mx[3]) / 2 }
  if math.abs(eye[1] - c.pos[1]) + math.abs(eye[3] - c.pos[3]) < 1 then eye[3] = eye[3] - 1.5 end
  p.ship.yaw = saucer.math.atan2(c.pos[1] - eye[1], c.pos[3] - eye[3])
  p.ship.pitch = 0
  p.ship.pos = ship.center_for_eye(eye, p.ship.yaw, p.ship.size)
  p.site = 1
end

local function texts(p)
  local t = {}
  for _, m in ipairs(p.msgs) do t[#t + 1] = m.text end
  return table.concat(t, "|")
end

describe("game", function()
  it("starts every player on foot in their own Villa", function()
    local st = new_state(2)
    expect(#st.players).to_be(2)
    expect(st.players[1].ship.size).to_be(1)
    expect(st.players[1].mode).to_be("walk")
    expect(st.players[1].body.pos).to_equal(L.spawn.pos)
    expect(st.players[2].ship.pos[1] ~= st.players[1].ship.pos[1]).to_be(true)
    expect(game.ruin(1)).to_be_truthy()
    expect(game.site_bounds(1)).to_be_truthy()
    expect(game.on_event({ type = "x" }, st)).to_be("x")
    expect(texts(st.players[1])).to_contain("helm")
  end)
  it("toggles camera, help and mystery mode", function()
    local st = new_state()
    run(st, cmd({ pressed = { "camera", "menu", "mystery_mode" } }))
    local p = st.players[1]
    expect(p.cam).to_be("chase")
    expect(p.help).to_be(true)
    expect(st.mystery.mode).to_be("hints")
    run(st, cmd({ pressed = { "camera" } }))
    expect(p.cam).to_be("first")
  end)
  it("walks on foot while the saucer holds station", function()
    local st = new_state()
    local p = st.players[1]
    local pos = { p.ship.pos[1], p.ship.pos[2], p.ship.pos[3] }
    p.ship.vel = { 0, 0, 5 }
    run(st, cmd({ axes = { move_z = 1 } }), 150)
    expect(p.body.pos[3]).to_be_greater(L.spawn.pos[3] + 2)
    expect(math.abs(p.ship.vel[3])).to_be_less(0.5)
    expect(p.ship.pos[1]).to_be(pos[1])
  end)
  it("takes the helm near it, flies, and stands up again", function()
    local st = new_state()
    local p = st.players[1]
    run(st, cmd({ pressed = { "use" } }))
    expect(texts(p)).to_contain("Nothing to use here")
    expect(p.mode).to_be("walk")
    p.body = avatar.new(L, L.helm.stand, 0)
    run(st, cmd({ pressed = { "use" } }))
    expect(p.mode).to_be("helm")
    local z = p.ship.pos[3]
    run(st, cmd({ axes = { move_z = 1 } }), 60)
    expect(p.ship.pos[3]).to_be_greater(z + 5)
    run(st, cmd({ pressed = { "use" } }))
    expect(p.mode).to_be("walk")
    expect(p.body.pos).to_equal(L.helm.stand)
    expect(texts(p)).to_contain("holds station")
  end)
  it("folds into the Seat around the player on foot and unfolds in open space", function()
    local st = new_state()
    local p = st.players[1]
    local eye = game.viewpoint(p)
    run(st, cmd({ pressed = { "shrink" } }))
    expect(p.ship.size).to_be(2)
    expect(p.mode).to_be("helm")
    local now = game.viewpoint(p)
    for k = 1, 3 do expect(now[k]).to_be_near(eye[k], 1e-9) end
    run(st, cmd({ pressed = { "use" } }))
    expect(texts(p)).to_contain("No room to stand up")
    run(st, cmd(), 60)
    expect(texts(p)).to_contain("Configuration: Seat")
    run(st, cmd({ pressed = { "size1" } }))
    expect(p.ship.size).to_be(1)
    run(st, cmd(), 80)
    expect(p.ship.morph).to_be(false)
    expect(texts(p)).to_contain("Configuration: Villa")
    run(st, cmd({ pressed = { "grow" } }))
    run(st, cmd({ pressed = { "size2" } }))
    expect(p.ship.size).to_be(2)
    run(st, cmd({ pressed = { "size1" } }))
    expect(texts(p)).to_contain("Hull is still reshaping")
  end)
  it("refuses unaffordable or blocked growth and shows a ghost", function()
    local st = new_state()
    local p = st.players[1]
    p.ship.charge = 0
    run(st, cmd({ pressed = { "shrink" } }))
    expect(texts(p)).to_contain("Not enough Charge")
    p.ship.size, p.ship.charge, p.mode = 2, 100, "helm"
    -- park the Seat on a derelict floor: the Villa would sink into it
    local r = game.ruin(1)
    local w = r.walls[1]
    p.ship.pos = { (w[1][1] + w[2][1]) / 2, w[2][2] + 0.8, (w[1][3] + w[2][3]) / 2 }
    run(st, cmd({ pressed = { "size1" } }))
    expect(texts(p)).to_contain("No room to grow here")
    expect(p.ghost).to_be_greater(0)
    expect(p.ghost_size).to_be(1)
    expect(p.ghost_pos).to_be_truthy()
  end)
  it("treats other players' saucers as solid", function()
    local st = new_state(2)
    local a, b = st.players[1], st.players[2]
    a.mode = "helm"
    b.ship.pos = { a.ship.pos[1], a.ship.pos[2], a.ship.pos[3] + 30 }
    for _ = 1, 200 do game.step(st, { cmd({ axes = { move_z = 1 } }), cmd() }, 1 / 60) end
    expect(a.ship.pos[3] < b.ship.pos[3] - 25).to_be(true)
    expect(game.blocked(st, a, b.ship.pos, 1, 1, 0)).to_be(true)
  end)
  it("tractor reports nothing in range outside a site and in an empty view", function()
    local st = new_state()
    local p = st.players[1]
    run(st, cmd({ pressed = { "tractor" } }))
    expect(texts(p)).to_contain("Nothing in tractor range")
    p.site = 1
    p.mode = "helm"
    p.ship.yaw = saucer.math.pi
    run(st, cmd({ pressed = { "tractor" } }))
    expect(p.tractor).to_be(false)
  end)
  it("tractors loot into the hold, refuses too-big items and a full hold", function()
    local st = new_state()
    local p = st.players[1]
    local r = game.ruin(1)
    local cands = tractor.candidates(st, p, 1, r)
    local c = cands[1]
    park(st, p, c)
    local size = p.ship.size
    local found = tractor.find(st, p, 1, r, game.viewpoint(p))
    expect(found ~= nil).to_be(true)
    -- the Seat's tractor is too weak for M items
    p.ship.size = 2
    found.item.size = 2
    expect(tractor.can_lift(p.ship, found.item)).to_be(false)
    p.ship.size = size
    local full = {}
    for i = 1, 12 do full[i] = { name = "x", value = 1, hot = false } end
    p.hold = full
    if not found.echo then
      run(st, cmd({ pressed = { "tractor" } }))
      expect(texts(p)).to_contain("Hold is full")
    end
    p.hold = {}
    run(st, cmd({ pressed = { "tractor" } }))
    expect(p.tractor).to_be_truthy()
    run(st, cmd(), 40)
    expect(p.tractor).to_be(false)
    expect(#p.hold + st.mystery.found).to_be(1)
  end)
  it("tractors from on foot, aiming through the glass dome", function()
    local st = new_state()
    local p = st.players[1]
    local r = game.ruin(1)
    local c
    for _, x in ipairs(tractor.candidates(st, p, 1, r)) do
      if r.rooms[x.room].class >= 4 and not x.echo then c = x end
    end
    park(st, p, c)
    p.mode = "walk"
    p.body = avatar.new(L, L.helm.stand, 0)
    for _ = 1, 3 do
      local eye = game.viewpoint(p)
      p.ship.yaw = saucer.math.atan2(c.pos[1] - eye[1], c.pos[3] - eye[3])
    end
    local eye = game.viewpoint(p)
    local dx, dz = c.pos[1] - eye[1], c.pos[3] - eye[3]
    p.body.pitch = saucer.math.atan2(c.pos[2] - eye[2], saucer.math.sqrt(dx * dx + dz * dz))
    run(st, cmd({ pressed = { "tractor" } }))
    expect(p.tractor).to_be_truthy()
    run(st, cmd(), 40)
    expect(#p.hold).to_be(1)
  end)
  it("loses the lock when flying away and banks hot loot on leaving", function()
    local st = new_state()
    local p = st.players[1]
    local r = game.ruin(1)
    local c = tractor.candidates(st, p, 1, r)[1]
    park(st, p, c)
    run(st, cmd({ pressed = { "tractor" } }))
    p.ship.pos = { 0, 500, 0 }
    run(st, cmd())
    expect(texts(p)).to_contain("Tractor lock lost")
    p.hold = { { name = "a", value = 10, hot = true }, { name = "b", value = 5, hot = false } }
    p.site = 1
    run(st, cmd())
    expect(p.site).to_be(0)
    expect(p.banked_value).to_be(10)
    expect(texts(p)).to_contain("Banked 1 item (10 c)")
  end)
  it("collects an Echo and completes the chain", function()
    local st = new_state()
    local p = st.players[1]
    st.mystery.echoes[2].found_by, st.mystery.echoes[3].found_by, st.mystery.found = 1, 1, 2
    st.mystery.echoes[1].site = 1
    local r = game.ruin(1)
    local echo
    for _, c in ipairs(tractor.candidates(st, p, 1, r)) do if c.echo then echo = c end end
    p.tractor = { key = echo.key, site = 1, left = 0.01 }
    p.ship.size = 2
    p.mode = "helm"
    p.ship.pos = { echo.pos[1], echo.pos[2], echo.pos[3] - 2 }
    run(st, cmd())
    expect(st.mystery.solved).to_be(true)
    expect(texts(p)).to_contain("Resonant vault")
  end)
  it("rebuilds derived data identically after restore", function()
    local st = new_state()
    local h = game.ruin(1).hash
    game.rebuild(st)
    expect(game.ruin(1).hash).to_be(h)
    expect(game.site_at({ 1e6, 0, 0 })).to_be(0)
  end)
  it("binds the default actions for every player", function()
    expect(input_setup.setup(2)).to_be(0)
  end)
end)

describe("autopilot", function()
  local fake
  before_each(function()
    fake = { log = {} }
    function fake.axis(p, a, v) fake.log[#fake.log + 1] = a end
    function fake.press(p, a) fake.log[#fake.log + 1] = a end
    function fake.wait() end
  end)
  it("maps door classes to the largest saucer that fits", function()
    expect(ap.config_for_class(4)).to_be(1)
    expect(ap.config_for_class(3)).to_be(2)
    expect(ap.config_for_class(1)).to_be(2)
    expect(ap.config_for_class(0)).to_be(2)
  end)
  it("routes through each door with the right size", function()
    local st = new_state()
    local r = game.ruin(1)
    local last = r.rooms[#r.rooms]
    local wps = ap.route(r, st.sector.sites[1].pos, last.id)
    expect(#wps % 3).to_be(0)
    expect(wps[1].size).to_be(1) -- the Villa flies into the great hall
    expect(wps[#wps].size).to_be(2) -- the duct needs the Seat
  end)
  it("finds where to stand so a reconfiguration lands on a spot", function()
    local spot = ap.spot_for({ 0, 10, 0 }, 0, 2, 1)
    local center = ship.center_for_eye(ship.eye_world(spot, 0, 2), 0, 1)
    for k = 1, 3 do expect(center[k]).to_be_near(({ 0, 10, 0 })[k], 1e-9) end
  end)
  it("walks the body and turns it with real command frames", function()
    local st = new_state()
    local get = function() return st.players[1] end
    local held, pressed = {}, {}
    local t = {}
    function t.axis(_, a, v) held[a] = v end
    function t.press(_, a) pressed[#pressed + 1] = a end
    function t.wait(n)
      for _ = 1, n or 1 do
        run(st, cmd({ axes = held, pressed = pressed }))
        pressed = {}
      end
    end
    expect(ap.walk_path(t, 1, get, { { 0, 0.6, 2 }, L.helm.stand }, 0.3, 600)).to_be(true)
    t.press(1, "use")
    t.wait(1)
    expect(get().mode).to_be("helm")
    expect(ap.look(t, 1, get, 0.5, 0.1, 300)).to_be(true)
    expect(ap.look(t, 1, get, 3.0, 0, 1)).to_be(false)
    expect(select(2, ap.walk_path(t, 1, get, { { 50, 0.6, 0 } }, 0.3, 2))).to_be(1)
    expect(ap.resize(t, 1, get, 2)).to_be(true)
    expect(ap.resize(t, 1, get, 1)).to_be(true)
  end)
  it("steers toward a target and faces a point", function()
    local s = ship.new({ 0, 0, 0 }, 0, 2)
    local axes, dist = ap.steer(s, { 0, 0, 10 })
    expect(axes.move_z).to_be_greater(0)
    expect(dist).to_be(10)
    local a2, _, diff = ap.steer(s, { 0, 0, 0 }, { 10, 0, 0 })
    expect(diff).to_be_greater(0)
    expect(a2.turn).to_be_less(0)
    local a3 = ap.steer(s, { 0, 5, 0 })
    expect(a3.turn).to_be(0)
  end)
  it("drives a ship with an injected input API", function()
    local s = ship.new({ 0, 0, 0 }, 0, 2)
    local get = function() return { ship = s } end
    -- a fake world: wait() advances the ship toward the target directly
    local target = { 0, 0, 3 }
    function fake.wait() s.pos = { 0, 0, s.pos[3] + 1 } end
    expect(ap.fly(fake, 1, get, target, 0.5, 10)).to_be(true)
    expect(ap.fly(fake, 1, get, { 100, 0, 0 }, 0.5, 3)).to_be(false)
    function fake.wait() s.morph = false end
    function fake.press(p, a)
      s.size = a == "shrink" and s.size + 1 or s.size - 1
      s.morph = true
    end
    s.size = 1
    expect(ap.resize(fake, 1, get, 2)).to_be(true)
    expect(ap.resize(fake, 1, get, 1)).to_be(true)
    s.pos = { 0, 0, 0 }
    function fake.wait() s.yaw = saucer.math.pi / 2 end
    expect(ap.face(fake, 1, get, { 10, 0, 0 }, 5)).to_be(true)
    function fake.wait() end
    expect(ap.face(fake, 1, get, { -10, 0, 0 }, 2)).to_be(false)
    function fake.wait() s.morph = false end
    expect(select(2, ap.follow(fake, 1, get, { { pos = { 50, 0, 0 }, size = 2 } }, 2))).to_be(1)
    function fake.press() end
    expect(select(2, ap.follow(fake, 1, get, { { pos = { 0, 0, 0 }, size = 1 } }, 2))).to_be(1)
    s.pos = { 0, 0, 0 }
    expect(ap.follow(fake, 1, get, { { pos = { 0, 0, 0 } } }, 2)).to_be(true)
  end)
end)
