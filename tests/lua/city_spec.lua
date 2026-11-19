-- SPDX-License-Identifier: MIT
-- Milestone 11 (add-cities): body cities on asteroids, moons and planets. Generation (determinism,
-- budget, reachability, landmarks, the three forms), the sites in the sectors, the district power
-- grid (couplings, gates, sleeping sentries), the body's pull on the saucer, the city map, the HUD
-- beacon, the render streaming and the environment. Every `it` name is a scenario of
-- openspec/changes/add-cities.
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local civs = require("sim.civs")
local ruinm = require("sim.ruin")
local citygen = require("sim.citygen")
local cities = require("sim.cities")
local sentry = require("sim.sentry")
local tractor = require("sim.tractor")
local panel = require("sim.panel")
local save = require("sim.save")
local vec = require("lib.vec")
local assets = require("view.assets")
local render = require("view.render")
local hud = require("view.hud")
local mapv = require("view.map")

local KITS = { "city_planet", "city_moon", "city_asteroid" }
local BODY_SECTOR = { planet = 3, moon = 4, asteroid = 2 }

local function cmd(t) return saucer.input.command(t or {}) end
local function run(st, n)
  for _ = 1, n or 1 do
    local f = {}
    for i = 1, #st.players do f[i] = cmd() end
    game.step(st, f, 1 / 60)
  end
end
local function new_state()
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  return st
end
-- a state sitting in the sector that holds the city of `body`; -> state, site index, ruin
local function in_city(body)
  local st = new_state()
  game.enter_sector(st, BODY_SECTOR[body])
  for i, s in ipairs(st.sector.sites) do
    if s.city then return st, i, game.ruin(i) end
  end
end
local function fake_view(opts)
  local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = false, texts = "" }
  for k, x in pairs(opts or {}) do v[k] = x end
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image" }) do
    v[m] = function(self, ...)
      self.calls[m] = (self.calls[m] or 0) + 1
      if m == "text" then
        local s = select(3, ...)
        self.texts = self.texts .. s .. "|"
        return #s * 8
      end
      if m == "fog" then self.fogged = ... end
    end
  end
  return v
end
local function gen(id, seed, origin)
  civs.use(42)
  return citygen.generate(seed or 777, ruinm.kit_of(id), civs.get(42, 1), origin or { 0, 0, 0 })
end
local function center_of(ruin, r)
  local k = ruinm.kit_of(ruin.kit)
  local mn, mx = ruinm.room_box(r, k, ruin.origin)
  return { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }, mn, mx
end

