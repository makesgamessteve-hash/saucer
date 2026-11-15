-- SPDX-License-Identifier: MIT
-- spec saucer-size
local ship = require("sim.ship")
local configs = require("sim.config")
local never = function() return false end
local always = function() return true end

local function near(a, b) return math.abs(a - b) < 1e-9 end

describe("saucer configurations", function()
  it("has two sizes: the Villa with rooms and the one-seat car", function()
    expect(configs.count()).to_be(2)
    expect(configs.get(1).id).to_be("villa")
    expect(configs.get(1).interior).to_be(true)
    expect(configs.get(2).id).to_be("seat")
    expect(configs.get(2).interior).to_be(false)
    expect(configs.by_id("seat")).to_be(2)
    expect(configs.by_id("nope")).to_be(nil)
  end)
end)

describe("size changes", function()
  local s
  before_each(function() s = ship.new({ 0, 0, 0 }, 0, 1) end)
  it("folding to the Seat costs 20 Charge, unfolding half that", function()
    expect(ship.cost(1, 2)).to_be(20)
    expect(ship.cost(2, 1)).to_be(10)
  end)
  it("reconfigures around the pilot's eyes", function()
    local eye = ship.eye_world(s.pos, s.yaw, 1)
    expect(ship.request(s, 2, never)).to_be(true)
    expect(s.size).to_be(2)
    expect(s.charge).to_be(80)
    local after = ship.eye_world(s.pos, s.yaw, 2)
    for k = 1, 3 do expect(near(after[k], eye[k])).to_be(true) end
    -- the helm is forward of the Villa's centre, so the Seat ends up there
    expect(s.pos[3]).to_be_greater(6)
    expect(s.morph.from).to_be(1)
    expect(ship.progress(s)).to_be(0)
    local done
    for _ = 1, 90 do done = ship.update(s, 1 / 60, false) or done end
    expect(done).to_be("done")
    expect(s.morph).to_be(false)
    expect(ship.progress(s)).to_be(1)
  end)
  it("can fold around any eye point and facing (on foot)", function()
    expect(ship.request(s, 2, never, { 3, 2, -1 }, 1.0)).to_be(true)
    expect(s.yaw).to_be(1.0)
    local e = ship.eye_world(s.pos, s.yaw, 2)
    expect(near(e[1], 3) and near(e[2], 2) and near(e[3], -1)).to_be(true)
  end)
  it("rejects invalid, same, busy and unaffordable requests", function()
    expect(select(2, ship.request(s, 0, never))).to_be("range")
    expect(select(2, ship.request(s, 3, never))).to_be("range")
    expect(select(2, ship.request(s, 1, never))).to_be("same")
    ship.request(s, 2, never)
    expect(select(2, ship.request(s, 1, never))).to_be("busy")
    local poor = ship.new({ 0, 0, 0 }, 0, 1)
    poor.charge = 1
    expect(select(2, ship.request(poor, 2, never))).to_be("charge")
  end)
  it("blocks unfolding without clearance, keeps Charge and says where", function()
    local small = ship.new({ 0, 0, 0 }, 0, 2)
    small.charge = 50
    local ok, why, where = ship.request(small, 1, always)
    expect(ok).to_be(false)
    expect(why).to_be("clearance")
    expect(where[3]).to_be_less(-6)
    expect(small.charge).to_be(50)
    expect(small.size).to_be(2)
    local seen
    expect(ship.request(small, 1, function(pos) seen = pos; return false end)).to_be(true)
    expect(seen[3]).to_be(small.pos[3])
  end)
  it("uses the new hull for collision at once", function()
    ship.request(s, 2, never)
    expect((ship.dims(s))).to_be(0.9)
    expect(s.vel).to_equal({ 0, 0, 0 })
  end)
  it("regenerates Charge only in open space and not while reshaping", function()
    s.charge = 50
    ship.update(s, 1, false)
    expect(s.charge).to_be(50)
    ship.update(s, 1, true)
    expect(s.charge).to_be(52)
    s.charge = 99.5
    ship.update(s, 1, true)
    expect(s.charge).to_be(100)
    ship.request(s, 2, never)
    ship.update(s, 0.1, true)
    expect(s.charge).to_be(80)
  end)
end)
