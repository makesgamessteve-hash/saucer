-- SPDX-License-Identifier: MIT
-- spec ruin-gen
local ruin = require("sim.ruin")
local data = require("lib.data")
local civs = data.load("civs/civs.lua")

describe("derelict generation", function()
  it("is deterministic per seed", function()
    local a = ruin.generate(1234, "starship", civs[1], { 0, 0, 0 })
    local b = ruin.generate(1234, "starship", civs[1], { 0, 0, 0 })
    expect(a.hash).to_be(b.hash)
    expect(#a.walls).to_be(#b.walls)
  end)
  it("every room is reachable at its size and loot fits", function()
    for seed = 1, 60 do
      for _, kitid in ipairs({ "starship", "station" }) do
        local r = ruin.generate(seed, kitid, civs[(seed % 2) + 1], { 0, 0, 0 })
        local ok = ruin.validate(r.rooms, r.doors, r.slots)
        expect(ok).to_be(true)
        expect(#r.rooms).to_be_greater(1)
      end
    end
  end)
  it("size locks never increase along the mission chain", function()
    for seed = 1, 30 do
      local r = ruin.generate(seed, "starship", civs[2], { 0, 0, 0 })
      for _, room in ipairs(r.rooms) do
        if room.parent > 0 then expect(room.class <= r.rooms[room.parent].class).to_be(true) end
      end
    end
  end)
  it("the tutorial site has a Cruiser hangar", function()
    local r = ruin.generate(99, "starship", civs[2], { 0, 0, 0 }, nil, 3)
    expect(r.rooms[1].class).to_be(3)
  end)
  it("falls back to a fixed layout when every try fails", function()
    local tiny = { entrance = { { 3, 1 } }, size_lock = 0 }
    local saved = ruin.GRID
    ruin.GRID = { 4, 2, 4 }
    local r = ruin.generate(5, "starship", tiny, { 0, 0, 0 }, 2)
    ruin.GRID = saved
    expect(r.fallback).to_be(true)
  end)
  it("splits walls around door holes", function()
    local p = ruin.slab_pieces(0, 10, 0, 5, { { 2, 4, 3 }, { 6, 8, 5 } })
    -- left, lintel 1, middle, (no lintel 2: full height hole), right
    expect(#p).to_be(4)
    expect(p[1]).to_equal({ 0, 2, 0, 5 })
    expect(p[2]).to_equal({ 2, 4, 3, 5 })
  end)
  it("reports unreachable rooms and oversized slots", function()
    local rooms = { { id = 1, class = 2 }, { id = 2, class = 1 } }
    local doors = { { a = 0, b = 1, class = 2 } }
    expect(select(2, ruin.validate(rooms, doors, {}))).to_contain("unreachable")
    doors[2] = { a = 1, b = 2, class = 1 }
    local ok, why = ruin.validate(rooms, doors, { { id = 1, room = 2, max_size = 2 } })
    expect(ok).to_be(false)
    expect(why).to_contain("too big")
  end)
  it("bounds and entrance are around the rooms", function()
    local r = ruin.generate(3, "station", civs[1], { 10, 0, 10 })
    local lo, hi = ruin.bounds(r, { 10, 0, 10 }, 5)
    local e = ruin.entrance(r, { 10, 0, 10 })
    expect(e[3] >= lo[3] and e[3] <= hi[3]).to_be(true)
    expect(e[1] > lo[1] and e[1] < hi[1]).to_be(true)
  end)
end)
