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
      local c = d.cell
      local fx0, fx1 = math.huge, -math.huge
      for n = 1, sol.found do
        fx0, fx1 = math.min(fx0, sol[n][1][1]), math.max(fx1, sol[n][2][1])
        expect(sol[n][2][2]).to_be(p.frame.y)
      end
      expect(fx0 == c[1] and fx1 == c[3]).to_be(true)
      for n, s in ipairs(sol) do
        if n <= sol.found then goto next end
        expect(s[1][1] >= b[1] - 1e-6 and s[2][1] <= b[3] + 1e-6 and s[1][3] >= b[2] - 1e-6 and s[2][3] <= b[4] + 1e-6).to_be(true)
        expect(s[2][2] <= p.frame.y + d.top + 1e-6 and s[1][2] >= p.frame.y - 40 - mega.WARREN_H - mega.FLOOR).to_be(true)
        ::next::
      end
      expect(#sol).to_be_greater(#d.organs)
    end
    expect(mf).to_be(1)
    expect(tall).to_be_greater(0)
    -- canyons: neighbouring blocks never touch (their foundations meet under the avenue)
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
    expect(s.lights).to_be(s.full)
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

  it("every outer district's organ is hollow at the street: a hall behind a mouth, its finds inside", function()
    local st, i, r, p = in_city("planet")
    local n = 0
    for _, d in ipairs(p.districts) do
      local og = d.organ
      if og then
        n = n + 1
        local h = og.hall
        expect(og.h >= mega.HALL_H[1] - mega.SNAP and og.h <= mega.HALL_H[2]).to_be(true)
        expect(#og.finds >= mega.FINDS[1] and #og.finds <= mega.FINDS[2]).to_be(true)
        -- nothing solid inside the hall, and its finds lie in it
        local sol = mega.build(d)
        for k, b in ipairs(sol) do
          if k > 1 then
            local inside = b[1][1] < h[4] and b[2][1] > h[1] and b[1][3] < h[6] and b[2][3] > h[3] and b[1][2] < h[5] and b[2][2] > h[2]
            expect(inside).to_be(false)
          end
        end
        for _, f in ipairs(og.finds) do expect(mega.in_hall(d, f.pos) == og).to_be(true) end
        expect(mega.in_hall(d, og.centre)).to_be(og)
        expect(mega.in_hall(d, { h[1] - 50, og.centre[2], og.centre[3] })).to_be(nil)
        -- the mouth: a ship-sized gap in one face, from the street up
        local o = d.organs[og.index]
        local W = mega.WALL
        local mx = og.side <= 2 and (og.side == 1 and h[1] - W / 2 or h[4] + W / 2) or (h[1] + h[4]) / 2
        local mz = og.side >= 3 and (og.side == 3 and h[3] - W / 2 or h[6] + W / 2) or (h[3] + h[6]) / 2
        local blocked = false
        for k, b in ipairs(sol) do
          if k > 1 and mx > b[1][1] and mx < b[2][1] and mz > b[1][3] and mz < b[2][3] and p.frame.y + 10 > b[1][2] and p.frame.y + 10 < b[2][2] then blocked = true end
        end
        expect(blocked).to_be(false)
        expect(o.megaform).to_be(nil)
      end
    end
    expect(n).to_be_greater(#p.districts // 2)
    expect(mega.in_hall(nil, { 0, 0, 0 })).to_be(nil)
    expect(mega.plan_organ(1, { organs = {}, k = 1, y = 0, box = { 0, 0, 1, 1 } })).to_be(nil)
  end)

  it("an organ's finds are beamed like any other and stay taken for that player", function()
    local st, i, r, p = in_city("planet")
    local pl = st.players[1]
    local d
    for _, x in ipairs(p.districts) do if x.organ and not d then d = x end end
    pl.site = 0
    local f1 = d.organ.finds[1].pos
    pl.ship.pos = { f1[1], p.frame.y + 20, f1[3] }
    local tractor = require("sim.tractor")
    local cands = {}
    for _, c in ipairs(tractor.candidates(st, pl, 0, nil)) do if c.organ then cands[#cands + 1] = c end end
    local near = 0
    for _, f in ipairs(d.organ.finds) do
      if math.abs(f.pos[1] - pl.ship.pos[1]) <= mega.SENSE and math.abs(f.pos[3] - pl.ship.pos[3]) <= mega.SENSE then near = near + 1 end
    end
    expect(near >= 1).to_be(true)
    expect(#cands).to_be(near)
    local c = cands[1]
    expect(c.kind).to_be("slot")
    expect(c.item.civ ~= nil).to_be(true)
    local before = #pl.hold
    game.pick_up(st, pl, c, 0)
    expect(#pl.hold).to_be(before + 1)
    expect(pl.looted[c.key]).to_be(true)
    local again = 0
    for _, x in ipairs(tractor.candidates(st, pl, 0, nil)) do if x.organ then again = again + 1 end end
    expect(again).to_be(near - 1)
    -- inside a site, or far from any organ: none
    pl.site = i
    expect(#mega.candidates(st, pl)).to_be(0)
    pl.site = 0
    pl.ship.pos = { 1e6, 0, 1e6 }
    expect(#mega.candidates(st, pl)).to_be(0)
    -- the machine in the hall turns with the clock and stays in its hall
    local a, b = megav.organ_pose(d, 0), megav.organ_pose(d, 10)
    expect(a.yaw ~= b.yaw).to_be(true)
    expect(mega.in_hall(d, a.pos)).to_be(d.organ)
    -- a big machine: its halo spans most of the hall, and no ring ever pokes out of it
    local h = d.organ.hall
    expect(a.scale * 2 > 0.5 * math.min(h[4] - h[1], h[6] - h[3])).to_be(true)
    for _, tt in ipairs({ 0, 3.3, 77, 1e4 }) do
      local o = megav.organ_pose(d, tt)
      expect(#o.rings).to_be(3)
      for _, r in ipairs(o.rings) do
        expect(r.scale <= math.min(h[4] - h[1], h[6] - h[3]) / 2 - 8).to_be(true)
        expect(r.scale * math.abs(math.sin(r.pitch)) <= d.organ.h / 2 - 4 or r.scale <= d.organ.h / 2 - 4).to_be(true)
      end
      expect(math.abs(o.core.pos[2] - d.organ.centre[2]) + o.core.size <= d.organ.h / 2).to_be(true)
    end
    local v = fake_view()
    local s = megav.draw(v, A, p, { pos = d.organ.centre, yaw = 0, pitch = 0 }, 1, function() return true end, 1000, 3)
    expect((s.organs or 0) >= 1).to_be(true)
    expect((s.drifters or 0) >= 2).to_be(true)
    -- the drifters glide down the avenue, back and forth, and never leave it
    for kk = 1, 2 do
      for _, tt in ipairs({ 0, 7.5, 300, 1e4 }) do
        local o = megav.drift_pose(p, d, kk, tt)
        local c = d.cell
        expect(o.pos[1] >= c[1] - 1e-6 and o.pos[1] <= c[3] + 1e-6 and o.pos[3] >= c[2] - 1e-6 and o.pos[3] <= c[4] + 1e-6).to_be(true)
        expect(o.pos[2] > p.frame.y + 30).to_be(true)
        expect(#o.trail).to_be(2)
      end
      expect(megav.drift_pose(p, d, kk, 1).pos[kk == 1 and 3 or 1] ~= megav.drift_pose(p, d, kk, 2).pos[kk == 1 and 3 or 1]).to_be(true)
    end
  end)

  it("the terraces hold fold bays with cradles, and growing back to the Villa in one is free", function()
    local relic = require("sim.relic")
    for _, body in ipairs({ "planet", "moon", "asteroid" }) do
      local st, i, r, p = in_city(body)
      local with = 0
      for _, d in ipairs(p.districts) do
        local sol = mega.solids(p, d)
        local bays = mega.bays(p, d)
        expect(#bays <= mega.BAYS).to_be(true)
        if #bays > 0 then with = with + 1 end
        for _, b in ipairs(bays) do
          expect(b.hi[1] - b.lo[1]).to_be(mega.BAY)
          expect(b.hi[3] - b.lo[3]).to_be(mega.BAY)
          expect(b.hi[2] - b.lo[2] >= 20).to_be(true)
          expect(b.lo[2] - d.y >= mega.BAY_MIN_Y).to_be(true)
          -- standing on a terrace: some solid's top is the pad, and the pad's air is clear but for its own cradle
          local on, cradle = false, false
          for _, o in ipairs(sol) do
            local over = o[1][1] < b.hi[1] and o[2][1] > b.lo[1] and o[1][3] < b.hi[3] and o[2][3] > b.lo[3]
            if over and o[2][2] == b.lo[2] and o[1][1] <= b.lo[1] and o[2][1] >= b.hi[1] and o[1][3] <= b.lo[3] and o[2][3] >= b.hi[3] then on = true end
            if o == b.cradle_box then cradle = true
            elseif over then expect(o[1][2] < b.lo[2] + mega.BAY_CLEAR and o[2][2] > b.lo[2]).to_be(false) end
          end
          expect(on).to_be(true)
          expect(cradle).to_be(true)
          expect(select(1, mega.bay_at(p, b.marker))).to_be(b)
        end
      end
      expect(with).to_be_greater(#p.districts // 3)
      -- a Seat in a bay grows back for free; out of it, or in a site, it pays
      local d, b
      for _, x in ipairs(p.districts) do if not b and #mega.bays(p, x) > 0 then d, b = x, mega.bays(p, x)[1] end end
      local pl = st.players[1]
      pl.site = 0
      pl.ship.size = 3
      pl.ship.pos = { b.marker[1], b.marker[2], b.marker[3] }
      expect(relic.cradle_of(st, pl)).to_be(b)
      expect(relic.free_regrow(st, pl, 1)).to_be(true)
      pl.ship.pos = { b.marker[1], b.marker[2] + 200, b.marker[3] }
      expect(relic.free_regrow(st, pl, 1)).to_be(false)
      pl.ship.pos = { 1e6, 0, 1e6 }
      expect(relic.cradle_of(st, pl)).to_be(nil)
      expect(mega.bay_at(p, { 1e6, 0, 1e6 })).to_be(nil)
      -- the view lights each bay's rim and cradle
      local n0 = 0
      for _, q in ipairs(megav.light_parts(p, d)) do if q.max[2] - q.min[2] < 0.5 then n0 = n0 + 1 end end
      expect(n0 >= 5 * #mega.bays(p, d)).to_be(true)
    end
  end)

  it("under each organ a shaft drops into a warren of corridors and chambers, its sanctum's finds beamed only from below", function()
    for _, body in ipairs({ "planet", "asteroid" }) do
      local st, i, r, p = in_city(body)
      local n = 0
      for _, d in ipairs(p.districts) do
        local w = d.warren
        if w then
          n = n + 1
          local sol = mega.solids(p, d)
          expect(sol.found).to_be(4)
          local function solid_at(x, y, z)
            for _, b in ipairs(sol) do
              if x > b[1][1] and x < b[2][1] and y > b[1][2] and y < b[2][2] and z > b[1][3] and z < b[2][3] then return true end
            end
            return false
          end
          -- the shaft: open from the hall floor down into the hub, and it lies in the hall
          local sh = w.shaft
          local sx, sz = (sh[1] + sh[3]) / 2, (sh[2] + sh[4]) / 2
          expect(mega.in_hall(d, { sx, d.y + 5, sz })).to_be(d.organ)
          for y = w.y0 + 2, d.y + 10, 4 do
            expect(solid_at(sx, y, sz)).to_be(false)
            expect(solid_at(sh[1] + 2, y, sh[2] + 2)).to_be(false)
          end
          expect(solid_at(sx, w.y0 - 2, sz)).to_be(true)
          -- every space is open from floor to ceiling (sampled), shut in by walls around, inside the district
          local chambers, sanct = 0, 0
          for _, sp in ipairs(w.spaces) do
            expect(sp[1] >= d.box[1] and sp[3] <= d.box[3] and sp[2] >= d.box[2] and sp[4] <= d.box[4]).to_be(true)
            for _, f in ipairs({ { 0.5, 0.5 }, { 0.1, 0.1 }, { 0.9, 0.9 }, { 0.1, 0.9 } }) do
              local x, z = sp[1] + (sp[3] - sp[1]) * f[1], sp[2] + (sp[4] - sp[2]) * f[2]
              expect(solid_at(x, w.y0 + 3, z) or solid_at(x, w.y1 - 3, z)).to_be(false)
              expect(mega.in_warren(d, { x, w.y0 + 20, z })).to_be(w)
            end
            if sp[5] == "chamber" or sp[5] == "sanctum" then chambers = chambers + 1 end
            if sp[5] == "sanctum" then sanct = sanct + 1 end
          end
          expect(chambers >= 1 and chambers <= 4).to_be(true)
          expect(sanct).to_be(1)
          -- walled: just outside the warren's extent is rock
          local hub = w.spaces[1]
          local outside = 0
          for _, x in ipairs({ hub[1] - 5, hub[3] + 5 }) do if solid_at(x, w.y0 + 20, hub[2] + 5) then outside = outside + 1 end end
          for _, z in ipairs({ hub[2] - 5, hub[4] + 5 }) do if solid_at(hub[1] + 5, w.y0 + 20, z) then outside = outside + 1 end end
          expect(outside >= 1).to_be(true)
          expect(#w.finds >= chambers).to_be(true)
          for _, f in ipairs(w.finds) do expect(mega.in_warren(d, { f.pos[1], f.pos[2] + 5, f.pos[3] })).to_be(w) end
          expect(mega.in_warren(d, { sx, d.y + 30, sz })).to_be(nil)
          expect(mega.in_warren(d, { sh[1] - 20, w.y1 + 2, sz })).to_be(nil)
        end
      end
      expect(n).to_be_greater(#p.districts // 3)
      -- the warren's finds: sensed from the warren, not from the hall above; taken they stay taken
      local d
      for _, x in ipairs(p.districts) do if x.warren and not d then d = x end end
      local f = d.warren.finds[1]
      local pl = st.players[1]
      pl.site = 0
      local function deep()
        local out = {}
        for _, c in ipairs(mega.candidates(st, pl)) do if c.pos[2] < d.y then out[#out + 1] = c end end
        return out
      end
      pl.ship.pos = { f.pos[1], d.y + 30, f.pos[3] }
      expect(#deep()).to_be(0)
      pl.ship.pos = { f.pos[1], f.pos[2] + 15, f.pos[3] }
      local c = deep()
      expect(#c >= 1).to_be(true)
      game.pick_up(st, pl, c[1], 0)
      expect(pl.looted[c[1].key]).to_be(true)
      expect(#deep()).to_be(#c - 1)
      -- the sanctum breathes, its stones keep off the floor and ceiling
      for _, tt in ipairs({ 0, 5, 300 }) do
        local sp = megav.sanctum_pose(d, tt)
        expect(#sp.stones).to_be(megav.STONES)
        for _, o in ipairs(sp.stones) do
          expect(o.pos[2] - o.size > d.warren.y0 and o.pos[2] + o.size < d.warren.y1).to_be(true)
          expect(mega.in_warren(d, o.pos)).to_be(d.warren)
        end
      end
      expect(megav.sanctum_pose(d, 0).heart.size ~= megav.sanctum_pose(d, 3).heart.size).to_be(true)
      local v = fake_view()
      local s = megav.draw(v, A, p, { pos = d.organ.centre, yaw = 0, pitch = 0 }, 1, function() return true end, 1000, 3)
      expect((s.sanctums or 0) >= 1).to_be(true)
    end
    expect(mega.in_warren(nil, { 0, 0, 0 })).to_be(nil)
    expect(mega.plan_warren(1, { k = 1 })).to_be(nil)
  end)
end)
