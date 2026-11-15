-- SPDX-License-Identifier: MIT
-- Detail pass (OpenSpec add-detail-pass): saucer props and hull detail, and
-- the deterministic, budgeted derelict detail generators. All visual only.
local game = require("sim.game")
local render = require("view.render")
local assets = require("view.assets")
local kit = require("lib.meshkit")
local data = require("lib.data")
local avatar = require("sim.avatar")
local shipm = require("sim.ship")

local function fake_view()
  local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = false, meshes = {} }
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image" }) do
    v[m] = function(self, a, b)
      self.calls[m] = (self.calls[m] or 0) + 1
      if m == "mesh" then self.meshes[#self.meshes + 1] = { id = a, opts = b } end
      if m == "text" then return 8 end
    end
  end
  return v
end

local function new_state(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  for _, p in ipairs(st.players) do
    p.mode, p.panel = "walk", false
    p.body = avatar.new(avatar.layout(), { -2.0, 0.6, -1.0 }, 0)
  end
  return st
end

describe("saucer detail", function()
  it("gives every decor prop a builder and keeps props out of collision", function()
    local props = data.load("meshes/props.lua")
    local L = avatar.layout()
    local n = #L.furniture
    for _, d in ipairs(data.load("saucer/decor.lua")) do
      expect(props.BUILD[d.kind] ~= nil).to_be(true)
      local out = props.build({}, d, L.decks[d.deck].floor)
      expect(#out).to_be_greater(0)
    end
    expect(#props.build({}, { kind = "no_such_prop", at = { 0, 0 } }, 0)).to_be(0)
    expect(#avatar.layout().furniture).to_be(n)
  end)
  it("builds the detailed interior and hulls with stable hashes", function()
    for _, r in ipairs({ { "interior", { part = "rooms" } }, { "interior", { part = "group", group = "2:Engine room" } },
                         { "interior", { part = "group", group = "1:deck" } }, { "interior", { part = "group", group = "2:deck" } },
                         { "interior", { part = "group", group = "1:Stairs" } }, { "saucer", { config = "villa" } },
                         { "saucer", { config = "seat" } } }) do
      local id1, h1 = kit.build(r[1], r[2], 1)
      local id2, h2 = kit.build(r[1], r[2], 1)
      expect(h1).to_be(h2)
      expect(saucer.mesh.info(id1).triangles).to_be_greater(100)
      saucer.mesh.free(id1)
      saucer.mesh.free(id2)
    end
    local hull = kit.recipe("saucer", { config = "villa" }, 1)
    expect(#hull.parts).to_be_greater(150)
    expect(#data.load("meshes/saucer.lua").THRUSTERS.belly).to_be(4)
  end)
  it("animates the engine and lights the thrusters, render-side only", function()
    local A = assets.init()
    local st = new_state()
    local p = st.players[1]
    local d = render.pose(p.ship)
    local v = fake_view()
    expect(render.engine_parts(v, A, d, 100)).to_be(4)
    local yaw1 = v.meshes[1].opts.yaw
    local v2 = fake_view()
    render.engine_parts(v2, A, d, 160)
    expect(v2.meshes[1].opts.yaw ~= yaw1).to_be(true)
    expect(render.engine_parts(v, { }, d, 1)).to_be(0)
    local c = require("sim.config")
    p.ship.vel = { 0, 8, 20 }
    expect(render.thruster_glow(v, A, p, d, c.get(1))).to_be(6)
    expect(render.thruster_glow(v, A, p, d, c.get(2))).to_be(1)
    expect(render.thruster_glow(v, A, p, d, { id = "cruiser" })).to_be(0)
    expect(render.thruster_glow(v, { }, p, d, c.get(1))).to_be(0)
  end)
  it("drops a far saucer's rooms (LOD) but keeps its hull and glass", function()
    local st = new_state(2)
    st.players[2].ship.pos = { st.players[1].ship.pos[1] + 600, st.players[1].ship.pos[2], st.players[1].ship.pos[3] }
    local v = fake_view()
    render.render(v, st, 1)
    local far = v.calls.mesh
    st.players[2].ship.pos = { st.players[1].ship.pos[1] + 60, st.players[1].ship.pos[2], st.players[1].ship.pos[3] }
    local v2 = fake_view()
    render.render(v2, st, 1)
    expect(v2.calls.mesh).to_be_greater(far + 8)
  end)
end)
