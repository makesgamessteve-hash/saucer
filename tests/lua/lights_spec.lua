-- SPDX-License-Identifier: MIT
-- add-realistic-lighting: the saucer's light switches (sim/lights.lua), the lights a frame submits
-- (view/lights.lua) and their pull on a sentry's suspicion.
local game = require("sim.game")
local lights = require("sim.lights")
local stealth = require("sim.stealth")
local lv = require("view.lights")
local hud = require("view.hud")
local vec = require("lib.vec")
-- a busted-like assert over the runner's expect()
local assert = {
  equals = function(a, b) expect(b).to_be(a) end,
  same = function(a, b) expect(b).to_equal(a) end,
  is_true = function(v) expect(v).to_be(true) end,
  is_false = function(v) expect(v).to_be(false) end,
  is_nil = function(v) expect(v).to_be(nil) end,
  is_truthy = function(v) expect(v).to_be_truthy() end,
  near = function(a, b, eps) expect(b).to_be_near(a, eps) end,
}

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state()
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  return st
end
local function run(st, c, n)
  for _ = 1, n or 1 do game.step(st, { c or cmd() }, 1 / 60) end
end
local function last_msg(p) return p.msgs[#p.msgs] and p.msgs[#p.msgs].text or "" end
-- a view that records the lights it is given
local function light_view()
  local v = { lights = {}, calls = {} }
  function v:light(l) self.lights[#self.lights + 1] = l end
  function v:lighting(t) self.base = t end
  function v:billboard() self.calls.billboard = (self.calls.billboard or 0) + 1 end
  return v
end
local function kinds(v)
  local k = {}
  for _, l in ipairs(v.lights) do k[l.kind] = (k[l.kind] or 0) + 1 end
  return k
end

describe("the saucer's light switches", function()
  it("start with the cabin lamps on and the headlights and floods off", function()
    local st = new_state()
    local p = st.players[1]
    local l = lights.of(p)
    assert.is_false(l.head)
    assert.is_false(l.flood)
    assert.is_true(l.cabin)
    local old = { mode = "helm" }
    assert.same(lights.DEFAULT, lights.of(old)) -- an older save without switches
  end)

  it("keys 4, 5 and 6 toggle headlights, floods and the cabin lamps with a message", function()
    local st = new_state()
    local p = st.players[1]
    p.mode = "helm"
    run(st, cmd({ pressed = { "headlights" } }))
    assert.is_true(p.lights.head)
    assert.equals("Headlights on", last_msg(p))
    run(st, cmd({ pressed = { "floods" } }))
    assert.is_true(p.lights.flood)
    run(st, cmd({ pressed = { "cabin_lights" } }))
    assert.is_false(p.lights.cabin)
    assert.equals("Cabin lights off", last_msg(p))
    run(st, cmd({ pressed = { "headlights" } }))
    assert.is_false(p.lights.head)
  end)

  it("the pad's light button taps for the headlights (cabin on foot in the Villa) and holds for floods", function()
    local st = new_state()
    local p = st.players[1]
    p.mode = "helm"
    run(st, cmd({ buttons = { "lights" } }), 3)
    run(st, cmd())
    assert.is_true(p.lights.head)
    assert.is_nil(p.lights_hold)
    run(st, cmd({ buttons = { "lights" } }), lights.HOLD + 5)
    assert.is_true(p.lights.flood)
    run(st, cmd())
    assert.is_true(p.lights.head) -- a hold does not also tap
    assert.equals("cabin", lights.tap_target({ mode = "walk" }))
    assert.equals("head", lights.tap_target({ mode = "helm" }))
    local w = { mode = "wake" }
    lights.step(st, w, cmd({ pressed = { "headlights" } }), nil)
    assert.is_nil(w.lights)
    assert.is_true(lights.toggle(st, w, "head"))
  end)

  it("lit up you are easier to see, but not on foot", function()
    local st = new_state()
    local p = st.players[1]
    p.mode = "helm"
    local S = stealth.tune()
    local dark = stealth.signature(p, S)
    p.lights.head = true
    local head = stealth.signature(p, S)
    p.lights.flood = true
    local both = stealth.signature(p, S)
    assert.is_true(head > dark)
    assert.is_true(both > head)
    assert.near(S.lights.head + S.lights.flood, both - dark, 1e-9)
    assert.equals(0, lights.signature({ mode = "foot", excursion = {}, lights = p.lights }, S))
    assert.equals(0, lights.signature({ mode = "helm" }, S))
    assert.equals(0, lights.signature(p, {}))
  end)

  it("the HUD shows which lights are on", function()
    assert.is_nil(hud.lights_label({}))
    assert.is_nil(hud.lights_label({ lights = { head = false, flood = false, cabin = true } }))
    assert.equals("HEADLIGHTS FLOODS CABIN OFF", hud.lights_label({ lights = { head = true, flood = true, cabin = false } }))
    assert.equals("HL", hud.lights_label({ lights = { head = true, cabin = true } }, true))
    local found = false
    for _, line in ipairs(hud.HELP) do if line:find("headlights", 1, true) then found = true end end
    assert.is_true(found)
  end)
end)

describe("the lights a frame submits", function()
  it("each sector's star is fixed by the seed and lights from above the horizon", function()
    local a, b = lv.star(42, 1), lv.star(42, 1)
    assert.equals(a, b)
    assert.near(1, vec.len(a.dir), 1e-6)
    assert.is_true(a.dir[2] > 0.2)
    local seen = {}
    for sid = 1, 40 do seen[lv.star(42, sid).kind] = true end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    assert.is_true(n >= 3)
  end)

  it("outside a star lights the scene; inside a site no sun reaches, only its coloured lamps", function()
    local st = new_state()
    local p = st.players[1]
    local v = light_view()
    local r = lv.begin(v, st, p, { pos = { 0, 5000, 0 } }, nil)
    assert.is_nil(r.inside)
    assert.equals(1, kinds(v).sun)
    assert.same(lv.AMBIENT_SPACE, v.base.ambient)
    -- a city at night and in a storm dims its star
    local v2 = light_view()
    lv.begin(v2, st, p, { pos = { 0, 5000, 0 } }, { day = 0.0, storm = 1 })
    assert.is_true(v2.lights[1].intensity < v.lights[1].intensity)
    local found
    for i, site in ipairs(st.sector.sites) do
      local ruin = game.ruin(i)
      if ruin and not found then
        local c = lv.room_lamps(ruin, site.pos, i)
        if #c.list > 0 then found = { i = i, lamp = c.list[1], c = c, ruin = ruin, site = site } end
      end
    end
    assert.is_truthy(found)
    local below = vec.add(found.lamp.pos, { 0, -0.5, 0 })
    assert.equals(found.i, lv.inside_site(st, below))
    local v3 = light_view()
    local r3 = lv.begin(v3, st, p, { pos = below }, nil)
    assert.equals(found.i, r3.inside)
    assert.is_nil(kinds(v3).sun)
    assert.same(lv.AMBIENT_INSIDE, v3.base.ambient)
    assert.equals(found.c, lv.room_lamps(found.ruin, found.site.pos, found.i)) -- cached
    assert.is_true(#lv.near(found.c, below, 20) >= 1)
    local v4 = light_view()
    local A = { tex = { glow = 1 }, pal = { base = 1 } }
    assert.is_true(lv.site_lamps(v4, A, st, below) >= 1)
    assert.equals("point", v4.lights[1].kind)
    assert.is_true((v4.calls.billboard or 0) >= 1)
    assert.equals(2, lv.sky(v4, A, below, lv.star(42, 1)))
    assert.equals(0, lv.sky(v4, { tex = {} }, below, lv.star(42, 1)))
  end)

  it("ruins, stations and cities each have their own lamp colours", function()
    assert.equals(lv.PALETTES.station, lv.palette({ kit = "station" }))
    assert.equals(lv.PALETTES.alien, lv.palette({ kit = "nonesuch" }))
    local city = lv.palette({ city = { style = { window = { 1, 0, 0 }, accent = { 0, 1, 0 } } } })
    assert.same({ 1, 0, 0 }, city[1])
    assert.equals(#lv.PALETTES.alien + 2, #city)
    assert.equals(#lv.PALETTES.alien + 2, #lv.palette({ city = {} }))
  end)

  it("a hangar bay and a station's halls are lit by their own lamps", function()
    local st = new_state()
    local dock = require("sim.dock")
    if dock.count(st) > 0 then
      local v = light_view()
      local b = dock.bay(st, 1)
      local mid = { (b.lo[1] + b.hi[1]) / 2, b.floor + 2, (b.lo[3] + b.hi[3]) / 2 }
      assert.same(b.lo, lv.inside_bay(st, mid).lo)
      local r = lv.begin(v, st, st.players[1], { pos = mid }, nil)
      assert.equals("bay", r.inside)
      assert.is_true(lv.bays(v, st, mid, 0) >= 6)
    end
    assert.is_nil(lv.inside_bay(st, { 1e6, 1e6, 1e6 }))
    local v2 = light_view()
    local L = { areas = { { kind = "nonesuch", box = { 0, 0, 30, 22 }, h = 6 }, { box = { 500, 500, 510, 510 } } } }
    assert.equals(6, lv.station_lamps(v2, L, { 15, 2, 11 }))
    for _, l in ipairs(v2.lights) do assert.equals("point", l.kind) end
    local v3 = light_view()
    lv.sentry_spot(v3, { 0, 10, 0 }, { 0, -1, 0 }, { 1, 0.2, 0.2 }, 40, 0.3)
    assert.equals("spot", v3.lights[1].kind)
    assert.is_true(v3.lights[1].inner < v3.lights[1].outer)
  end)

  it("the saucer's headlights, floods and cabin lamps follow its switches", function()
    local st = new_state()
    local p = st.players[1]
    local d = { pos = p.ship.pos, yaw = p.ship.yaw, size = p.ship.size, scale = 1 }
    local function at(dd, off) return vec.add(dd.pos, off) end
    local function count(l, eye)
      p.lights = l
      local v = light_view()
      local n = lv.saucer(v, p, d, at, eye or p.ship.pos)
      return n, kinds(v), v
    end
    local n, k = count({ head = false, flood = false, cabin = false })
    assert.equals(0, n)
    n, k = count({ head = true, flood = false, cabin = false })
    assert.equals(2, k.spot)
    local _, _, v = count({ head = true, flood = true, cabin = false })
    assert.equals(lv.owner_of(p), v.lights[1].owner)
    assert.is_true(v.lights[1].shadow)
    n, k = count({ head = false, flood = true, cabin = false })
    assert.equals(1, k.point)
    n = count({ head = false, flood = false, cabin = true })
    assert.is_true(n >= 4)
    n = count({ head = false, flood = false, cabin = true }, vec.add(p.ship.pos, { 0, 500, 0 }))
    assert.equals(0, n) -- far away nobody sees the cabin lamps
    p.lights = nil
    assert.equals(0, lv.saucer(light_view(), p, d, at, p.ship.pos))
  end)
end)

-- add-lighting-mood: pools of light with dark between them, one global dimmer, light you see in the air
describe("dark interiors and light in the air", function()
  local ruinm = require("sim.ruin")
  local function room_of(ruin, origin, pos)
    local kit = ruinm.kit_of(ruin.kit)
    for i, r in ipairs(ruin.rooms) do
      local mn, mx = ruinm.room_box(r, kit, origin)
      local inside = true
      for a = 1, 3 do inside = inside and pos[a] >= mn[a] - 0.01 and pos[a] <= mx[a] + 0.01 end
      if inside then return i end
    end
  end

  it("a derelict's rooms get one to three low pools each, and some rooms stay dark", function()
    local st = new_state()
    local dark, lit = 0, 0
    for i, site in ipairs(st.sector.sites) do
      local ruin = game.ruin(i)
      if ruin and not ruin.city then
        local c = lv.room_lamps(ruin, site.pos, i)
        local per = {}
        for _, l in ipairs(c.list) do
          local ri = room_of(ruin, site.pos, l.pos)
          assert.is_truthy(ri)
          per[ri] = (per[ri] or 0) + 1
          assert.is_true(l.range >= 7 and l.range <= 17)
          assert.near(lv.POOL_LUX * l.range * l.range, l.intensity, 1e-6)
        end
        for ri = 1, #ruin.rooms do
          local k = per[ri] or 0
          assert.is_true(k <= 3)
          if k == 0 then dark = dark + 1 else lit = lit + 1 end
        end
      end
    end
    assert.is_true(dark >= 1)
    assert.is_true(lit > dark)
  end)

  it("a city's rooms are all lit, with more and brighter pools", function()
    local st = new_state()
    local ruin, site, idx
    for i, s in ipairs(st.sector.sites) do
      local r = game.ruin(i)
      if r and not ruin and #r.rooms > 2 then ruin, site, idx = r, s, i end
    end
    assert.is_truthy(ruin)
    local city = {}
    for k, val in pairs(ruin) do city[k] = val end
    city.city = {}
    local c = lv.room_lamps(city, site.pos, idx)
    local lit = {}
    for _, l in ipairs(c.list) do
      lit[room_of(city, site.pos, l.pos)] = true
      assert.near(lv.POOL_LUX * lv.CITY_LUX * l.range * l.range, l.intensity, 1e-6)
    end
    for ri = 1, #city.rooms do assert.is_true(lit[ri] == true) end
    assert.is_true(#c.list >= #lv.room_lamps(ruin, site.pos, idx).list)
  end)

  it("placed lamps are dimmed by one global scale and glow faintly; the saucer's lights cut beams", function()
    local v = light_view()
    local L = { areas = { { kind = "nonesuch", box = { 0, 0, 30, 22 }, h = 6 } } }
    lv.station_lamps(v, L, { 15, 2, 11 })
    local old = lv.LAMP_SCALE
    lv.LAMP_SCALE = 1
    local v1 = light_view()
    lv.station_lamps(v1, L, { 15, 2, 11 })
    lv.LAMP_SCALE = old
    assert.near(v1.lights[1].intensity * old, v.lights[1].intensity, 1e-6)
    assert.near(lv.HAZE_LAMP * lv.HAZE, v.lights[1].haze, 1e-9)
    local v2 = light_view()
    lv.sentry_spot(v2, { 0, 10, 0 }, { 0, -1, 0 }, { 1, 0.2, 0.2 }, 40, 0.3)
    assert.near(lv.HAZE_SENTRY * lv.HAZE, v2.lights[1].haze, 1e-9)
    -- the saucer: headlights glow most, floods a little, cabin lamps not at all and never dimmed
    local st = new_state()
    local p = st.players[1]
    local d = { pos = p.ship.pos, yaw = p.ship.yaw, size = p.ship.size, scale = 1 }
    local function at(dd, off) return vec.add(dd.pos, off) end
    p.lights = { head = true, flood = true, cabin = true }
    local v3 = light_view()
    lv.saucer(v3, p, d, at, p.ship.pos)
    local head, flood, cabin
    for _, l in ipairs(v3.lights) do
      if l.kind == "spot" then head = l elseif l.owner then flood = l elseif l.cabin then cabin = l end
    end
    assert.near(lv.HAZE_HEAD * lv.HAZE, head.haze, 1e-9)
    assert.near(lv.HAZE_FLOOD * lv.HAZE, flood.haze, 1e-9)
    assert.is_true(head.haze > flood.haze)
    assert.near(lv.FLOOD[require("sim.config").get(d.size).id].intensity, flood.intensity, 1e-6)
    if cabin then assert.equals(0, cabin.haze) end
    -- the sun never glows
    local v4 = light_view()
    lv.begin(v4, st, p, { pos = { 0, 5000, 0 } }, nil)
    assert.is_nil(v4.lights[1].haze)
  end)
end)
