-- SPDX-License-Identifier: MIT
-- add-relic-locks (plan phase 9): a relic's foot pockets and its locks (sim/relicfoot.lua) -- pockets by the
-- builders' body scale off Seat chambers (never the route, a hall or the heart), short crawlspaces no saucer fits,
-- the hand-lock sealing at most 15% of the value, 60-75% Seat-locks, at most one guarded pocket, lore niches.
local game = require("sim.game")
local ruinm = require("sim.ruin")
local relic = require("sim.relic")
local relicfoot = require("sim.relicfoot")
local relicloot = require("sim.relicloot")
local relicsentry = require("sim.relicsentry")
local ex = require("sim.excursion")
local shipm = require("sim.ship")

local SEEDS = { 42, 7, 1234, 99, 5, 2024 }
local function far_relic(seed)
  local st = {}
  game.init(st, { seed = seed, players = 1 })
  game.enter_sector(st, 3)
  for i, s in ipairs(st.sector.sites) do
    if s.kit == "relic" then return st, i, s, game.ruin(i) end
  end
end
local cache = {}
local function relic_of(seed)
  if not cache[seed] then cache[seed] = { far_relic(seed) } end
  return table.unpack(cache[seed])
end
local function quiet(log)
  return { msg = function(_, _, t) if log then log[#log + 1] = t end end, fx = function() end }
end

describe("relic foot pockets", function()
  it("counts pockets by the builders' body scale", function()
    expect(relicfoot.count({ axes = { body_scale = "tiny" } })).to_be(3)
    expect(relicfoot.count({ axes = { body_scale = "human" } })).to_be(2)
    expect(relicfoot.count({ axes = { body_scale = "giant" } })).to_be(1)
    expect(relicfoot.count({ axes = { body_scale = "colossal" } })).to_be(1)
    expect(relicfoot.count({})).to_be(2)
    expect(relicfoot.count(nil)).to_be(2)
    for _, seed in ipairs(SEEDS) do
      local _, _, site, r = relic_of(seed)
      local n = relicfoot.count(game.civ_of(site))
      expect(r.foot ~= nil).to_be(true)
      expect(#r.foot.pockets >= 1 and #r.foot.pockets <= n).to_be(true)
      expect(#r.relic.pocket_list).to_be(#r.foot.pockets)
    end
  end)

  it("opens pockets off Seat chambers only, never the route, a hall or the heart", function()
    for _, seed in ipairs(SEEDS) do
      local _, _, _, r = relic_of(seed)
      local halls = {}
      for _, h in ipairs(r.relic.halls) do halls[h] = true end
      local guarded = 0
      for _, pk in ipairs(r.foot.pockets) do
        local host = r.rooms[pk.host]
        expect(host.kind).to_be("chamber")
        expect(halls[pk.host]).to_be(nil)
        expect(pk.host ~= r.relic.core).to_be(true)
        expect(r.rooms[pk.crawl_room].kind).to_be("crawl")
        expect(r.rooms[pk.pocket_room].kind).to_be("pocket")
        if pk.guarded then guarded = guarded + 1 end
      end
      expect(guarded <= relicfoot.MAX_GUARDED).to_be(true)
    end
  end)

  it("keeps every pocket a short walk down a channel no saucer fits", function()
    local kit = ruinm.kit_of("relic")
    for _, seed in ipairs(SEEDS) do
      local _, _, _, r = relic_of(seed)
      for _, pk in ipairs(r.foot.pockets) do
        expect(pk.length <= 60).to_be(true)
        local C = r.rooms[pk.crawl_room]
        local cells = math.max(C.size[1], C.size[3])
        expect(cells >= relicfoot.CRAWL[1] and cells <= relicfoot.CRAWL[2]).to_be(true)
        expect(cells * kit.cell >= 8 and cells * kit.cell <= 30).to_be(true)
        expect(pk.channel.w).to_be(1.0)
        expect(pk.channel.h).to_be(1.0)
        expect(#pk.route).to_be(4)
        expect(pk.role ~= nil).to_be(true)
      end
    end
  end)

  it("seals at most 15% of the value behind the hand-lock and keeps 60-75% Seat-locks", function()
    for _, seed in ipairs(SEEDS) do
      local _, _, site, r = relic_of(seed)
      local total, value = 0, {}
      for _, s in ipairs(r.slots) do
        local v = relicloot.value(s)
        total = total + v
        value[s.room] = (value[s.room] or 0) + v
      end
      local f = r.foot
      expect(#f.locks <= 1).to_be(true)
      local nests = {}
      for k, br in ipairs(relicsentry.branches(r)) do if k <= relicsentry.SNATCHERS then nests[br.chamber.id] = true end end
      if f.gated then
        expect((value[f.gated] or 0) <= total * relicfoot.HAND_SHARE + 1e-6).to_be(true)
        expect(nests[f.gated]).to_be(nil)
        expect(f.gated ~= r.relic.core).to_be(true)
        expect(f.pockets[1].role).to_be("lock")
        expect(f.shutters[1].room).to_be(f.gated)
      end
      local seats = 0
      for _, l in ipairs(r.relic.locks) do
        expect(l.kind).to_be("seat")
        seats = seats + 1
        if l.chamber then expect(nests[l.room]).to_be(nil) end
      end
      local share = seats / (seats + #f.locks)
      expect(share >= 0.6 and share <= 0.75 or #f.locks == 0).to_be(true)
      expect(site.relic).to_be(true)
    end
  end)

  it("derives once per generated ruin and leaves the generated ruin as it was", function()
    local st, _, site = relic_of(42)
    local gen = ruinm.generate(site.seed, site.kit, game.civ_of(site), site.pos, nil, site.first)
    local n = #gen.rooms
    local d1 = relicfoot.derive(site, gen, game.civ_of(site), st.seed)
    local d2 = relicfoot.derive(site, gen, game.civ_of(site), st.seed)
    expect(d1).to_be(d2)
    expect(#gen.rooms).to_be(n)
    expect(gen.foot).to_be(nil)
    expect(#d1.rooms > n).to_be(true)
    expect(relicfoot.apply(site, d1, nil, 1)).to_be(d1) -- once only
    expect(relicfoot.derive(site, nil)).to_be(nil)
    local plain = { rooms = {} }
    expect(relicfoot.derive(site, plain)).to_be(plain)
  end)

  it("gives the slice relic pockets too, with the Vyrr's own lore fallback", function()
    local st = {}
    game.init(st, { seed = 42, players = 1, relic_slice = true })
    local i = relic.site_index(st)
    local r = game.ruin(i)
    expect(#r.foot.pockets >= 1).to_be(true)
    local text
    for _, n in ipairs(r.foot.niches) do text = n.text end
    if text then expect(type(text)).to_be("string") end
  end)

  it("reads a lore niche's glyphs by hand and names the pocket room", function()
    local found
    for seed = 1, 60 do
      local st, i, _, r = far_relic(seed)
      if r and r.foot and #r.foot.niches > 0 then found = { st, i, r } break end
    end
    expect(found ~= nil).to_be(true)
    local st, i, r = found[1], found[2], found[3]
    local n = r.foot.niches[1]
    expect(#n.text > 10).to_be(true)
    local pk = r.foot.pockets[n.pocket]
    expect(pk.role).to_be("lore")
    local p = st.players[1]
    p.site = i
    local K = pk.route[4]
    p.mode = "foot"
    p.hands = {}
    p.excursion = { site = i, body = { pos = { K[1], K[2], K[3] }, yaw = 0, pitch = 0, crouch = false }, area = "hall",
                    coin = "pocket" }
    expect(ex.area(st, p)).to_be("pocket")
    p.excursion.body.pos = { pk.route[2][1], pk.route[2][2], pk.route[2][3] }
    p.excursion.body.crouch = true
    expect(ex.area(st, p)).to_be("crawl")
    p.excursion.body.crouch = false
    p.excursion.body.pos = { n.pos[1], n.pos[2] - 1.6, n.pos[3] }
    local t = ex.reach(st, p)
    expect(t ~= nil and t.kind).to_be("lore")
    local _, prompt = ex.status(st, p)
    expect(prompt).to_be("USE: READ THE GLYPHS")
    local log = {}
    expect(ex.use(st, p, quiet(log))).to_be(true)
    expect(p.lore_read).to_be(1)
    expect(log[1]).to_be(n.text)
    expect(ex.AREA_MSG.pocket ~= nil).to_be(true)
  end)

  it("says which door a Seat-lock opened, and the hand-lock opens a relic chamber", function()
    local st = {}
    game.init(st, { seed = 42, players = 1, relic_slice = true })
    local i = relic.site_index(st)
    local r = game.ruin(i)
    local p = st.players[1]
    local lock
    for _, l in ipairs(r.relic.locks) do if l.chamber then lock = l end end
    expect(lock ~= nil).to_be(true)
    p.site = i
    p.ship.size = 2
    p.ship.pos = shipm.center_for_eye({ lock.socket[1], lock.socket[2], lock.socket[3] - 1 }, 0, 2)
    p.ship.yaw = 0
    local held = { held = function(_, nm) return nm == "use" end }
    local log = {}
    expect(relic.socket_near(st, p)).to_be(lock)
    relic.lock_step(st, p, held, 1.0, quiet(log))
    expect(relic.lock_step(st, p, held, 1.0, quiet(log))).to_be(true)
    expect(log[#log]).to_be("The Seat-lock turns: the sealed chamber opens")
    expect(r.foot.locks[1] ~= nil).to_be(true)
    local hl = {}
    ex.open_lock(st, p, i, 1, quiet(hl))
    expect(hl[1]:find("sealed chamber grinds open", 1, true) ~= nil).to_be(true)
    expect(game.shutter_closed(i, 1)).to_be(false)
  end)
end)
