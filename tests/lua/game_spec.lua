-- SPDX-License-Identifier: MIT
-- The simulation driven with synthetic command frames.
local game = require("sim.game")
local ship = require("sim.ship")
local tractor = require("sim.tractor")
local ap = require("sim.autopilot")
local input_setup = require("input_setup")

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state(players)
  local st = {}
  game.init(st, { seed = 42, players = players or 1 })
  return st
end
local function run(st, c, n)
  for _ = 1, n or 1 do game.step(st, { c, c, c, c }, 1 / 60) end
end
-- park player p in the room of candidate c, facing it, as the Cruiser
local function park(st, p, c)
  local ruinm = require("sim.ruin")
  local r = game.ruin(1)
  local room = r.rooms[c.room]
  local mn, mx = ruinm.room_box(room, ruinm.kit_of(r.kit), st.sector.sites[1].pos)
  p.ship.size = room.class >= 3 and 2 or (room.class == 2 and 3 or 4)
  local pos = { (mn[1] + mx[1]) / 2, c.pos[2] + 0.3, (mn[3] + mx[3]) / 2 }
  if math.abs(pos[1] - c.pos[1]) + math.abs(pos[3] - c.pos[3]) < 1 then pos[3] = pos[3] - 1.5 end
  p.ship.pos = pos
  p.ship.yaw = saucer.math.atan2(c.pos[1] - pos[1], c.pos[3] - pos[3])
  p.site = 1
end

local function texts(p)
  local t = {}
  for _, m in ipairs(p.msgs) do t[#t + 1] = m.text end
  return table.concat(t, "|")
end

describe("game", function()
  it("starts every player in their own Villa", function()
    local st = new_state(2)
    expect(#st.players).to_be(2)
    expect(st.players[1].ship.size).to_be(1)
    expect(st.players[2].ship.pos[1] ~= st.players[1].ship.pos[1]).to_be(true)
    expect(game.ruin(1)).to_be_truthy()
    expect(game.site_bounds(1)).to_be_truthy()
    expect(game.on_event({ type = "x" }, st)).to_be("x")
  end)
  it("toggles camera, help and mystery mode", function()
    local st = new_state()
    run(st, cmd({ pressed = { "camera", "menu", "mystery_mode" } }))
    local p = st.players[1]
    expect(p.cam).to_be("chase")
    expect(p.help).to_be(true)
    expect(st.mystery.mode).to_be("hints")
  end)
  it("shrinks with Q, picks sizes directly, grows in open space", function()
    local st = new_state()
    local p = st.players[1]
    run(st, cmd({ pressed = { "shrink" } }))
    run(st, cmd(), 40)
    expect(p.ship.size).to_be(2)
    run(st, cmd({ pressed = { "size4" } }))
    run(st, cmd(), 40)
    expect(p.ship.size).to_be(4)
    run(st, cmd({ pressed = { "grow" } }))
    run(st, cmd(), 70)
    expect(p.ship.size).to_be(3)
    expect(texts(p)).to_contain("Configuration: Pod")
  end)
  it("refuses unaffordable or blocked growth and shows a ghost", function()
    local st = new_state()
    local p = st.players[1]
    p.ship.charge = 0
    run(st, cmd({ pressed = { "shrink" } }))
    expect(texts(p)).to_contain("Not enough Charge")
    p.ship.size, p.ship.charge = 4, 100
    -- park the Seat inside a wall's clearance: put it in the first derelict's entrance floor
    local r = game.ruin(1)
    local w = r.walls[1]
    p.ship.pos = { (w[1][1] + w[2][1]) / 2, w[2][2] + 0.8, (w[1][3] + w[2][3]) / 2 }
    run(st, cmd({ pressed = { "size1" } }))
    expect(texts(p)).to_contain("No room to grow here")
    expect(p.ghost).to_be_greater(0)
    expect(p.ghost_size).to_be(1)
  end)
  it("treats other players' saucers as solid", function()
    local st = new_state(2)
    local a, b = st.players[1], st.players[2]
    b.ship.pos = { a.ship.pos[1], a.ship.pos[2], a.ship.pos[3] + 30 }
    for _ = 1, 200 do game.step(st, { cmd({ axes = { move_z = 1 } }), cmd() }, 1 / 60) end
    expect(a.ship.pos[3] < b.ship.pos[3] - 23).to_be(true)
    expect(game.blocked(st, a, b.ship.pos, 1, 1, 0)).to_be(true)
  end)
  it("tractor reports nothing in range outside a site and in an empty view", function()
    local st = new_state()
    local p = st.players[1]
    run(st, cmd({ pressed = { "tractor" } }))
    expect(texts(p)).to_contain("Nothing in tractor range")
    p.site = 1
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
    local found = tractor.find(st, p, 1, r)
    expect(found ~= nil).to_be(true)
    -- the Seat's tractor is too weak for M items
    p.ship.size = 4
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
    p.ship.size = 4
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
    expect(ap.config_for_class(1)).to_be(4)
    expect(ap.config_for_class(0)).to_be(4)
  end)
  it("routes through each door with the right size", function()
    local st = new_state()
    local r = game.ruin(1)
    local last = r.rooms[#r.rooms]
    local wps = ap.route(r, st.sector.sites[1].pos, last.id)
    expect(#wps % 3).to_be(0)
    expect(wps[1].size).to_be(2)
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
    function fake.wait()
      if s.target then s.size, s.target = s.target, false end
    end
    function fake.press(p, a) s.target = a == "shrink" and s.size + 1 or s.size - 1 end
    expect(ap.resize(fake, 1, get, 4)).to_be(true)
    expect(ap.resize(fake, 1, get, 3)).to_be(true)
    s.pos = { 0, 0, 0 }
    function fake.wait() s.yaw = saucer.math.pi / 2 end
    expect(ap.face(fake, 1, get, { 10, 0, 0 }, 5)).to_be(true)
    function fake.wait() end
    expect(ap.face(fake, 1, get, { -10, 0, 0 }, 2)).to_be(false)
    expect(select(2, ap.follow(fake, 1, get, { { pos = { 50, 0, 0 }, size = 3 } }, 2))).to_be(1)
    function fake.press() end
    expect(select(2, ap.follow(fake, 1, get, { { pos = { 0, 0, 0 }, size = 1 } }, 2))).to_be(1)
    s.pos = { 0, 0, 0 }
    expect(ap.follow(fake, 1, get, { { pos = { 0, 0, 0 } } }, 2)).to_be(true)
  end)
end)
