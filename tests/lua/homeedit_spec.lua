-- SPDX-License-Identifier: MIT
-- add-home-layout: edit mode, placement rules, undo, guest home-life and
-- host-only ship systems.
local game = require("sim.game")
local layout = require("sim.layout")
local homeedit = require("sim.homeedit")
local avatar = require("sim.avatar")
local decor = require("sim.decor")
local kitchen = require("sim.kitchen")
local home = require("sim.home")
local save = require("sim.save")
local coop = require("sim.coop")

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  return st
end
local function run(st, c, n)
  for _ = 1, n or 1 do
    local cs = {}
    for i = 1, #st.players do cs[i] = c or cmd() end
    game.step(st, cs, 1 / 60)
  end
end
local function ctx()
  return { msg = function() end, fx = function() end }
end
local function wake(st)
  for _, p in ipairs(st.players) do
    p.mode, p.panel = "walk", false
  end
end
local function stand(p, node, yaw)
  local L = layout.of(p)
  p.mode, p.panel = "walk", false
  p.body = avatar.new(L, L.nav.nodes[node], yaw or 0)
end

describe("edit mode", function()
  it("enters and leaves from the decks, not the helm", function()
    local st = new_state()
    local p = st.players[1]
    wake(st)
    stand(p, "helm")
    expect(homeedit.can_start(st, p)).to_be(true)
    expect(homeedit.enter(st, p, ctx())).to_be(true)
    expect(homeedit.on(p)).to_be(true)
    homeedit.leave(st, p, ctx(), true)
    expect(homeedit.on(p)).to_be(false)
    p.mode = "helm"
    local ok, why = homeedit.can_start(st, p)
    expect(ok).to_be(false)
    expect(why:find("helm", 1, true) ~= nil).to_be(true)
  end)

  it("picks a stool, places it a metre away, and undo puts it back", function()
    local st = new_state()
    local p = st.players[1]
    wake(st)
    stand(p, "kitchen")
    -- stand next to stool_a
    local pose = layout.home_pose("stool_a")
    p.body = avatar.new(layout.base(), { pose.x + 0.8, 0.6, pose.z }, 0)
    homeedit.enter(st, p, ctx())
    local t = homeedit.nearest(st, p)
    expect(t and t.typ == "builtin" and t.id == "stool_a").to_be(true)
    homeedit.pick_now(st, p, ctx(), t)
    expect(homeedit.holding(p).id).to_be("stool_a")
    -- the built-in is still in the world until placed
    expect(layout.has_moves(p)).to_be(false)
    local ok = homeedit.place_now(st, p, ctx(), 1, pose.x, pose.z + 1.5, 0)
    expect(ok).to_be(true)
    expect(homeedit.holding(p)).to_be(nil)
    expect(layout.has_moves(p)).to_be(true)
    local cx, cz = layout.centre(layout.piece(layout.of(p), "stool_a"))
    expect(math.abs(cz - (pose.z + 1.5)) < 1e-6).to_be(true)
    expect(homeedit.undo(st, p, ctx())).to_be(true)
    expect(layout.has_moves(p)).to_be(false)
    local cx2, cz2 = layout.centre(layout.piece(layout.of(p), "stool_a"))
    expect(math.abs(cx2 - pose.x) < 1e-6).to_be(true)
  end)

  it("refuses a placement that blocks the bedroom door", function()
    local st = new_state()
    local p = st.players[1]
    wake(st)
    stand(p, "bed")
    homeedit.enter(st, p, ctx())
    local pose = layout.home_pose("nightstand")
    p.body = avatar.new(layout.base(), { pose.x, -3.0, pose.z + 0.8 }, 0)
    homeedit.pick_now(st, p, ctx(), { typ = "builtin", id = "nightstand" })
    local ok, why = homeedit.can_place(st, p, homeedit.def_of(homeedit.holding(p)), 2, 2.7, 0.8, 0, { builtin = "nightstand" })
    expect(ok).to_be(false)
    expect(why).to_be_truthy()
  end)

  it("a bought piece goes into the host store when picked up", function()
    local st = new_state()
    local p = st.players[1]
    wake(st)
    stand(p, "planner")
    local D = decor.ensure(p)
    D.store.lamp = 1
    -- place it instantly in front, then pick it up in edit mode
    expect(decor.place(st, p, "lamp")).to_be(true)
    expect(#D.placed).to_be(1)
    local lamp = D.placed[1]
    p.body = avatar.new(layout.base(), { lamp.x, 0.6, lamp.z }, 0)
    homeedit.enter(st, p, ctx())
    homeedit.pick_now(st, p, ctx(), { typ = "placed", id = lamp.id })
    expect(#D.placed).to_be(0)
    expect(homeedit.holding(p).typ).to_be("placed")
    expect(homeedit.pack(st, p, ctx())).to_be(true)
    expect((D.store.lamp or 0) >= 1).to_be(true)
    expect(homeedit.holding(p)).to_be(nil)
    expect(#D.placed).to_be(0)
  end)

  it("stow_for_save puts a carry back and drops p.edit", function()
    local st = new_state()
    local p = st.players[1]
    wake(st)
    local pose = layout.home_pose("stool_b")
    p.body = avatar.new(layout.base(), { pose.x + 0.8, 0.6, pose.z }, 0)
    homeedit.enter(st, p, ctx())
    homeedit.pick_now(st, p, ctx(), { typ = "builtin", id = "stool_b" })
    expect(homeedit.holding(p)).to_be_truthy()
    homeedit.stow_for_save(st, p)
    expect(p.edit).to_be(nil)
    expect(layout.has_moves(p)).to_be(false)
  end)

  it("p.edit is not saved", function()
    expect(save.SKIP.edit).to_be(true)
  end)

  it("the P key toggles edit mode through the game loop", function()
    local st = new_state()
    local p = st.players[1]
    wake(st)
    stand(p, "helm")
    run(st, cmd({ pressed = { "edit" } }))
    expect(homeedit.on(p)).to_be(true)
    run(st, cmd({ pressed = { "edit" } }))
    expect(homeedit.on(p)).to_be(false)
  end)
end)

describe("guest home-life", function()
  it("guests may cook and use the planner, but not the lab or the bed", function()
    expect(homeedit.guest_may("kitchen")).to_be(true)
    expect(homeedit.guest_may("planner")).to_be(true)
    expect(homeedit.guest_may("garden")).to_be(true)
    expect(homeedit.guest_may("tv")).to_be(true)
    expect(homeedit.guest_may("lab")).to_be(false)
    expect(homeedit.guest_may("trade")).to_be(false)
    expect(homeedit.guest_may("hatch")).to_be(false)
    expect(homeedit.guest_may("tractor")).to_be(false)
    expect(homeedit.guest_may("bed")).to_be(false)
  end)

  it("a guest cooks from the host pantry and both get the meal", function()
    local st = new_state(2)
    wake(st)
    local host, guest = st.players[1], st.players[2]
    -- pretend the guest is visiting without a real dock (house() looks at visiting)
    guest.visiting = host.index
    guest.vbody = avatar.new(layout.base(), layout.base().nav.nodes.kitchen, 0)
    kitchen.ensure(host)
    expect(kitchen.start(st, guest, "snack", ctx())).to_be(true)
    guest.cooking.left = 0
    kitchen.step(st, guest, 0.02, ctx())
    expect(guest.meals).to_be(1)
    expect(guest.buffs and guest.buffs.fed).to_be_truthy()
    expect(host.buffs and host.buffs.fed).to_be_truthy()
  end)
end)
