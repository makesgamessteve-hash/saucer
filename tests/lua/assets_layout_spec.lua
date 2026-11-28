-- SPDX-License-Identifier: MIT
-- add-home-layout: group meshes rebuild when a built-in has moved.
local game = require("sim.game")
local layout = require("sim.layout")
local assets = require("view.assets")

local function new_state()
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  return st
end

describe("assets.groups_for", function()
  it("returns the default group cache when nothing has moved", function()
    assets.init()
    local st = new_state()
    local p = st.players[1]
    local groups, mats = assets.groups_for(p)
    expect(groups).to_be_truthy()
    expect(next(groups)).to_be_truthy()
    local g2 = assets.groups_for(nil)
    expect(g2).to_be(groups)
  end)

  it("rebuilds group meshes after a sofa move and caches that revision", function()
    assets.init()
    local st = new_state()
    local p = st.players[1]
    local def_groups = assets.groups_for(p)
    local sofa = layout.home_pose("sofa")
    layout.set_move(p, "sofa", { deck = 1, x = -5.2, z = 0.8, turn = 6, w = sofa.w, d = sofa.d })
    local moved, mats = assets.groups_for(p)
    expect(moved).to_be_truthy()
    expect(moved ~= def_groups).to_be(true)
    -- a second call at the same revision is the same table
    local again = assets.groups_for(p)
    expect(again).to_be(moved)
    -- bumping the revision rebuilds once more
    layout.set_move(p, "armchair", { deck = 1, x = -6.6, z = -3.2, turn = 0,
      w = layout.home_pose("armchair").w, d = layout.home_pose("armchair").d })
    local v2 = assets.groups_for(p)
    expect(v2 ~= moved).to_be(true)
  end)
end)
