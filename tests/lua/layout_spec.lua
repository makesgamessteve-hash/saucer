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

describe("layout helpers", function()
  it("view is empty until ensure, then returns p.home", function()
    local st = new_state()
    local p = st.players[1]
    local v = layout.view(p)
    expect(v.layout).to_be(nil)
    expect(p.home).to_be(nil)
    layout.ensure(p)
    expect(layout.view(p)).to_be(p.home)
  end)

  it("house and body follow a visiting guest", function()
    local st = {}
    game.init(st, { seed = 42, players = 2 })
    local host, guest = st.players[1], st.players[2]
    guest.visiting = host.index
    guest.vbody = avatar.new(layout.base(), { 0, 0.6, 0 }, 0)
    expect(layout.house(st, guest)).to_be(host)
    expect(layout.body(guest)).to_be(guest.vbody)
    expect(layout.house(st, host)).to_be(host)
  end)

  it("rev bumps after a move, record lists it, and piece misses unknown ids", function()
    local st = new_state()
    local p = st.players[1]
    expect(layout.rev(p)).to_be(0)
    expect(layout.record(p)).to_be(nil)
    expect(layout.piece(layout.base(), "no_such")).to_be(nil)
    expect(layout.home_pose("no_such")).to_be(nil)
    local sofa = layout.home_pose("sofa")
    layout.set_move(p, "sofa", { deck = 1, x = sofa.x, z = sofa.z + 0.5, turn = 0, w = sofa.w, d = sofa.d })
    expect(layout.rev(p) > 0).to_be(true)
    expect(layout.record(p).sofa).to_be_truthy()
    expect(layout.movable(layout.piece(layout.base(), "sofa"))).to_be(true)
    expect(layout.movable({ kind = "wall" })).to_be(false)
  end)

  it("size_of and centre work on a circle, yaw and quarter_to_turn convert", function()
    local c = { circle = { 2, 3, 0.5 } }
    local w, d = layout.size_of(c)
    expect(w).to_be(1)
    expect(d).to_be(1)
    local cx, cz = layout.centre(c)
    expect(cx).to_be(2)
    expect(cz).to_be(3)
    expect(math.abs(layout.yaw(6) - math.pi / 2) < 1e-6).to_be(true)
    expect(layout.quarter_to_turn(1)).to_be(6)
    expect(layout.quarter_to_turn(4)).to_be(0)
  end)

  it("preview on top of an existing move keeps the earlier piece", function()
    local st = new_state()
    local p = st.players[1]
    local sofa = layout.home_pose("sofa")
    local stool = layout.home_pose("stool_a")
    layout.set_move(p, "sofa", { deck = 1, x = sofa.x + 0.8, z = sofa.z, turn = 0, w = sofa.w, d = sofa.d })
    local L = layout.preview(p, "stool_a", { deck = 1, x = stool.x, z = stool.z + 1, turn = 0, w = stool.w, d = stool.d })
    local scx = layout.centre(layout.piece(L, "sofa"))
    expect(math.abs(scx - (sofa.x + 0.8)) < 1e-6).to_be(true)
    local _, tcz = layout.centre(layout.piece(L, "stool_a"))
    expect(math.abs(tcz - (stool.z + 1)) < 1e-6).to_be(true)
    -- preview did not add the stool to the saved layout
    expect(layout.piece(layout.of(p), "stool_a").moved).to_be(nil)
  end)

  it("the sofa seat follows a moved sofa; other seats stay put", function()
    local st = new_state()
    local p = st.players[1]
    local home = layout.seat(p, "sofa")
    expect(home).to_be_truthy()
    expect(layout.seat(p, "no_such")).to_be(nil)
    layout.set_move(p, "sofa", { deck = 1, x = -5.2, z = 0.8, turn = 6, w = 2, d = 0.9 })
    local s = layout.seat(p, "sofa")
    expect(s ~= home).to_be(true)
    expect(math.abs(s.eye[1] - (home.eye[1] + (-5.2 - (-7.5)))) < 0.05).to_be(true)
  end)
end)
