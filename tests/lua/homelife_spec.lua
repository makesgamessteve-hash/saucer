-- SPDX-License-Identifier: MIT
-- Milestone 4 (add-holodeck-home-life): buffs, the galley, the bookshelf,
-- the TV, vault finds, the holodeck sim and its view, driven directly and
-- through game.step with synthetic commands.
local game = require("sim.game")
local avatar = require("sim.avatar")
local holo = require("sim.holo")
local buffs = require("sim.buffs")
local kitchen = require("sim.kitchen")
local books = require("sim.books")
local tv = require("sim.tv")
local finds = require("sim.finds")
local items = require("sim.items")
local lab = require("sim.lab")
local trade = require("sim.trade")
local save = require("sim.save")
local home = require("sim.home")
local hud = require("view.hud")
local render = require("view.render")
local vholo = require("view.holo")
local L = avatar.layout()

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  for _, p in ipairs(st.players) do p.mode, p.panel = "walk", false end
  return st
end
local function run(st, c, n)
  -- one frame per player in the game (a frame for an empty slot would join it)
  for _ = 1, n or 1 do
    local cs = {}
    for i = 1, #st.players do cs[i] = c or cmd() end
    game.step(st, cs, 1 / 60)
  end
end
local said = {}
local ctx = {
  msg = function(_, _, t) said[#said + 1] = t end,
  fx = function() end,
}
local function last() return said[#said] or "" end
local function stand(p, node)
  p.mode, p.panel = "walk", false
  p.body = avatar.new(L, L.nav.nodes[node], 0)
end
local function fake_view()
  local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = false, texts = "" }
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
local function rows_text(rows)
  local t = {}
  for _, r in ipairs(rows) do t[#t + 1] = r.text end
  return table.concat(t, "|")
end
local function row(rows, prefix)
  for _, r in ipairs(rows) do if r.text:sub(1, #prefix) == prefix then return r end end
  return nil
end

describe("buffs", function()
  it("give, extend, factor and list", function()
    local st = new_state()
    local p = st.players[1]
    expect(buffs.give(st, p, "nope", 5)).to_be(false)
    expect(buffs.factor(st, p, "charge_regen")).to_be(1)
    expect(buffs.give(st, p, "fed", 1)).to_be(true)
    local til = p.buffs.fed
    buffs.give(st, p, "fed", 0.5)
    expect(p.buffs.fed).to_be(til)
    buffs.give(st, p, "calm", 2)
    expect(buffs.factor(st, p, "charge_regen")).to_be(1.5)
    expect(buffs.factor(st, p, "scan_cooldown")).to_be(0.75)
    local l = buffs.list(st, p)
    expect(#l).to_be(2)
    expect(l[1].id).to_be("calm")
    p.buffs.ghost = st.tick + 100
    expect(#buffs.list(st, p)).to_be(2)
    st.tick = til + 1
    expect(buffs.active(st, p, "fed")).to_be(false)
    expect(home.fed(st, p)).to_be(false)
    expect(home.regen_factor(st, p)).to_be(1)
  end)
end)

describe("kitchen", function()
  it("cooks from the pantry and reports what is missing", function()
    local st = new_state()
    local p = st.players[1]
    expect(kitchen.ensure(p).noodles).to_be(2)
    expect(kitchen.ingredient("nope")).to_be(nil)
    expect(kitchen.name("nope")).to_be("nope")
    expect(kitchen.recipe("nope")).to_be(nil)
    expect(kitchen.start(st, p, "nope", ctx)).to_be(false)
    expect(kitchen.needs_text(kitchen.recipe("snack"))).to_be("nothing")
    expect(kitchen.needs_text({ needs = { tea = 2 } })).to_be("2 Leaf tea")
    expect(kitchen.start(st, p, "spiced_noodles", ctx)).to_be(false)
    expect(last()).to_contain("Missing Velari ember spice")
    kitchen.stock(p, "velari_spice", 1)
    local rows = kitchen.rows(st, p, ctx)
    expect(rows_text(rows)).to_contain("Pantry: Velari ember spice x1 (alien)")
    expect(row(rows, "Cook Ember-spiced").enabled).to_be(true)
    row(rows, "Cook Ember-spiced").act(st, p)
    expect(p.pantry.velari_spice).to_be(nil)
    expect(p.cooking.recipe).to_be("spiced_noodles")
    expect(kitchen.step(st, p, 1, ctx)).to_be(nil)
    expect(kitchen.step(st, p, 5, ctx).id).to_be("spiced_noodles")
    expect(buffs.active(st, p, "keen")).to_be(true)
    expect(kitchen.step(st, p, 1, ctx)).to_be(nil)
    p.pantry = {}
    expect(rows_text(kitchen.rows(st, p, ctx))).to_contain("Pantry: empty")
    row(kitchen.rows(st, p, ctx), "Close").act(st, p)
    expect(p.panel).to_be(false)
  end)
  it("cooking holds the player at the stove until the meal is ready", function()
    local st = new_state()
    local p = st.players[1]
    stand(p, "kitchen")
    run(st, cmd({ pressed = { "use" } }))
    expect(p.panel.kind).to_be("kitchen")
    run(st, cmd({ pressed = { "use" } }))
    expect(p.cooking).to_be_truthy()
    local pos = { game.viewpoint(p) }
    expect(pos[3]).to_be(L.stove.pitch)
    run(st, cmd({ axes = { move_z = 1 }, pressed = { "use" } }), 30)
    expect(p.cooking).to_be_truthy()
    run(st, cmd(), 200)
    expect(p.cooking).to_be(false)
    expect(p.meals).to_be(1)
  end)
end)

describe("bookshelf", function()
  it("shelves, resolves, reads and leaves leads", function()
    local st = new_state()
    local p = st.players[1]
    expect(#books.ensure(p)).to_be(1)
    expect(books.add(p, "manual")).to_be(false)
    expect(books.add(p, "velari_log")).to_be(true)
    expect(books.add(p, "station_log")).to_be(true)
    books.add(p, "echo:1")
    books.add(p, "memory")
    books.add(p, "lost_tome")
    expect(books.wrap("a bb ccc", 4)).to_equal({ "a bb", "ccc" })
    expect(#books.wrap("")).to_be(0)
    expect(books.resolve(st, "echo:1").pages[1][3]).to_be("(not decoded yet)")
    expect(books.resolve(st, "echo:9").pages[1][3]).to_be("(silent)")
    expect(books.resolve(st, "memory").title).to_contain("Memory of")
    expect(books.resolve(st, "lost_tome").pages[1][1]).to_contain("blank")
    local sl = books.resolve(st, "station_log")
    expect(table.concat(sl.pages[1], " "):find("{", 1, true)).to_be(nil)
    local rows = books.rows(st, p, ctx)
    expect(rows[1].text).to_contain("lost_tome")
    expect(rows_text(rows)).to_contain("(clue) *")
    expect(books.open(st, p, "nope", ctx)).to_be(false)
    row(rows, "Read Velari captain's log").act(st, p)
    expect(p.reading.id).to_be("velari_log")
    expect(last()).to_contain("A lead")
    local lead = books.next_echo_site(st.mystery)
    expect(p.leads[tostring(lead)]).to_be(true)
    expect(books.turn(st, p)).to_be(true)
    expect(books.turn(st, p)).to_be(true)
    expect(p.reading).to_be(false)
    expect(books.turn(st, p)).to_be(false)
    said = {}
    books.open(st, p, "velari_log", ctx)
    expect(#said).to_be(0) -- only the first read leaves a lead
    books.close(p)
    expect(p.reading).to_be(false)
    books.open(st, p, "station_log", ctx)
    expect(p.books_read).to_be(2)
    -- every echo found: the clue falls back to the last site
    for _, e in ipairs(st.mystery.echoes) do e.found_by = 1 end
    expect(books.next_echo_site(st.mystery)).to_be(st.mystery.echoes[#st.mystery.echoes].site)
    st.mystery.echoes[2].found_by = 0
    expect(books.next_echo_site(st.mystery)).to_be(st.mystery.echoes[2].site)
    expect(books.next_echo_site({ echoes = {} })).to_be(1)
  end)
  it("reading is a seated mode driven by Use and the stick", function()
    local st = new_state()
    local p = st.players[1]
    stand(p, "books")
    run(st, cmd({ pressed = { "use" } }))
    expect(p.panel.kind).to_be("books")
    run(st, cmd({ pressed = { "use" } }))
    expect(p.reading.id).to_be("manual")
    local _, yaw = game.viewpoint(p)
    expect(yaw).to_be(L.shelf.yaw)
    local v = fake_view()
    render.render(v, saucer.util.readonly(st), 1)
    expect(v.texts).to_contain("PAGE 1/")
    run(st, cmd({ pressed = { "use" } }))
    expect(p.reading.page).to_be(2)
    run(st, cmd({ axes = { move_z = 1 } }))
    expect(p.reading).to_be(false)
  end)
end)

describe("tv", function()
  it("receives channels in range, hints, flips and switches off", function()
    local st = new_state()
    local p = st.players[1]
    local got = tv.received(st, p)
    expect(#got).to_be_greater(0)
    local rows = tv.rows(st, p, ctx)
    expect(rows[1].text).to_contain("Watch")
    rows[1].act(st, p)
    expect(p.tv.idx).to_be(1)
    expect(p.last_hint).to_be_truthy()
    expect(tv.current(st, p).id).to_be(got[1].id)
    local s1, h1 = tv.now(st, p, got[1])
    expect(s1).to_be(p.tv.show)
    expect(h1).to_be(p.tv.hint)
    for _ = 1, #got do tv.next(st, p, ctx) end
    expect(p.tv).to_be(false)
    expect(last()).to_contain("switch the TV off")
    expect(tv.current(st, p)).to_be(nil)
    expect(tv.tune(st, p, 99, ctx)).to_be(false)
    -- far away: no signal
    p.ship.pos = { 1e7, 0, 1e7 }
    expect(rows_text(tv.rows(st, p, ctx))).to_contain("No signal")
    p.tv = { ch = "gone", idx = 1 }
    expect(tv.current(st, p)).to_be(nil)
  end)
  it("every topic has something to say or stays quiet", function()
    local st = new_state()
    local p = st.players[1]
    for _, id in ipairs(saucer.util.sorted_keys(tv.TOPICS)) do
      local h = tv.TOPICS[id](st, p)
      expect(h == nil or type(h) == "string").to_be(true)
    end
    p.hold[#p.hold + 1] = finds.item({ kind = "program", id = "memory" })
    expect(tv.TOPICS.lab(st, p)).to_be(nil)
    expect(tv.TOPICS.holo(st, p)).to_contain("data core")
    p.hold[1] = finds.item({ kind = "module", id = "size" })
    expect(tv.TOPICS.holo(st, p)).to_contain("modules")
    p.hold[1] = { type = "x", ident = false }
    expect(tv.TOPICS.lab(st, p)).to_contain("lab bench")
    st.mystery.vault_revealed = true
    expect(tv.TOPICS.vault(st, p)).to_contain("sealed")
    st.mystery.mode = "off"
    expect(tv.TOPICS.mystery(st, p)).to_be(nil)
    kitchen.stock(p, "velari_spice", 1)
    expect(tv.TOPICS.kitchen(st, p)).to_contain("Ember")
    p.pantry = {}
    expect(tv.TOPICS.kitchen(st, p)).to_contain("Alien spices")
    p.trails = {}
    for i = 1, #st.sector.sites do p.trails[tostring(i)] = { pts = { { 0, 0, 0 } }, marks = {} } end
    expect(tv.TOPICS.finds(st, p)).to_be(nil)
    expect(tv.TOPICS.sentries(st, p)).to_be(nil)
    -- a channel with nothing to say plays music
    local _, h = tv.show(st, p, { shows = { "Quiet" }, topics = { "finds", "nope" } })
    expect(h).to_contain("soft music")
  end)
  it("the TV is a seated mode on the sofa", function()
    local st = new_state()
    local p = st.players[1]
    stand(p, "tv")
    run(st, cmd({ pressed = { "use" } }))
    expect(p.panel.kind).to_be("tv")
    run(st, cmd({ pressed = { "use" } }))
    expect(p.tv).to_be_truthy()
    local _, yaw = game.viewpoint(p)
    expect(yaw).to_be(L.sofa.yaw)
    local v = fake_view()
    render.render(v, saucer.util.readonly(st), 1)
    expect(v.texts).to_contain(tv.current(st, p).name:upper())
    run(st, cmd({ pressed = { "use" } }))
    run(st, cmd({ axes = { move_z = -1 } }))
    expect(p.tv).to_be(false)
  end)
end)

describe("finds", function()
  it("makes hold items and unpacks books and ingredients", function()
    local st = new_state()
    local p = st.players[1]
    local core = finds.item({ kind = "program", id = "memory" })
    expect(core.ident).to_be(false)
    expect(items.label(core)).to_be("Data core (undecoded)")
    core.ident = true
    expect(items.label(core)).to_contain("Resonant Memory")
    expect(finds.item({ kind = "program", id = "nope" }).home.title).to_be("nope")
    expect(finds.item({ kind = "module", id = "nope" }).name).to_be("nope")
    expect(finds.item({ kind = "book", id = "nope" }).name).to_be("nope")
    expect(finds.item({ kind = "other", id = "x" }).name).to_be("Find")
    local bk = finds.item({ kind = "book", id = "oquun_hymns" })
    expect(items.sellable(bk)).to_be(false)
    expect(finds.unpack(st, p, bk, ctx)).to_be(true)
    expect(last()).to_contain("Shelved")
    finds.unpack(st, p, bk, ctx)
    expect(last()).to_contain("Already on the shelf")
    expect(finds.unpack(st, p, finds.item({ kind = "ingredient", id = "sunfruit", n = 3 }), ctx)).to_be(true)
    expect(p.pantry.sunfruit).to_be(3)
    expect(finds.unpack(st, p, core, ctx)).to_be(false)
    expect(finds.unpack(st, p, { type = "x" }, ctx)).to_be(false)
    expect(#finds.candidates(st, p, 99, nil)).to_be(0)
    local c = finds.candidates(st, p, 1, game.ruin(1))
    expect(#c).to_be(3)
    p.looted[c[1].key] = true
    expect(#finds.candidates(st, p, 1, game.ruin(1))).to_be(2)
  end)
  it("the lab decodes a data core into a holodeck program", function()
    local st = new_state()
    local p = st.players[1]
    local core = finds.item({ kind = "program", id = "memory" })
    core.uid = 77
    p.hold[#p.hold + 1] = core
    expect(lab.is_core(core)).to_be(true)
    expect(lab.is_core({})).to_be(false)
    local rows = lab.rows(st, p, ctx)
    local r = row(rows, "Decode Data core")
    expect(r).to_be_truthy()
    r.act(st, p)
    expect(#p.lab.queue).to_be(1)
    run(st, cmd(), 60 * 25)
    expect(holo.has(p, "memory")).to_be(true)
    expect(items.find(p, 77)).to_be(nil)
  end)
end)

describe("holodeck", function()
  it("discovers programs, modules and the library", function()
    local st = new_state()
    local p = st.players[1]
    local ids = {}
    for _, pr in ipairs(holo.programs()) do ids[#ids + 1] = pr.id end
    expect(table.concat(ids, ",")).to_be("beach,forest,seat_course,replay,memory")
    expect(holo.program("nope")).to_be(nil)
    expect(holo.has(p, "nope")).to_be(false)
    expect(holo.has(p, "forest")).to_be(false)
    expect(holo.unlock(p, "forest")).to_be(true)
    expect(holo.unlock(p, "forest")).to_be(false)
    expect(holo.unlock(p, "nope")).to_be(false)
    expect(#holo.library(p)).to_be(4)
    expect(holo.level(p, "size")).to_be(6)
    expect(holo.install(p, 999)).to_be(false)
    local m = finds.item({ kind = "module", id = "size" })
    m.uid = 5
    p.hold[#p.hold + 1] = m
    local ok = holo.install(p, 5)
    expect(ok).to_be(true)
    expect(holo.level(p, "size")).to_be(10)
    p.holo.mods.size = 3
    local m2 = finds.item({ kind = "module", id = "size" })
    m2.uid = 6
    p.hold[#p.hold + 1] = m2
    local ok2, why = holo.install(p, 6)
    expect(ok2).to_be(false)
    expect(why).to_contain("top level")
    local m3 = finds.item({ kind = "module", id = "nope" })
    m3.uid = 7
    p.hold[#p.hold + 1] = m3
    expect(select(2, holo.install(p, 7))).to_be("unknown module")
    expect(holo.can_run(st, p, "nope")).to_be(false)
    expect(holo.can_run(st, p, "memory")).to_be(false)
    expect(select(2, holo.can_run(st, p, "replay"))).to_contain("explore")
    expect(holo.start(st, p, "memory", nil, ctx)).to_be(false)
  end)
  it("runs a walking program: spots, the arch, the walls and solids", function()
    local st = new_state()
    local p = st.players[1]
    stand(p, "holodeck")
    run(st, cmd({ pressed = { "use" } }))
    expect(p.panel.kind).to_be("holodeck")
    local rows = holo.rows(st, p, ctx)
    expect(rows_text(rows)).to_contain("Space 12 m")
    expect(rows_text(rows)).to_contain("Run Derelict Replay (explore a derelict first)")
    row(rows, "Run Sunset Beach").act(st, p)
    expect(p.holo_run.id).to_be("beach")
    local sc = holo.scene(st, p, p.holo_run)
    expect(holo.scene(st, p, p.holo_run)).to_be(sc) -- cached
    expect(#sc.solids).to_be_greater(0)
    p.holo_run.body.pos = { 0, 0, holo.arch(sc.size)[2] + 0.3 }
    expect(holo.hint(st, p)).to_be("USE: EXIT THE PROGRAM")
    -- nothing to use away from the spots and the arch
    p.holo_run.body.pos = { -3, 0, 0 }
    expect(holo.hint(st, p)).to_be(nil)
    expect(holo.use(st, p, ctx)).to_be(false)
    expect(last()).to_contain("exit arch")
    -- the arena's walls and the deck chair stop the body
    p.holo_run.body.pos = { 0, 0, 5.6 }
    p.holo_run.body.yaw = 0
    run(st, cmd({ axes = { move_z = 1 } }), 30)
    expect(p.holo_run.body.pos[3] <= 6 - holo.BODY_R + 1e-6).to_be(true)
    p.holo_run.body.pos = { 0.6, 0, 0.2 }
    expect(holo.hint(st, p)).to_contain("DECK CHAIR")
    run(st, cmd({ pressed = { "use" } }))
    expect(buffs.active(st, p, "calm")).to_be(true)
    run(st, cmd({ axes = { move_z = 1 } }), 30)
    expect(p.holo_run.body.pos[3] < 0.9 - 0.4).to_be(true)
    -- render inside the program, and the HUD status
    local v = fake_view()
    render.render(v, saucer.util.readonly(st), 1)
    expect(v.texts).to_contain("HOLODECK: SUNSET BEACH")
    local where = hud.status(p, st)
    expect(where).to_contain("SUNSET")
    -- the fold keys do nothing in here
    run(st, cmd({ pressed = { "shrink" } }))
    expect(p.holo_run).to_be_truthy()
    expect(p.ship.size).to_be(1)
  end)
  it("flies the Seat course and saves the best time; guests join and leave", function()
    local st = new_state(2)
    local p, q = st.players[1], st.players[2]
    holo.start(st, p, "seat_course", nil, ctx)
    expect(p.holo_run.craft).to_be_truthy()
    expect(holo.hint(st, p)).to_be("USE: END THE RUN")
    -- no guest slots at seats level 1
    local ok, why = holo.join(st, q, p, ctx)
    expect(ok).to_be(false)
    expect(why).to_contain("slot")
    p.holo.mods.seats = 2
    q.ship.pos = { 1e6, 0, 0 }
    expect(select(2, holo.join(st, q, p, ctx))).to_be("too far")
    q.ship.pos = p.ship.pos
    q.mode = "walk"
    local qrows = holo.rows(st, q, ctx)
    row(qrows, "Join P1").act(st, q)
    expect(q.holo_run.guest_of).to_be(1)
    expect(holo.join(st, p, q, ctx)).to_be(false)
    expect(hud.status(q, st)).to_contain("SEAT FLIGHT")
    -- fly through the rings by placing the craft
    local sc = holo.scene(st, p, p.holo_run)
    for i, g in ipairs(sc.gates) do
      p.holo_run.craft.pos = { g[1], g[2], g[3] }
      run(st, cmd(), 1)
      expect(p.holo_run.gate).to_be(i + 1)
    end
    expect(p.holo_run.done).to_be(true)
    expect(p.holo.best.seat_course).to_be_truthy()
    local v = fake_view()
    render.render(v, saucer.util.readonly(st), 1)
    expect(v.texts).to_contain("COURSE CLEAR")
    local v2 = fake_view()
    v2.player, v2.index = 2, 2
    render.render(v2, saucer.util.readonly(st), 1)
    expect(v2.texts).to_contain("SEAT FLIGHT")
    -- the craft stays in the box
    p.holo_run.craft.pos = { 1e3, -50, 0 }
    run(st, cmd(), 1)
    expect(p.holo_run.craft.pos[1] <= sc.size).to_be(true)
    expect(p.holo_run.craft.pos[2] >= 0.8).to_be(true)
    -- the host ends it: the guest drops out too
    run(st, cmd({ pressed = { "use" } }))
    expect(p.holo_run).to_be(false)
    expect(q.holo_run).to_be(false)
    expect(avatar.room(L, p.body)).to_be("Holodeck")
    expect(holo.exit(st, p, ctx)).to_be(false)
    -- a second, faster or slower run keeps the best
    holo.start(st, p, "seat_course", nil, ctx)
    p.holo_run.t = 999
    for _, g in ipairs(sc.gates) do
      p.holo_run.craft.pos = { g[1], g[2], g[3] }
      run(st, cmd(), 1)
    end
    expect(p.msgs[#p.msgs].text).to_contain("best")
    -- a guest that leaves on their own
    holo.start(st, p, "beach", nil, ctx)
    holo.join(st, q, p, ctx)
    expect(#p.holo_run.guests).to_be(1)
    holo.exit(st, q, ctx)
    expect(#p.holo_run.guests).to_be(0)
    -- a guest whose host is gone is sent back
    holo.join(st, q, p, ctx)
    p.holo_run = false
    run(st, cmd(), 1)
    expect(q.holo_run).to_be(false)
    q.holo_run = { guest_of = 1, body = { pos = { 0, 0, 0 }, yaw = 0, pitch = 0 } }
    expect(holo.use(st, q, ctx)).to_be(true)
    expect(holo.spot_near(st, q)).to_be(nil)
    expect(holo.near_arch(st, q)).to_be(false)
  end)
  it("replays an explored derelict and recreates the alien memory", function()
    local st = new_state()
    local p = st.players[1]
    -- a recorded route through site 1
    local o = st.sector.sites[1].pos
    for k = 0, 300 do
      p.ship.pos = { o[1] + k * 0.3, o[2], o[3] }
      st.tick = st.tick + 60
      game.record_trail(st, p, 1)
      if k % 50 == 0 then game.record_trail(st, p, 1, p.ship.pos) end
    end
    expect(#p.trails["1"].pts <= 240).to_be(true)
    expect(#p.trails["1"].marks).to_be_greater(0)
    local rows = holo.rows(st, p, ctx)
    row(rows, "Run Derelict Replay: site 1").act(st, p)
    expect(p.holo_run.arg).to_be(1)
    local v = fake_view()
    render.render(v, saucer.util.readonly(st), 1)
    expect(v.calls.mesh).to_be_greater(3)
    p.holo_run.body.pos = { 0, 0, -math.min(2.6, holo.scene(st, p, p.holo_run).size * 0.4) - 0.2 }
    run(st, cmd({ pressed = { "use" } }))
    expect(last()).to_contain("Replay")
    holo.exit(st, p, ctx)
    holo.unlock(p, "memory")
    holo.start(st, p, "memory", nil, ctx)
    p.holo_run.body.pos = { 0, 0, -0.7 }
    run(st, cmd({ pressed = { "use" } }))
    expect(books.has(p, "memory")).to_be_truthy()
    expect(p.holo.memories).to_be(1)
    render.render(fake_view(), saucer.util.readonly(st), 1)
    st.mystery.mode = "off"
    holo.use(st, p, ctx)
    expect(last()).to_contain("Sandbox")
    holo.exit(st, p, ctx)
    -- every program renders at every detail level
    for d = 1, 3 do
      p.holo.mods.detail = d
      for _, pr in ipairs(holo.programs()) do
        holo.unlock(p, pr.id)
        holo.start(st, p, pr.id, pr.id == "replay" and 1 or nil, ctx)
        local vv = fake_view()
        render.render(vv, saucer.util.readonly(st), 1)
        expect(vv.calls.mesh).to_be_greater(0)
        holo.exit(st, p, ctx)
      end
    end
  end)
  it("view helpers: grid fade, meshes cached, the room and the arch shimmer", function()
    expect(vholo.edge(6, { 0, 0, 0 })).to_be(0)
    expect(vholo.edge(6, { 5.9, 0, 0 }) > 0).to_be(true)
    expect(vholo.grid_mesh(6)).to_be(vholo.grid_mesh(6))
    local st = new_state()
    local p = st.players[1]
    holo.start(st, p, "beach", nil, ctx)
    p.holo_run.body.pos = { 5.6, 0, 0 }
    render.render(fake_view(), saucer.util.readonly(st), 1)
    -- someone else's view of the saucer while a program runs (arch shimmer)
    local st2 = new_state(2)
    holo.start(st2, st2.players[1], "beach", nil, ctx)
    st2.players[2].body = avatar.new(L, L.nav.nodes.holodeck, 1.57)
    local v = fake_view()
    v.player, v.index = 2, 2
    render.render(v, saucer.util.readonly(st2), 2)
    expect(v.calls.mesh).to_be_greater(5)
  end)
end)

describe("trader shop and saving", function()
  it("buys groceries, programs and modules at the trader", function()
    local st = new_state()
    local p = st.players[1]
    p.docked = 1
    p.ship.pos = st.sector.trader.pos
    p.credits = 200
    local rows = trade.rows(st, p, ctx)
    expect(rows_text(rows)).to_contain("Buy 2 Hydro eggs")
    row(rows, "Buy 2 Hydro eggs").act(st, p)
    expect(p.pantry.eggs).to_be(2)
    row(trade.rows(st, p, ctx), "Buy holo program Quiet Forest").act(st, p)
    expect(holo.has(p, "forest")).to_be(true)
    expect(rows_text(trade.rows(st, p, ctx))).to_contain("(owned)")
    row(trade.rows(st, p, ctx), "Buy Holo emitter").act(st, p)
    local mod
    for _, it in ipairs(p.hold) do if it.home and it.home.kind == "module" then mod = it end end
    expect(mod).to_be_truthy()
    row(trade.rows(st, p, ctx), "Buy Cooking Under").act(st, p)
    expect(books.has(p, "star_cookbook")).to_be_truthy()
    p.credits = 0
    local r = row(trade.rows(st, p, ctx), "Buy Guest pattern")
    expect(r.enabled).to_be(false)
    expect(trade.buy(p, { kind = "book", id = "nope", price = 5 })).to_be(false)
  end)
  it("saves the shelf, pantry, holodeck and buffs, not the seated modes", function()
    local st = new_state()
    local p = st.players[1]
    books.add(p, "velari_log")
    kitchen.stock(p, "glowcap", 2)
    holo.unlock(p, "memory")
    buffs.give(st, p, "calm", 3)
    p.tv = { ch = "trader_wave", idx = 1 }
    local rec = save.record(st)
    local st2 = {}
    game.init(st2, { seed = 42, players = 1 })
    save.apply(st2, rec, game)
    local q = st2.players[1]
    expect(books.has(q, "velari_log")).to_be_truthy()
    expect(q.pantry.glowcap).to_be(2)
    expect(holo.has(q, "memory")).to_be(true)
    expect(buffs.active(st2, q, "calm")).to_be(true)
    expect(q.tv).to_be(false)
  end)
end)
