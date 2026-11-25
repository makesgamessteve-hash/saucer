-- SPDX-License-Identifier: MIT
-- add-alien-cities-2 (plan phase 10 part 2, design civs-and-relics §4.2, §4.4): the megacity round a city's core.
-- Outer districts of civ-shaped megaforms fill a ~21 km footprint; only the districts near a ship are solid (built
-- there and then if the view has not built them yet), and the view draws them by distance: full meshes with lit
-- windows near, silhouettes far, a horizon band beyond. Every `it` name is a scenario of the change's spec.
local game = require("sim.game")
local sector = require("sim.sector")
local civs = require("sim.civs")
local ruinm = require("sim.ruin")
local citygen = require("sim.citygen")
local mega = require("sim.citymega")
local megav = require("view.citymega")
local render = require("view.render")

local BODY_SECTOR = { planet = 3, moon = 4, asteroid = 2 }
local function cmd(t) return saucer.input.command(t or {}) end
local function run(st, n, c)
  for _ = 1, n or 1 do
    local f = {}
    for i = 1, #st.players do f[i] = cmd(c) end
    game.step(st, f, 1 / 60)
  end
end
local function in_city(body, players)
  local st = {}
  game.init(st, { seed = 42, players = players or 1 })
  game.enter_sector(st, BODY_SECTOR[body])
  for i, s in ipairs(st.sector.sites) do
    if s.city then return st, i, game.ruin(i), game.mega_plan(st, i) end
  end
