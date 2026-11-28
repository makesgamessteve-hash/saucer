-- SPDX-License-Identifier: MIT
-- Milestone 9 (OpenSpec add-home-among-stars): decorating the dome (furniture,
-- display slots, the garden, Comfort), Hardcore mode and the mod browser.
local game = require("sim.game")
local avatar = require("sim.avatar")
local panel = require("sim.panel")
local decor = require("sim.decor")
local hardcore = require("sim.hardcore")
local items = require("sim.items")
local hull = require("sim.hull")
local trade = require("sim.trade")
local clock = require("sim.clock")
local kitchen = require("sim.kitchen")
local home = require("sim.home")
local homeedit = require("sim.homeedit")
local layout = require("sim.layout")
local modbrowser = require("sim.modbrowser")
local render = require("view.render")
local hud = require("view.hud")
local L = avatar.layout()

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  return st
end
local function run(st, c, n)
  for _ = 1, n or 1 do
    local cs = {}
    for i = 1, #st.players do cs[i] = c or cmd() end
    game.step(st, cs, 1 / 60)
  end
end
local said = {}
local ctx = { msg = function(_, _, t) said[#said + 1] = t end, fx = function() end }
local function last() return said[#said] or "" end
local function stand(p, node, yaw)
  p.mode, p.panel = "walk", false
  p.body = avatar.new(L, L.nav.nodes[node], yaw or 0)
end
local function curio(p, name)
  local it = items.stamp(p, { name = name or "Lucid Lens", type = "lens", value = 40, size = 1 }, 2, nil)
  it.ident, it.category = true, "curio"
  p.hold[#p.hold + 1] = it
  return it
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
    end
  end
  return v
end
local function find_row(rows, prefix)
  for _, r in ipairs(rows) do
    if r.text:sub(1, #prefix) == prefix then return r end
  end
  return nil
end

describe("decorating the dome", function()
  it("starts lazily: a game that never decorates has no p.decor", function()
    local st = new_state()
    local p = st.players[1]
    run(st, cmd(), 3)
    expect(p.decor).to_be(nil)
    expect(decor.comfort(st, p)).to_be(0)
    expect(decor.regen_factor(st, p)).to_be(1)
    expect(decor.level(st, p)).to_be("Bare")
    expect(#decor.solids(p)).to_be(0)
    expect(decor.display_count(p)).to_be(0)
    decor.grow(st, p)
    -- the panels read a default without storing it
    stand(p, "planner")
    local rows = decor.planner_rows(st, p, ctx)
    expect(find_row(rows, "Place Floor lamp")).to_be_truthy()
    expect(#decor.garden_rows(st, p, ctx)).to_be_greater(1)
    expect(#decor.display_rows(st, p, ctx)).to_be(2)
    expect(decor.nearest(p)).to_be(nil)
    expect(p.decor).to_be(nil)
    expect(decor.view(p).store.lamp).to_be(1)
  end)
  it("places, refuses and packs away furniture", function()
    local st = new_state()
    local p = st.players[1]
    stand(p, "planner", -1.5708)
    decor.buy_furniture(p, "aquarium")
    expect(p.decor.store.aquarium).to_be(1)
    expect(decor.place(st, p, "telescope", ctx)).to_be(false) -- none in storage
    expect(decor.place(st, p, "nothing", ctx)).to_be(false)
    local ok = decor.place(st, p, "aquarium", ctx)
    expect(ok).to_be(true)
    expect(last()).to_contain("Placed the aquarium")
    expect(p.decor.store.aquarium).to_be(nil)
    local pc = p.decor.placed[1]
    expect(pc.x % decor.GRID).to_be(0)
    expect(#decor.solids(p)).to_be(1)
    -- the same spot again: another piece is there
    decor.buy_furniture(p, "aquarium")
    expect(decor.place(st, p, "aquarium", ctx)).to_be(false)
    expect(last()).to_contain("another piece")
    -- a rug may lie under things and is not solid
    decor.buy_furniture(p, "rug")
    p.body.yaw = 0
    local rug_ok = decor.place(st, p, "rug", ctx)
    if rug_ok then expect(#decor.solids(p)).to_be(1) end
    -- not while sitting at the helm or visiting
    p.mode = "helm"
    expect(select(2, decor.place(st, p, "lamp", ctx))).to_be("walk your own dome")
    p.mode = "walk"
    -- every refusal reason
    local def = decor.furniture("lamp")
    expect(select(2, decor.can_place(p, def, 9, 0, 0, 0))).to_be("not on this deck")
    expect(select(2, decor.can_place(p, def, 1, L.decks[1].radius, 0, 0))).to_be("too close to the hull")
    local st1 = avatar.station_by_id(L, "kitchen")
    expect(decor.can_place(p, def, st1.deck, st1.pos[1], st1.pos[3], 0)).to_be(false)
    for _, k in ipairs(L.keep_clear or {}) do
      local b = k.box
      expect(select(2, decor.can_place(p, def, k.deck, (b[1] + b[3]) / 2, (b[2] + b[4]) / 2, 0))).to_be_truthy()
    end
    for _, door in ipairs(L.doors or {}) do
      if door.box then
        local b = door.box
        expect(decor.can_place(p, def, door.deck, (b[1] + b[3]) / 2, (b[2] + b[4]) / 2, 0)).to_be(false)
      end
    end
    expect(select(2, decor.can_place(p, def, 1, p.body.pos[1], p.body.pos[3], 0, p.body))).to_be_truthy()
    -- furniture with a circle (the stairwell) and turned pieces
    local fp = decor.footprint(decor.furniture("bookcase"), 0, 0, 1)
    expect(fp[3] - fp[1]).to_be(0.4)
    -- pack away the nearest
    stand(p, "planner", -1.5708)
    expect(decor.nearest(p)).to_be(1)
    local rows = decor.planner_rows(st, p, ctx)
    expect(find_row(rows, "Pack away the aquarium")).to_be_truthy()
    expect(decor.pick_up(st, p, ctx)).to_be(true)
    expect(p.decor.store.aquarium).to_be(2)
    p.body.pos = { 0, -50, 0 }
    expect(decor.pick_up(st, p, ctx)).to_be(false)
  end)
  it("drives the planner, display and garden panels with Use", function()
    local st = new_state()
    local p = st.players[1]
    stand(p, "planner", -1.5708)
    home.USE.planner(st, p)
    expect(p.panel.kind).to_be("planner")
    expect(p.decor).to_be_truthy()
    local rows = panel.rows(st, p)
    find_row(rows, "Place Floor lamp").act(st, p)
    expect(p.panel).to_be(false)
    local hold = homeedit.holding(p)
    expect(hold and hold.kind == "lamp").to_be(true)
    local def = decor.furniture("lamp")
    local d, x, z, q = decor.spot(p.body, def)
    expect(homeedit.place_now(st, p, ctx, d, x, z, layout.quarter_to_turn(q))).to_be(true)
    expect(#p.decor.placed).to_be(1)
    home.USE.planner(st, p)
    find_row(panel.rows(st, p), "Close").act(st, p)
    expect(p.panel).to_be(false)
    -- display slot 2
    local it = curio(p)
    local junk = items.stamp(p, { name = "Echo", type = "idol", value = 1, size = 1 }, 1, nil)
    junk.echo, junk.ident = true, true
    p.hold[#p.hold + 1] = junk
    home.USE.display(st, p, { slot = 2 })
    expect(p.panel.slot).to_be(2)
    rows = panel.rows(st, p)
    expect(#rows).to_be(2) -- the Echo cannot go on show
    rows[1].act(st, p)
    expect(p.decor.display[2].uid).to_be(it.uid)
    expect(items.find(p, it.uid)).to_be(nil)
    expect(decor.display_count(p)).to_be(1)
    expect(decor.show(st, p, 2, junk.uid, ctx)).to_be(false) -- taken
    expect(decor.show(st, p, 99, junk.uid, ctx)).to_be(false) -- no such slot
    expect(decor.show(st, p, 3, junk.uid, ctx)).to_be(false) -- not displayable
    home.USE.display(st, p, { slot = 2 })
    rows = panel.rows(st, p)
    expect(rows[1].text).to_contain("On display")
    -- a full hold keeps it on the plinth
    local saved = p.hold
    p.hold = {}
    for i = 1, require("sim.config").all().hold_slots do p.hold[i] = { uid = -i } end
    expect(decor.unshow(st, p, 2, ctx)).to_be(false)
    expect(last()).to_contain("hold is full")
    p.hold = saved
    rows[2].act(st, p)
    expect(p.decor.display[2]).to_be(nil)
    expect(items.find(p, it.uid)).to_be_truthy()
    expect(decor.unshow(st, p, 2, ctx)).to_be(false)
    expect(decor.displayable(nil)).to_be(false)
    expect(decor.displayable({ ident = true, home = { kind = "program" } })).to_be(false)
    panel.close(p)
    -- the garden: plant, water, grow, harvest
    home.USE.garden(st, p)
    rows = panel.rows(st, p)
    find_row(rows, "Plant Glowmoss in bed 1").act(st, p)
    expect(p.decor.garden[1].seed).to_be("glowmoss")
    expect(decor.plant(st, p, 1, "glowmoss", ctx)).to_be(false) -- taken
    expect(decor.plant(st, p, 99, "glowmoss", ctx)).to_be(false)
    expect(decor.plant(st, p, 2, "sunvine", ctx)).to_be(false) -- no seeds
    expect(decor.stage(st, p.decor.garden[1])).to_be(1)
    expect(decor.stage(st, nil)).to_be(0)
    rows = panel.rows(st, p)
    find_row(rows, "Water bed 1").act(st, p)
    expect(decor.water(st, p, 3, ctx)).to_be(false)
    expect(decor.harvest(st, p, 1, ctx)).to_be(false) -- not ripe
    -- dry soil stops growth: 40 minutes of water, then nothing
    st.tick = st.tick + clock.TICKS_PER_MINUTE * 100
    local g = decor.growth(st, p.decor.garden[1])
    expect(g).to_be_less(30.001)
    expect(find_row(panel.rows(st, p), "Bed 1").text).to_contain("(dry)")
    decor.water(st, p, 1, ctx)
    st.tick = st.tick + clock.TICKS_PER_MINUTE * 40
    expect(decor.stage(st, p.decor.garden[1])).to_be(4)
    expect(find_row(panel.rows(st, p), "Harvest bed 1")).to_be_truthy()
    find_row(panel.rows(st, p), "Harvest bed 1").act(st, p)
    expect(kitchen.ensure(p).glowcap).to_be(1)
    expect(p.decor.garden[1].harvests).to_be(1)
    expect(decor.stage(st, p.decor.garden[1])).to_be(1)
    -- every seed gone: the other beds say where to get some
    decor.plant(st, p, 2, "glowmoss", ctx)
    expect(find_row(panel.rows(st, p), "Bed 3: empty")).to_be_truthy()
  end)
  it("adds up Comfort (duplicates count less) and speeds up Charge", function()
    local st = new_state()
    local p = st.players[1]
    local D = decor.ensure(p)
    D.placed = { { id = 1, kind = "crystal", deck = 1, x = 0, z = 0, q = 0 },
                 { id = 2, kind = "crystal", deck = 1, x = 0, z = 0, q = 0 },
                 { id = 3, kind = "ghost", deck = 1, x = 0, z = 0, q = 0 } }
    expect(decor.comfort(st, p)).to_be(7) -- 5 + 2.5
    D.display[1] = { category = "curio", type = "a" }
    D.display[2] = { category = "material", name = "b" }
    expect(decor.comfort(st, p)).to_be(11)
    D.garden[1] = { seed = "sunvine", growth = 45, watered = 0, last = 0 }
    D.garden[2] = { seed = "glowmoss", growth = 0, watered = -1e6, last = 0 } -- dry: a sprout
    expect(decor.comfort(st, p)).to_be(14) -- 7.5 + 4 + 2 + 0.5
    expect(decor.level(st, p)).to_be("Cosy")
    expect(decor.regen_factor(st, p)).to_be(1 + 14 * 0.02)
    for i = 1, 12 do D.placed[#D.placed + 1] = { id = 9 + i, kind = ({ "lamp", "beanbag", "armchair", "bookcase",
      "aquarium", "telescope", "hammock" })[i % 7 + 1], deck = 1, x = 0, z = 0, q = 0 } end
    expect(decor.level(st, p)).to_be("Beloved")
    expect(decor.regen_factor(st, p)).to_be(1.5) -- capped
    -- the guest admires a host's display
    local q = { index = 2 }
    expect(decor.admire(st, q, p, 1, ctx)).to_be(true)
    expect(q.admired[1].host).to_be(1)
    expect(decor.admire(st, q, p, 5, ctx)).to_be(false)
    expect(decor.admire(st, q, { index = 3 }, 1, ctx)).to_be(false)
  end)
  it("sells furniture and seeds at the trader", function()
    local p = new_state().players[1]
    local shop = trade.shop()
    local f, s
    for _, e in ipairs(shop) do
      if e.kind == "furniture" and not f then f = e end
      if e.kind == "seed" and not s then s = e end
    end
    expect(f.price).to_be(decor.furniture(f.id).price)
    expect(trade.shop_name(f)).to_be(decor.furniture(f.id).name:lower())
    expect(trade.shop_name(s)).to_contain("seeds")
    p.credits = 1000
    expect(trade.buy(p, f)).to_be(true)
    expect(p.decor.store[f.id]).to_be((f.id == "lamp" and 2) or 1)
    expect(trade.buy(p, s)).to_be(true)
    expect(p.decor.seeds[s.id]).to_be_greater(0)
  end)
  it("draws placed furniture, trophies and plants (every kind and stage)", function()
    local st = new_state()
    local p = st.players[1]
    local D = decor.ensure(p)
    for i, def in ipairs(decor.defs().furniture) do
      D.placed[#D.placed + 1] = { id = i, kind = def.id, deck = 1, x = 0, z = 0, q = i % 4 }
    end
    D.display[1] = { category = "curio", size = 2 }
    D.display[2] = { category = "nope" }
    local i = 0
    for _, sd in ipairs(decor.defs().seeds) do
      for stage = 0, 3 do
        i = i + 1
        if L.garden[i] then
          D.garden[i] = { seed = sd.id, growth = sd.minutes * stage / 3, watered = 0, last = 0 }
        end
      end
    end
    local v = fake_view()
    local d = { pos = { 0, 0, 0 }, yaw = 0, roll = 0, scale = 1 }
    local n = render.decor(v, nil, p, d, st)
    expect(n).to_be(#D.placed + 2 + #L.garden)
    expect(render.decor(v, nil, { }, d, st)).to_be(0)
  end)
end)

describe("Hardcore", function()
  it("is chosen on the title card before anyone gets up", function()
    local st = new_state()
    local p = st.players[1]
    expect(hardcore.on(st)).to_be(false)
    local row = find_row(panel.rows(st, p), "Hardcore: off")
    expect(row).to_be_truthy()
    row.act(st, p)
    expect(hardcore.on(st)).to_be(true)
    expect(find_row(panel.rows(st, p), "Hardcore: ON")).to_be_truthy()
    find_row(panel.rows(st, p), "Hardcore: ON").act(st, p)
    expect(hardcore.on(st)).to_be(false)
    expect(hardcore.toggle(st, p, ctx)).to_be(true)
    p.mode = "walk"
    expect(hardcore.can_choose(st)).to_be(false)
    expect(hardcore.toggle(st, p, ctx)).to_be(false)
    p.mode = "wake"
    p.panel = { kind = "title", sel = 1 }
    expect(find_row(panel.rows(st, p), "Hardcore")).to_be_truthy()
    p.mode = "walk"
    expect(find_row(panel.rows(st, p), "Hardcore")).to_be(nil)
    -- --hardcore sets it from the start
    local st2 = {}
    game.init(st2, { seed = 42, players = 1, hardcore = true })
    expect(hardcore.on(st2)).to_be(true)
  end)
  it("a Fold Retreat loses the cargo for good; the bed cannot load", function()
    local st = new_state()
    st.hardcore = true
    local p = st.players[1]
    local hot = curio(p, "Hot")
    hot.hot = true
    local banked = curio(p, "Banked")
    banked.hot = false
    local echo = curio(p, "Echo")
    echo.echo = true
    local mod = curio(p, "Module")
    mod.home = { kind = "module" }
    local lost = hardcore.retreat_losses(st, p)
    expect(#lost).to_be(2)
    p.site = 2
    expect(hull.retreat(st, p, st.sector.trader.pos)).to_be(nil)
    expect(p.lost_for_good).to_be(2)
    expect(#p.hold).to_be(2)
    expect(#(st.caches or {})).to_be(0)
    -- in play: the hull gives out and the HUD says what was lost
    local st3 = new_state()
    st3.hardcore = true
    local p3 = st3.players[1]
    run(st3, cmd({ pressed = { "use" } }))
    curio(p3, "Doomed").hot = true
    p3.ship.hull = 0
    run(st3, cmd())
    local said3 = {}
    for _, m in ipairs(p3.msgs) do said3[#said3 + 1] = m.text end
    expect(table.concat(said3, "|")).to_contain("lost for good")
    -- Standard keeps the old rule
    st.hardcore = nil
    expect(#hardcore.retreat_losses(st, p)).to_be(#items.losable(p))
    -- the bed
    st.hardcore = true
    p.panel = { kind = "bed", sel = 1 }
    expect(find_row(panel.rows(st, p), "Load saved game")).to_be(nil)
    expect(find_row(panel.rows(st, p), "Mod browser")).to_be_truthy()
    st.hardcore = nil
    expect(find_row(panel.rows(st, p), "Load saved game")).to_be_truthy()
  end)
  it("shows HARDCORE on the HUD", function()
    local st = new_state()
    st.hardcore = true
    local p = st.players[1]
    stand(p, "planner")
    local v = fake_view()
    hud.draw(v, st, p)
    expect(v.texts).to_contain("HARDCORE")
    local v2 = fake_view({ width = 240, height = 270 })
    hud.draw(v2, st, p)
    expect(v2.texts).to_contain("HC|")
  end)
end)

describe("mod browser", function()
  it("lists the mod folders and switches them for the next start", function()
    local st = new_state()
    local p = st.players[1]
    local real = saucer.mods.available
    local calls = {}
    saucer.mods.available = function()
      return {
        { id = "base", name = "Saucer", version = "0.1.0", description = "", loaded = true, off = false, status = "ok" },
        { id = "a", name = "Alpha", version = "1.0", description = "first", loaded = true, off = false, status = "ok" },
        { id = "b", name = "Beta", version = "2.0", description = "", loaded = true, off = true, status = "ok" },
        { id = "c", name = "Gamma", version = "1", description = "", loaded = false, off = true, status = "switched off" },
        { id = "d", name = "Delta", version = "1", description = "", loaded = false, off = false, status = "missing dependency x" },
      }
    end
    local real_set = saucer.mods.set_enabled
    saucer.mods.set_enabled = function(id, on, who) calls[#calls + 1] = { id, on, who } return true end
    local ok, err = pcall(function()
      local rows = modbrowser.rows(st, p, ctx)
      expect(rows[1].enabled).to_be(false)
      expect(rows[2].text).to_be("[base] Saucer 0.1.0")
      expect(rows[2].enabled).to_be(false)
      expect(rows[3].text).to_be("[on] Alpha 1.0")
      expect(rows[3].hint).to_be("first")
      expect(rows[4].text).to_be("[on->off] Beta 2.0")
      expect(rows[5].text).to_be("[off] Gamma 1")
      expect(rows[6].text).to_be("[off->on] Delta 1 - missing dependency x")
      rows[3].act(st, p)
      expect(calls[1][1]).to_be("a")
      expect(calls[1][2]).to_be(false)
      expect(calls[1][3]).to_be(1)
      expect(last()).to_contain("Alpha will be off")
      rows[5].act(st, p)
      expect(calls[2][2]).to_be(true)
      -- opened from the title card, closed again
      p.panel = { kind = "title", sel = 1 }
      find_row(panel.rows(st, p), "Mod browser").act(st, p)
      expect(p.panel.kind).to_be("mods")
      expect(panel.title(st, p)).to_be("MOD BROWSER")
      local hv = fake_view()
      p.panel.sel = 3
      hud.panel(hv, st, p)
      expect(hv.texts).to_contain("first")
      local all = panel.rows(st, p)
      all[#all].act(st, p)
      expect(p.panel).to_be(false)
    end)
    saucer.mods.available = real
    saucer.mods.set_enabled = real_set
    if not ok then error(err, 0) end
  end)
  it("reports the real mod folders (the base game at least)", function()
    local list = saucer.mods.available()
    local base
    for _, m in ipairs(list) do if m.id == "base" then base = m end end
    expect(base.loaded).to_be(true)
    expect(base.off).to_be(false)
    expect(saucer.mods.set_enabled("base", false, 1)).to_be(false)
    expect(saucer.mods.set_enabled("no_such_mod", false, 1)).to_be(false)
  end)
end)
