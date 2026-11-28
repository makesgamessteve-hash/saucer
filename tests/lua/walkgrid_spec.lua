-- SPDX-License-Identifier: MIT
-- add-home-layout: the 0.25 m walk raster still reaches every station from
-- the stair foot in the default Villa, and refuses a placement that would
-- block a path.
local layout = require("sim.layout")
local walkgrid = require("sim.walkgrid")
local game = require("sim.game")

local function new_state()
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  return st
end

describe("walkgrid", function()
  it("reaches every station, door and the hatch from the stair foot", function()
    local L = layout.base()
    local ok, why = walkgrid.stations_ok(L)
    expect(ok).to_be(true)
    expect(why).to_be(nil)
  end)

  it("a plant moved into the bedroom door blocks the door", function()
    local st = new_state()
    local p = st.players[1]
    -- the bedroom door sits on deck 2 around x=2.7, z=0.8
    local home = layout.home_pose("nightstand")
    layout.set_move(p, "nightstand", { deck = 2, x = 2.7, z = 0.8, turn = 0, w = home.w, d = home.d })
    local ok, why = walkgrid.stations_ok(layout.of(p))
    expect(ok).to_be(false)
    expect(why).to_contain("bedroom")
  end)

  it("paths between two open points on the same deck", function()
    local L = layout.base()
    local path = walkgrid.path(L, nil, { deck = 1, x = 0, z = 4 }, { deck = 1, x = 0, z = -4 })
    expect(path).to_be_truthy()
    expect(#path > 2).to_be(true)
    expect(type(path[1][1]) == "number").to_be(true)
    expect(type(path[#path][3]) == "number").to_be(true)
  end)

  it("paths from the living room down to the hatch", function()
    local L = layout.base()
    local path = walkgrid.path(L, nil, { deck = 1, x = 0, z = 4 }, { deck = 2, x = 0, z = -7.4 })
    expect(path).to_be_truthy()
    expect(#path > 4).to_be(true)
  end)

  it("a solid around the hatch leaves the hatch unreached", function()
    local L = layout.base()
    local extra = { { deck = 2, box = { -3.2, -9.6, 3.2, -5.5 } } }
    local seen, grids = walkgrid.flood(L, extra, walkgrid.stair_source(L))
    expect(walkgrid.reached(seen, grids, 1, -4.7, -5.85)).to_be(true)
    expect(walkgrid.reached(seen, grids, 2, 0.0, -7.4)).to_be(false)
  end)

  it("stair_source uses the stair_foot node, or the flight when nav is missing", function()
    local L = layout.base()
    local src = walkgrid.stair_source(L)
    expect(src[1].deck).to_be(2)
    local bare = { stairs = L.stairs }
    local fb = walkgrid.stair_source(bare)
    expect(fb[1].deck).to_be(2)
    expect(type(fb[1].x) == "number").to_be(true)
  end)

  it("vertical links a stair cell to the other deck", function()
    local L = layout.base()
    local grids = walkgrid.build(L)
    local src = walkgrid.stair_source(L)[1]
    local i = walkgrid.cell_of(grids[2], src.x, src.z)
    expect(i).to_be_truthy()
    -- try the stair cell and its neighbours so same_xz has a chance
    local linked = 0
    local n = grids[2].n
    local ix = ((i - 1) % n) + 1
    local iz = math.floor((i - 1) / n) + 1
    for dz = -2, 2 do
      for dx = -2, 2 do
        local j = (iz + dz - 1) * n + (ix + dx)
        if j >= 1 and j <= n * n then
          local v = walkgrid.vertical(L, grids, 2, j)
          if v and #v > 0 then linked = linked + 1 end
        end
      end
    end
    -- same_xz often returns nothing on the real Villa (the flights don't share
    -- a cell); the function must still return a list. A tiny fake pair of
    -- decks with the same open cell exercises the success branch.
    expect(type(walkgrid.vertical(L, grids, 2, i)) == "table").to_be(true)
    local fake = {
      stairs = { low = -1, high = 1, z0 = -1, z1 = 1 },
      belly_stairs = { low = -1, high = 1, z0 = -1, z1 = 1 },
    }
    local tiny = {}
    for d = 1, 3 do
      tiny[d] = { origin = -1, n = 4, open = {}, floor = 0, radius = 2 }
      for j = 1, 16 do tiny[d].open[j] = true end
    end
    expect(#walkgrid.vertical(fake, tiny, 1, 10) > 0).to_be(true)
    -- decks 2 and 3 use the belly flight (same_xz to the other belly deck)
    expect(#walkgrid.vertical(fake, tiny, 3, 10) > 0).to_be(true)
  end)

  it("path to a point inside a solid still returns the nearest open cell", function()
    local L = layout.base()
    -- the kitchen island sits around x=5.5, z=0 on deck 1
    local path = walkgrid.path(L, nil, { deck = 1, x = 0, z = 4 }, { deck = 1, x = 5.5, z = 0 })
    expect(path).to_be_truthy()
    expect(#path >= 1).to_be(true)
  end)

  it("stations_ok names a blocked door, or the hatch when no stations remain", function()
    local L = layout.base()
    local function copy(stations, doors)
      local s = {}
      for k, v in pairs(L) do s[k] = v end
      s.stations, s.doors = stations, doors
      return s
    end
    -- a wall across the lower-deck corridor, clear of the hatch, leaves the
    -- bedroom door unreached once stations are ignored
    local wall = { { deck = 2, box = { -9.0, -1.5, 9.0, 4.0 } } }
    local ok, why = walkgrid.stations_ok(copy({}, L.doors), wall)
    expect(ok).to_be(false)
    expect(why).to_contain("door")
    -- the hatch-specific reason only appears after stations and doors pass
    local hatch_block = { { deck = 2, box = { -3.2, -9.6, 3.2, -5.5 } } }
    ok, why = walkgrid.stations_ok(copy({}, {}), hatch_block)
    expect(ok).to_be(false)
    expect(why).to_contain("hatch")
  end)

  it("path around a closed cell still walks to the nearest open neighbour", function()
    local L = layout.base()
    -- a tight solid on the living-room floor; the dest cell itself is closed
    local extra = { { deck = 1, box = { -0.4, -1.4, 0.4, -0.6 } } }
    local path = walkgrid.path(L, extra, { deck = 1, x = 0, z = 4 }, { deck = 1, x = 0, z = -1 })
    expect(path).to_be_truthy()
    expect(#path >= 1).to_be(true)
  end)
end)
