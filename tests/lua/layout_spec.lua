-- SPDX-License-Identifier: MIT
-- add-home-layout: layout.of returns the shared base table until a built-in
-- is moved, then a copy whose stations follow the furniture.
local game = require("sim.game")
local layout = require("sim.layout")
local avatar = require("sim.avatar")

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state()
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  return st
end

describe("layout.of", function()
  it("returns the exact base table when nothing has moved", function()
    local st = new_state()
    local p = st.players[1]
    expect(layout.of(p)).to_be(layout.base())
    expect(layout.of(p)).to_be(avatar.layout())
    expect(layout.has_moves(p)).to_be(false)
    expect(layout.rev(p)).to_be(0)
  end)

  it("does not create p.home until the first edit", function()
    local st = new_state()
    local p = st.players[1]
    layout.of(p)
    expect(p.home).to_be(nil)
  end)

  it("moves a sofa and the returned furniture box follows it", function()
    local st = new_state()
    local p = st.players[1]
    local home = layout.home_pose("sofa")
    expect(home).to_be_truthy()
    layout.set_move(p, "sofa", { deck = 1, x = home.x + 1.0, z = home.z, turn = 6, w = home.w, d = home.d })
    expect(layout.has_moves(p)).to_be(true)
    expect(layout.of(p) ~= layout.base()).to_be(true)
    local f = layout.piece(layout.of(p), "sofa")
    local cx, cz = layout.centre(f)
    expect(math.abs(cx - (home.x + 1.0)) < 1e-6).to_be(true)
    expect(f.turn).to_be(6)
    -- a 90° turn swaps the sides of the AABB
    local w, d = f.box[3] - f.box[1], f.box[4] - f.box[2]
    expect(math.abs(w - home.d) < 1e-6 and math.abs(d - home.w) < 1e-6).to_be(true)
  end)

  it("clears a move back to the shared base table", function()
    local st = new_state()
    local p = st.players[1]
    local home = layout.home_pose("plant_lr")
    layout.set_move(p, "plant_lr", { deck = 1, x = 0, z = 0, turn = 0, w = home.w, d = home.d })
    layout.set_move(p, "plant_lr", nil)
    expect(layout.has_moves(p)).to_be(false)
    expect(layout.of(p)).to_be(layout.base())
  end)

  it("the bed station follows a moved bed", function()
    local st = new_state()
    local p = st.players[1]
    local home = layout.home_pose("bed")
    layout.set_move(p, "bed", { deck = 2, x = 4.0, z = 3.5, turn = 0, w = home.w, d = home.d })
    local L = layout.of(p)
    local stn
    for _, s in ipairs(L.stations) do if s.kind == "bed" then stn = s end end
    expect(stn).to_be_truthy()
    expect(math.abs(stn.pos[1] - 4.0) < 1e-6).to_be(true)
    expect(math.abs(stn.pos[3] - 3.5) < 1e-6).to_be(true)
    expect(stn.deck).to_be(2)
  end)

  it("preview does not write p.home", function()
    local st = new_state()
    local p = st.players[1]
    local home = layout.home_pose("stool_a")
    local L = layout.preview(p, "stool_a", { deck = 1, x = 0, z = 0, turn = 0, w = home.w, d = home.d })
    expect(layout.piece(L, "stool_a")).to_be_truthy()
    expect(p.home).to_be(nil)
    expect(layout.has_moves(p)).to_be(false)
  end)

  it("undo records cap at 20", function()
    local st = new_state()
    local p = st.players[1]
    for i = 1, 25 do layout.push_undo(p, { typ = "test", n = i }) end
    expect(#p.home.undo).to_be(20)
    expect(layout.pop_undo(p).n).to_be(25)
  end)

  it("15-degree footprints rotate the AABB", function()
    local fp0 = layout.footprint(2, 1, 0, 0, 0)
    expect(fp0[1]).to_be(-1)
    expect(fp0[2]).to_be(-0.5)
    local fp6 = layout.footprint(2, 1, 0, 0, 6)
    expect(math.abs(fp6[1] - -0.5) < 1e-6).to_be(true)
    expect(math.abs(fp6[2] - -1) < 1e-6).to_be(true)
    local fp3 = layout.footprint(2, 1, 0, 0, 3) -- 45°
    expect(fp3[3] - fp3[1] > 2).to_be(true)
  end)
end)

describe("layout under a read-only proxy", function()

  it("of() applies moves when state is wrapped in a render proxy", function()
    local st = new_state()
    local p = st.players[1]
    local sofa = layout.home_pose("sofa")
    layout.set_move(p, "sofa", { deck = 1, x = -5.2, z = 0.8, turn = 6, w = sofa.w, d = sofa.d })
    local ro = saucer.util.readonly(p)
    expect(layout.has_moves(ro)).to_be(true)
    local L = layout.of(ro)
    local f = layout.piece(L, "sofa")
    local cx, cz = layout.centre(f)
    expect(math.abs(cx - (-5.2)) < 0.05).to_be(true)
    expect(math.abs(cz - 0.8) < 0.05).to_be(true)
    expect(f.turn).to_be(6)
  end)
end)
