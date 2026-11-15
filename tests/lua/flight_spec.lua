-- SPDX-License-Identifier: MIT
local flight = require("sim.flight")
local ship = require("sim.ship")
local free = function(s, d) return { s.pos[1] + d[1], s.pos[2] + d[2], s.pos[3] + d[3] }, 0 end
local wall = function(s, d) return { s.pos[1], s.pos[2], s.pos[3] }, 1 end

describe("flight", function()
  it("accelerates forward along +z at yaw 0", function()
    local s = ship.new({ 0, 0, 0 }, 0, 1)
    local cmd = saucer.input.command({ axes = { move_z = 1 } })
    for _ = 1, 60 do flight.step(s, cmd, 1 / 60, free) end
    expect(s.pos[3]).to_be_greater(5)
    expect(math.abs(s.pos[1])).to_be_less(1e-9)
  end)
  it("turning right decreases yaw; looking is clamped", function()
    local s = ship.new({ 0, 0, 0 }, 0, 1)
    local cmd = saucer.input.command({ axes = { turn = 1, look = 1 } })
    for _ = 1, 120 do flight.step(s, cmd, 1 / 60, free) end
    expect(s.yaw).to_be_less(0)
    expect(s.pitch).to_be(flight.PITCH_LIMIT)
  end)
  it("boost and lift move faster and up", function()
    local a, b = ship.new({ 0, 0, 0 }, 0, 2), ship.new({ 0, 0, 0 }, 0, 2)
    local c1 = saucer.input.command({ axes = { move_z = 1, lift = 1 } })
    local c2 = saucer.input.command({ axes = { move_z = 1, lift = 1 }, buttons = { "boost" } })
    for _ = 1, 30 do
      flight.step(a, c1, 1 / 60, free)
      flight.step(b, c2, 1 / 60, free)
    end
    expect(b.pos[3]).to_be_greater(a.pos[3])
    expect(a.pos[2]).to_be_greater(0)
  end)
  it("stops on walls", function()
    local s = ship.new({ 0, 0, 0 }, 0, 1)
    local cmd = saucer.input.command({ axes = { move_z = 1 } })
    flight.step(s, cmd, 1 / 60, wall)
    expect(s.vel[3]).to_be(0)
  end)
  it("forward thrust follows the look pitch: look up and you climb", function()
    local s = ship.new({ 0, 0, 0 }, 0, 1)
    s.pitch = 0.8
    local cmd = saucer.input.command({ axes = { move_z = 1 } })
    for _ = 1, 60 do flight.step(s, cmd, 1 / 60, free) end
    expect(s.pos[2]).to_be_greater(3)
    expect(s.pos[3]).to_be_greater(3)
    local d = ship.new({ 0, 0, 0 }, 0, 1)
    d.pitch = -flight.PITCH_LIMIT
    for _ = 1, 60 do flight.step(d, cmd, 1 / 60, free) end
    expect(d.pos[2]).to_be_less(-5)
    expect(math.abs(d.pos[3])).to_be_less(math.abs(d.pos[2]))
  end)
  it("lift is vertical, scaled, and independent of pitch", function()
    local s = ship.new({ 0, 0, 0 }, 0, 1)
    s.pitch = 0.6
    local w = flight.want(s, 0, 0, 1, 10)
    expect(w[1]).to_be_near(0, 1e-9)
    expect(w[2]).to_be_near(10 * flight.LIFT_FACTOR, 1e-9)
    expect(w[3]).to_be_near(0, 1e-9)
    local down = flight.want(s, 0, 0, -1, 10)
    expect(down[2]).to_be_near(-10 * flight.LIFT_FACTOR, 1e-9)
  end)
  it("banks into turns up to BANK_MAX and levels out again", function()
    local s = ship.new({ 0, 0, 0 }, 0, 1)
    local hard = saucer.input.command({ axes = { turn = 1, move_x = 1 } })
    for _ = 1, 240 do flight.step(s, hard, 1 / 60, free) end
    expect(s.bank).to_be_near(flight.BANK_MAX, 1e-3)
    expect(s.bank <= flight.BANK_MAX).to_be(true)
    local left = saucer.input.command({ axes = { turn = -1 } })
    for _ = 1, 240 do flight.step(s, left, 1 / 60, free) end
    expect(s.bank).to_be_less(0)
    local idle = saucer.input.command({ axes = {} })
    for _ = 1, 400 do flight.step(s, idle, 1 / 60, free) end
    expect(math.abs(s.bank)).to_be_less(1e-3)
  end)
  it("dampens to a hover that holds altitude", function()
    local s = ship.new({ 0, 50, 0 }, 0, 1)
    local up = saucer.input.command({ axes = { lift = 1 } })
    for _ = 1, 30 do flight.step(s, up, 1 / 60, free) end
    local idle = saucer.input.command({ axes = {} })
    for _ = 1, 300 do flight.step(s, idle, 1 / 60, free) end
    local y = s.pos[2]
    for _ = 1, 60 do flight.step(s, idle, 1 / 60, free) end
    expect(s.pos[2]).to_be_near(y, 1e-2)
    expect(y).to_be_greater(50)
  end)
  it("reports elevation of a point relative to the ship", function()
    local s = ship.new({ 0, 10, 0 }, 0, 1)
    expect(flight.elevation(s, { 0, 40, 0 })).to_be(30)
    expect(flight.elevation(s, { 5, -5, 0 })).to_be(-15)
  end)
end)
