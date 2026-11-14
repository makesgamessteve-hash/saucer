-- SPDX-License-Identifier: MIT
-- spec saucer-interior: walking on both decks of the Villa
local avatar = require("sim.avatar")
local L = avatar.layout()
local DT = 1 / 60

local function walk(b, input, n)
  local blocked = 0
  for _ = 1, n do blocked = blocked + avatar.step(b, input, DT, L) end
  return blocked
end

describe("interior layout", function()
  it("has a dome deck over a lower deck joined by stairs", function()
    expect(#L.decks).to_be(2)
    expect(L.decks[1].floor).to_be_greater(L.decks[2].floor)
    expect(L.stairs.high).to_be_greater(L.stairs.low)
  end)
  it("names the rooms people expect", function()
    local names = {}
    for _, r in ipairs(L.rooms) do names[r.name] = true end
    for _, n in ipairs({ "Kitchen", "Living room", "Helm", "Bedroom", "Bathroom", "Engine room" }) do
      expect(names[n]).to_be(true)
    end
  end)
  it("keeps every solid piece inside its deck", function()
    for _, f in ipairs(L.furniture) do
      local r = L.decks[f.deck].radius + 0.3
      if f.box then
        for _, c in ipairs({ { f.box[1], f.box[2] }, { f.box[3], f.box[4] }, { f.box[1], f.box[4] }, { f.box[3], f.box[2] } }) do
          expect(c[1] * c[1] + c[2] * c[2] <= r * r).to_be(true)
        end
      end
    end
  end)
end)

describe("walking", function()
  it("spawns on the dome deck in the living room area", function()
    local b = avatar.new()
    expect(avatar.deck_of(L, b)).to_be(1)
    expect(b.pos).to_equal(L.spawn.pos)
  end)
  it("walks forward along +z at yaw 0, sideways with move_x, faster when running", function()
    local b = avatar.new(L, { 0, 0.6, -1 }, 0)
    expect(walk(b, { move_z = 1 }, 30)).to_be(0)
    expect(b.pos[3]).to_be_near(-1 + L.walk_speed * 0.5, 1e-6)
    local r = avatar.new(L, { 0, 0.6, -1 }, 0)
    walk(r, { move_z = 1, run = true }, 30)
    expect(r.pos[3]).to_be_greater(b.pos[3])
    local s = avatar.new(L, { 0, 0.6, 0 }, 0)
    walk(s, { move_x = 1 }, 30)
    expect(s.pos[1]).to_be_less(0) -- right is -x (see lib/vec.right)
  end)
  it("turns with the turn axis and clamps the pitch", function()
    local b = avatar.new()
    walk(b, { turn = 1, look = 1 }, 30)
    expect(b.yaw).to_be_less(0)
    walk(b, { look = 1 }, 90)
    expect(b.pitch).to_be(L.pitch_limit)
    expect(walk(b, {}, 1)).to_be(0)
  end)
  it("bumps into furniture and the dome's edge", function()
    local b = avatar.new(L, { 4.3, 0.6, -3 }, 0) -- kitchen island ahead
    local blocked = walk(b, { move_z = 1 }, 60)
    expect(blocked).to_be_greater(0)
    expect(b.pos[3]).to_be_less(-1.4 - L.body_radius + 0.01)
    local e = avatar.new(L, { 0, 0.6, -8 }, saucer.math.pi)
    walk(e, { move_z = 1 }, 120)
    expect(e.pos[3]).to_be_greater(-L.decks[1].radius)
    -- a round obstacle: the engine core on the lower deck
    local c = avatar.new(L, { 0, -3.0, 0.2 }, saucer.math.pi)
    walk(c, { move_z = 1 }, 120)
    expect(c.pos[3]).to_be_greater(-1.8 + 1.1 + L.body_radius - 0.01)
  end)
  it("slides along a wall", function()
    local b = avatar.new(L, { 4.3, 0.6, -2 }, 0)
    local yaw = saucer.math.pi / 4
    b.yaw = yaw
    walk(b, { move_z = 1 }, 60)
    expect(b.pos[1]).to_be_greater(4.3)
  end)
  it("walks down the stairs to the lower deck and back up", function()
    local b = avatar.new(L, { 4.6, 0.6, -5.2 }, -saucer.math.pi / 2) -- facing -x, at the top landing
    walk(b, { move_z = 1 }, 200)
    expect(avatar.deck_of(L, b)).to_be(2)
    expect(b.pos[2]).to_be(L.decks[2].floor)
    expect(b.pos[1]).to_be_less(L.stairs.low)
    b.yaw = saucer.math.pi / 2
    walk(b, { move_z = 1 }, 200)
    expect(avatar.deck_of(L, b)).to_be(1)
    expect(b.pos[2]).to_be(L.decks[1].floor)
  end)
  it("cannot step into the stairwell from the side or over the rail", function()
    local b = avatar.new(L, { 0, 0.6, -3.5 }, saucer.math.pi) -- dome deck, facing -z toward the hole
    walk(b, { move_z = 1 }, 120)
    expect(b.pos[2]).to_be(L.decks[1].floor)
    expect(b.pos[3]).to_be_greater(L.stairs.z1)
    local f, d = avatar.floor_at(L, 0, -5.2, 0.6)
    expect(d).to_be(2)
    expect(f).to_be_less(0)
  end)
  it("walks in the XR head direction", function()
    local b = avatar.new(L, { 0, 0.6, 0 }, 0)
    walk(b, { move_z = 1, aim = { 32767, 0, 0 } }, 30) -- head turned to +x
    expect(b.pos[1]).to_be_greater(1)
    expect(avatar.head_yaw(nil)).to_be(0)
    expect(avatar.head_yaw({ 0, 0, 0 })).to_be(0)
  end)
  it("knows when the helm is in reach and which room you are in", function()
    expect(avatar.near_helm(L, avatar.new(L, L.helm.stand, 0))).to_be(true)
    expect(avatar.near_helm(L, avatar.new())).to_be(false)
    expect(avatar.room(L, avatar.new(L, { 5, 0.6, 0 }))).to_be("Kitchen")
    expect(avatar.room(L, avatar.new(L, { -6, 0.6, 0 }))).to_be("Living room")
    expect(avatar.room(L, avatar.new(L, { 3, -3.0, 4 }))).to_be("Bedroom")
    expect(avatar.room(L, avatar.new(L, { -3, -3.0, 4 }))).to_be("Bathroom")
    expect(avatar.room(L, avatar.new(L, { 3, -3.0, -2 }))).to_be("Engine room")
    expect(avatar.room(L, avatar.new(L, { 0, 0.6, -8.5 }))).to_be("Dome deck")
  end)
  it("rotates hull-local offsets like the renderer", function()
    local v = avatar.rot(saucer.math.pi / 2, { 0, 1, 1 })
    expect(v[1]).to_be_near(1, 1e-9)
    expect(v[2]).to_be(1)
    expect(v[3]).to_be_near(0, 1e-9)
  end)
end)
