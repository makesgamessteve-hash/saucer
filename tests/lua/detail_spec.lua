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

describe("derelict detail", function()
  local detail = require("view.detail")
  local ruinm = require("sim.ruin")
  local function sites(seed)
    local st = {}
    game.init(st, { seed = seed, players = 1 })
    local out = {}
    for i, s in ipairs(st.sector.sites) do
      local r = game.ruin(i)
      if r then out[#out + 1] = { ruin = r, origin = s.pos, kit = ruinm.kit_of(r.kit) } end
    end
    return out
  end
  local function same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
      local x, y = a[i], b[i]
      if x.kind ~= y.kind then return false end
      for _, key in ipairs({ "min", "max", "c", "pos", "color" }) do
        local u, v = x[key], y[key]
        if (u == nil) ~= (v == nil) then return false end
        if u then for j = 1, #u do if u[j] ~= v[j] then return false end end end
      end
    end
    return true
  end
  it("is deterministic per seed and differs between rooms", function()
    for _, seed in ipairs({ 42, 7 }) do
      for _, s in ipairs(sites(seed)) do
        for _, r in ipairs(s.ruin.rooms) do
          local a = detail.room(s.ruin, r, s.kit, s.origin)
          local b = detail.room(s.ruin, r, s.kit, s.origin)
          expect(same(a, b)).to_be(true)
        end
        for i, so in ipairs(s.ruin.solids or {}) do
          expect(same(detail.solid(s.ruin, so, i, s.kit, s.origin), detail.solid(s.ruin, so, i, s.kit, s.origin))).to_be(true)
        end
        expect(same(detail.links(s.ruin, s.kit), detail.links(s.ruin, s.kit))).to_be(true)
      end
    end
    local s = sites(42)[1]
    local big = {}
    for _, r in ipairs(s.ruin.rooms) do if r.class >= 4 then big[#big + 1] = r end end
    expect(same(detail.room(s.ruin, big[1], s.kit, s.origin), detail.room(s.ruin, big[2], s.kit, s.origin))).to_be(false)
  end)
  it("stays within the part budgets and gives every kit real detail", function()
    local kinds = {}
    for _, seed in ipairs({ 42, 7, 3 }) do
      for _, s in ipairs(sites(seed)) do
        local total = 0
        for _, r in ipairs(s.ruin.rooms) do
          local parts = detail.room(s.ruin, r, s.kit, s.origin)
          expect(#parts <= detail.budget_of(r, s.kit)).to_be(true)
          total = total + #parts
        end
        for i, so in ipairs(s.ruin.solids or {}) do
          expect(#detail.solid(s.ruin, so, i, s.kit, s.origin) <= detail.BUDGET.solid).to_be(true)
        end
        expect(#detail.links(s.ruin, s.kit) <= detail.BUDGET.links).to_be(true)
        expect(total).to_be_greater(400)
        kinds[s.kit.id] = true
      end
    end
    expect(kinds.starship and kinds.station and kinds.city).to_be(true)
    local sk = detail.sink(2)
    expect(sk.box({ 0, 0, 0 }, { 1, 1, 1 })).to_be(true)
    sk.box({ 0, 0, 0 }, { 1, 1, 1 })
    expect(sk.box({ 0, 0, 0 }, { 1, 1, 1 })).to_be(false)
    expect(sk.dropped).to_be(1)
    expect(sk.full()).to_be(true)
  end)
  it("keeps axis-aligned detail near its room and out of doorways and loot slots", function()
    for _, s in ipairs(sites(42)) do
      for _, r in ipairs(s.ruin.rooms) do
        local mn, mx = ruinm.room_box(r, s.kit, s.origin)
        local c = detail.context(s.ruin, r, s.kit, s.origin)
        for _, p in ipairs(detail.room(s.ruin, r, s.kit, s.origin)) do
          if p.min and not p.pos then
            for a = 1, 3 do
              expect(p.min[a] >= mn[a] - 2.5).to_be(true)
              expect(p.max[a] <= mx[a] + 2.5).to_be(true)
            end
          end
        end
        for _, sl in ipairs(s.ruin.slots or {}) do
          if sl.room == r.id then
            expect(detail.clear(c, sl.pos, sl.pos)).to_be(false)
          end
        end
      end
    end
  end)
  it("leaves the sim alone: generating detail never touches the ruin", function()
    for _, s in ipairs(sites(42)) do
      local before = kit.copy(s.ruin)
      for _, r in ipairs(s.ruin.rooms) do detail.room(s.ruin, r, s.kit, s.origin) end
      for i, so in ipairs(s.ruin.solids or {}) do detail.solid(s.ruin, so, i, s.kit, s.origin) end
      detail.links(s.ruin, s.kit)
      expect(s.ruin).to_equal(before)
    end
  end)
  it("styles kits, finds exposed faces and hanging towers", function()
    local s = sites(42)
    local st = detail.style({ id = "nope", detail = { torn = 99 } })
    expect(st.torn).to_be(99)
    expect(st.metal ~= nil).to_be(true)
    local exposed, closed = 0, 0
    for _, x in ipairs(s) do
      for _, r in ipairs(x.ruin.rooms) do
        local c = detail.context(x.ruin, r, x.kit, x.origin)
        for _, f in ipairs({ { 1, -1 }, { 1, 1 }, { 3, -1 }, { 3, 1 } }) do
          if detail.exposed(c, f) then exposed = exposed + 1 else closed = closed + 1 end
        end
      end
    end
    expect(exposed).to_be_greater(0)
    expect(closed).to_be_greater(0)
    local city = s[3]
    local hang, stand = 0, 0
    for _, so in ipairs(city.ruin.solids) do
      if detail.hanging(city.ruin, so, city.kit, city.origin) then hang = hang + 1 else stand = stand + 1 end
    end
    expect(hang + stand).to_be(#city.ruin.solids)
    expect(detail.hanging(city.ruin, { { 0, 0, 0 }, { 1, 1, 1 } }, city.kit, nil)).to_be(false)
    -- every prop builder works on its own
    local c = detail.context(s[1].ruin, s[1].ruin.rooms[1], s[1].kit, s[1].origin)
    for name, fn in pairs(detail.PROPS) do
      local before = #c.out.parts
      fn(c, 0, 0, 0, 1)
      expect(#c.out.parts).to_be_greater(before)
      expect(type(name)).to_be("string")
    end
    local t = detail.tube({ 0, 0, 0 }, { 0, 0, 4 }, 0.2, { 1, 1, 1 })
    expect(t.h).to_be(4)
    expect(detail.bar({ 0, 0, 0 }, { 3, 0, 0 }, 0.2, { 1, 1, 1 }).max[2]).to_be(3)
  end)
end)

describe("detail rendering", function()
  it("draws detail near the camera, builds a few per frame, and uses kit textures", function()
    local A = assets.init()
    local st = new_state()
    local p = st.players[1]
    local r1 = game.ruin(1)
    local ruinm = require("sim.ruin")
    p.ship.pos = ruinm.entrance(r1, st.sector.sites[1].pos)
    local cam = render.camera(p, false)
    for _, ch in ipairs(assets.ruin_chunks(r1, st.sector.sites[1].pos).chunks) do ch.detail = nil end
    local saved = render.DETAIL_BUILDS
    render.DETAIL_BUILDS = 1
    local s1 = render.draw_ruins(fake_view(), A, st, cam, true)
    expect(s1.built).to_be(1)
    render.DETAIL_BUILDS = 1000
    local s2 = render.draw_ruins(fake_view(), A, st, cam, true)
    expect(s2.detail).to_be_greater(1)
    render.DETAIL_BUILDS = saved
    local set = assets.ruin_chunks(r1, st.sector.sites[1].pos)
    expect(assets.kit_texture(A, set.kit)).to_be(A.tex.kit_starship)
    expect(assets.kit_texture(A, nil)).to_be(A.tex.hull)
    -- the city also gets a sky-bridge chunk
    local c3 = assets.ruin_chunks(game.ruin(3), st.sector.sites[3].pos)
    expect(c3.links ~= nil).to_be(true)
    expect(assets.chunk_detail(c3, c3.links) ~= nil).to_be(true)
    -- empty detail builds no mesh
    local fake = { ruin = { solids = { { { 0, 0, 0 }, { 1, 1, 1 }, kind = "none" } }, seed = 1, rooms = {} }, kit = set.kit }
    local saved_budget = require("view.detail").BUDGET.solid
    require("view.detail").BUDGET.solid = 0
    expect(assets.chunk_detail(fake, { solid = 1 })).to_be(false)
    require("view.detail").BUDGET.solid = saved_budget
  end)
end)
