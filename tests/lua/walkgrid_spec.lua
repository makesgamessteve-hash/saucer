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
end)