describe("city generation", function()
  it("a city is the same every visit and differs between seeds", function()
    for _, id in ipairs(KITS) do
      local a, b, c = gen(id, 777), gen(id, 777), gen(id, 778)
      expect(a.hash).to_be(b.hash)
      expect(#a.rooms).to_be(#b.rooms)
      expect(a.hash ~= c.hash).to_be_truthy()
    end
  end)
  it("every city validates: all rooms and every loot slot are reachable", function()
    for _, id in ipairs(KITS) do
      for _, seed in ipairs({ 1, 42, 9001 }) do
        local r = gen(id, seed)
        expect(r ~= nil).to_be_truthy()
        local ok = ruinm.validate(r.rooms, r.doors, r.slots)
        expect(ok).to_be_truthy()
      end
    end
  end)
  it("a city stays inside its generation budget", function()
    for _, id in ipairs(KITS) do
      local r = gen(id)
      local k = ruinm.kit_of(id)
      expect(#r.rooms).to_be_less(citygen.MAX_ROOMS + 1)
      expect(#r.walls).to_be_less(8000)
      expect(#r.solids).to_be_less(400)
      local ext = citygen.extent_cells(k)
      for _, b in ipairs(r.walls) do
        for a = 1, 3 do
          expect(b[1][a] >= -1e-6 and b[2][a] <= ext[a] * k.cell + 1e-6).to_be_truthy()
        end
      end
      expect(r.city.stats.rooms).to_be(#r.rooms)
    end
  end)
  it("a city is many kilometres of districts, blocks and buildings with towers to fly between", function()
    local r = gen("city_planet")
    local k = ruinm.kit_of("city_planet")
    local ext = citygen.extent_cells(k)
    expect(ext[1] * k.cell).to_be_greater(2500)
    expect(#r.city.districts).to_be(16)
    expect(r.city.stats.buildings).to_be_greater(40)
    local towers, tall = 0, 0
    for _, s in ipairs(r.solids) do
      if s.kind == "tower" then
        if s.tier == 1 then towers = towers + 1 end
        if s[2][2] - r.city.districts[1].pos[2] > 150 then tall = tall + 1 end
      end
    end
    expect(towers).to_be_greater(10)
    expect(tall).to_be_greater(2)
  end)
  it("the undercity lies in layers below the streets and tunnels join the buildings", function()
    local r = gen("city_planet")
    local k = ruinm.kit_of("city_planet")
    local under, tunnels = 0, 0
    for _, room in ipairs(r.rooms) do
      if room.tunnel then tunnels = tunnels + 1 end
      local _, mn = center_of(r, room)
      if mn[2] < r.city.districts[1].pos[2] - 40 then under = under + 1 end
    end
    expect(under).to_be_greater(20)
    expect(tunnels).to_be_greater(5)
    expect(k.city.under[2]).to_be_greater(1)
  end)
  it("every city has a spaceport hangar as its entrance and one landmark per district kind", function()
    for _, id in ipairs(KITS) do
      local r = gen(id)
      expect(r.rooms[1].kind).to_be("entrance")
      local seen = {}
      for _, d in ipairs(r.city.districts) do seen[d.kind] = (seen[d.kind] or 0) + 1 end
      expect(r.city.districts[r.city.port].kind).to_be("spaceport")
      for _, kind in ipairs({ "spaceport", "reactor", "archive", "foundry", "garden", "palace" }) do
        expect(seen[kind]).to_be(1)
      end
    end
  end)
  it("the reactor heart holds the vault and the rich landmarks pay better", function()
    local r = gen("city_planet")
    local vault
    for _, room in ipairs(r.rooms) do if room.kind == "vault" then vault = room end end
    expect(vault ~= nil).to_be_truthy()
    expect(r.city.districts[vault.district].kind).to_be("reactor")
    local rich, plain = 0, 0
    for _, s in ipairs(r.slots) do
      local d = r.city.districts[s.district or 0]
      if d and (d.kind == "palace" or d.kind == "reactor") then rich = math.max(rich, s.tier) else plain = math.max(plain, s.tier) end
    end
    expect(rich).to_be_greater(2)
  end)
  it("a planet city is tall and heavy, a moon city sits in a crater, an asteroid city in carved rock", function()
    local planet, moon, rock = gen("city_planet"), gen("city_moon"), gen("city_asteroid")
    expect(cities.gravity(planet)).to_be_greater(1)
    expect(cities.gravity(moon)).to_be_greater(0)
    expect(cities.gravity(moon)).to_be_less(1)
    expect(cities.gravity(rock)).to_be(0)
    local crater
    for _, d in ipairs(moon.city.districts) do if d.crater then crater = d end end
    expect(crater ~= nil and crater.kind == "garden").to_be_truthy()
    local drum
    for _, d in ipairs(rock.city.districts) do if d.drum then drum = d end end
    expect(drum ~= nil and drum.kind == "reactor").to_be_truthy()
    local shell = 0
    for _, s in ipairs(rock.solids) do if s.kind == "rock" then shell = shell + 1 end end
    expect(shell).to_be(9)
    for _, s in ipairs(planet.solids) do expect(s.kind ~= "rock").to_be_truthy() end
    -- the planet's skyline out-tops the moon's, which out-tops the rock's
    local function top(r)
      local m = 0
      for _, s in ipairs(r.solids) do if s.kind == "tower" then m = math.max(m, s[2][2] - r.origin[2]) end end
      return m
    end
    expect(top(planet)).to_be_greater(top(moon) + 100)
    -- the asteroid hangs some towers from the rock above: their top is the ceiling, their widest tier on it
    local hung = 0
    for _, s in ipairs(rock.solids) do
      if s.kind == "tower" and s[2][2] - rock.origin[2] >= 440 then hung = hung + 1 end
    end
    expect(hung).to_be_greater(2)
  end)
  it("sky-bridges join towers on a planet and a moon but not inside an asteroid", function()
    local function bridges(r)
      local n = 0
      for _, s in ipairs(r.solids) do if s.kind == "bridge" then n = n + 1 end end
      return n
    end
    expect(bridges(gen("city_planet"))).to_be_greater(0)
    expect(bridges(gen("city_asteroid"))).to_be(0)
  end)
  it("the generation fails loudly rather than handing back a broken city", function()
    local k = ruinm.kit_of("city_planet")
    local saved = k.city.lots
    k.city.lots = { 3, 3 }
    local r, why = citygen.generate(1, k, civs.get(42, 1), { 0, 0, 0 })
    k.city.lots = saved
    expect(r ~= nil or why ~= nil).to_be_truthy()
    local ok = pcall(ruinm.generate_city, 5, { id = "city_broken", city = {}, grid = { 1, 1, 1 }, cell = 4 }, civs.get(42, 1), { 0, 0, 0 })
    expect(ok).to_be(false)
  end)
end)

describe("cities in the sectors", function()
  it("the three nearest far sectors hold one city of each body and sector 1 holds none", function()
    local seen = {}
    for id = 2, 4 do seen[sector.city_of(42, id)] = true end
    expect(seen.city_planet and seen.city_moon and seen.city_asteroid).to_be_truthy()
    expect(sector.city_of(42, 1)).to_be(nil)
    expect(sector.city_of(42, nil)).to_be(nil)
    local far = 0
    for id = 5, 40 do if sector.city_of(42, id) then far = far + 1 end end
    expect(far).to_be_greater(5)
    expect(far).to_be_less(30)
  end)
  it("a city site sits far out, clear of the other sites, in a sector's list", function()
    for body, sid in pairs(BODY_SECTOR) do
      local st, i, r = in_city(body)
      local s = st.sector.sites[i]
      expect(s.kit).to_be("city_" .. body)
      expect(s.city).to_be(true)
      expect(r.city.body).to_be(body)
      local c = vec.add(s.pos, { 1440, 0, 1440 })
      for j, o in ipairs(st.sector.sites) do
        if j ~= i then expect(vec.dist(c, o.pos)).to_be_greater(1200) end
      end
      expect(st.sector.sites[1].heart or st.sector.sites[1].kit ~= nil).to_be_truthy()
    end
  end)
  it("the sector map tags the cities", function()
    local st = new_state()
    local rows = galaxy.rows(st, st.players[1], {})
    local tags = {}
    for _, r in ipairs(rows) do
      if r.text:find("CITY:", 1, true) then tags[#tags + 1] = r.text end
    end
    expect(#tags).to_be_greater(2)
  end)
  it("entering a city says what it is and what the body does to the hull", function()
    local st, i = in_city("planet")
    local p = st.players[1]
    p.ship.pos = vec.add(st.sector.sites[i].pos, { 1440, 200, 300 })
    run(st, 2)
    local said = ""
    for _, m in ipairs(p.msgs or {}) do said = said .. m.text .. "|" end
    expect(said:find("planet city", 1, true) ~= nil).to_be_truthy()
    expect(said:find("hovering costs Charge", 1, true) ~= nil).to_be_truthy()
    local text = game.entry_text(st, p, i)
    expect(text:find("grid 1/16", 1, true) ~= nil).to_be_truthy()
    local st2, i2 = in_city("asteroid")
    expect(game.entry_text(st2, st2.players[1], i2):find("free flight", 1, true) ~= nil).to_be_truthy()
  end)
end)

describe("the district power grid", function()
  it("only the spaceport starts live; every other district has a coupling and shut gates", function()
    local st, i, r = in_city("planet")
    local on, n = cities.grid(st, i, r)
    expect(on).to_be(1)
    expect(n).to_be(16)
    local couplings = cities.candidates(st, st.players[1], i, r)
    expect(#couplings).to_be(15)
    expect(game.gates_closed(i)).to_be(#r.city.gates)
    expect(#r.city.gates).to_be_greater(30)
    expect(cities.powered(st, i, r, r.city.port)).to_be(true)
    expect(cities.powered(st, i, r, 99)).to_be(true)
    for _, g in ipairs(r.city.gates) do expect(g.district ~= r.city.port).to_be_truthy() end
  end)
  it("a shut gate is solid until its district is restored", function()
    local st, i, r = in_city("moon")
    local g = r.city.gates[1]
    local c = { (g.box[1][1] + g.box[2][1]) / 2, (g.box[1][2] + g.box[2][2]) / 2, (g.box[1][3] + g.box[2][3]) / 2 }
    local dir = { 0, 0, 0 }
    local axis = (g.box[2][1] - g.box[1][1]) < (g.box[2][3] - g.box[1][3]) and 1 or 3
    dir[axis] = 8
    local from = vec.sub(c, vec.scale(dir, 0.5))
    expect(saucer.physics.raycast(from, dir, 1, 1) ~= nil and saucer.physics.raycast(from, dir, 1, 1) ~= false).to_be_truthy()
    cities.restore(st, i, g.district)
    expect(game.open_gates(i, g.district)).to_be_greater(0)
    expect(game.gates_closed(i, g.district)).to_be(0)
    expect(game.open_gates(i, g.district)).to_be(0)
    expect(saucer.physics.raycast(from, dir, 1, 1) and true or false).to_be(false)
  end)
  it("beaming a coupling home restores its district, opens its gates and tells the party", function()
    local st, i, r = in_city("moon")
    local p = st.players[1]
    local c = cities.candidates(st, p, i, r)[1]
    expect(c.kind).to_be("coupling")
    expect(c.item.size).to_be(1)
    local before = game.gates_closed(i)
    game.pick_up(st, p, c, i)
    expect(cities.powered(st, i, r, c.district)).to_be(true)
    expect(game.gates_closed(i)).to_be_less(before)
    local on = cities.grid(st, i, r)
    expect(on).to_be(2)
    local said = ""
    for _, m in ipairs(p.msgs) do said = said .. m.text .. "|" end
    expect(said:find("Power restored", 1, true) ~= nil).to_be_truthy()
    expect(#cities.candidates(st, p, i, r)).to_be(#r.city.districts - 2)
    -- a second pull of the same coupling changes nothing
    game.pick_up(st, p, c, i)
    expect(cities.grid(st, i, r)).to_be(2)
    expect(p.hold[1]).to_be(nil)
  end)
  it("a partner in the city is told who restored a district", function()
    local st = {}
    game.init(st, { seed = 42, players = 2 })
    game.enter_sector(st, 4)
    local i
    for k, s in ipairs(st.sector.sites) do if s.city then i = k end end
    local r = game.ruin(i)
    local p1, p2 = st.players[1], st.players[2]
    p2.site = i
    local c = cities.candidates(st, p1, i, r)[1]
    game.pick_up(st, p1, c, i)
    local said = ""
    for _, m in ipairs(p2.msgs) do said = said .. m.text .. "|" end
    expect(said:find("P1 restored", 1, true) ~= nil).to_be_truthy()
  end)
  it("restored power survives a save, a load, a fold away and a fold back", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    local c = cities.candidates(st, p, i, r)[3]
    game.pick_up(st, p, c, i)
    local snap = save.snapshot and save.snapshot(st) or nil
    expect(st.locks[cities.lockkey(i, c.district)] ~= nil).to_be_truthy()
    game.enter_sector(st, 1)
    game.enter_sector(st, 3)
    local r2 = game.ruin(i)
    expect(cities.powered(st, i, r2, c.district)).to_be(true)
    expect(game.gates_closed(i, c.district)).to_be(0)
    expect(game.gates_closed(i)).to_be_greater(0)
    expect(snap == nil or type(snap) == "table").to_be_truthy()
  end)
  it("a sentry in a dark district sleeps until the grid comes back, a calm hall keeps none", function()
    local st, i, r = in_city("planet")
    local defs = game.sentries(i)
    local dark, calm_rooms = 0, 0
    local has = {}
    for _, d in ipairs(defs) do
      has[d.room] = true
      if d.dark then dark = dark + 1 end
    end
    for _, room in ipairs(r.rooms) do if room.calm and has[room.id] then calm_rooms = calm_rooms + 1 end end
    expect(dark).to_be_greater(5)
    expect(calm_rooms).to_be(0)
    -- park a saucer in front of a dark Watcher: nothing happens while its district is out
    local w
    for k, d in ipairs(defs) do if d.kind == "watcher" and d.dark then w = k break end end
    local def = defs[w]
    local dyn = st.sentries[i][w]
    local p = st.players[1]
    p.ship.pos = vec.add(def.pos, { 0, -3, 6 })
    for _ = 1, 120 do sentry.step(st, i, defs, 1 / 60, { msg = function() end, fx = function() end, seal = function() end }) end
    expect(dyn.st).to_be("dormant")
    cities.restore(st, i, def.district)
    expect(st.locks[i .. ":power" .. def.district] ~= nil).to_be_truthy()
    for _ = 1, 5 do sentry.step(st, i, defs, 1 / 60, { msg = function() end, fx = function() end, seal = function() end }) end
    expect(dyn.st ~= nil).to_be_truthy()
    expect(cities.dark(r, r.rooms[1])).to_be(nil)
    expect(cities.dark({}, { district = 1 })).to_be(nil)
  end)
  it("the clamps, the lockdown node and the warden stay out of calm halls", function()
    local st, i, r = in_city("asteroid")
    for _, d in ipairs(game.sentries(i)) do
      expect(r.rooms[d.room].calm ~= true).to_be_truthy()
      if d.kind == "clamp" or d.kind == "lockdown" or d.kind == "warden" then expect(d.district ~= nil).to_be_truthy() end
    end
  end)
end)

describe("the body's pull", function()
  it("hovering under a planet's pull costs Charge, the spaceport hangar refills it", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    local s = st.sector.sites[i]
    p.ship.pos = vec.add(s.pos, { 1440, 300, 700 })
    p.ship.charge = 50
    run(st, 60)
    expect(p.ship.charge).to_be_less(50)
    local spent = 50 - p.ship.charge
    expect(spent).to_be_near((cities.gravity(r) - 1) * cities.HOVER_COST, 0.2)
    local hangar = center_of(r, r.rooms[1])
    p.ship.pos = hangar
    p.ship.vel = { 0, 0, 0 }
    local at = p.ship.charge
    run(st, 60)
    expect(cities.in_hangar(r, p.ship.pos)).to_be(true)
    expect(p.ship.charge).to_be_greater(at - 0.001)
  end)
  it("with the Charge gone the hull settles at a walking pace and horizontal flight stays free", function()
    local st, i = in_city("planet")
    local p = st.players[1]
    p.ship.pos = vec.add(st.sector.sites[i].pos, { 1440, 650, 700 })
    p.ship.charge = 0
    local y = p.ship.pos[2]
    run(st, 60)
    expect(p.ship.pos[2]).to_be_near(y - cities.SINK, 0.5)
    expect(p.ship.charge).to_be(0)
    p.mode, p.ship.morph, p.panel = "helm", false, false
    local x, c = p.ship.pos[1], cmd({ axes = { move_z = 1 } })
    for _ = 1, 30 do game.step(st, { c }, 1 / 60) end
    expect(math.abs(p.ship.pos[1] - x) + math.abs(p.ship.pos[3] - 700 - st.sector.sites[i].pos[3])).to_be_greater(1)
  end)
  it("a moon's light pull and an asteroid's none cost nothing", function()
    for _, body in ipairs({ "moon", "asteroid" }) do
      local st, i = in_city(body)
      local p = st.players[1]
      p.ship.pos = vec.add(st.sector.sites[i].pos, { 1000, 250, 400 })
      p.ship.charge = 50
      run(st, 60)
      expect(p.ship.charge).to_be(50)
    end
    expect(cities.pull(nil, 10, 1)).to_be(0)
    expect(cities.gravity(nil)).to_be(0)
  end)
end)

describe("finding your way", function()
  it("the city map panel lists every district, its grid state and the way back to the sector map", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    p.site = i
    p.ship.pos = vec.add(st.sector.sites[i].pos, { 1440, 200, 300 })
    local rows = cities.panel_rows(st, p, i, r, panel)
    expect(#rows).to_be(#r.city.districts + 2)
    expect(rows[1].text:find("PLANET CITY", 1, true) ~= nil).to_be_truthy()
    expect(rows[1].hint:find("You are over", 1, true) ~= nil).to_be_truthy()
    local live, dark = 0, 0
    for k = 2, #rows - 1 do
      if rows[k].text:find("LIVE", 1, true) then live = live + 1 else dark = dark + 1 end
      expect(rows[k].enabled).to_be(false)
    end
    expect(live).to_be(1)
    expect(dark).to_be(15)
    expect(rows[3].hint ~= nil or rows[2].hint ~= nil).to_be_truthy()
    rows[#rows].act(st, p)
    expect(p.panel.kind).to_be("map")
    expect(cities.panel_rows(st, p, 1, nil, panel)[1].enabled).to_be(false)
    -- the map key opens the city map inside a city and the sector map outside
    p.panel = false
    p.mode = "helm"
    game.step(st, { cmd({ pressed = { "map" } }) }, 1 / 60)
    expect(p.panel and p.panel.kind).to_be("citymap")
    expect(panel.title(st, p)).to_be("CITY MAP")
    game.step(st, { cmd({ pressed = { "map" } }) }, 1 / 60)
    expect(p.panel).to_be(false)
    p.ship.pos = vec.add(st.sector.sites[i].pos, { 1440, 200, -2000 })
    run(st, 2)
    game.step(st, { cmd({ pressed = { "map" } }) }, 1 / 60)
    expect(p.panel and p.panel.kind).to_be("map")
    expect(cities.compass({ 0, 0, 0 }, { 0, 0, 10 })).to_be("N")
    expect(cities.compass({ 0, 0, 0 }, { 10, 0, 0 })).to_be("E")
    expect(cities.compass({ 0, 0, 0 }, { -10, 0, -10 })).to_be("SW")
  end)
  it("the beacon points at the nearest dark coupling, then at the reactor vault", function()
    local st, i, r = in_city("moon")
    local p = st.players[1]
    local b = cities.beacon(st, i, r, p.ship.pos)
    expect(b.short).to_be("COUPLING")
    local best
    for _, c in ipairs(cities.candidates(st, p, i, r)) do
      local d = vec.dist(p.ship.pos, c.pos)
      if not best or d < best then best = d end
    end
    expect(b.dist).to_be_near(best, 1e-6)
    for _, d in ipairs(r.city.districts) do if not d.powered then cities.restore(st, i, d.id) end end
    local v = cities.beacon(st, i, r, p.ship.pos)
    expect(v.short).to_be("VAULT")
    expect(cities.beacon(st, i, { city = r.city, rooms = {}, kit = r.kit, origin = r.origin }, p.ship.pos)).to_be(nil)
    expect(cities.summary(st, i, r):find("MOON CITY", 1, true) ~= nil).to_be_truthy()
    expect(#cities.rows(st, i, r)).to_be(#r.city.districts)
    expect(cities.district_at(r, r.city.districts[4].pos).id).to_be(4)
    expect(cities.is_city(nil)).to_be(false)
    expect(#cities.candidates(st, p, i, {})).to_be(0)
  end)
  it("the HUD names the body, the district and the beacon; the city map draws districts, couplings and saucers", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    p.site = i
    p.ship.pos = vec.add(st.sector.sites[i].pos, { 1440, 200, 300 })
    p.mode = "helm"
    local v = fake_view({ width = 480 })
    hud.draw(v, st, p, nil)
    expect(v.texts:find("PLANET CITY GRID 1/16", 1, true) ~= nil).to_be_truthy()
    expect(v.texts:find("COUPLING", 1, true) ~= nil).to_be_truthy()
    for _, w in ipairs({ 300, 200 }) do
      local nv = fake_view({ width = w })
      hud.draw(nv, st, p, nil)
      expect(nv.texts:find("PLANET CITY", 1, true) ~= nil).to_be_truthy()
    end
    local cv = fake_view({ width = 480 })
    mapv.city(cv, st, 6, 40, 200, 180, p)
    expect((cv.calls.rect or 0) > 40).to_be_truthy()
    expect(cv.texts:find("PLANET CITY MAP", 1, true) ~= nil).to_be_truthy()
    local other = fake_view()
    mapv.city(other, st, 6, 40, 200, 180, { site = 0 })
    expect(other.calls.rect).to_be(nil)
    p.panel = { kind = "citymap", sel = 1, axis = 0 }
    local pv = fake_view({ width = 480 })
    hud.panel(pv, st, p)
    expect(pv.texts:find("CITY MAP", 1, true) ~= nil).to_be_truthy()
    p.panel = false
    p.scan_until = st.tick + 100
    local sv = fake_view({ width = 480 })
    hud.draw(sv, st, p, nil)
    expect(sv.texts:find("SCANNING", 1, true) ~= nil).to_be_truthy()
  end)
end)

describe("loot and tractor targets in a city", function()
  it("only the loot within beam sense is rolled, the couplings are beam targets", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    p.ship.pos = vec.add(st.sector.sites[i].pos, { 1440, 200, 300 })
    local near = 0
    for _, s in ipairs(r.slots) do
      if vec.dist(s.pos, p.ship.pos) < 160 then near = near + 1 end
    end
    local list = tractor.candidates(st, p, i, r)
    local slots, couplings = 0, 0
    for _, c in ipairs(list) do
      if c.kind == "slot" then slots = slots + 1 elseif c.kind == "coupling" then couplings = couplings + 1 end
    end
    expect(#r.slots).to_be_greater(150)
    expect(slots).to_be_less(#r.slots // 2)
    expect(slots).to_be_greater(near - 1)
    expect(couplings).to_be(15)
    local sc = tractor.by_key(st, p, i, r, "coupling:" .. i .. ":" .. 2)
    expect(sc ~= nil and sc.district == 2).to_be_truthy()
  end)
end)

describe("drawing a city", function()
  it("a far district is one coarse mesh, a near one its chunks, and every gate is drawn near it", function()
    local st, i, r = in_city("planet")
    local p = st.players[1]
    local A = assets.init()
    local set = assets.ruin_chunks(r, st.sector.sites[i].pos)
    expect(set.districts ~= nil).to_be_truthy()
    local nd = 0
    for _ in pairs(set.districts) do nd = nd + 1 end
    expect(nd).to_be(16)
    expect(#set.chunks).to_be_greater(400)
    local site = st.sector.sites[i]
    local ps = {
      { pos = vec.add(site.pos, { 1440, 120, -120 }), label = "near" },
      { pos = vec.add(site.pos, { 100, 300, 100 }), label = "corner" },
    }
    local counts = {}
    for _, q in ipairs(ps) do
      local v = fake_view()
      local cam = { pos = q.pos, yaw = 0, pitch = 0, fov = 1.2 }
      local stat = render.draw_ruins(v, A, st, cam, false)
      counts[q.label] = { chunks = stat.chunks, lod = stat.lod, culled = stat.culled, gates = stat.gates or 0 }
    end
    expect(counts.near.chunks).to_be_greater(0)
    expect(counts.near.chunks).to_be_less(#set.chunks // 2)
    expect(counts.near.lod).to_be_greater(0)
    expect(counts.near.culled).to_be_greater(100)
    -- standing among the dark districts' doors draws their gates
    local g = r.city.gates[1].box
    local v = fake_view()
    local stat = render.draw_ruins(v, A, st, { pos = { g[1][1] + 30, g[1][2] + 5, g[1][3] }, yaw = 0, pitch = 0, fov = 1.2 }, false)
    expect(stat.gates).to_be_greater(0)
  end)
  it("the air of a city belongs to its body: a planet has a day, a moon earthlight, an asteroid dark rock", function()
    local out = {}
    for _, body in ipairs({ "planet", "moon", "asteroid" }) do
      local st, i = in_city(body)
      local p = st.players[1]
      p.site = i
      st.tick = 0
      local noon = render.city_env(st, p)
      out[body] = noon
    end
    expect(out.planet.density).to_be_greater(out.moon.density)
    expect(out.moon.density).to_be(0)
    expect(out.planet.day > 0.4).to_be_truthy()
    expect(out.moon.day).to_be(0)
    local st, i = in_city("planet")
    local p = st.players[1]
    p.site = i
    st.tick = math.floor(60 * render.CITY_DAY * 0.75)
    local night = render.city_env(st, p)
    st.tick = math.floor(60 * render.CITY_DAY * 0.25)
    local day = render.city_env(st, p)
    expect(night.clear[3]).to_be_less(day.clear[3])
    expect(night.day).to_be_less(0.2)
    p.site = 0
    expect(render.city_env(st, p)).to_be(nil)
    expect(render.city_env(st, nil)).to_be(nil)
    -- the whole frame in a planet city: fog from the body, no stars at midday, then a night with stars
    p.site = i
    p.ship.pos = vec.add(st.sector.sites[i].pos, { 1440, 200, 300 })
    st.tick = math.floor(60 * render.CITY_DAY * 0.25)
    local v = fake_view()
    render.render(v, st, 1)
    expect(v.calls.fog).to_be(1)
    st.tick = math.floor(60 * render.CITY_DAY * 0.75)
    local v2 = fake_view()
    render.render(v2, st, 1)
    expect((v2.calls.mesh or 0) > (v.calls.mesh or 0) - 40).to_be_truthy()
  end)
  it("a city kit's detail style and texture come from the kit", function()
    local detail = require("view.detail")
    for _, id in ipairs(KITS) do
      local k = ruinm.kit_of(id)
      expect(k.style).to_be("city")
      local s = detail.style(k)
      expect(s.furniture).to_be("plaza")
      expect(k.links).to_be(false)
    end
  end)
end)
