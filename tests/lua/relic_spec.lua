-- SPDX-License-Identifier: MIT
-- add-relic-stations, first slice: the Vyrr spine relic's layout (sim/relicgen.lua), its play rules
-- (sim/relic.lua) and its skins (view/relic.lua): sizes and classes against the design's §5 scale rules, the
-- Villa route, fold bays at the Seat port, the Charge plan, skins outside every flyable box, PIERCE wounds.
local game = require("sim.game")
local ruinm = require("sim.ruin")
local gen = require("sim.relicgen")
local relic = require("sim.relic")
local civs = require("sim.civs")
local sentry = require("sim.sentry")
local shipm = require("sim.ship")
local configs = require("sim.config")
local relicv = require("view.relic")
local matv = require("view.materials")

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state(slice)
  local st = {}
  game.init(st, { seed = 42, players = 1, relic_slice = slice })
  return st
end
local function run(st, c, n)
  for _ = 1, n or 1 do game.step(st, { c or cmd() }, 1 / 60) end
end
local ORIGIN = { 0, -4000, 0 }
local function gen42(seed) return ruinm.generate(seed or 42, "relic", relic.civ(), ORIGIN) end
local function kit() return ruinm.kit_of("relic") end
local function copy(t, seen)
  if type(t) ~= "table" then return t end
  seen = seen or {}
  if seen[t] then return seen[t] end
  local o = {}
  seen[t] = o
  for k, v in pairs(t) do o[copy(k, seen)] = copy(v, seen) end
  return o
end
local function space(r, class)
  for _, s in ipairs(r.relic.spaces) do if s.class == class then return s end end
end

