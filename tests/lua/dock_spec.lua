-- SPDX-License-Identifier: MIT
-- add-dock-land-eva slice 2: the station's hangar bay and tractor beam (the
-- end-to-end dock is tests/game/dock.lua).
local game = require("sim.game")
local dock = require("sim.dock")
local landing = require("sim.landing")
local env = require("sim.env")
local excursion = require("sim.excursion")
local assets = require("view.assets")
local render = require("view.render")
local dockv = require("view.dock")
local hud = require("view.hud")
local vec = require("lib.vec")
local sm = saucer.math

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state()
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  return st
end
local function run(st, c, n)
  for _ = 1, n or 1 do game.step(st, { c or cmd() }, 1 / 60) end
end
local ctx = game.ctx
local function texts(p)
  local t = {}
  for _, m in ipairs(p.msgs) do t[#t + 1] = m.text end
  return table.concat(t, "|")
end
local function fake_view()
  local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = false }
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image" }) do
    v[m] = function(self) self.calls[m] = (self.calls[m] or 0) + 1 return 0 end
  end
  return v
end
local function at_mouth(st, dx, dy, dz)
  local p = st.players[1]
  local b = dock.bay(st, 1)
  p.mode, p.panel, p.site = "helm", false, 0
  p.ship.pos = { b.mouth[1] + dx, b.mouth[2] + dy, b.mouth[3] + dz }
  p.ship.vel = { 0, 0, 0 }
  return p, b
end

