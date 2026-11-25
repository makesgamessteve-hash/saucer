-- SPDX-License-Identifier: MIT
-- add-relic-stations (plan phase 8): relics in normal play -- placed in far sectors, guarded, their loot spread,
-- their explored rooms and scans kept in the state (and in saves), their decay drawn from the civ's fate.
local game = require("sim.game")
local sector = require("sim.sector")
local galaxy = require("sim.galaxy")
local civs = require("sim.civs")
local ruinm = require("sim.ruin")
local relic = require("sim.relic")
local relicloot = require("sim.relicloot")
local relicsentry = require("sim.relicsentry")
local save = require("sim.save")
local decay = require("view.relicdecay")
local relicmap = require("view.relicmap")

local function relic_sites(s)
  local out = {}
  for i, site in ipairs(s.sites) do if site.kit == "relic" then out[#out + 1] = i end end
  return out
end
local function in_sector(sid, seed)
  local st = {}
  game.init(st, { seed = seed or 42, players = 1 })
  if sid ~= 1 then game.enter_sector(st, sid) end
  return st
end
local function quiet() return { msg = function() end, fx = function() end } end
local function into(st, i, id)
  local r = game.ruin(i)
  local kit = ruinm.kit_of(r.kit)
  local mn, mx = ruinm.room_box(r.rooms[id], kit, r.origin)
  local p = st.players[1]
  p.ship.pos = { (mn[1] + mx[1]) / 2, mn[2] + kit.wall + 6, (mn[3] + mx[3]) / 2 }
  p.site = i
  return p
end

describe("relics in far sectors", function()
  it("sector RELIC_FIRST always holds one; home and the Heart never do; others by chance", function()
    for _, seed in ipairs({ 42, 7, 1234, 99, 5, 2024 }) do
      civs.use(seed)
      local g = galaxy.generate(seed)
      local n = 0
      for sid = 1, #g.sectors do
        local info = g.sectors[sid]
        local s = sector.generate(seed, sid, info)
        local rs = relic_sites(s)
        expect(#rs <= 1).to_be(true)
        if sid == 1 or info.heart then expect(#rs).to_be(0) end
        if sid == sector.RELIC_FIRST and not info.heart then expect(#rs).to_be(1) end
        if #rs == 1 then
          n = n + 1
          local site = s.sites[rs[1]]
          expect(rs[1]).to_be(#s.sites)   -- appended last: every other site index unchanged
          expect(site.relic).to_be(true)
          local found = false
          for _, ci in ipairs(info.civs) do if ci == site.civ then found = true end end
          expect(found).to_be(true)
        end
      end
      expect(n >= 1).to_be(true)
    end
  end)
  it("a sector's other sites are as they were without the relic", function()
    civs.use(42)
    local g = galaxy.generate(42)
    local with = sector.generate(42, 3, g.sectors[3])
    local keep = sector.relic_site
    sector.relic_site = function() return nil end
    local without = sector.generate(42, 3, g.sectors[3])
    sector.relic_site = keep
    expect(#with.sites).to_be(#without.sites + 1)
    for i, s in ipairs(without.sites) do
      expect(with.sites[i].seed).to_be(s.seed)
      expect(with.sites[i].pos[1]).to_be(s.pos[1])
      expect(with.sites[i].pos[3]).to_be(s.pos[3])
    end
  end)
  it("the relic's build box keeps RELIC_MARGIN from every other site and the station", function()
    for _, seed in ipairs({ 42, 1234 }) do
      civs.use(seed)
      local g = galaxy.generate(seed)
      for sid = 2, #g.sectors do
        local s = sector.generate(seed, sid, g.sectors[sid])
        for _, i in ipairs(relic_sites(s)) do
          local site = s.sites[i]
          local ext = sector.relic_extent(civs.get(seed, site.civ))
          local lo, hi = site.pos, { site.pos[1] + ext[1], site.pos[2] + ext[2], site.pos[3] + ext[3] }
          for j, o in ipairs(s.sites) do
            if j ~= i and not o.city then
              local d = 0
              for k = 1, 3 do
                local c = o.pos[k]
                if c < lo[k] then d = d + (lo[k] - c) ^ 2 elseif c > hi[k] then d = d + (c - hi[k]) ^ 2 end
              end
              expect(math.sqrt(d) > sector.RELIC_MARGIN).to_be(true)
            end
          end
          local tp = s.trader.pos
          local inside = tp[1] > lo[1] and tp[1] < hi[1] and tp[3] > lo[3] and tp[3] < hi[3]
          expect(inside).to_be(false)
        end
      end
    end
  end)
  it("relic_of refuses home and a missing sector id", function()
    expect(sector.relic_of(42, 1, {})).to_be(nil)
    expect(sector.relic_of(42, nil, {})).to_be(nil)
    expect(sector.relic_of(42, 5, { heart = true })).to_be(nil)
    expect(sector.relic_of(42, 2, { civs = { 1 } })).to_be(nil)
    expect(sector.relic_of(42, 3, nil)).to_be(1)
  end)
  it("a relic's extent: a styled civ gets the archetypes' grid", function()
    local e = sector.relic_extent(civs.vyrr())
    expect(#e).to_be(3)
    expect(e[1] > 0 and e[2] > 0 and e[3] > 0).to_be(true)
  end)
end)

describe("relic sentries", function()
  it("Watchers in halls, Snatchers on Seat branches, Spotters at junctions; the heart and the maw's hall calm", function()
    local st = in_sector(3)
    local i = relic_sites(st.sector)[1]
    local r = game.ruin(i)
    local c, rooms = {}, {}
    for _, d in ipairs(game.sentries(i)) do
      c[d.kind] = (c[d.kind] or 0) + 1
      if d.room then rooms[d.room] = true end
    end
    expect((c.watcher or 0) >= 1).to_be(true)
    expect((c.watcher or 0) <= relicsentry.WATCHERS).to_be(true)
    expect((c.snatcher or 0) >= 1).to_be(true)
    expect((c.snatcher or 0) <= relicsentry.SNATCHERS).to_be(true)
    expect((c.spotter or 0) <= relicsentry.SPOTTERS).to_be(true)
    expect(rooms[r.relic.core]).to_be(nil)
    expect(rooms[r.relic.halls[1]]).to_be(nil)
  end)
  it("the slice's relic keeps no sentries; branches run from a hall to a chamber", function()
    local st = {}
    game.init(st, { seed = 42, players = 1, relic_slice = true })
    for i, s in ipairs(st.sector.sites) do
      if s.kit == "relic" then expect(#game.sentries(i)).to_be(0) end
    end
    civs.use(42)
    local g = galaxy.generate(42)
    local s = sector.generate(42, 3, g.sectors[3])
    local site = s.sites[relic_sites(s)[1]]
    local r = ruinm.generate(site.seed, site.kit, civs.get(42, site.civ), site.pos)
    local br = relicsentry.branches(r)
    expect(#br >= 1).to_be(true)
    for k = 2, #br do expect(#br[k - 1].rooms >= #br[k].rooms).to_be(true) end
  end)
end)

describe("relic loot in normal play", function()
  it("the warrens hold a quarter to two fifths of the value, in richer finds", function()
    for _, seed in ipairs({ 42, 7, 1234 }) do
      civs.use(seed)
      local g = galaxy.generate(seed)
      local s = sector.generate(seed, 3, g.sectors[3])
      local site = s.sites[relic_sites(s)[1]]
      local r = ruinm.generate(site.seed, site.kit, civs.get(seed, site.civ), site.pos)
      relicloot.apply(site, r)
      local n = #r.slots
      relicloot.apply(site, r)   -- once only
      expect(#r.slots).to_be(n)
      local share, w, h = relicloot.share(r.slots)
      expect(share >= relicloot.SHARE[1] - 1e-9 and share <= relicloot.SHARE[2] + 0.02).to_be(true)
      local nw, nh = 0, 0
      for k, sl in ipairs(r.slots) do
        expect(sl.id).to_be(k)
        if not sl.xl then if sl.warren then nw = nw + 1 else nh = nh + 1 end end
      end
      expect((w / nw) / (h / nh) >= 1.5).to_be(true)
    end
  end)
  it("leaves the slice and plain ruins alone", function()
    local r = { relic = {}, slots = { 1 } }
    expect(relicloot.apply({ relic = true, relic_civ = 1 }, r).slots[1]).to_be(1)
    expect(relicloot.apply({}, r).slots[1]).to_be(1)
    expect(relicloot.share({})).to_be(0)
  end)
end)

describe("what a relic remembers", function()
  it("the approach scan names it once; rooms and the heart are kept, through a save", function()
    local st = in_sector(3)
    local i = relic_sites(st.sector)[1]
    local r = game.ruin(i)
    local msgs = {}
    local ctx = { msg = function(_, _, t) msgs[#msgs + 1] = t end, fx = function() end }
    local p = st.players[1]
    st.tick = relic.NOTE_EVERY * 3 + 1
    relic.play_step(st, p, ctx)   -- off-beat: nothing
    expect(relic.found(st, i)).to_be(nil)
    st.tick = relic.NOTE_EVERY * 4
    p.ship.pos = { 0, 1e6, 0 }
    relic.play_step(st, p, ctx)   -- too far: nothing
    expect(relic.found(st, i)).to_be(nil)
    into(st, i, r.relic.halls[1])
    relic.play_step(st, p, ctx)
    expect(relic.found(st, i).found).to_be(st.tick)
    expect(msgs[1]:find("Relic signature", 1, true)).to_be(1)
    expect(relic.room_seen(st, i, r.relic.halls[1])).to_be(true)
    relic.play_step(st, p, ctx)
    expect(#msgs).to_be(1)
    into(st, i, r.relic.core)
    relic.play_step(st, p, ctx)
    expect(relic.found(st, i).heart).to_be(st.tick)
    expect(#msgs).to_be(2)
    into(st, i, r.relic.halls[2])
    relic.play_step(st, p, nil)
    expect(#relic.rooms_seen(st, i)).to_be(3)
    local st2 = {}
    game.init(st2, { seed = 42, players = 1 })
    save.apply(st2, save.record(st), game)
    expect(st2.sector_id).to_be(3)
    expect(#relic.rooms_seen(st2, i)).to_be(3)
    expect(relic.found(st2, i).heart).to_be_truthy()
    expect(relic.room_seen(st2, i, r.relic.core)).to_be(true)
  end)
  it("the radar map joins the state's rooms with the view's", function()
    local st = in_sector(3)
    local i = relic_sites(st.sector)[1]
    local r = game.ruin(i)
    relicmap.forget()
    local list = relicmap.visited(r, { r.relic.core, 99999 })
    expect(#list).to_be(1)
    expect(#relicmap.dots(r, r.relic.core, nil, { r.relic.core }) > 0).to_be(true)
    local p = into(st, i, r.relic.halls[1])
    local rr, here, site = relicmap.inside(st, p)
    expect(rr).to_be(r)
    expect(site).to_be(i)
    expect(here ~= nil).to_be(true)
  end)
  it("a step through a sector without relics leaves the state as it was", function()
    local st = in_sector(1)
    st.tick = 0
    relic.play_step(st, st.players[1], quiet())
    expect(st.relics_found).to_be(nil)
    expect(st.relic_rooms).to_be(nil)
  end)
end)

describe("pale crystal walls", function()
  it("a dominant crystal sparkles a third as much; one without sparkle stays without", function()
    local matv = require("view.materials")
    local lib = matv.library()
    expect(math.abs(matv.calm_crystal(lib.quartz).sparkle - lib.quartz.sparkle * matv.DOMINANT_SPARKLE) < 1e-9).to_be(true)
    expect(matv.calm_crystal(lib.amethyst).sparkle).to_be(nil)
  end)
end)

describe("relic decay", function()
  it("dead lamps by fate and era", function()
    expect(decay.dead({ axes = { fate = "ascension", era = "old" } })).to_be(0)
    expect(math.abs(decay.dead({ axes = { fate = "war of silence", era = "primordial" } }) - 0.72) < 1e-9).to_be(true)
    expect(decay.dead({ fate = "plague", era = "recent" }) < decay.dead({ fate = "plague", era = "ancient" })).to_be(true)
    expect(decay.dead(nil) > 0).to_be(true)
    local n = 0
    for k = 1, 100 do if decay.lamp_dead({ axes = { fate = "flight", era = "old" } }, k) then n = n + 1 end end
    expect(n).to_be(25)
    expect(decay.lamp_dead({ axes = { fate = "ascension" } }, 3)).to_be(false)
  end)
  it("heaps lie by the walls of halls and trunks, clear of doors and the middle", function()
    civs.use(42)
    local g = galaxy.generate(42)
    local s = sector.generate(42, 3, g.sectors[3])
    local site = s.sites[relic_sites(s)[1]]
    local civ = { id = "t", axes = { fate = "war of silence", era = "ancient" } }
    local r = ruinm.generate(site.seed, site.kit, civs.get(42, site.civ), site.pos)
    local kit = ruinm.kit_of(r.kit)
    local heaps = decay.place(r, civ)
    expect(#heaps > 0).to_be(true)
    local rooms = {}
    for _, rm in ipairs(r.rooms) do rooms[rm.id] = rm end
    for _, h in ipairs(heaps) do
      local rm = rooms[h.room]
      expect(rm.kind == "hall" or rm.kind == "trunk").to_be(true)
      local mn, mx = ruinm.room_box(rm, kit, r.origin)
      local wall = math.min(h.pos[1] - mn[1], mx[1] - h.pos[1], h.pos[3] - mn[3], mx[3] - h.pos[3])
      expect(wall <= kit.wall + decay.WALL_BAND[2] + 1e-6).to_be(true)
      expect(h.pos[2]).to_be(mn[2] + kit.wall)
    end
    expect(#decay.place(r, { axes = { fate = "ascension" } })).to_be(0)
  end)
end)
