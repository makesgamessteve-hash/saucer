-- SPDX-License-Identifier: MIT
-- add-playtest-recs: the eleven recommendations of the 2026-11-17 playtest
-- (docs/playtest/2026-11-17.md): upgrades, the lab's second bench and decode
-- priority, the fold warning, the Seat hint, the helm beam relay, the
-- pickpocket's roll, the tow bill, the drowsy Warden, co-op twin vaults,
-- party requests and fold readiness, the grapple key and the HUD's message
-- stack, and the story-item sale warning.
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local upgrades = require("sim.upgrades")
local lab = require("sim.lab")
local trade = require("sim.trade")
local requests = require("sim.requests")
local coop = require("sim.coop")
local twin = require("sim.twin")
local hull = require("sim.hull")
local sentry = require("sim.sentry")
local tractor = require("sim.tractor")
local visit = require("sim.visit")
local items = require("sim.items")
local panel = require("sim.panel")
local avatar = require("sim.avatar")
local vec = require("lib.vec")
local hud = require("view.hud")

local function cmd(t) return saucer.input.command(t or {}) end
local function run(st, cs, n)
  for _ = 1, n or 1 do
    local f = {}
    for i = 1, #st.players do f[i] = (cs and cs[i]) or cmd() end
    game.step(st, f, 1 / 60)
  end
