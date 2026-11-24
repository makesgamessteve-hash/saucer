-- SPDX-License-Identifier: MIT
-- add-relic-stations, add-relic-dungeons: the Vyrr warren relic's layout (sim/relicgen.lua), its play rules
-- (sim/relic.lua), its skins (view/relic.lua) and phenomena (view/phenomena.lua): the dungeon's scale (Villa spaces,
-- levels, Seat chambers, the heart), sizes and classes against the design's §5 scale rules, the Villa route, fold
-- bays at every Seat port, the Charge plan, skins outside every flyable box, PIERCE wounds, the triangle budget.
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

local function box_of(r, room) return ruinm.room_box(room, kit(), r.origin) end
local function villa_degree(r)
  local deg = {}
  for _, d in ipairs(r.doors) do
    if d.class >= 4 then
      deg[d.a] = (deg[d.a] or 0) + 1
      deg[d.b] = (deg[d.b] or 0) + 1
    end
  end
  return deg
end

describe("the warren relic's layout", function()
  it("is a dungeon: 40-80 Villa spaces on 3-5 levels, 15-30 Seat chambers, the heart past it all", function()
    local r = gen42()
    expect(r.relic.archetype).to_be("warren")
    local villa, kinds = 0, {}
    for _, sp in ipairs(r.relic.spaces) do if sp.villa then villa = villa + 1 end end
    for _, room in ipairs(r.rooms) do kinds[room.kind] = (kinds[room.kind] or 0) + 1 end
    expect(villa >= 40 and villa <= 80).to_be(true)
    expect(r.relic.levels >= 3 and r.relic.levels <= 5).to_be(true)
    expect(#r.relic.chambers >= 15 and #r.relic.chambers <= 30).to_be(true)
    expect(kinds.entrance).to_be(1)
    expect(kinds.core).to_be(1)
    expect(kinds.reliquary).to_be(1)
    expect(kinds.hall >= 20 and kinds.trunk >= 15 and kinds.shaft >= 2).to_be(true)
    expect(r.rooms[1].kind).to_be("entrance")
    expect(r.relic.heart).to_be(r.relic.core)
    expect(r.relic.length >= 1000).to_be(true)
  end)

  it("meets the scale rules: a 34 x 20 maw, halls big and small, 40 x 24 trunks, a 480 m heart", function()
    local r = gen42()
    local k = kit()
    expect(k.doors[4][1]).to_be(34)
    expect(k.doors[4][2]).to_be(20)
    expect(r.doors[1].a).to_be(0)
    local small, big = 1e9, 0
    for _, s in ipairs(r.relic.spaces) do
      if s.class == "hall" then
        small = math.min(small, s.clear[1], s.clear[3])
        big = math.max(big, s.clear[1], s.clear[3])
      end
      if s.class == "trunk" then expect(math.min(s.clear[1], s.clear[3]) >= 39 and s.clear[2] >= 23).to_be(true) end
      if s.villa then
        -- the Villa (26 x 12) fits every Villa-class space with room to turn
        expect(math.min(s.clear[1], s.clear[3]) >= configs.get(1).diameter + 8 and s.clear[2] >= configs.get(1).height + 8)
          .to_be(true)
      end
    end
    expect(small >= 54 and small < 60).to_be(true)
    expect(big >= 95).to_be(true)
    local c = space(r, "core")
    expect(c.clear[1] >= 470 and c.clear[2] >= 150 and c.clear[3] >= 470).to_be(true)
  end)

  it("joins its halls with loops, dead ends and shafts, and no two spaces overlap", function()
    local r = gen42()
    local deg = villa_degree(r)
    local edges, nodes, dead = 0, 0, 0
    for _, d in ipairs(r.doors) do if d.class >= 4 and d.a > 0 then edges = edges + 1 end end
    for _, room in ipairs(r.rooms) do
      if room.class >= 4 then nodes = nodes + 1 end
      if room.kind == "hall" and deg[room.id] == 2 then dead = dead + 1 end -- one corridor in (two doors: its own)
    end
    -- a tree of n Villa spaces has n - 1 doors between them: more means loops
    expect(edges > nodes - 1).to_be(true)
    local leaf = 0
    for _, room in ipairs(r.rooms) do if room.kind == "hall" and deg[room.id] == 1 then leaf = leaf + 1 end end
    expect(leaf >= 1).to_be(true)
    local vertical = 0
    for _, d in ipairs(r.doors) do if d.axis == 2 then vertical = vertical + 1 end end
    expect(vertical >= 4).to_be(true)
    for i = 1, #r.rooms do
      local a0, a1 = box_of(r, r.rooms[i])
      for j = i + 1, #r.rooms do
        local b0, b1 = box_of(r, r.rooms[j])
        local cut = true
        for q = 1, 3 do if a0[q] >= b1[q] - 0.01 or b0[q] >= a1[q] - 0.01 then cut = false end end
        expect(cut).to_be(false)
      end
    end
  end)

  it("puts the heart deep: entered from the lowest level only, at least 1 km of route from the maw", function()
    local r = gen42()
    local heart = r.rooms[r.relic.core]
    expect(r.relic.route_m >= 1000).to_be(true)
    expect(#r.relic.route >= 12).to_be(true)
    expect(r.relic.route[1]).to_be(1)
    expect(r.relic.route[#r.relic.route]).to_be(heart.id)
    local into = 0
    for _, d in ipairs(r.doors) do
      if d.b == heart.id or d.a == heart.id then
        local t = r.rooms[d.a == heart.id and d.b or d.a]
        expect(t.kind).to_be("trunk")
        expect(r.rooms[t.parent].node[3]).to_be(0)
        into = into + 1
      end
    end
    expect(into >= 1).to_be(true)
    -- the route: shortest, so no other way is shorter than walking it
    local d2 = gen.route(r, kit())
    expect(d2).to_be(r.relic.route_m)
  end)

  it("keeps the Villa on the route: every big room Villa-reachable, Villa share at least 75%", function()
    local r = gen42()
    for _, room in ipairs(r.rooms) do
      if room.class >= 4 then expect(r.reach[room.id + 1] >= 4).to_be(true) end
    end
    expect(r.relic.villa_share >= 0.75).to_be(true)
  end)

  it("has the locked reliquary's branch: a 2.6 x 2.1 port, an 80 m passage with one elbow, a 12 x 8 x 12 room", function()
    local r = gen42()
    local k = kit()
    local br = r.relic.branches[1]
    local port = r.doors[br.port.door]
    expect(port.class).to_be(1)
    expect(k.doors[1][1]).to_be(2.6)
    expect(k.doors[1][2]).to_be(2.1)
    expect(br.length).to_be(80)
    expect(br.lock).to_be(1)
    expect(r.rooms[br.reliquary].kind).to_be("reliquary")
    expect(r.rooms[port.a].id).to_be(r.relic.lung)
    local A, B = r.rooms[br.rooms[1]], r.rooms[br.rooms[2]]
    expect(A.kind == "passage" and B.kind == "passage").to_be(true)
    -- one elbow: A and B run along different axes, both 4 x 4 m
    local la = A.size[1] > 1 and 1 or 3
    local lb = B.size[1] > 1 and 1 or 3
    expect(la ~= lb).to_be(true)
    expect(A.size[2] * k.cell).to_be(4)
    local q = space(r, "reliquary")
    expect(q.clear[1] >= 11 and q.clear[2] >= 7 and q.clear[3] >= 11).to_be(true)
    local lock = r.relic.locks[1]
    expect(lock.room).to_be(br.reliquary)
    expect(r.doors[lock.door].b).to_be(br.reliquary)
  end)

  it("gives every Seat branch a port, Seat-class rooms only, a chamber and a fold bay by the port", function()
    local r = gen42()
    local k = kit()
    local seat_rooms = {}
    for _, br in ipairs(r.relic.branches) do
      expect(r.doors[br.port.door].class).to_be(1)
      local b = r.relic.bays[br.bay]
      expect(b ~= nil and b.cradle ~= nil).to_be(true)
      local d = 0
      for i = 1, 3 do d = d + (b.marker[i] - br.port.pos[i]) ^ 2 end
      expect(d <= gen.BAY_REACH ^ 2).to_be(true)
      expect(b.room).to_be(r.doors[br.port.door].a)
      local has_chamber = false
      for _, id in ipairs(br.rooms) do
        seat_rooms[id] = true
        expect(r.rooms[id].class).to_be(1)
        if r.rooms[id].kind == "chamber" or r.rooms[id].kind == "reliquary" then has_chamber = true end
      end
      expect(has_chamber).to_be(true)
    end
    for _, d in ipairs(r.doors) do
      if seat_rooms[d.b] then expect(d.class).to_be(1) end
    end
    for _, id in ipairs(r.relic.chambers) do
      local c = space(r, r.rooms[id].kind)
      expect(c.clear[1] >= 11 and c.clear[2] >= 7).to_be(true)
      expect(seat_rooms[id]).to_be(true)
    end
    expect(k.dungeon.chambers[1]).to_be(15)
  end)

  it("puts fold bays of at least 44 x 20 x 44 m with cradles in the halls, four in the lung, none over a hole", function()
    local r = gen42()
    local in_lung = 0
    for _, b in ipairs(r.relic.bays) do
      expect(b.hi[1] - b.lo[1] >= 44 and b.hi[2] - b.lo[2] >= 20 and b.hi[3] - b.lo[3] >= 44).to_be(true)
      expect(b.cradle ~= nil).to_be(true)
      if b.room == r.relic.lung then in_lung = in_lung + 1 end
      local room = r.rooms[b.room]
      local mn, mx = box_of(r, room)
      expect(b.lo[1] >= mn[1] and b.hi[1] <= mx[1] and b.lo[3] >= mn[3] and b.hi[3] <= mx[3]).to_be(true)
      for _, h in ipairs(ruinm.face_holes(room, r.doors, r.rooms, kit(), r.origin, 2, -1)) do
        expect(b.lo[1] >= h[2] or b.hi[1] <= h[1] or b.lo[3] >= h[4] or b.hi[3] <= h[3]).to_be(true)
      end
    end
    expect(in_lung).to_be(4)
  end)

  it("spreads finds over the halls and chambers, three in the reliquary and the XL idol before the engine", function()
    local r = gen42()
    local hall, warren, idol = 0, 0, 0
    local per = {}
    for _, s in ipairs(r.slots) do
      if s.idol then
        idol = idol + 1
        expect(s.max_size).to_be(4)
        expect(s.room).to_be(r.relic.core)
        local e = r.solids[1]
        local inside = s.pos[1] > e[1][1] and s.pos[1] < e[2][1] and s.pos[3] > e[1][3] and s.pos[3] < e[2][3]
        expect(inside).to_be(false)
      elseif s.warren then
        warren = warren + 1
        per[s.room] = (per[s.room] or 0) + 1
        expect(s.max_size).to_be(1)
      else
        hall = hall + 1
        expect(r.rooms[s.room].kind).to_be("hall")
      end
    end
    expect(hall >= 3).to_be(true)
    expect(per[r.relic.branches[1].reliquary]).to_be(3)
    for _, id in ipairs(r.relic.chambers) do
      if r.rooms[id].kind == "chamber" then expect(per[id] >= 1 and per[id] <= 2).to_be(true) end
    end
    expect(idol).to_be(1)
  end)

  it("stands the heart's engine as a solid column, floor to ceiling, in the middle of the heart", function()
    local r = gen42()
    local e = r.solids[1]
    expect(#r.solids).to_be(1)
    expect(e.kind).to_be("engine")
    local mn, mx = box_of(r, r.rooms[r.relic.core])
    expect(e[1][2]).to_be(mn[2] + kit().wall)
    expect(e[2][2]).to_be(mx[2] - kit().wall)
    expect(math.abs((e[1][1] + e[2][1]) / 2 - (mn[1] + mx[1]) / 2) < 1e-6).to_be(true)
    expect(e[2][1] - e[1][1]).to_be(80)
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

  it("is a function of the seed: the same seed the same warren, another seed another one, quickly", function()
    local a, b = gen42(42), gen42(7)
    expect(a.hash ~= b.hash).to_be(true)
    expect(gen42(42)).to_be(a) -- memoized
    local t0 = os.clock()
    local x = gen.try(a.seed, kit(), relic.civ(), ORIGIN)
    local y = gen.try(a.seed, kit(), relic.civ(), ORIGIN)
    expect(os.clock() - t0 < 2.0).to_be(true)
    expect(x.hash).to_be(y.hash)
    expect(#x.rooms).to_be(#y.rooms)
    for i, ph in ipairs(x.relic.phenomena) do
      expect(ph.kind).to_be(y.relic.phenomena[i].kind)
      expect(ph.seed).to_be(y.relic.phenomena[i].seed)
    end
    -- twenty seeds: all valid, and not all the same shape
    local shapes = {}
    for s = 1, 20 do
      local w = gen.generate(s * 101, kit(), relic.civ(), ORIGIN)
      shapes[#w.rooms] = true
    end
    local n = 0
    for _ in pairs(shapes) do n = n + 1 end
    expect(n >= 4).to_be(true)
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
    expect(bad(function(c) c.relic.levels = 2 end)).to_be("levels")
    expect(bad(function(c) c.relic.chambers = {} end)).to_be("chambers")
    expect(bad(function(c) for _, s in ipairs(c.relic.spaces) do s.villa = false end end):match("villa") ~= nil).to_be(true)
    expect(bad(function(c) c.relic.phenomena[1].pos = { 0, 0, 0 } end)).to_be("phenomenon outside its room")
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
    k.dungeon.chambers = { 200, 300 }
    local ok, err = pcall(gen.generate, 1, k, nil, ORIGIN)
    expect(ok).to_be(false)
    expect(tostring(err):match("relic generation failed") ~= nil).to_be(true)
    for s = 100, 120 do gen.generate(s, kit(), nil, ORIGIN) end
    expect(gen.generate(42, kit(), relic.civ(), ORIGIN).relic.length >= 1000).to_be(true)
  end)

  it("finds a door's hole in the world", function()
    local r = gen42()
    local c, w, h = gen.hole(r.doors[r.relic.branches[1].port.door], kit(), ORIGIN)
    expect(w).to_be(2.6)
    expect(h).to_be(2.1)
    expect(c[2] > ORIGIN[2]).to_be(true)
  end)
end)

describe("relic phenomena", function()
  local phv = require("view.phenomena")
  it("fill the halls with strange sights from the civ's own list, four in the heart, none in the engine", function()
    local r = gen42()
    local civ = relic.civ()
    local kinds, in_heart = {}, 0
    for _, ph in ipairs(r.relic.phenomena) do
      expect(civ.language.phenomena[ph.kind] ~= nil).to_be(true)
      kinds[ph.kind] = true
      local room = r.rooms[ph.room]
      expect(room.kind == "hall" or room.kind == "trunk" or room.kind == "shaft" or room.kind == "core").to_be(true)
      if room.kind == "core" then
        in_heart = in_heart + 1
        local e = r.solids[1]
        local inside = ph.pos[1] > e[1][1] and ph.pos[1] < e[2][1] and ph.pos[3] > e[1][3] and ph.pos[3] < e[2][3]
        expect(inside).to_be(false)
      end
    end
    expect(in_heart).to_be(4)
    expect(#r.relic.phenomena >= 15).to_be(true)
    local n = 0
    for _ in pairs(kinds) do n = n + 1 end
    expect(n >= 5).to_be(true)
    -- a civ without a list gets the default eight
    local plain = gen.try(42, kit(), { id = "x" }, ORIGIN) or gen.try(saucer.seed_child(42, "retry", 1), kit(), { id = "x" }, ORIGIN)
    if plain then for _, ph in ipairs(plain.relic.phenomena) do expect(gen.PHENOMENA[ph.kind]).to_be(1) end end
  end)

  it("move only with the clock and the eye, stay in their room and never touch the state", function()
    local r = gen42()
    local k = kit()
    local seen = {}
    local base = { pos = { 0, -4000, 0 } }
    for _, kind in ipairs({ "motes", "orbit", "eye", "procession", "breath", "ripple", "shadow", "chimes" }) do
      local ph, room
      for _, p in ipairs(r.relic.phenomena) do if p.kind == kind and r.rooms[p.room].kind ~= "core" then ph = p break end end
      if not ph then
        ph = copy(r.relic.phenomena[1])
        ph.kind = kind
      end
      room = r.rooms[ph.room]
      local mn, mx = ruinm.room_box(room, k, ORIGIN)
      local m = 2 + ph.size * 1.3
      for _, t in ipairs({ 0, 3.7, 41.2, 900 }) do
        local mid = { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }
        for _, eye in ipairs({ mid, ph.pos, { mn[1] + 1, mn[2] + 1, mn[3] + 1 } }) do
          local a = phv.pose(ph, t, eye, mn, mx)
          local b = phv.pose(ph, t, eye, mn, mx)
          expect(#a > 0).to_be(true)
          for i, o in ipairs(a) do
            expect(o.pos[1]).to_be(b[i].pos[1])
            for q = 1, 3 do expect(o.pos[q] >= mn[q] - m and o.pos[q] <= mx[q] + m).to_be(true) end
            expect((o.alpha or 1) >= 0 and (o.alpha or 1) <= 1).to_be(true)
          end
          seen[kind] = true
        end
      end
    end
    -- an eye dims as the saucer comes close; a shadow is gone up close
    local ph = { kind = "eye", pos = { 0, 0, 0 }, size = 20, seed = 3, phase = 0 }
    local far = phv.pose(ph, 0, { 0, 0, 500 }, { -100, -100, -100 }, { 100, 100, 100 })[1].alpha
    local near = phv.pose(ph, 0, { 0, 0, 10 }, { -100, -100, -100 }, { 100, 100, 100 })[1].alpha
    expect(far > near).to_be(true)
    local sh = { kind = "shadow", pos = { 0, 0, 0 }, size = 10, seed = 3, phase = 0, long = 3 }
    expect(phv.pose(sh, 0, { 0, -93, 92 }, { -100, -100, -100 }, { 100, 100, 100 })[1].alpha).to_be(0)
    expect(phv.pose(sh, 0, { 0, 0, -95 }, { -100, -100, -100 }, { 100, 100, 100 })[1].alpha > 0.5).to_be(true)
    -- the state never sees them: a run with the view drawing them ends where one without does
    local st = new_state(true)
    local i = relic.site_index(st)
    local before = copy(st.players[1].ship)
    local calls = 0
    local v = { mesh = function() calls = calls + 1 end, billboard = function() calls = calls + 1 end }
    local show = {}
    for j = 1, #game.ruin(i).rooms do show[j] = 0 end
    expect(phv.draw(v, { tex = { glow = 1 } }, game.ruin(i), show, { pos = { 0, -4000, 0 } }, 12.5, {}) > 0).to_be(true)
    expect(calls > 0).to_be(true)
    for key, val in pairs(before) do
      if type(val) ~= "table" then expect(st.players[1].ship[key]).to_be(val) end
    end
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

  it("never cover a Seat port or a shaft with a cushion or a lobe", function()
    local r = gen42()
    local k = kit()
    local all = relicv.parts(r, ORIGIN)
    local checked = 0
    for _, e in ipairs(all.rooms) do
      local room = e.room
      if room.class >= 4 then
        local mn, mx = ruinm.room_box(room, k, ORIGIN)
        for _, f in ipairs({ { 1, -1 }, { 1, 1 }, { 3, -1 }, { 3, 1 }, { 2, 1 } }) do
          for _, fd in ipairs(relicv.face_doors(r, room, k, ORIGIN, f[1], f[2])) do
            if fd.door.class < 4 or f[1] == 2 then
              checked = checked + 1
              local h = fd.rect
              local pu, pv = f[1] == 2 and 1 or (f[1] == 1 and 3 or 1), f[1] == 2 and 3 or 2
              local plane = f[2] < 0 and mn[f[1]] or mx[f[1]]
              for _, list in ipairs({ e.parts, e.ext }) do
                for _, part in ipairs(list) do
                  if part.kind == "patch" then
                    local c, u, v = part.c, part.u, part.v
                    local lo = { math.min(c[1], c[1] + u[1] + v[1]), math.min(c[2], c[2] + u[2] + v[2]), math.min(c[3], c[3] + u[3] + v[3]) }
                    local hi = { math.max(c[1], c[1] + u[1] + v[1]), math.max(c[2], c[2] + u[2] + v[2]), math.max(c[3], c[3] + u[3] + v[3]) }
                    -- a patch in this face's plane (inside cushion or outside lobe) must not reach over the hole
                    if math.abs(lo[f[1]] - hi[f[1]]) < 1e-6 and math.abs(lo[f[1]] - plane) <= k.wall + 1e-6 then
                      local over = lo[pu] < h[2] - 0.01 and hi[pu] > h[1] + 0.01 and lo[pv] < h[4] - 0.01 and hi[pv] > h[3] + 0.01
                      expect(over).to_be(false)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
    expect(checked >= 20).to_be(true)
  end)

  it("build room meshes as the eye comes near, free them as it leaves, and keep what draws under the web cap", function()
    local st = new_state(true)
    local i = relic.site_index(st)
    local r = game.ruin(i)
    local site = st.sector.sites[i]
    local set = relicv.meshes(r, site.pos)
    expect(relicv.meshes(r, site.pos)).to_be(set)
    expect(set.built).to_be(0)
    -- the web's cap (design §2.3.5: 180k visible triangles) holds from every room: what it may see, built
    for j = 1, #set.rooms do relicv.ensure(set, j) end
    expect(relicv.ensure(set, 1)).to_be(set.rooms[1].tris)
    local worst = 0
    for j = 1, #set.rooms do
      local sum = 0
      for q in pairs(relicv.visible(set, j)) do sum = sum + set.rooms[q].tris end
      worst = math.max(worst, sum)
    end
    expect(worst > 0 and worst <= 180000).to_be(true)
    expect(set.triangles >= worst).to_be(true)
    for j = 1, #set.rooms do relicv.release(set, j) end
    relicv.release(set, 1)
    expect(set.built).to_be(0)
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
    -- outside, before the maw: the near rooms in full (a few a frame), the rest as hull boxes
    local cam = { pos = { door[1], door[2], door[3] - 50 }, yaw = 0, pitch = 0 }
    local stats = relicv.draw(v, A, st, cam, false, 1.5)
    for _ = 1, 6 do stats = relicv.draw(v, A, st, cam, false, 1.5) end
    expect(stats.rooms > 0).to_be(true)
    expect(stats.culled > 0).to_be(true)
    expect(calls.mats.time).to_be(1.5)
    expect(calls.mats.slots[matv.SLOT.lung].breath).to_be(matv.BREATH)
    expect(calls.billboard >= 1).to_be(true) -- the closed lock's socket
    -- inside the first hall: only the rooms a few doors on draw, and nothing far stays built
    local hall = r.relic.halls[1]
    local c = set.rooms[hall].center
    local inside
    for _ = 1, 10 do inside = relicv.draw(v, A, st, { pos = c, yaw = 0, pitch = 0 }, false, 2) end
    local vis = 0
    for _ in pairs(relicv.visible(set, hall)) do vis = vis + 1 end
    expect(inside.rooms > 0 and inside.rooms <= vis).to_be(true)
    expect(inside.tris <= 180000).to_be(true)
    local keep = relicv.around(set, hall, relicv.KEEP)
    for j, rm in ipairs(set.rooms) do
      if rm.mesh then expect(keep[j] ~= nil).to_be(true) end
    end
    expect(inside.phenomena >= 0).to_be(true)
    -- in the heart: its engine turns (three rings and a glow)
    local heart = set.rooms[r.relic.core]
    local hc = { heart.center[1], heart.center[2], heart.min[3] + 30 }
    local before = calls.mesh
    local hs
    for _ = 1, 12 do hs = relicv.draw(v, A, st, { pos = hc, yaw = 0, pitch = 0 }, false, 3) end
    expect(hs.rooms >= 1).to_be(true)
    expect(calls.mesh - before >= 12 * 4).to_be(true) -- the heart and its three rings, every frame
    expect(relicv.room_index(set, hc)).to_be(r.relic.core)
    -- far away: nothing
    local none = relicv.draw(v, A, st, { pos = { 1e5, 0, 1e5 }, yaw = 0, pitch = 0 }, false, 0)
    expect(none.rooms).to_be(0)
    relicv.idol(v, A, { 0, 0, 0 }, 0, 1, 10)
    expect(relicv.idol_mesh()).to_be(relicv.idol_mesh())
    expect(relicv.ghost_mesh()).to_be(relicv.ghost_mesh())
    expect(relicv.engine_rings()).to_be(relicv.engine_rings())
    expect(relicv.engine(v, A, { solids = {} }, 0, {})).to_be(false)
  end)
end)