end
local function hover_over(p, d) return { (d.box[1] + d.box[3]) / 2, p.frame.y + d.top + 120, (d.box[2] + d.box[4]) / 2 } end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function fake_view()
  local v = { calls = {}, meshes = {} }
  function v:mesh(id, o) self.calls.mesh = (self.calls.mesh or 0) + 1 self.meshes[#self.meshes + 1] = id end
  function v:billboard() end
  return v
end
local A = { pal = { base = 1 }, tex = { glow = 1, hull = 1 } }

describe("megacity", function()
  it("a city's core is ringed by outer districts, 24 to 48 districts in all", function()
    for _, body in ipairs({ "planet", "moon", "asteroid" }) do
      local st, i, r, p = in_city(body)
      local total = #r.city.districts + #p.districts
      expect(total >= 24 and total <= mega.DISTRICTS).to_be(true)
      expect(p.span >= 15000).to_be(true)
      -- the same plan from the same seed, and every district its own value from the city's builders
      local again = mega.plan(r, st.sector, i)
      expect(#again.districts > 0).to_be(true)
      local fr = p.frame
      for _, d in ipairs(p.districts) do
        expect(d.id > mega.BASE_ID).to_be(true)
        expect(d.archetype).to_be(citygen.ARCHETYPES[d.value].label)
        -- clear of the core
        local b = d.box
        local core = { fr.origin[1], fr.origin[3], fr.origin[1] + fr.ext[1], fr.origin[3] + fr.ext[3] }
        expect(b[3] <= core[1] or b[1] >= core[3] or b[4] <= core[2] or b[2] >= core[4]).to_be(true)
        -- clear of every other site, every station and the arrival point
        for _, o in ipairs(mega.obstacles(st.sector, i)) do
          expect(mega.rect_dist(b, o[1], o[2]) >= o[3]).to_be(true)
        end
      end
    end
  end)

  it("outer districts stand civ-shaped megaforms between canyon avenues, one city form up to 2.8 km", function()
    local st, i, r, p = in_city("planet")
    local mf, tall = 0, 0
    for _, d in ipairs(p.districts) do
      local b = d.box
      expect(#d.organs > 0).to_be(true)
      for _, o in ipairs(d.organs) do
        expect(o.x0 >= b[1] and o.z0 >= b[2] and o.x0 + o.w <= b[3] + 1e-6 and o.z0 + o.w2 <= b[4] + 1e-6).to_be(true)
        if o.megaform then
          mf = mf + 1
          expect(o.h >= mega.MEGAFORM_H[1] and o.h <= mega.MEGAFORM_H[2]).to_be(true)
        else
          expect(o.h >= mega.ORGAN_H[1] and o.h <= mega.CROWN_H[2]).to_be(true)
          if o.h > mega.ORGAN_H[2] then tall = tall + 1 end
        end
      end
      -- what you see is what you hit: every solid inside the block, from the foundation to the top
      local sol = mega.build(d)
      for _, s in ipairs(sol) do
        expect(s[1][1] >= b[1] - 1e-6 and s[2][1] <= b[3] + 1e-6 and s[1][3] >= b[2] - 1e-6 and s[2][3] <= b[4] + 1e-6).to_be(true)
        expect(s[2][2] <= p.frame.y + d.top + 1e-6 and s[1][2] >= p.frame.y - 40).to_be(true)
      end
      expect(#sol).to_be_greater(#d.organs)
    end
    expect(mf).to_be(1)
    expect(tall).to_be_greater(0)
    -- canyons: neighbouring blocks never touch
    for a = 1, #p.districts do
      for b2 = a + 1, #p.districts do
        local x, y = p.districts[a].box, p.districts[b2].box
        local apart = x[3] + mega.AVENUE[1] / 2 <= y[1] + 1e-6 or y[3] + mega.AVENUE[1] / 2 <= x[1] + 1e-6
          or x[4] + mega.AVENUE[1] / 2 <= y[2] + 1e-6 or y[4] + mega.AVENUE[1] / 2 <= x[2] + 1e-6
        expect(apart).to_be(true)
      end
    end
    -- strata decks join two megaforms of a row
    local decks = 0
    for _, d in ipairs(p.districts) do decks = decks + #d.decks end
    expect(decks).to_be_greater(0)
  end)

  it("only the districts near a ship are solid, built there and then if need be", function()
    local st, i, r, p = in_city("planet")
    local d = p.districts[1]
    mega.clear_cache()
    local before = mega.stats.sync_built
    st.players[1].ship.pos = hover_over(p, d)
    run(st, 1)
    expect(mega.live(i)[1] ~= nil).to_be(true)
    expect(mega.stats.sync_built).to_be_greater(before)
    -- a megaform is solid: no room for a ship inside it
    local o = d.organs[1]
    expect(saucer.physics.clearance({ o.x0 + o.w / 2, p.frame.y + 20, o.z0 + o.w2 / 2 }, 4, 4)).to_be(false)
    local n = count(mega.live(i))
    expect(n >= 1 and n <= mega.PER_PLAYER).to_be(true)
    -- fly far off: the district goes, and its boxes leave the physics list
    local live_count = saucer.physics.count()
    st.players[1].ship.pos = { p.frame.cx, p.frame.y + 400, p.frame.cz }
    run(st, 1)
    expect(count(mega.live(i))).to_be(0)
    expect(saucer.physics.count() < live_count).to_be(true)
    expect(saucer.physics.clearance({ o.x0 + o.w / 2, p.frame.y + 20, o.z0 + o.w2 / 2 }, 4, 4)).to_be(true)
  end)

  it("at most nine districts per player and sixteen in all are solid, nearest first", function()
    local st, i, r, p = in_city("planet")
    -- a wide reach so every district is in it
    local keep = mega.ACTIVE
    mega.ACTIVE = 1e6
    local one = mega.wanted(p, { { p.frame.cx, p.frame.y, p.frame.cz } })
    expect(#one).to_be(mega.PER_PLAYER)
    local pts = {}
    for k = 1, 4 do
      local d = p.districts[(k * 7) % #p.districts + 1]
      pts[k] = hover_over(p, d)
    end
    local all = mega.wanted(p, pts)
    expect(#all).to_be(mega.MAX_ACTIVE)
    for n = 2, #all do expect(all[n] > all[n - 1]).to_be(true) end
    mega.ACTIVE = keep
    -- nobody near: nothing
    expect(#mega.wanted(p, { { 1e7, 0, 1e7 } })).to_be(0)
    -- a district stays while the ship is between ACTIVE and KEEP of it
    local d = p.districts[1]
    local edge = { d.box[3] + (mega.ACTIVE + mega.KEEP) / 2, p.frame.y + 10, (d.box[2] + d.box[4]) / 2 }
    local function has(list) for _, k in ipairs(list) do if k == 1 then return true end end return false end
    expect(has(mega.wanted(p, { edge }))).to_be(false)
    expect(has(mega.wanted(p, { edge }, { [1] = { 1 } }))).to_be(true)
    -- under the street or far over the tops counts as away
    expect(#mega.wanted(p, { { (d.box[1] + d.box[3]) / 2, p.frame.y - 60 - mega.KEEP - 10, (d.box[2] + d.box[4]) / 2 } })).to_be(0)
  end)

  it("streaming districts in and out keeps the game deterministic across save and restore", function()
    local st0, i, r, p = in_city("planet")
    local d = p.districts[2]
    local o
    for _, x in ipairs(d.organs) do if x.gx == 1 and not o then o = x end end
    local R = require("sim.config").get(st0.players[1].ship.size).diameter / 2
    local function start()
      local s2 = in_city("planet")
      local ship = s2.players[1].ship
      ship.pos = { o.x0 - R - 30, p.frame.y + 20, o.z0 + o.w2 / 2 }
      ship.yaw, ship.pitch = math.pi / 2, 0
      s2.players[1].mode, s2.players[1].panel = "helm", false
      expect(saucer.physics.clearance(ship.pos, R, 3)).to_be(true)
      return s2
    end
    local fwd = { axes = { move_z = 1 } }
    -- straight at a megaform's face: it stops the ship
    local a = start()
    for _ = 1, 240 do run(a, 1, fwd) end
    expect(a.players[1].ship.pos[1] + R <= o.x0 + 0.5).to_be(true)
    expect(a.players[1].ship.pos[1] > o.x0 - R - 30 + 1).to_be(true)
    local live_a = count(mega.live(i))
    -- the same flight with a restore half way (the physics world is rebuilt from the state): the same end
    local b = start()
    for _ = 1, 120 do run(b, 1, fwd) end
    game.rebuild(b)
    expect(count(mega.live(i))).to_be_greater(0)
    for _ = 1, 120 do run(b, 1, fwd) end
    expect(count(mega.live(i))).to_be(live_a)
    for k = 1, 3 do expect(a.players[1].ship.pos[k]).to_be(b.players[1].ship.pos[k]) end
    for k = 1, 3 do expect(a.players[1].ship.vel[k]).to_be(b.players[1].ship.vel[k]) end
  end)

  it("the view draws full blocks and lit windows near, silhouettes far and a horizon band beyond", function()
    local st, i, r, p = in_city("planet")
    local d = p.districts[1]
    local cam = { pos = hover_over(p, d), yaw = 0, pitch = 0, far = 4000 }
    local vis = function() return true end
    local v = fake_view()
    local s = megav.draw(v, A, p, cam, 1, vis, 1000)
    expect(s.full).to_be_greater(0)
    expect(s.lights).to_be(1)
    expect(s.band).to_be(1)
    expect(s.sil).to_be_greater(0)
    expect(s.full + s.sil <= #p.districts).to_be(true)
    -- no budget: nothing full is built, the silhouettes stand in
    local p2 = mega.plan(r, st.sector, i)
    local v2 = fake_view()
    local s2 = megav.draw(v2, A, p2, cam, 1, vis, -1)
    expect(s2.full).to_be(0)
    expect(s2.built).to_be(1)
    -- culled districts are not drawn
    local s3 = megav.draw(fake_view(), A, p, cam, 1, function() return false end, 1000)
    expect(s3.full + s3.sil).to_be(0)
    expect(s3.culled).to_be_greater(0)
    -- far away: the full meshes and the lights are freed
    local far = { pos = { p.frame.cx + 1e5, p.frame.y, p.frame.cz }, yaw = 0, pitch = 0 }
    local s4 = megav.draw(fake_view(), A, p, far, 1, vis, 1000)
    expect(s4.freed).to_be_greater(0)
    expect(s4.full + s4.sil).to_be(0)
    expect(count(megav.cache(p).full)).to_be(0)
    -- the far plane reaches the band over a megacity, not elsewhere
    expect(megav.far_plane({ pos = cam.pos, far = 4000 }, function() return true end).far).to_be(megav.FAR_PLANE)
    expect(megav.far_plane({ pos = cam.pos, far = 4000 }, function() return nil end).far).to_be(4000)
    expect(#megav.band_parts(p)).to_be_greater(megav.BAND_N - 1)
    expect(#megav.light_parts(p, d)).to_be_greater(10)
  end)

  it("over an outer district the city's air and light hold, and the frame draws the megacity", function()
    local st, i, r, p = in_city("planet")
    local pl = st.players[1]
    pl.site = 0
    pl.ship.pos = hover_over(p, p.districts[1])
    expect(render.city_env(st, pl) ~= nil).to_be(true)
    pl.ship.pos = { 1e6, 0, 1e6 }
    expect(render.city_env(st, pl)).to_be(nil)
    expect(game.mega_city_at(st, pl.ship.pos, 0)).to_be(nil)
    -- a whole frame over the outer ring: the megacity is drawn
    pl.ship.pos = hover_over(p, p.districts[1])
    local stats = render.draw_ruins(fake_view(), A, st, { pos = pl.ship.pos, yaw = 0, pitch = 0 }, false)
    expect(stats.mega ~= nil).to_be(true)
    expect(game.mega_plan(st, 1 + (i % #st.sector.sites))).to_be(nil)
  end)

  it("the wall clock is for the view's budget and the physics list sheds removed tail boxes", function()
    local t0 = saucer.time.wall_ms()
    expect(type(t0)).to_be("number")
    expect(saucer.time.wall_ms() >= t0).to_be(true)
    local n = saucer.physics.count()
    local a = saucer.physics.add_box({ 9e5, 0, 9e5 }, { 9e5 + 1, 1, 9e5 + 1 })
    local b = saucer.physics.add_box({ 9e5, 0, 9e5 }, { 9e5 + 1, 1, 9e5 + 1 })
    expect(saucer.physics.count()).to_be(n + 2)
    saucer.physics.remove(a)
    expect(saucer.physics.count()).to_be(n + 2)
    saucer.physics.remove(b)
    expect(saucer.physics.count()).to_be(n)
  end)
end)