describe("the hangar bay", function()
  it("is a fixed cell off every station with a door in its back wall", function()
    local st = new_state()
    local b = dock.bay(st, 1)
    expect(b.rest[2] - b.floor).to_be_near(landing.tune().leg_len, 1e-9)
    expect(b.hi[1] > b.pad[1] and b.pad[1] > b.lo[1]).to_be(true)
    expect(b.mouth[1] > b.hi[1]).to_be(true)
    local boxes = dock.solids(st)
    expect(#boxes).to_be(11 * dock.count(st))
    -- the physics world has them: the ground under the pad is the bay's floor
    local g = landing.ground(b.pad[1], b.pad[2] + 5, b.pad[3])
    expect(g).to_be_near(b.floor, 1e-6)
    -- a person (or a pocketed saucer) in the cell breathes its air; outside it is vacuum
    local p = st.players[1]
    p.mode, p.site = "helm", 0
    p.ship.pos = vec.copy(b.rest)
    expect(env.at(st, p).breathable).to_be(true)
    p.ship.pos = { b.mouth[1] + 200, b.mouth[2], b.mouth[3] }
    expect(env.at(st, p).breathable).to_be(false)
    expect(dock.inside(st, b.rest)).to_be(1)
    expect(dock.inside(st, p.ship.pos)).to_be(nil)
  end)
  it("tows along a curve that starts where you are and ends over the pad", function()
    local st = new_state()
    local p, b = at_mouth(st, 40, 5, 30)
    expect(dock.start(st, p, 1, ctx)).to_be(true)
    local bb = p.berth
    local pos0, yaw0 = dock.guide_pose(bb, 0)
    expect(vec.dist(pos0, p.ship.pos)).to_be_near(0, 1e-9)
    expect(yaw0).to_be_near(sm.wrap(p.ship.yaw), 1e-9)
    local posm = dock.guide_pose(bb, bb.path.split)
    expect(vec.dist(posm, b.mouth) < 20).to_be(true)
    local pos1, yaw1 = dock.guide_pose(bb, 1)
    expect(vec.dist(pos1, bb.path.hover)).to_be_near(0, 1e-9)
    expect(yaw1).to_be_near(sm.wrap(b.yaw), 1e-6)
    expect(bb.total >= dock.tune().guide_min and bb.total <= dock.tune().guide_max).to_be(true)
  end)
end)

describe("the tractor beam", function()
  it("takes over only when slow, close, in front of the bay and the pad is clear", function()
    local st = new_state()
    local p = at_mouth(st, 40, 5, 30)
    expect(dock.can_capture(st, p)).to_be(1)
    p.ship.pos[1] = p.ship.pos[1] + 200
    expect(dock.can_capture(st, p)).to_be(nil)           -- too far
    p = at_mouth(st, 40, 5, 30)
    p.ship.vel = { dock.tune().capture_speed + 5, 0, 0 }
    expect(dock.can_capture(st, p)).to_be(nil)           -- too fast
    p = at_mouth(st, -60, 0, 0)
    expect(dock.can_capture(st, p)).to_be(nil)           -- behind the station
    p = at_mouth(st, 40, 5, 30)
    p.ship.size = 2
    expect(dock.can_capture(st, p)).to_be(nil)           -- only the Villa
    p.ship.size = 1
    p.site = 3
    expect(dock.can_capture(st, p)).to_be(nil)           -- not inside a derelict
    p.site = 0
    p.mode = "walk"
    expect(dock.can_capture(st, p)).to_be(nil)
  end)
  it("grabs on approach, towing the saucer in until it settles on the pad and the clamps close", function()
    local st = new_state()
    local p, b = at_mouth(st, 30, 0, 10)
    run(st)
    expect(p.berth and p.berth.phase == "guide" and p.berth.kind == "bay").to_be(true)
    expect(texts(p)).to_contain("TRACTOR BEAM")
    local w, h = dock.hint(st, p)
    expect(w).to_be("TRACTOR BEAM")
    expect(h).to_contain("PULL AWAY")
    local phases = {}
    for _ = 1, 60 * 40 do
      run(st)
      if p.berth then phases[p.berth.phase] = true end
      if p.berth and p.berth.phase == "landed" and p.berth.clamp >= 1 then break end
    end
    expect(phases.guide and phases.descend and phases.landed).to_be(true)
    expect(vec.dist(p.ship.pos, b.rest)).to_be_near(0, 1e-6)
    expect(p.berth.clamp).to_be(1)
    expect(select(1, dock.hint(st, p))).to_contain("DOCKED")
    expect(texts(p)).to_contain("clamps")
    -- lift off: the clamps open first, then the gear, then the beam carries it out
    run(st, cmd({ pressed = { "land" } }))
    expect(p.berth.phase).to_be("lift")
    expect(select(2, dock.hint(st, p))).to_contain("LIFTING")
    run(st, cmd(), 30)
    expect(p.berth.clamp < 1).to_be(true)
    expect(p.ship.pos[2]).to_be_near(b.rest[2], 1e-9)    -- not rising before the clamps are open
    local released = false
    for _ = 1, 60 * 20 do
      run(st)
      if p.berth and p.berth.phase == "release" then released = true end
      if not p.berth then break end
    end
    expect(released).to_be(true)
    expect(p.berth).to_be(false)
    expect(p.ship.pos[1] > b.hi[1] + 20).to_be(true)
    expect(p.dock_off).to_be(true)
    run(st, cmd(), 10)
    expect(p.berth).to_be(false)                         -- it does not grab you again at once
  end)
  it("lets go when you pull away, and again for the Land button, and waits until you are clear", function()
    local st = new_state()
    local p, b = at_mouth(st, 40, 5, 30)
    run(st)
    expect(p.berth.phase).to_be("guide")
    local away = { p.ship.pos[1] - b.mouth[1], p.ship.pos[3] - b.mouth[3] }
    p.ship.yaw = sm.atan2(away[1], away[2])
    run(st, cmd({ axes = { move_z = 1 } }), 70)
    expect(p.berth).to_be(false)
    expect(p.dock_off).to_be(true)
    expect(texts(p)).to_contain("pull away")
    -- still near: no new grab. Far away: the beam is armed again.
    run(st, cmd(), 5)
    expect(p.berth).to_be(false)
    p.ship.pos = { b.mouth[1] + 400, b.mouth[2], b.mouth[3] }
    run(st)
    expect(p.dock_off).to_be(false)
    -- thrust that is not pulling away only drains the hold timer
    p.ship.pos = { b.mouth[1] + 40, b.mouth[2] + 5, b.mouth[3] + 30 }
    p.ship.vel = { 0, 0, 0 }
    run(st)
    expect(p.berth.phase).to_be("guide")
    run(st, cmd({ axes = { move_z = 1 } }), 10)
    p.ship.yaw = sm.atan2(-away[1], -away[2])
    run(st, cmd({ axes = { move_z = 1 } }), 10)
    expect(p.berth.cancel < dock.tune().cancel_hold).to_be(true)
    -- and Land cancels the tow
    run(st, cmd({ pressed = { "land" } }))
    expect(p.berth).to_be(false)
    -- the Land button asks for a tow when it is near
    p.ship.pos = { b.mouth[1] + 40, b.mouth[2] + 5, b.mouth[3] + 30 }
    p.ship.vel = { 0, 0, 0 }
    p.dock_off = true
    local _, hint = dock.hint(st, p)
    expect(hint).to_contain("TOW")
    run(st, cmd({ pressed = { "land" } }))
    expect(p.berth.phase).to_be("guide")
    expect(texts(p)).to_contain("ask the station")
    -- cancel only applies to the guide and the settle, and to bays
    p.berth.phase = "release"
    expect(dock.cancel(st, p, ctx)).to_be(false)
    expect(landing.press(st, p, ctx)).to_be(false)
    p.berth = { phase = "guide", kind = "surface" }
    expect(dock.cancel(st, p, ctx)).to_be(false)
    p.berth = false
    expect(dock.cancel(st, p, ctx)).to_be(false)
    p.ship.pos = { b.mouth[1] + 900, b.mouth[2], b.mouth[3] }
    expect(dock.hint(st, p)).to_be(nil)
  end)
  it("tells the HUD what is going on at every stage", function()
    local st = new_state()
    local p, b = at_mouth(st, 40, 5, 30)
    p.berth = { phase = "descend", kind = "bay" }
    expect(select(1, dock.hint(st, p))).to_be("DOCK PAD")
    p.berth.kind = "surface"
    expect(select(1, dock.hint(st, p))).to_be("LANDING")
    p.berth.phase = "release"
    expect(select(2, dock.hint(st, p))).to_contain("OUT")
    p.berth.phase = "lift"
    expect(select(1, dock.hint(st, p))).to_be("LANDED")
    p.berth.kind = "bay"
    expect(select(1, dock.hint(st, p))).to_be("DOCK PAD")
    p.berth.phase = "landed"
    expect(select(1, dock.hint(st, p))).to_contain("DOCKED")
    p.berth.kind = "surface"
    expect(select(1, dock.hint(st, p))).to_contain("LANDED")
    -- the HUD line uses it, and falls back to the plain helm
    expect(hud.status(p, st)).to_contain("LANDED")
    p.berth = false
    p.dock_off = true
    expect(hud.status(p, st)).to_be("AT THE HELM")
    expect(hud.status(p)).to_be("AT THE HELM")
    p.dock_off = false
    expect(select(2, hud.status(p, st))).to_contain("TOW")
  end)
end)

describe("through the bay door", function()
  local function in_bay_foot(st, coin)
    local p, b = at_mouth(st, 0, 0, 0)
    p.ship.pos = vec.copy(b.rest)
    p.mode = "foot"
    p.excursion = { site = 0, t = 0, coin = coin, from = 1, hand_t = 0, held = false,
                    body = { pos = { b.lo[1] + 6, b.floor, b.door.z }, yaw = -sm.pi / 2, pitch = 0, vy = 0, crouch = false, ground = true },
                    path = {}, work = false, warned = 0, area = "hall", deploy = false }
    return p, b
  end
  it("walks into the station and back, keeping the saucer docked", function()
    local st = new_state()
    local p, b = in_bay_foot(st, "stand")
    p.berth = { phase = "landed", kind = "bay", bay = 1, clamp = 1, legs = 1, t = 0, ref = b.floor, feet = { b.floor, b.floor, b.floor },
                at = vec.copy(b.rest), yaw = b.yaw, site = 0 }
    expect(select(1, excursion.status(st, p))).to_be("ON FOOT: STATION BAY")
    p.excursion.body.pos = { b.lo[1] + 0.5, b.floor, b.door.z + 5 }
    expect(dock.door_step(st, p, ctx)).to_be(false)          -- beside the door, not through it
    p.excursion.body.pos = { b.lo[1] + 0.5, b.floor, b.door.z }
    p.ship.morph = { from = 1, total = 1 }
    p.excursion.coin = "fold"
    expect(dock.door_step(st, p, ctx)).to_be(false)          -- not while the saucer is reshaping
    p.ship.morph = false
    p.excursion.coin = "stand"
    expect(dock.door_step(st, p, ctx)).to_be(true)
    expect(p.station.coin).to_be("docked")
    expect(p.excursion).to_be(false)
    expect(p.berth.phase).to_be("landed")
    -- the station scene draws the Villa on its pad and the HUD names the coin
    local v = fake_view()
    render.render(v, st, 1)
    expect(v.calls.mesh).to_be_greater(10)
    expect(require("sim.visit").coin_text(p)).to_be("SAUCER: DOCKED IN THE BAY")
    -- the unfold keys do nothing for a docked Villa
    run(st, cmd({ pressed = { "size1" } }))
    expect(p.station.coin).to_be("docked")
    expect(texts(p)).to_contain("docked in the bay")
    -- walking back to the doorway returns you to the bay
    p.station.body.pos = { 0, 0, 1 }
    p.station.body.yaw = sm.pi
    run(st, cmd({ axes = { move_z = 1 } }), 30)
    expect(p.station).to_be(false)
    expect(p.excursion.coin).to_be("stand")
    expect(p.excursion.body.pos[1] < b.lo[1] + 4).to_be(true)
    expect(texts(p)).to_contain("Villa waits")
  end)
  it("carries a pocketed coin through and back, and refuses while things are reshaping", function()
    local st = new_state()
    local p, b = in_bay_foot(st, "pocket")
    p.ship.size = 3
    p.excursion.body.pos = { b.lo[1] + 0.5, b.floor, b.door.z }
    expect(dock.door_step(st, p, ctx)).to_be(true)
    expect(p.station.coin).to_be("pocket")
    local sp = p.station
    sp.body.pos = { 0, 0, 0.1 }
    sp.coin = "grow"
    expect(dock.station_door_step(st, p, ctx)).to_be(false)  -- not while it unfolds
    sp.coin = "thief"
    expect(dock.station_door_step(st, p, ctx)).to_be(false)
    sp.coin = "pocket"
    sp.body.pos = { 5, 0, 0.1 }
    expect(dock.station_door_step(st, p, ctx)).to_be(false)  -- off to the side of the doorway
    sp.body.pos = { 0, 0, 0.1 }
    expect(dock.station_door_step(st, p, ctx)).to_be(true)
    expect(p.excursion.coin).to_be("pocket")
    p.station = false
    expect(dock.station_door_step(st, p, ctx)).to_be(false)
    -- an ordinary station visit (no bay door) never takes you through it
    p.station = { coin = "pocket", body = { pos = { 0, 0, 0 } } }
    expect(dock.station_door_step(st, p, ctx)).to_be(false)
    p.station = false
    -- on foot outside the bay, or in a derelict: no door
    p.excursion.body.pos = { b.mouth[1] + 300, b.floor, b.door.z }
    expect(dock.door_step(st, p, ctx)).to_be(false)
    p.site = 4
    expect(dock.door_step(st, p, ctx)).to_be(false)
    p.excursion = false
    expect(dock.door_step(st, p, ctx)).to_be(false)
  end)
  it("says where the door is, and refuses a Villa unfold into a wall with the usual prompt", function()
    local st = new_state()
    local p, b = in_bay_foot(st, "pocket")
    p.ship.size = 3
    expect(select(2, excursion.status(st, p))).to_contain("DOOR")
    p.excursion.body.pos = { b.lo[1] + 3, b.floor, b.lo[3] + 6 }
    p.excursion.body.yaw = -sm.pi / 2
    p.suit = 100
    run(st, cmd({ pressed = { "size1" } }))
    expect(p.excursion.coin).to_be("pocket")
    expect(texts(p)).to_contain("No room")
  end)
end)

describe("drawing the bay", function()
  it("draws the cell, the beam on a towed saucer and the clamps, without touching the state", function()
    local st = new_state()
    local p, b = at_mouth(st, 30, 0, 10)
    local A = assets.init()
    local v = fake_view()
    local cam = { pos = vec.copy(b.pad) }
    local n0 = dockv.draw(v, A, st, cam)
    expect(n0).to_be_greater(30)
    run(st)
    expect(p.berth.phase).to_be("guide")
    local n1 = dockv.draw(v, A, st, cam)
    expect(n1).to_be(n0 + 4)                                 -- four beam rays
    expect(dockv.draw(v, A, st, { pos = { b.pad[1] + 5000, b.pad[2], b.pad[3] } })).to_be(0)
    p.berth.clamp = 0.5
    expect(dockv.clamps(v, A, p)).to_be(6)
    p.berth.kind = "surface"
    expect(dockv.clamps(v, A, p)).to_be(0)
    p.berth = false
    expect(dockv.clamps(v, A, p)).to_be(0)
    local w = fake_view()
    render.render(w, st, 1)
    expect(w.calls.mesh).to_be_greater(10)
  end)
end)
