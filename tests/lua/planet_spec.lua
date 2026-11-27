-- SPDX-License-Identifier: MIT
-- add-generated-planets: a seeded body under every planet, moon and asteroid city.
-- Every `it` name is a scenario of the change's cities spec.
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local civs = require("sim.civs")
local ruinm = require("sim.ruin")
local citygen = require("sim.citygen")
local planet = require("sim.planet")
local planetv = require("view.planet")
local render = require("view.render")
local landing = require("sim.landing")
local vec = require("lib.vec")

local KITS = { "city_planet", "city_moon", "city_asteroid" }
local BODY_SECTOR = { planet = 3, moon = 4, asteroid = 2 }

local function gen(id, seed, origin)
  civs.use(42)
  return citygen.generate(seed or 777, ruinm.kit_of(id), civs.get(42, 1), origin or { 8000, 0, 4000 })
end

local function fake_view(opts)
  local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = false, texts = "", meshes = {} }
  for k, x in pairs(opts or {}) do v[k] = x end
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image", "materials" }) do
    v[m] = function(self, ...)
      self.calls[m] = (self.calls[m] or 0) + 1
      if m == "mesh" then self.meshes[#self.meshes + 1] = { ... } end
      if m == "text" then
        local s = select(3, ...)
        self.texts = self.texts .. s .. "|"
        return #s * 8
      end
      if m == "fog" then self.fogged = ... end
      if m == "materials" then return 7 end
    end
  end
  return v
end

local function new_state()
  local st = {}
  game.init(st, { seed = 42, players = 1 })
  return st
end

describe("generated planet bodies", function()
  it("a body city sits on a seeded sphere, the street tangent to it", function()
    for _, id in ipairs(KITS) do
      local r = gen(id, 777)
      local pl = planet.of(r)
      expect(pl).to_be_truthy()
      expect(pl.body).to_be(r.city.body)
      local range = planet.RADIUS[pl.body]
      expect(pl.R >= range[1] and pl.R <= range[2]).to_be_truthy()
      expect(math.abs(pl.gy - (pl.cy + pl.R))).to_be_less(0.01)
      local y = planet.height(pl, pl.cx, pl.cz)
      expect(math.abs(y - pl.gy)).to_be_less(1)
    end
  end)

  it("the same city seed always makes the same body", function()
    local a, b = planet.of(gen("city_planet", 901)), planet.of(gen("city_planet", 901))
    expect(a.R).to_be(b.R)
    expect(a.sea).to_be(b.sea)
    expect(planet.height(a, a.cx + 20000, a.cz - 8000)).to_be(planet.height(b, b.cx + 20000, b.cz - 8000))
    expect(planet.kind(a, a.cx + 20000, a.cz - 8000)).to_be(planet.kind(b, b.cx + 20000, b.cz - 8000))
    local c = planet.of(gen("city_planet", 902))
    expect(c.R ~= a.R or c.sea ~= a.sea).to_be_truthy()
  end)

  it("a planet has land and ocean, a moon has craters, an asteroid is rock", function()
    local kinds = { planet = {}, moon = {}, asteroid = {} }
    for _, id in ipairs(KITS) do
      local r = gen(id, 1201)
      local pl = planet.of(r)
      -- sample rings outside the city, clear of the sector-heart bay
      for _, rr in ipairs({ pl.rim + 8000, pl.rim + 20000, pl.R * 0.35, pl.R * 0.6 }) do
        for a = 0, 31 do
          local x = pl.cx + math.cos(a / 32 * 6.283) * rr
          local z = pl.cz + math.sin(a / 32 * 6.283) * rr
          if not planet.in_heart(pl, x, z) then
            kinds[pl.body][planet.kind(pl, x, z)] = true
          end
        end
      end
    end
    expect(kinds.planet.ocean or kinds.planet.shallow).to_be_truthy()
    expect(kinds.planet.land or kinds.planet.highland or kinds.planet.desert).to_be_truthy()
    expect(kinds.moon.ocean).to_be_falsy()
    expect(kinds.moon.land or kinds.moon.highland or kinds.moon.maria or kinds.moon.crater).to_be_truthy()
    expect(kinds.asteroid.ocean).to_be_falsy()
    expect(kinds.asteroid.land or kinds.asteroid.highland or kinds.asteroid.maria).to_be_truthy()
  end)

  it("the sector heart stays in open space, the body wraps the city's far side", function()
    local r = gen("city_planet", 777, { 8000, 0, 4000 })
    local pl = planet.of(r)
    expect(planet.in_heart(pl, 0, 0)).to_be_truthy()
    expect(planet.support_of(pl, 0, pl.gy + 100, 0)).to_be(nil)
    expect(planet.in_air(pl, { 0, pl.gy + 100, 0 })).to_be_falsy()
    -- a point on the far side of the city, away from the origin, is on the body
    local dx, dz = pl.cx, pl.cz
    local l = math.sqrt(dx * dx + dz * dz)
    local x, z = pl.cx + dx / l * (pl.rim + 8000), pl.cz + dz / l * (pl.rim + 8000)
    expect(planet.in_heart(pl, x, z)).to_be_falsy()
    expect(planet.height(pl, x, z)).to_be_truthy()
    expect(planet.support_of(pl, x, pl.gy + 500, z)).to_be_truthy()
  end)

  it("a globe and a terrain cap are built and drawn for a body city", function()
    planet.clear()
    planetv.reset()
    local r = gen("city_planet", 333, { 9000, 0, 2000 })
    local pl = planet.of(r)
    local gp, tp, ap = planetv.globe_parts(pl), planetv.terrain_parts(pl), planetv.atmo_parts(pl)
    expect(#gp).to_be(1)
    expect(#tp).to_be_greater(8)
    expect(#ap).to_be_greater(0)
    -- the globe is one high-segment sphere (the shader paints land and ocean on it)
    expect(gp[1].kind).to_be("sphere")
    expect(gp[1].seg).to_be_greater(32)
    expect(gp[1].emissive or 0).to_be_less(0.05)
    -- the cap is a smooth-shaded heightfield, not a quilt of flat tiles
    for _, part in ipairs(tp) do
      expect(part.kind).to_be("heightfield")
      expect(#part.heights).to_be((part.seg + 1) * (part.rings + 1))
    end
    for _, part in ipairs(ap) do
      expect(part.kind).to_be("sphere")
      expect(part.seg).to_be_greater(32)
    end
    local cp = planetv.cloud_parts(pl)
    expect(#cp).to_be_greater(0)
    -- neighbouring land samples do not jump on a lat/lon or tile grid
    local jumps, samples = 0, 0
    for a = 0, 63 do
      local rr = pl.rim + 12000
      local x = pl.cx + math.cos(a / 64 * 6.283) * rr
      local z = pl.cz + math.sin(a / 64 * 6.283) * rr
      local x2 = pl.cx + math.cos((a + 1) / 64 * 6.283) * rr
      local z2 = pl.cz + math.sin((a + 1) / 64 * 6.283) * rr
      if not planet.in_heart(pl, x, z) and not planet.in_heart(pl, x2, z2) then
        samples = samples + 1
        if math.abs(planet.land(pl, x, z) - planet.land(pl, x2, z2)) > 0.22 then jumps = jumps + 1 end
      end
    end
    expect(samples).to_be_greater(20)
    expect(jumps).to_be_less(8)
    local moon = planet.of(gen("city_moon", 333, { 9000, 0, 2000 }))
    expect(#planetv.atmo_parts(moon)).to_be(0)
    -- draw through the live list
    planet.live()[1] = pl
    -- hack: activate uses game.ruin; inject the record
    local v = fake_view()
    local st = { globes = 0 }
    -- build + draw the injected live body
    local s = planetv.draw(v, { pal = { base = 1 } }, { sector = { sites = {} } }, { pos = { pl.cx, pl.gy + 2000, pl.cz }, yaw = 0, pitch = -0.3, fov = 1 })
    expect(s.globes + s.terrains).to_be_greater(0)
    expect((v.calls.mesh or 0)).to_be_greater(0)
    planet.clear()
    planetv.reset()
  end)

  it("from a sector with a planet city the body is drawn and the sky billboard is hidden", function()
    local st = new_state()
    game.enter_sector(st, BODY_SECTOR.planet)
    local site
    for i, s in ipairs(st.sector.sites) do if s.city then site = i end end
    expect(site).to_be_truthy()
    planet.activate(st)
    expect(#planet.live()).to_be(1)
    expect(planet.live()[1].body).to_be("planet")
    expect(planet.hide_sky_billboard()).to_be_truthy()
    local r = game.ruin(site)
    local pl = planet.live()[1]
    -- sit over the far-side terrain, not in the heart bay
    local dx, dz = pl.cx, pl.cz
    local l = math.max(1, math.sqrt(dx * dx + dz * dz))
    st.players[1].ship.pos = { pl.cx + dx / l * (pl.rim + 4000), pl.gy + 400, pl.cz + dz / l * (pl.rim + 4000) }
    st.players[1].site = 0
    expect(planet.over(st.players[1].ship.pos)).to_be_truthy()
    expect(render.city_env(st, st.players[1])).to_be_truthy()
    local v = fake_view()
    render.render(v, st, 1)
    expect(v.calls.mesh).to_be_greater(0)
    expect(v.calls.fog).to_be(1)
    -- arrival stays in open space
    st.players[1].ship.pos = { 0, 80, -120 }
    expect(planet.over(st.players[1].ship.pos)).to_be_falsy()
    expect(planet.in_heart(pl, 0, 0)).to_be_truthy()
  end)

  it("the hull lands on and will not sink through the body's surface", function()
    planet.clear()
    local r = gen("city_planet", 444, { 10000, 0, 5000 })
    local pl = planet.of(r)
    planet.live()[1] = pl
    local dx, dz = pl.cx, pl.cz
    local l = math.max(1, math.sqrt(dx * dx + dz * dz))
    local x = pl.cx + dx / l * (pl.rim + 6000)
    local z = pl.cz + dz / l * (pl.rim + 6000)
    local y = planet.height(pl, x, z)
    expect(y).to_be_truthy()
    local g, ny = landing.ground(x, y + 20, z, 80)
    expect(g).to_be_truthy()
    expect(math.abs(g - y)).to_be_less(1)
    expect(ny).to_be(1)
    -- a probe in the heart bay finds nothing of the body
    expect(landing.ground(0, 200, 0, 80)).to_be(nil)
    local lifted = planet.clamp({ x, y - 30, z }, 8)
    expect(lifted[2]).to_be_greater(y)
    planet.clear()
  end)

  it("a moon keeps the sky's distant planet; a planet city hides it", function()
    planet.clear()
    expect(planet.hide_sky_billboard()).to_be_falsy()
    local st = new_state()
    game.enter_sector(st, BODY_SECTOR.moon)
    planet.activate(st)
    expect(#planet.live()).to_be(1)
    expect(planet.live()[1].body).to_be("moon")
    expect(planet.hide_sky_billboard()).to_be_falsy()
    game.enter_sector(st, BODY_SECTOR.planet)
    planet.activate(st)
    expect(planet.hide_sky_billboard()).to_be_truthy()
    planet.clear()
  end)
end)
