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
end)