describe("the spine relic's layout", function()
  it("is one straight spine about 900 m long: maw, three halls with trunks, the Core", function()
    local r = gen42()
    expect(r.relic.archetype).to_be("spine")
    expect(r.relic.length >= 850 and r.relic.length <= 1000).to_be(true)
    local kinds = {}
    for _, room in ipairs(r.rooms) do kinds[#kinds + 1] = room.kind end
    expect(table.concat(kinds, ",")).to_be("entrance,hall,trunk,hall,trunk,hall,trunk,core,passage,passage,reliquary")
    -- along +z, each room starting where the last ends
    for k = 2, 8 do expect(r.rooms[k].cell[3]).to_be(r.rooms[k - 1].cell[3] + r.rooms[k - 1].size[3]) end
  end)

  it("meets the scale rules: a 34 x 20 maw, 96 x 48 x 96 halls, 40 x 24 trunks, a 128 m Core", function()
    local r = gen42()
    local k = kit()
    expect(k.doors[4][1]).to_be(34)
    expect(k.doors[4][2]).to_be(20)
    expect(r.doors[1].a).to_be(0)
    local h = space(r, "hall")
    expect(h.clear[1] >= 95 and h.clear[2] >= 47 and h.clear[3] >= 95).to_be(true)
    local t = space(r, "trunk")
    expect(t.clear[1] >= 39 and t.clear[2] >= 23 and t.length >= 150).to_be(true)
    local c = space(r, "core")
    expect(c.clear[1] >= 127 and c.clear[3] >= 127).to_be(true)
    for _, s in ipairs(r.relic.spaces) do
      if s.villa then
        -- the Villa (26 x 12) fits every Villa-class space with room to turn
        expect(s.clear[1] >= configs.get(1).diameter + 8 and s.clear[2] >= configs.get(1).height + 8).to_be(true)
      end
    end
  end)

  it("keeps the Villa on the route: every big room Villa-reachable, Villa share at least 75%", function()
    local r = gen42()
    for _, room in ipairs(r.rooms) do
      if room.class >= 4 then expect(r.reach[room.id + 1] >= 4).to_be(true) end
    end
    expect(r.relic.villa_share >= 0.75).to_be(true)
  end)

  it("has one Seat branch: a 2.6 x 2.1 port, an 80 m 4 x 4 passage with one elbow, a 12 x 8 x 12 reliquary", function()
    local r = gen42()
    local k = kit()
    local br = r.relic.branches[1]
    expect(#r.relic.branches).to_be(1)
    local port = r.doors[br.port.door]
    expect(port.class).to_be(1)
    expect(k.doors[1][1]).to_be(2.6)
    expect(k.doors[1][2]).to_be(2.1)
    expect(br.length).to_be(80)
    local A, B, Q = r.rooms[br.rooms[1]], r.rooms[br.rooms[2]], r.rooms[br.rooms[3]]
    -- A runs across (x), B along the spine (z): one elbow; both 4 x 4 m
    expect(A.size[2] * k.cell).to_be(4)
    expect(A.size[3] * k.cell).to_be(4)
    expect(B.size[1] * k.cell).to_be(4)
    expect(B.size[3] > 1 and A.size[1] > 1).to_be(true)
    local q = space(r, "reliquary")
    expect(q.clear[1] >= 11 and q.clear[2] >= 7 and q.clear[3] >= 11).to_be(true)
    expect(Q.class).to_be(1)
    -- no Villa door into the branch
    for _, d in ipairs(r.doors) do
      if d.b == A.id or d.b == B.id or d.b == Q.id then expect(d.class).to_be(1) end
    end
  end)

  it("puts fold bays of at least 44 x 20 x 44 m with cradles in the halls, four in the port's hall", function()
    local r = gen42()
    local in_lung = 0
    for _, b in ipairs(r.relic.bays) do
      expect(b.hi[1] - b.lo[1] >= 44 and b.hi[2] - b.lo[2] >= 20 and b.hi[3] - b.lo[3] >= 44).to_be(true)
      expect(b.cradle ~= nil).to_be(true)
      if b.room == r.relic.lung then in_lung = in_lung + 1 end
    end
    expect(in_lung).to_be(4)
    -- the branch's bay is near the port mouth
    local br = r.relic.branches[1]
    local b = r.relic.bays[br.bay]
    local d = 0
    for i = 1, 3 do d = d + (b.marker[i] - br.port.pos[i]) ^ 2 end
    expect(d <= 30 * 30).to_be(true)
  end)

  it("spreads six finds over the halls, three class-1 finds in the reliquary and the XL idol in the Core", function()
    local r = gen42()
    local hall, warren, idol = 0, 0, 0
    for _, s in ipairs(r.slots) do
      if s.idol then
        idol = idol + 1
        expect(s.max_size).to_be(4)
        expect(s.room).to_be(r.relic.core)
      elseif s.warren then
        warren = warren + 1
        expect(s.max_size).to_be(1)
      else
        hall = hall + 1
        expect(r.rooms[s.room].kind).to_be("hall")
      end
    end
    expect(hall).to_be(6)
    expect(warren).to_be(3)
    expect(idol).to_be(1)
  end)

  it("plans the Charge of a full clear within the tank: the shrink costs, the cradle regrow is free", function()
    local r = gen42()
    local worst, steps = gen.charge_plan(r.relic)
    expect(worst <= gen.CHARGE_MAX).to_be(true)
    expect(steps[2][1]).to_be("regrow")
    expect(steps[2][3]).to_be(0)
    -- without a cradle the regrow is paid and the run carries on
    local rel = copy(r.relic)
    rel.bays[rel.branches[1].bay].cradle = nil
    rel.branches[1].pockets = { {} }
    local w2, s2 = gen.charge_plan(rel)
    expect(s2[2][3]).to_be(10)
    expect(w2 > worst).to_be(true)
  end)

  it("moves bays and finds with the seed, not the spine; the hash follows the seed", function()
    local a, b = gen42(42), gen42(7)
    expect(#a.rooms).to_be(#b.rooms)
    expect(a.hash ~= b.hash).to_be(true)
    expect(gen42(42)).to_be(a) -- memoized
  end)

  it("rejects broken layouts with a reason", function()
    local r = gen42()
    local k = kit()
    local function bad(edit)
      local c = copy(r)
      edit(c)
      local ok, why = gen.validate(c, k)
      expect(ok).to_be(false)
      return why
    end
    expect(gen.validate(r, k)).to_be(true)
    expect(bad(function(c) c.relic.bays[c.relic.branches[1].bay] = nil end)).to_be("port without a bay")
    expect(bad(function(c) c.relic.bays[c.relic.branches[1].bay].marker = { 0, 0, 0 } end)).to_be("bay too far from its port")
    expect(bad(function(c) c.relic.villa_share = 0.5 end)).to_be("villa share")
    expect(bad(function(c) space(c, "hall").clear = { 10, 10, 10 } end)).to_be("hall too small")
    expect(bad(function(c) space(c, "trunk").clear = { 10, 10, 160 } end)).to_be("trunk too narrow")
    expect(bad(function(c) c.slots = {}; c.doors[2].class = 1 end):match("not villa%-reachable") ~= nil).to_be(true)
    expect(bad(function(c) c.doors = {} end):match("unreachable") ~= nil).to_be(true)
    local max = gen.CHARGE_MAX
    gen.CHARGE_MAX = 5
    expect(bad(function() end)).to_be("charge plan")
    gen.CHARGE_MAX = max
  end)

  it("fails loudly when no try validates, and forgets old layouts", function()
    local k = copy(kit())
    k.id = "relic_broken"
    k.spine.hall = { 8, 4, 8 }
    local ok, err = pcall(gen.generate, 1, k, nil, ORIGIN)
    expect(ok).to_be(false)
    expect(tostring(err):match("relic generation failed") ~= nil).to_be(true)
    for s = 100, 120 do gen.generate(s, kit(), nil, ORIGIN) end
    expect(gen.generate(42, kit(), relic.civ(), ORIGIN).relic.length >= 850).to_be(true)
  end)

  it("finds a door's hole in the world", function()
    local r = gen42()
    local c, w, h = gen.hole(r.doors[r.relic.branches[1].port.door], kit(), ORIGIN)
    expect(w).to_be(2.6)
    expect(h).to_be(2.1)
    expect(c[1] > ORIGIN[1]).to_be(true)
  end)
end)

describe("relic play", function()
  it("adds the Vyrr relic only with the debug entry, and only once", function()
    local plain = new_state(false)
    expect(relic.site_index(plain)).to_be(nil)
    local st = new_state(true)
    local i = relic.site_index(st)
    expect(i ~= nil).to_be(true)
    local n = #st.sector.sites
    expect(relic.spawn_slice(st)).to_be(i)
    expect(#st.sector.sites).to_be(n)
    expect(civs.of(st, st.sector.sites[i]).id).to_be("vyrr")
    expect(civs.by_id(nil, "vyrr").name).to_be("Vyrr")
    expect(#game.sentries(i)).to_be(0)
    expect(#sentry.layout(st.sector.sites[i], game.ruin(i), relic.civ())).to_be(0)
  end)

  it("knows the cradle bays, what regrows free and what refills", function()
    local st = new_state(true)
    local i = relic.site_index(st)
    local r = game.ruin(i)
    local p = st.players[1]
    expect(relic.bay_at(nil, { 0, 0, 0 })).to_be(nil)
    expect(relic.bay_at(r, { 0, 0, 0 })).to_be(nil)
    expect(relic.cradle_of(st, p)).to_be(nil) -- outside every site
    local b = r.relic.bays[1]
    p.ship.pos = { b.marker[1], b.cradle[2] + 7, b.marker[3] }
    p.site = i
    expect(relic.bay_at(r, p.ship.pos)).to_be(b)
    expect(relic.cradle_regen(st, p)).to_be(relic.CRADLE_REGEN)
    p.ship.morph = { total = 1 }
    expect(relic.cradle_regen(st, p)).to_be(nil)
    p.ship.morph = nil
    p.ship.size = 2
    expect(relic.cradle_regen(st, p)).to_be(nil)
    expect(relic.free_regrow(st, p, 1)).to_be(true)
    expect(relic.free_regrow(st, p, 3)).to_be(false)
    p.ship.pos = { b.marker[1] + 200, b.cradle[2] + 7, b.marker[3] }
    expect(relic.free_regrow(st, p, 1)).to_be(false)
  end)

  it("lets ship.request grow for free", function()
    local ship = shipm.new({ 0, 0, 0 }, 0, 2)
    ship.charge = 0
    local never = function() return false end
    expect(shipm.request(ship, 1, never)).to_be(false)
    expect(shipm.request(ship, 1, never, nil, nil, true)).to_be(true)
  end)

  it("turns the Seat-lock only for a Seat held at its socket", function()
    local st = new_state(true)
    local i = relic.site_index(st)
    local r = game.ruin(i)
    local p = st.players[1]
    local lock = r.relic.locks[1]
    p.site = i
    p.ship.size = 2
    p.ship.pos = shipm.center_for_eye({ lock.socket[1], lock.socket[2], lock.socket[3] - 1 }, 0, 2)
    p.ship.yaw = 0
    expect(relic.socket_near(st, p)).to_be(lock)
    local held = { held = function(_, n) return n == "use" end }
    local idle = { held = function() return false end }
    expect(relic.lock_step(st, p, held, 1.0)).to_be(false)
    expect(relic.lock_step(st, p, idle, 1 / 60)).to_be(false)
    expect(p.relic_turn).to_be(nil)
    expect(relic.lock_step(st, p, held, 1.0)).to_be(false)
    expect(relic.lock_step(st, p, held, 0.6)).to_be(true)
    expect(relic.lock_open(st, i, lock.id)).to_be(true)
    expect(relic.socket_near(st, p)).to_be(nil) -- open locks offer no socket
    expect(game.open_relic_lock(i, lock.id)).to_be(false) -- already gone
    p.ship.size = 1
    expect(relic.socket_near(st, p)).to_be(nil)
    p.site = 0
    expect(relic.socket_near(st, p)).to_be(nil)
  end)

  it("makes the idol a fixed XL find and pays reliquary finds double", function()
    local it1 = relic.idol_item({}, 5)
    expect(it1.size).to_be(4)
    expect(it1.xl).to_be(true)
    expect(it1.value >= kit().loot.idol_value).to_be(true)
    expect(relic.warren_value(101)).to_be(202)
  end)

  it("shows the ghost Villa only for a Seat in a relic's Villa space, red where it cannot fit", function()
    local st = new_state(true)
    local i = relic.site_index(st)
    local r = game.ruin(i)
    local p = st.players[1]
    expect(relic.ghost(st, p)).to_be(nil) -- site 0
    p.site = i
    expect(relic.ghost(st, p)).to_be(nil) -- the Villa
    p.ship.size = 2
    local k = kit()
    local hmn, hmx = ruinm.room_box(r.rooms[r.relic.halls[1]], k, r.origin)
    p.ship.pos = { (hmn[1] + hmx[1]) / 2, hmn[2] + 10, (hmn[3] + hmx[3]) / 2 }
    local pos, fits = relic.ghost(st, p)
    expect(pos ~= nil and fits).to_be(true)
    p.ship.pos = { hmn[1] + 2, hmn[2] + 2, (hmn[3] + hmx[3]) / 2 }
    pos, fits = relic.ghost(st, p)
    expect(pos ~= nil and not fits).to_be(true)
    local qmn, qmx = ruinm.room_box(r.rooms[r.relic.branches[1].reliquary], k, r.origin)
    p.ship.pos = { (qmn[1] + qmx[1]) / 2, qmn[2] + 2, (qmn[3] + qmx[3]) / 2 }
    expect(relic.ghost(st, p)).to_be(nil) -- a Seat-class space
    local site = st.sector.sites[1]
    if not site.relic_civ then
      p.site = 1
      if game.ruin(1) then expect(relic.ghost(st, p)).to_be(nil) end
    end
  end)
end)

describe("relic skins", function()
  local function aabb(part)
    if part.kind == "box" then return part.min, part.max end
    local c, u, v, h = part.c, part.u, part.v, part.h
    local n = { u[2] * v[3] - u[3] * v[2], u[3] * v[1] - u[1] * v[3], u[1] * v[2] - u[2] * v[1] }
    local l = math.sqrt(n[1] ^ 2 + n[2] ^ 2 + n[3] ^ 2)
    local pts = { c, { c[1] + u[1], c[2] + u[2], c[3] + u[3] }, { c[1] + v[1], c[2] + v[2], c[3] + v[3] },
                  { c[1] + u[1] + v[1], c[2] + u[2] + v[2], c[3] + u[3] + v[3] },
                  { c[1] + (u[1] + v[1]) / 2 + h * n[1] / l, c[2] + (u[2] + v[2]) / 2 + h * n[2] / l,
                    c[3] + (u[3] + v[3]) / 2 + h * n[3] / l } }
    local mn, mx = { 1e9, 1e9, 1e9 }, { -1e9, -1e9, -1e9 }
    for _, q in ipairs(pts) do
      for a = 1, 3 do mn[a], mx[a] = math.min(mn[a], q[a]), math.max(mx[a], q[a]) end
    end
    return mn, mx
  end

  it("keep every cushion, rib, band and frame out of every flyable box (collision is the boxes only)", function()
    local r = gen42()
    local k = kit()
    local all = relicv.parts(r, ORIGIN)
    local inner = {}
    for _, room in ipairs(r.rooms) do
      local mn, mx = ruinm.room_box(room, k, ORIGIN)
      inner[#inner + 1] = { { mn[1] + k.wall, mn[2] + k.wall, mn[3] + k.wall }, { mx[1] - k.wall, mx[2] - k.wall, mx[3] - k.wall } }
    end
    local lists = { all.ext }
    for _, e in ipairs(all.rooms) do lists[#lists + 1] = e.parts end
    local skins, bad = 0, 0
    for _, list in ipairs(lists) do
      for _, part in ipairs(list) do
        if part.skin then
          skins = skins + 1
          local mn, mx = aabb(part)
          for _, b in ipairs(inner) do
            local cut = true
            for a = 1, 3 do if mn[a] >= b[2][a] - 0.01 or mx[a] <= b[1][a] + 0.01 then cut = false end end
            if cut then bad = bad + 1 end
          end
        end
      end
    end
    expect(skins > 300).to_be(true)
    expect(bad).to_be(0)
    expect(all.cushions > 100).to_be(true)
  end)

  it("swell the outside into lobes over every door-less side and roof, and ring the maw with eight petals", function()
    local r = gen42()
    local all = relicv.parts(r, ORIGIN)
    local lobes, petals, big = 0, 0, 0
    for _, part in ipairs(all.ext) do
      if part.lobe then
        lobes = lobes + 1
        if part.h >= 8 then big = big + 1 end
        expect(part.h <= relicv.LOBE_MAX * 1.25 + 1e-6).to_be(true)
      end
      if part.petal then petals = petals + 1 end
    end
    expect(lobes >= 20).to_be(true)
    expect(big >= 10).to_be(true)
    expect(petals).to_be(8)
  end)

  it("ring every PIERCE spine with a wound, breathe the lung hall and rot the plague hall", function()
    local r = gen42()
    local all = relicv.parts(r, ORIGIN)
    local S = matv.SLOT
    local spines, wounds = 0, 0
    for _, part in ipairs(all.ext) do
      if part.kind == "cone" and part.mat == S.accent and (part.h or 0) > relicv.SPINE then spines = spines + 1 end
      if part.kind == "ring" and part.mat == S.ring then wounds = wounds + 1 end
    end
    expect(spines > 20).to_be(true)
    expect(wounds >= spines).to_be(true)
    local lung, plague = 0, 0
    for _, e in ipairs(all.rooms) do
      for _, part in ipairs(e.parts) do
        if part.mat == S.lung then
          lung = lung + 1
          expect(e.room.id).to_be(r.relic.lung)
        end
        if part.mat == S.decay then
          plague = plague + 1
          expect(e.room.id).to_be(r.relic.plague)
        end
      end
    end
    expect(lung > 10 and plague > 10).to_be(true)
  end)

  it("light the relic in the civ's colours, one lamp over each cradle", function()
    local r = gen42()
    local lamps = relicv.lamps(r, ORIGIN, 1)
    expect(#lamps > #r.relic.bays + 10).to_be(true)
    local lv = require("view.lights")
    local c = lv.room_lamps(r, ORIGIN, 1)
    expect(#c.list).to_be(#lamps)
  end)

  it("build meshes once per layout and draw what the eye can see", function()
    local st = new_state(true)
    local i = relic.site_index(st)
    local r = game.ruin(i)
    local site = st.sector.sites[i]
    local set = relicv.meshes(r, site.pos)
    expect(relicv.meshes(r, site.pos)).to_be(set)
    expect(set.triangles > 0).to_be(true)
    -- the web's cap (design §2.3.5: 180k visible triangles) holds even with the whole relic in view
    expect(set.triangles <= 180000).to_be(true)
    local calls = { mesh = 0, billboard = 0 }
    local v = { player = 1 }
    function v:materials(t) calls.mats = t return 7 end
    function v:mesh() calls.mesh = calls.mesh + 1 end
    function v:billboard() calls.billboard = calls.billboard + 1 end
    local A = { pal = {}, tex = { glow = 1 }, unit = 1 }
    local door = ruinm.entrance(r, site.pos)
    local p = st.players[1]
    p.site, p.ship.size = i, 2
    local hmn, hmx = ruinm.room_box(r.rooms[r.relic.halls[1]], kit(), site.pos)
    p.ship.pos = { (hmn[1] + hmx[1]) / 2, hmn[2] + 10, (hmn[3] + hmx[3]) / 2 }
    p.relic_turn = 0.5
    local cam = { pos = { door[1], door[2], door[3] - 50 }, yaw = 0, pitch = 0 }
    local stats = relicv.draw(v, A, st, cam, false, 1.5)
    expect(stats.rooms > 0).to_be(true)
    expect(calls.mats.time).to_be(1.5)
    expect(calls.mats.slots[matv.SLOT.lung].breath).to_be(matv.BREATH)
    expect(calls.billboard >= 1).to_be(true) -- the closed lock's socket
    -- far away: nothing
    local none = relicv.draw(v, A, st, { pos = { 1e5, 0, 1e5 }, yaw = 0, pitch = 0 }, false, 0)
    expect(none.rooms).to_be(0)
    -- looking away from most of it: rooms are culled
    local away = relicv.draw(v, A, st, { pos = { door[1], door[2], door[3] - 50 }, yaw = math.pi, pitch = 0 }, false, 0)
    expect(away.culled > 0).to_be(true)
    relicv.idol(v, A, { 0, 0, 0 }, 0, 1, 10)
    expect(relicv.idol_mesh()).to_be(relicv.idol_mesh())
    expect(relicv.ghost_mesh()).to_be(relicv.ghost_mesh())
  end)
end)