end
local said = {}
local ctx = { msg = function(_, p, t)
  said[#said + 1] = t
  if p and p.msgs then p.msgs[#p.msgs + 1] = { tick = 0, text = t } end
end, fx = function() end }
local function heard(s)
  for _, t in ipairs(said) do if t:find(s, 1, true) then return true end end
  return false
end
local function pheard(p, s)
  for _, m in ipairs(p.msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end
local function new_state(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  for _, p in ipairs(st.players) do p.mode, p.panel = "helm", false end
  return st
end
local function row(rows, prefix)
  for _, r in ipairs(rows) do if r.text:sub(1, #prefix) == prefix then return r end end
  return nil
end
local function stamp(p, over)
  local it = { type = "plate", name = "Plate", size = 1, category = "material" }
  for k, v in pairs(over or {}) do it[k] = v end
  items.stamp(p, it, it.tier or 1, "velari")
  it.hot = false
  p.hold[#p.hold + 1] = it
  return it
end
local function fake_view(opts)
  local v = { calls = {}, width = 640, height = 360, player = 1, index = 1, xr = false, texts = "", lines = {} }
  for k, x in pairs(opts or {}) do v[k] = x end
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image" }) do
    v[m] = function(self, ...)
      self.calls[m] = (self.calls[m] or 0) + 1
      if m == "text" then
        local x, y, s = ...
        self.texts = self.texts .. s .. "|"
        self.lines[#self.lines + 1] = { x = x, y = y, s = s }
        return #s * 8
      end
    end
  end
  return v
end
local function dock(st, p)
  local tp = st.sector.trader.pos
  p.ship.pos = { tp[1] + 60 + 30 * (p.index - 1), tp[2], tp[3] + 60 }
  p.site = 0
  run(st, nil, 1)
end

describe("upgrades (recommendation 1)", function()
  it("sells levels after Fold Core T2 at the terminal, with their effects", function()
    local st = new_state()
    local p = st.players[1]
    dock(st, p)
    expect(trade.docked_at(st, p)).to_be(1)
    p.panel = false
    p.mode = "walk"
    panel.open(p, "trade")
    p.credits = 5000
    local rows = panel.rows(st, p)
    local relay = row(rows, "Upgrade Helm beam relay")
    expect(relay ~= nil and relay.enabled).to_be(true)
    expect(relay.hint).to_contain("helm")
    local coils = row(rows, "Upgrade Tractor coils")
    expect(coils.enabled).to_be(false)
    expect(coils.text).to_contain("needs Fold Core T2")
    expect(select(2, upgrades.buy(p, "tractor_coils"))).to_be("tier")
    expect(select(2, upgrades.buy(p, "nothing"))).to_be("unknown")
    relay.act(st, p)
    expect(upgrades.level(p, "beam_relay")).to_be(1)
    expect(p.credits).to_be(5000 - 180)
    expect(row(panel.rows(st, p), "Upgrade Helm beam relay").text).to_contain("fitted")
    expect(select(2, upgrades.buy(p, "beam_relay"))).to_be("max")
    p.fold_tier = 2
    -- hold racks: +4 a level
    expect(upgrades.hold_slots(p)).to_be(12)
    expect(upgrades.hold_slots(nil)).to_be(12)
    row(panel.rows(st, p), "Upgrade Hold racks").act(st, p)
    expect(upgrades.hold_slots(p)).to_be(16)
    expect(row(panel.rows(st, p), "Upgrade Hold racks").text).to_contain("1/2")
    -- coils: the beam pulls faster
    expect(upgrades.pull_factor(p)).to_be(1)
    upgrades.buy(p, "tractor_coils")
    expect(upgrades.pull_factor(p)).to_be_near(1 / 1.4, 1e-9)
    -- shield cells soak more per shield point
    local a, b = { size = 1, shield = 100, hull = 100 }, { size = 1, shield = 100, hull = 100 }
    hull.damage(a, 20)
    upgrades.buy(p, "shield_cells")
    expect(p.ship.cells).to_be(1)
    b.cells = 1
    hull.damage(b, 20)
    expect(b.shield).to_be_greater(a.shield)
    -- a second lab bench
    expect(upgrades.lab_slots(p)).to_be(1)
    upgrades.buy(p, "lab_bench")
    expect(lab.slots(p)).to_be(2)
    expect(p.upgrade_spent).to_be_greater(0)
    p.credits = 0
    expect(select(2, upgrades.buy(p, "hold_racks"))).to_be("credits")
  end)
  it("the station chandler fits them too", function()
    local st = new_state()
    local p = st.players[1]
    dock(st, p)
    expect(visit.pocket(st, p, visit.pocket_size(), ctx)).to_be(true)
    p.ship.morph, p.ship.t_left = false, 0
    local L = visit.layout(st, p)
    local ch
    for _, s in ipairs(L.stalls) do if s.vendor == "chandler" then ch = s end end
    panel.open(p, "vendor", ch.id)
    p.credits = 500
    local r = row(panel.rows(st, p), "Upgrade Helm beam relay")
    expect(r ~= nil and r.enabled).to_be(true)
    r.act(st, p)
    expect(upgrades.level(p, "beam_relay")).to_be(1)
  end)
end)

describe("the lab (recommendation 2)", function()
  it("puts decodes ahead of Identify jobs and runs two jobs with the second bench", function()
    local st = new_state()
    local p = st.players[1]
    p.ship.charge = 100
    local a = stamp(p, { tier = 1 })
    local b = stamp(p, { tier = 1 })
    expect(lab.enqueue(st, p, a.uid)).to_be(true)
    expect(lab.enqueue(st, p, b.uid)).to_be(true)
    -- a data core jumps the queue
    local core = stamp(p, { type = "core", name = "Data core", home = { kind = "program", id = "beach" }, value = 30 })
    expect(lab.enqueue(st, p, core.uid)).to_be(true)
    expect(p.lab.queue[1].kind).to_be("core")
    expect(lab.push_front(p, { uid = 999, kind = "decode", left = 1, total = 1 })).to_be(2)
    table.remove(p.lab.queue, 2)
    -- one bench: only the first runs
    lab.step(st, p, 1, ctx)
    expect(p.lab.queue[2].left).to_be(p.lab.queue[2].total)
    local rows = lab.rows(st, p, ctx)
    expect(rows[2].text).to_contain("(queued)")
    local s1 = hud.lab_status(st, p)
    expect(s1).to_contain("+2")
    -- two benches: the first two run side by side
    p.upgrades = { lab_bench = 1 }
    lab.step(st, p, 1, ctx)
    expect(p.lab.queue[2].left).to_be_less(p.lab.queue[2].total)
    expect(hud.lab_status(st, p)).to_contain("DECODE")
    expect(hud.lab_status(st, p)).to_contain("ID ")
    -- jobs finishing on the second bench come off the queue too
    p.lab.queue[2].left = 0.001
    p.lab.queue[1].left = 99
    local done = lab.step(st, p, 1 / 60, ctx)
    expect(done.kind).to_be("identify")
    -- paused in the Seat
    p.ship.size = 2
    expect(hud.lab_status(st, p)).to_contain("PAUSED")
    expect(lab.rows(st, p, ctx)[1].text).to_contain("(paused)")
  end)
end)

describe("the fold warning (recommendation 3)", function()
  it("asks before the first fold into danger 2 and remembers what you braved", function()
    local st = new_state()
    local p = st.players[1]
    local g = galaxy.generate(42)
    local d2 = g.spine[2]
    expect(g.sectors[d2].danger).to_be(2)
    local w = galaxy.warning(st, p, d2)
    expect(#w).to_be_greater(2)
    expect(w[2]).to_contain("Seat")
    expect(table.concat(w, " ")).to_contain("No Seat dive yet")
    -- every line fits the panel at 1280x720 (and in a split view)
    for _, l in ipairs(w) do expect(#l <= 52).to_be(true) end
    expect(table.concat(w, " ")).to_contain("tow bill")
    expect(#galaxy.warning(st, p, 1)).to_be(0)
    expect(#galaxy.warning(st, p, 999)).to_be(0)
    panel.open(p, "map")
    local r = row(panel.rows(st, p), g.sectors[d2].name)
    r.act(st, p)
    expect(p.panel.kind).to_be("fold_warn")
    expect(st.jump).to_be(false)
    expect(panel.title(st, p)).to_be("FOLD WARNING")
    row(panel.rows(st, p), "Not yet").act(st, p)
    expect(p.panel).to_be(false)
    -- Tab closes it too
    panel.open(p, "fold_warn", d2)
    run(st, { cmd({ pressed = { "map" } }) }, 1)
    expect(p.panel).to_be(false)
    panel.open(p, "fold_warn", d2)
    row(panel.rows(st, p), "Fold anyway").act(st, p)
    expect(st.jump.to).to_be(d2)
    expect(p.braved).to_be(2)
    expect(#galaxy.warning(st, p, d2)).to_be(0)
    -- a failing proposal still says why
    panel.open(p, "fold_warn", d2)
    row(panel.rows(st, p), "Fold anyway").act(st, p)
    expect(pheard(p, "already proposed")).to_be(true)
    -- seasoned and rich: only the danger lines
    st.jump = false
    p.seat_dives, p.fold_tier, p.credits, p.braved = 1, 2, 500, 1
    expect(#galaxy.warning(st, p, d2)).to_be(2)
    local d3
    for _, s in ipairs(g.sectors) do if s.danger == 3 then d3 = s.id break end end
    expect(galaxy.warning(st, p, d3)[1]).to_contain("Warden")
    -- arriving in a sector counts as braving it
    game.enter_sector(st, d2)
    expect(p.braved).to_be(2)
  end)
end)

describe("the Seat hint (recommendation 4)", function()
  it("says once that the Seat slips past Watchers, and names them on the way in", function()
    local st = new_state()
    local p = st.players[1]
    expect(sentry.seat_hint(st, p, ctx)).to_be(true)
    expect(heard("TIP: Watchers ignore")).to_be(true)
    expect(sentry.seat_hint(st, p, ctx)).to_be(false)
    local q = new_state().players[1]
    q.ship.size = 2
    expect(sentry.seat_hint(st, q, ctx)).to_be(false)
    -- the entry message names the Watchers for a Villa
    local guarded
    for i = 1, #st.sector.sites do
      if select(1, sentry.summary(game.sentries(i))) > 0 then guarded = i break end
    end
    expect(guarded ~= nil).to_be(true)
    expect(game.entry_text(st, p, guarded)).to_contain("the Seat slips past")
    p.ship.size = 2
    expect(game.entry_text(st, p, guarded)).to_be("Entering derelict site " .. guarded)
    -- a Seat dive is counted
    p.mode = "helm"
    local b = game.site_bounds(guarded)
    p.ship.pos = { (b[1][1] + b[2][1]) / 2, (b[1][2] + b[2][2]) / 2, (b[1][3] + b[2][3]) / 2 }
    p.ship.morph = false
    run(st, nil, 1)
    expect(p.seat_dives).to_be(1)
  end)
end)

describe("the helm beam relay (recommendation 5)", function()
  it("pulls a small find from the helm once fitted", function()
    local st = new_state()
    local p = st.players[1]
    expect(upgrades.relay(p, { size = 1 })).to_be(false)
    p.upgrades = { beam_relay = 1 }
    expect(upgrades.relay(p, { size = 2 })).to_be(true)
    expect(upgrades.relay(p, { size = 3 })).to_be(false)
    expect(upgrades.relay(p, nil)).to_be(false)
    -- hover over a size-S find in site 1 and press F at the helm
    local site = 1
    local cand
    for _, c in ipairs(tractor.candidates(st, p, site, game.ruin(site))) do
      if c.kind == "slot" and c.item.size <= 2 and not c.axis and not cand then cand = c end
    end
    expect(cand ~= nil).to_be(true)
    local b = tractor.beam_of(p.ship)
    local e = b.emitter
    p.ship.pos = { cand.pos[1] - e[1], cand.pos[2] - e[2] + 6, cand.pos[3] - e[3] }
    p.ship.vel, p.ship.bank, p.ship.yaw = { 0, 0, 0 }, 0, 0
    p.site = game.site_at(p.ship.pos)
    local sc = tractor.scan(st, p, p.site, game.ruin(p.site))
    if sc and sc.status == "lock" then
      run(st, { cmd({ pressed = { "tractor" } }) }, 1)
      expect(p.tractor ~= false).to_be(true)
      expect(p.tractor.relay).to_be(true)
      expect(pheard(p, "Helm relay lock")).to_be(true)
      -- the HUD says F pulls
      local v = fake_view()
      hud.beam(v, st, p, sc)
    end
    -- the HUD hint with a relay-sized lock
    local v = fake_view()
    p.tractor = false
    hud.beam(v, st, p, { cand = cand, status = "lock", info = { hint = "LOCK", off = { 0, 0, 0 }, max_lateral = 1, depth = 5 } })
    expect(v.texts).to_contain("HELM RELAY")
    p.upgrades = {}
    v = fake_view()
    hud.beam(v, st, p, { cand = cand, status = "lock", info = { hint = "LOCK", off = { 0, 0, 0 }, max_lateral = 1, depth = 5 } })
    expect(v.texts).to_contain("GO DOWN TO THE TRACTOR ROOM")
  end)
  it("still sends big finds down to the console", function()
    local st = new_state()
    local p = st.players[1]
    p.upgrades = { beam_relay = 1 }
    local big
    for i = 1, #st.sector.sites do
      for _, c in ipairs(tractor.candidates(st, p, i, game.ruin(i))) do
        if c.kind == "slot" and c.item.size >= 3 and c.item.size <= 4 and not big then big = { c = c, site = i } end
      end
    end
    if not big then return end
    local c = big.c
    local b = tractor.beam_of(p.ship)
    local e = b.emitter
    p.ship.pos = { c.pos[1] - e[1], c.pos[2] - e[2] + 8, c.pos[3] - e[3] }
    p.ship.vel, p.ship.bank = { 0, 0, 0 }, 0
    p.ship.yaw = c.axis or 0
    p.site = game.site_at(p.ship.pos)
    run(st, { cmd({ pressed = { "tractor" } }) }, 1)
    expect(p.tractor).to_be(false)
  end)
end)

describe("the pickpocket (recommendation 6)", function()
  it("works your first visit, then about one in four with quiet visits between", function()
    local st = new_state()
    local p = st.players[1]
    local on = {}
    for i = 1, 40 do on[i] = visit.thief_roll(st, p) end
    expect(on[1]).to_be(true)
    expect(on[2]).to_be(false)
    expect(on[3]).to_be(false)
    local n, gap = 0, 0
    for i = 1, 40 do
      if on[i] then
        n = n + 1
        gap = 0
      else
        gap = gap + 1
        expect(gap <= 6).to_be(true) -- pity: never more than six quiet visits
      end
    end
    expect(n >= 5 and n <= 14).to_be(true)
    -- the same seed rolls the same visits
    local st2 = new_state()
    for i = 1, 40 do expect(visit.thief_roll(st2, st2.players[1])).to_be(on[i]) end
  end)
  it("a quiet visit's thief never stalks", function()
    local st = new_state()
    local p = st.players[1]
    p.thief_visit, p.visits = 1, 1
    dock(st, p)
    expect(visit.pocket(st, p, visit.pocket_size(), ctx)).to_be(true)
    expect(p.station.thief.working).to_be(false)
    p.ship.morph, p.ship.t_left = false, 0
    p.station.coin, p.station.t = "pocket", 999
    local L = visit.layout(st, p)
    p.station.body.pos = { L.thief.home[1] + 1, 0, L.thief.home[2] }
    visit.thief_step(st, p, 1 / 60, ctx)
    expect(p.station.thief.mode).to_be("lurk")
  end)
end)

describe("the tow bill (recommendation 7)", function()
  it("costs nothing at home, credits then Charge at danger 2+", function()
    local st = new_state()
    local p = st.players[1]
    p.credits = 500
    expect(hull.bill(st, p)).to_be(0)
    expect(p.last_bill).to_be(nil)
    local g = galaxy.generate(42)
    game.enter_sector(st, g.spine[2])
    p.credits = 500
    expect(hull.bill(st, p)).to_be(60)
    expect(p.credits).to_be(440)
    p.credits, p.ship.charge = 20, 100
    local paid, chg = hull.bill(st, p)
    expect(paid).to_be(20)
    expect(chg).to_be(40)
    expect(p.ship.charge).to_be(60)
    p.credits, p.ship.charge = 0, 10
    paid, chg = hull.bill(st, p)
    expect(chg).to_be(10)
    expect(p.ship.charge).to_be(0)
    -- a real Fold Retreat reports it
    p.credits, p.ship.charge = 100, 80
    p.ship.hull = 0
    run(st, nil, 1)
    expect(pheard(p, "Tow bill")).to_be(true)
    expect(p.credits).to_be(40)
    p.credits, p.ship.charge, p.ship.hull = 0, 80, 0
    run(st, nil, 1)
    expect(pheard(p, "Charge.")).to_be(true)
  end)
end)

describe("the drowsy Warden (recommendation 8)", function()
  it("keeps patrolling, slower, after the grid console", function()
    local warden = require("sim.warden")
    local st = new_state()
    local g = galaxy.generate(42)
    local deep
    for _, s in ipairs(g.sectors) do if s.danger >= 3 then deep = s.id break end end
    game.enter_sector(st, deep)
    local si, wi
    for s2 = 1, #st.sector.sites do
      for k, d in ipairs(game.sentries(s2)) do if d.kind == "warden" and not wi then si, wi = s2, k end end
    end
    local def, dyn = game.sentries(si)[wi], st.sentries[si][wi]
    local p = st.players[1]
    local n = sentry.grid_down(st, si)
    expect(dyn.st).to_be("patrol")
    expect(n).to_be(#st.sentries[si] - 1)
    st.grids = { [tostring(si)] = { by = 1, tick = 0 } }
    local p0 = vec.copy(dyn.pos)
    sentry.step(st, si, game.sentries(si), 1, ctx)
    expect(dyn.drowsy).to_be(true)
    expect(dyn.st).to_be("patrol")
    local moved = vec.dist(p0, dyn.pos)
    expect(moved <= sentry.tune().warden.speed * 0.5 + 1e-6).to_be(true)
    -- it still hunts a hull in sight, but wakes no Snatchers
    p.mode, p.site = "helm", si
    p.ship.pos = vec.add(dyn.pos, { 0, 0, 0.5 })
    p.ship.vel = { 0, 0, 0 }
    sentry.step(st, si, game.sentries(si), 1 / 60, ctx)
    expect(dyn.st).to_be("hunt")
    for k, d in ipairs(game.sentries(si)) do
      if d.kind == "snatcher" then expect(st.sentries[si][k].woke).to_be(nil) end
    end
    -- the grid console says so
    local ex = require("sim.excursion")
    said = {}
    ex.shut_grid(st, p, si, ctx)
    expect(heard("keeps patrolling")).to_be(true)
    -- jammed, it still sleeps it off
    dyn.st, dyn.t = "disabled", 0.5
    warden.step(st, def, dyn, 1, ctx, sentry.tune(), true)
    expect(dyn.st).to_be("patrol")
  end)
end)

describe("co-op (recommendation 9)", function()
  local function twin_site(st)
    for i = 1, #st.sector.sites do
      if twin.layout(game.ruin(i)) then return i, twin.layout(game.ruin(i)) end
    end
  end
  it("twin vaults need one saucer on the anchor while the other beams", function()
    local st = new_state(2)
    local p, q = st.players[1], st.players[2]
    local solo = new_state(1)
    expect(#twin.candidates(solo, solo.players[1], 1, game.ruin(1))).to_be(0)
    expect(twin.layout(nil)).to_be(nil)
    local site, L = twin_site(st)
    expect(site ~= nil).to_be(true)
    expect(#twin.candidates(st, p, 0, nil)).to_be(0)
    local c = twin.candidates(st, p, site, game.ruin(site))
    expect(#c).to_be(2)
    expect(c[1].kind).to_be("anchor")
    expect(c[2].sealed).to_be(true)
    -- sealed: the beam says why
    local st1, info = tractor.check(p.ship, c[2])
    expect(st1).to_be("sealed")
    expect(info.hint).to_contain("PARTNER")
    -- q beams the anchor and hovers near it
    local ap = twin.anchor_pos(L)
    q.ship.pos = { ap[1], ap[2] + 8, ap[3] }
    q.site, q.mode = site, "helm"
    game.pick_up(st, q, c[1], site)
    expect(twin.holder(st, site)).to_be(q)
    expect(pheard(p, "holds the twin vault open")).to_be(true)
    expect(twin.open_for(st, site, q)).to_be(false)
    expect(twin.open_for(st, site, p)).to_be(true)
    -- the holder no longer sees the anchor; p sees the vault open
    expect(#twin.candidates(st, q, site, game.ruin(site))).to_be(1)
    local pc = twin.candidates(st, p, site, game.ruin(site))
    expect(pc[2].sealed).to_be(false)
    -- p beams the vault: a prize each
    p.site = site
    local h0, g0 = #p.hold, #q.hold
    game.pick_up(st, p, pc[2], site)
    expect(#p.hold).to_be(h0 + 1)
    expect(#q.hold).to_be(g0 + 1)
    expect(p.hold[#p.hold].twin).to_be(true)
    expect(p.twins).to_be(1)
    expect(#twin.candidates(st, p, site, game.ruin(site))).to_be(0)
    expect(twin.take(st, p, site, ctx)).to_be(false)
  end)
  it("the hold drops when the holder drifts away, and a full hold gets a gift", function()
    local st = new_state(2)
    local p, q = st.players[1], st.players[2]
    local site, L = twin_site(st)
    local ap = twin.anchor_pos(L)
    q.ship.pos = { ap[1], ap[2] + 8, ap[3] }
    q.site, q.mode = site, "helm"
    twin.hold(st, q, site, ctx)
    q.ship.pos = vec.add(ap, { twin.HOLD_RANGE + 10, 0, 0 })
    twin.step(st, ctx)
    expect(twin.holder(st, site)).to_be(nil)
    expect(pheard(q, "let go of the shutter")).to_be(true)
    -- hold again, then q's hold is full: the prize waits as a gift
    q.ship.pos = { ap[1], ap[2] + 8, ap[3] }
    twin.hold(st, q, site, ctx)
    for _ = 1, upgrades.hold_slots(q) do stamp(q) end
    p.site = site
    expect(twin.take(st, p, site, ctx)).to_be(true)
    expect(#st.gifts).to_be(1)
    expect(st.gifts[1].to).to_be(2)
    -- a shutter that fell while the vault came up
    local st2 = new_state(2)
    expect(twin.take(st2, st2.players[1], site, ctx)).to_be(false)
    expect(heard("fell shut")).to_be(true)
    -- not on foot
    local q2 = st2.players[2]
    q2.ship.pos, q2.site, q2.mode = { ap[1], ap[2] + 8, ap[3] }, site, "foot"
    twin.hold(st2, q2, site, ctx)
    expect(twin.holder(st2, site)).to_be(nil)
  end)
  it("party requests need two of you and pay everyone", function()
    local st = new_state(2)
    local p, q = st.players[1], st.players[2]
    local pr = st.traders[1].party
    expect(pr ~= nil).to_be(true)
    expect(new_state(1).traders[1].party).to_be(nil)
    expect(requests.party_label(pr)).to_contain("at least two")
    local function bring(who)
      local it = stamp(who, { category = pr.cat })
      return requests.party_deliver(st, who, 1, it.uid, ctx)
    end
    expect(requests.party_deliver(st, p, 1, 999, ctx)).to_be(false)
    expect(bring(p)).to_be(true)
    expect(bring(p)).to_be(true)
    -- p's share is in: a third from p is refused
    expect(requests.party_room(pr, p)).to_be(false)
    expect(bring(p)).to_be(false)
    local c0, d0 = p.credits, q.credits
    local ok, filled = bring(q)
    expect(ok and filled).to_be(true)
    expect(p.credits).to_be(c0 + requests.PARTY_PAY)
    expect(q.credits).to_be(d0 + requests.PARTY_PAY)
    expect(requests.rep(st, q, 1)).to_be(1)
    expect(st.traders[1].party ~= pr).to_be(true)
    -- the terminal row
    dock(st, p)
    p.mode = "walk"
    panel.open(p, "trade")
    local np = st.traders[1].party
    stamp(p, { category = np.cat })
    local r = row(panel.rows(st, p), "Party request:")
    expect(r.enabled).to_be(true)
    r.act(st, p)
    expect(np.got).to_be(1)
    -- a player joining later posts one
    local st3 = new_state(1)
    coop.join(st3, 2, ctx)
    expect(st3.traders[1].party ~= nil).to_be(true)
  end)
  it("shows who is ready to fold", function()
    local st = new_state(2)
    local p, q = st.players[1], st.players[2]
    p.ship.charge, q.ship.charge = 100, 100
    local r = coop.readiness(st)
    expect(#r).to_be(2)
    expect(hud.ready_line(st, p, false)).to_be(nil)
    expect(hud.ready_line(new_state(1), p, false)).to_be(nil)
    panel.open(q, "party")
    row(panel.rows(st, q), "I'm ready to fold").act(st, q)
    expect(q.ready_fold).to_be(true)
    expect(pheard(p, "P2 is ready to fold")).to_be(true)
    expect(hud.ready_line(st, p, false)).to_contain("P2 READY TO FOLD")
    expect(hud.ready_line(st, q, true)).to_be(nil)
    expect(row(panel.rows(st, q), "Fold: ").text).to_contain("P2 READY")
    row(panel.rows(st, q), "Not ready").act(st, q)
    expect(q.ready_fold).to_be(false)
    -- during a vote: everyone's state
    q.site = 3
    galaxy.propose(st, p, galaxy.generate(42).spine[2], ctx)
    expect(hud.ready_line(st, p, false)).to_contain("INSIDE A SITE")
    expect(hud.ready_line(st, p, true)).to_contain("WAIT")
    local v = fake_view()
    hud.jump(v, st, p, false)
    expect(v.texts).to_contain("P1 READY")
    game.enter_sector(st, galaxy.generate(42).spine[2])
    expect(q.ready_fold).to_be(false)
  end)
end)

describe("controls and the HUD (recommendation 10)", function()
  it("binds the grapple on its own key, pad button and touch button", function()
    local def = require("lib.data").load("input/default.lua")
    local g = def.buttons.grapple
    expect(table.concat(g, " ")).to_contain("key:Y")
    expect(table.concat(g, " ")).to_contain("pad:dpup")
    expect(table.concat(g, " ")).to_contain("touch:grapple")
    expect(def.button_order[#def.button_order - 5]).to_be("grapple")
    for _, b in ipairs(def.buttons.shroud) do expect(b ~= "key:Y").to_be(true) end
    expect(hud.TOUCH_LABEL.grapple).to_be("GRP")
  end)
  it("the Shroud key on foot no longer grapples", function()
    local st = new_state()
    local p = st.players[1]
    p.mode = "foot"
    expect(game.shroud(st, p)).to_be(false)
    expect(pheard(p, "Y fires the grapple")).to_be(true)
  end)
  it("wraps, folds repeats and puts the most urgent message first", function()
    local st = new_state()
    local p = st.players[1]
    p.msgs = {
      { tick = 0, text = "Got a thing" },
      { tick = 0, text = "A Clamp drone latches onto your hull: hold Boost to shake it off before it drains you dry" },
      { tick = 0, text = "THE WARDEN has seen you - and the Snatchers wake. Jam it, or break its line of sight" },
      { tick = 0, text = "Got a thing" },
    }
    local lines = hud.message_lines(st, p, 40, 6)
    expect(lines[1][2]).to_be(3)
    expect(lines[1][1]).to_contain("THE WARDEN")
    local all = {}
    for _, l in ipairs(lines) do
      expect(#l[1] <= 40).to_be(true)
      all[#all + 1] = l[1]
    end
    expect(table.concat(all, "|")).to_contain("(x2)")
    expect(#hud.message_lines(st, p, 40, 2)).to_be(2)
    expect(hud.urgency("TIP: something")).to_be(2)
    expect(hud.urgency("Banked 2 items")).to_be(1)
    local w = hud.wrap("one two three four five six seven", 10, 2)
    expect(#w).to_be(2)
    expect(w[2]:sub(-3)).to_be("...")
    -- expired messages are gone
    st.tick = hud.MSG_TICKS + 10
    expect(#hud.message_lines(st, p, 40, 6)).to_be(0)
  end)
  it("shows hints for the current mode only, and stacks the centre alerts", function()
    local st = new_state()
    local p = st.players[1]
    expect(hud.hint_context(p)).to_be("helm")
    expect(hud.hint_for(p, "kbm")).to_contain("fly")
    p.mode = "walk"
    expect(hud.hint_for(p, "kbm")).to_contain("walk")
    expect(hud.hint_for(p, "pad")).to_contain("LS walk")
    expect(hud.hint_for(p, "xr")).to_contain("use")
    p.mode, p.excursion = "foot", {}
    expect(hud.hint_context(p)).to_be("foot")
    expect(hud.hint_for(p, "kbm")).to_contain("Y grapple")
    p.station = {}
    expect(hud.hint_context(p)).to_be("station")
    p.mode, p.excursion, p.station = "helm", false, nil
    -- alerts: a Clamp, a Snatcher and a lock, most urgent first
    p.clamped_by = { site = 1, id = 1 }
    p.latched_by = { t = 1 }
    local a = hud.alerts(st, p, 640)
    expect(a[1][1]).to_contain("CLAMPED")
    expect(a[2][1]).to_contain("SNATCHER")
    expect(#hud.alerts(st, p, 300)).to_be(2)
    -- drawn at 1280x720's HUD size, every line fits on screen
    p.mode = "walk"
    p.body = avatar.new(avatar.layout(), { -2, 0.6, -1 }, 0)
    p.msgs = { { tick = 0, text = string.rep("long message ", 12) } }
    local v = fake_view({ width = 640, height = 360 })
    hud.draw(v, st, p, nil)
    for _, l in ipairs(v.lines) do
      expect(l.x + #l.s * 8 <= 640 + 1e-6).to_be(true)
    end
    expect(v.texts).to_contain("CLAMPED")
    expect(v.texts).to_contain("WASD walk")
    -- the walk hint goes after HINT_TICKS in one context
    st.tick = hud.HINT_TICKS + 5
    local v2 = fake_view({ width = 640, height = 360 })
    hud.draw(v2, st, p, nil)
    expect(v2.texts:find("WASD walk", 1, true)).to_be(nil)
    -- a new context shows its own hint again
    p.mode = "helm"
    local v3 = fake_view({ width = 640, height = 360 })
    hud.draw(v3, st, p, nil)
    expect(v3.texts).to_contain("WASD fly")
    p.clamped_by, p.latched_by = nil, nil
  end)
  it("on foot in a station the coin line is not overprinted", function()
    local st = new_state()
    local p = st.players[1]
    dock(st, p)
    expect(visit.pocket(st, p, visit.pocket_size(), ctx)).to_be(true)
    p.decoys = 3
    st.hardcore = true
    local v = fake_view({ width = 640, height = 360 })
    hud.draw(v, st, p, nil)
    for _, l in ipairs(v.lines) do
      if l.s:find("DECOYS", 1, true) then error("decoys drawn on foot") end
      if l.s == "HARDCORE" then expect(l.y).to_be(116) end
    end
  end)
end)

describe("story items at a stall (recommendation 11)", function()
  it("warns before a data core is sold, and sells it on the second pick", function()
    local st = new_state()
    local p = st.players[1]
    dock(st, p)
    p.mode = "walk"
    local core = stamp(p, { type = "core", name = "Data core", home = { kind = "program", id = "beach" }, value = 30 })
    local mod = stamp(p, { type = "module", name = "Module", home = { kind = "module", id = "x" }, value = 30 })
    local prog = { home = { kind = "program" }, ident = true }
    expect(trade.story_warning(core)).to_contain("decode")
    expect(trade.story_warning(mod)).to_contain("holodeck")
    expect(trade.story_warning(prog)).to_contain("program")
    expect(trade.story_warning({ type = "plate" })).to_be(nil)
    panel.open(p, "trade")
    local r = row(panel.rows(st, p), "Sell Data core")
    expect(r.text).to_contain("story item")
    expect(r.hint).to_contain("decode")
    r.act(st, p)
    expect(items.find(p, core.uid) ~= nil).to_be(true)
    expect(pheard(p, "Wait:")).to_be(true)
    local r2 = row(panel.rows(st, p), "CONFIRM: sell")
    expect(r2 ~= nil).to_be(true)
    r2.act(st, p)
    expect(items.find(p, core.uid)).to_be(nil)
    expect(trade.sell_text(p, { type = "plate", name = "Plate", ident = true }, 5)).to_be("Sell Plate - 5 c")
  end)
end)
