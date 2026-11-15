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
  it("halls take the whole Villa; ducts need the Seat", function()
    local ducts = 0
    for seed = 1, 30 do
      local r = ruin.generate(seed, "starship", civs[1], { 0, 0, 0 })
      expect(r.rooms[1].class).to_be(4)
      local villa = require("sim.config").get(1)
      local kit = ruin.kit_of("starship")
      expect(kit.doors[4][1]).to_be_greater(villa.diameter + 4)
      expect(kit.doors[4][2]).to_be_greater(villa.height + 2)
      for _, room in ipairs(r.rooms) do
        if room.class == 1 then ducts = ducts + 1 end
        if room.kind == "hall" or room.kind == "vault" then expect(room.class).to_be(4) end
      end
    end
    expect(ducts).to_be_greater(29)
  end)
  it("can force the entrance class", function()
    local r = ruin.generate(99, "starship", civs[2], { 0, 0, 0 }, nil, 4)
    expect(r.rooms[1].class).to_be(4)
  end)
  it("falls back to a fixed layout when every try fails", function()
    local tiny = { entrance = { { 4, 1 } }, size_lock = 0 }
    local saved = ruin.GRID
    ruin.GRID = { 4, 2, 4 }
    local r = ruin.generate(5, "starship", tiny, { 0, 0, 0 }, 2)
    ruin.GRID = saved
    expect(r.fallback).to_be(true)
  end)
  it("splits walls around door holes", function()
    local p = ruin.slab_pieces(0, 10, 0, 5, { { 2, 4, 0, 3 }, { 6, 8, 0, 5 } })
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
  it("cuts floor and ceiling hatches out of the middle of a slab", function()
    local p = ruin.slab_pieces(0, 10, 0, 10, { { 4, 6, 4, 6 } })
    -- left strip, below the hatch, above the hatch, right strip
    expect(#p).to_be(4)
    expect(p[2]).to_equal({ 4, 6, 0, 4 })
    expect(p[3]).to_equal({ 4, 6, 6, 10 })
    local merged = ruin.slab_pieces(0, 10, 0, 10, {})
    expect(#merged).to_be(1)
  end)
  it("grows in every direction: several levels, shafts and hatches", function()
    for _, kitid in ipairs({ "starship", "station", "city" }) do
      local kit = ruin.kit_of(kitid)
      local hatches, shafts, below, above = 0, 0, 0, 0
      for seed = 1, 20 do
        local r = ruin.generate(seed, kitid, civs[(seed % 2) + 1], { 0, 0, 0 })
        expect(r.fallback == nil).to_be(true)
        local span, levels = ruin.span(r.rooms, kit)
        expect(span >= kit.min_span).to_be(true)
        expect(levels >= kit.min_levels).to_be(true)
        for _, d in ipairs(r.doors) do if d.axis == 2 then hatches = hatches + 1 end end
        for _, room in ipairs(r.rooms) do
          if room.kind == "shaft" then shafts = shafts + 1 end
          if room.cell[2] < r.rooms[1].cell[2] then below = below + 1 end
          if room.cell[2] > r.rooms[1].cell[2] then above = above + 1 end
        end
      end
      expect(hatches).to_be_greater(20)
      expect(shafts).to_be_greater(5)
      expect(above).to_be_greater(10)
      expect(below).to_be_greater(10)
    end
  end)
  it("is huge: sites span well over a hundred metres on every axis", function()
    for _, kitid in ipairs({ "starship", "station", "city" }) do
      local r = ruin.generate(7, kitid, civs[1], { 0, 0, 0 })
      local lo, hi = ruin.bounds(r, { 0, 0, 0 }, 0)
      expect(hi[1] - lo[1]).to_be_greater(120)
      expect(hi[2] - lo[2]).to_be_greater(120)
      expect(hi[3] - lo[3]).to_be_greater(120)
    end
  end)
  it("adds exterior solids that never overlap rooms", function()
    for _, kitid in ipairs({ "starship", "station", "city" }) do
      local r = ruin.generate(11, kitid, civs[2], { 0, 0, 0 })
      local kit = ruin.kit_of(kitid)
      expect(#r.solids).to_be_greater(0)
      for _, s in ipairs(r.solids) do
        expect(s.kind).to_be(kit.solids.kind)
        for _, room in ipairs(r.rooms) do
          local mn, mx = ruin.room_box(room, kit, { 0, 0, 0 })
          local hit = true
          for a = 1, 3 do if s[1][a] >= mx[a] or s[2][a] <= mn[a] then hit = false end end
          expect(hit).to_be(false)
        end
      end
    end
  end)
  it("memoizes but stays deterministic across kits and origins", function()
    local a = ruin.generate(77, "city", civs[1], { 5, 6, 7 })
    local b = ruin.generate(77, "city", civs[1], { 5, 6, 7 })
    expect(a).to_be(b)
    local saved = ruin.GRID
    ruin.GRID = ruin.kit_of("city").grid
    local c = ruin.generate(77, "city", civs[1], { 5, 6, 7 })
    ruin.GRID = saved
    expect(c == a).to_be(false)
    expect(c.hash).to_be(a.hash)
  end)
  it("the fallback still climbs: hall, shaft up its ceiling, duct vault", function()
    local kit = ruin.kit_of("starship")
    local r = ruin.fallback(3, kit, { 0, 0, 0 })
    expect(#r.rooms).to_be(3)
    expect(r.rooms[2].kind).to_be("shaft")
    expect(r.doors[2].axis).to_be(2)
    expect(r.rooms[2].cell[2]).to_be_greater(r.rooms[1].cell[2])
    expect(r.rooms[3].class).to_be(1)
    expect(ruin.validate(r.rooms, r.doors, r.slots)).to_be(true)
  end)
  it("finds the room around a point, including upper levels", function()
    local r = ruin.generate(5, "station", civs[1], { 0, 0, 0 })
    local kit = ruin.kit_of("station")
    local top = r.rooms[1]
    for _, room in ipairs(r.rooms) do if room.cell[2] > top.cell[2] then top = room end end
    local mn, mx = ruin.room_box(top, kit, { 0, 0, 0 })
    local mid = { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }
    expect(ruin.room_at(r, { 0, 0, 0 }, mid)).to_be(top)
    expect(ruin.room_at(r, { 0, 0, 0 }, { 1e6, 0, 0 })).to_be(nil)
  end)
  it("matches the committed 3D layout known answers (every platform)", function()
    -- re-record through a reviewed change when the generator changes on purpose
    local kat = {
      { "starship", 1, -1809239244196615700, 9, 93, 5 },
      { "starship", 42, 7450091784366959143, 10, 108, 3 },
      { "station", 1, 3562661300374055466, 14, 155, 6 },
      { "station", 42, -2183098872117938082, 11, 118, 6 },
      { "city", 1, -142771327155978742, 14, 149, 16 },
      { "city", 42, -4299469698777214091, 15, 162, 28 },
    }
    for _, k in ipairs(kat) do
      local r = ruin.generate(k[2], k[1], civs[1], { 0, 0, 0 })
      expect(r.hash).to_be(k[3])
      expect(#r.rooms).to_be(k[4])
      expect(#r.walls).to_be(k[5])
      expect(#r.solids).to_be(k[6])
    end
  end)
end)
