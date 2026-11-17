-- SPDX-License-Identifier: MIT
-- Milestone 8 (add-wider-dark): the galaxy and fold jumps, generated
-- civilizations, the Xenoarchive, requests and reputation, local co-op
-- (joins, gifts, docking, visits), the Clamp, Lockdown, decoys, the Shroud and
-- the Override spike, the Heart and its endings, saves in a far sector, the
-- hive kit, the map, the HUD and the music.
local game = require("sim.game")
local galaxy = require("sim.galaxy")
local civs = require("sim.civs")
local archive = require("sim.archive")
local requests = require("sim.requests")
local coop = require("sim.coop")
local adv = require("sim.advsentry")
local heart = require("sim.heart")
local mystery = require("sim.mystery")
local sentry = require("sim.sentry")
local items = require("sim.items")
local save = require("sim.save")
local panel = require("sim.panel")
local ruinm = require("sim.ruin")
local vec = require("lib.vec")
local render = require("view.render")
local hud = require("view.hud")
local music = require("view.music")
local mapv = require("view.map")

local function cmd(t) return saucer.input.command(t or {}) end
local function run(st, cs, n)
  for _ = 1, n or 1 do
    local f = {}
    for i = 1, #st.players do f[i] = (cs and cs[i]) or cmd() end
    game.step(st, f, 1 / 60)
  end
end
local said = {}
local ctx = { msg = function(_, _, t) said[#said + 1] = t end, fx = function() end }
local function last() return said[#said] or "" end
local function heard(p, s)
  for _, m in ipairs(p.msgs or {}) do if m.text:find(s, 1, true) then return true end end
  for _, t in ipairs(said) do if t:find(s, 1, true) then return true end end
  return false
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
local function new_state(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  for _, p in ipairs(st.players) do p.mode, p.panel = "helm", false end
  return st
end
local function pick(st, p, prefix)
  local i = panel.find(st, p, prefix)
  assert(i, "no row " .. prefix)
  p.panel.sel = i
  local rows = panel.rows(st, p)
  rows[i].act(st, p)
end

describe("galaxy", function()
  it("generates the same seven sectors, a spine to the Heart and hops", function()
    local g = galaxy.generate(42)
    expect(#g.sectors).to_be(7)
    expect(#g.spine).to_be(4)
    expect(g.sectors[g.spine[4]].heart).to_be(true)
    expect(g.sectors[1].name).to_be("Home Drift")
    for _, s in ipairs(g.sectors) do
      expect(#s.civs >= 1).to_be(true)
      expect(s.danger >= 1 and s.danger <= 3).to_be(true)
    end
    expect(galaxy.hops(42, 1, 1)).to_be(0)
    expect(galaxy.hops(42, 1, g.spine[3])).to_be(2)
    expect(galaxy.sector(42, 2).id).to_be(2)
    local a = galaxy.formation({ arrival = { 0, 0, 0 } }, 1, 2)
    local b = galaxy.formation({ arrival = { 0, 0, 0 } }, 2, 2)
    expect(vec.dist(a, b)).to_be(galaxy.tune().arrival_spacing)
    expect(galaxy.copy({ a = { 1 } }).a[1]).to_be(1)
    expect(galaxy.dist({ 0, 0, 0 }, { 3, 4, 0 })).to_be(5)
  end)
  it("far sectors hold civ kits and danger; the home sector is unchanged", function()
    local st = new_state()
    local home = st.sector.sites[1]
    expect(home.tutorial).to_be(true)
    local g = galaxy.generate(42)
    local far = require("sim.sector").generate(42, g.spine[4], g.sectors[g.spine[4]])
    expect(far.sites[1].heart).to_be(true)
    expect(#far.sites).to_be(4)
    for _, s in ipairs(far.sites) do
      expect(s.tutorial).to_be(false)
      expect(s.danger).to_be(g.sectors[g.spine[4]].danger)
    end
  end)
  it("proposes, agrees, waits for readiness, spools and folds the party", function()
    local st = new_state(2)
    local p, q = st.players[1], st.players[2]
    local g = galaxy.generate(42)
    local to = g.spine[2]
    expect(select(2, galaxy.propose(st, p, 99, ctx))).to_be("no such sector")
    expect(select(2, galaxy.propose(st, p, 1, ctx))).to_be("already here")
    expect(select(2, galaxy.propose(st, p, g.spine[3], ctx))).to_be("out of Fold Core range")
    expect(galaxy.agree(st, q, ctx)).to_be(false)
    expect(galaxy.cancel(st, q, ctx)).to_be(false)
    expect(galaxy.propose(st, p, to, ctx)).to_be(true)
    expect(select(2, galaxy.propose(st, p, to, ctx))).to_be("a jump is already proposed")
    expect(galaxy.agreed(st)).to_be(false)
    -- the map: q sees an Agree row, p the tally
    panel.open(q, "map")
    local qrows = panel.rows(st, q)
    expect(qrows[2].text).to_contain("Agree")
    panel.open(p, "map")
    expect(panel.rows(st, p)[2].text).to_contain("1/2 agreed")
    pick(st, q, "Agree")
    expect(galaxy.agreed(st)).to_be(true)
    -- not ready: P2 in the Seat
    q.ship.size = 2
    st.tick = 179
    run(st, nil, 1)
    expect(galaxy.ready(st, q)).to_be(false)
    expect(heard(q, "not at Villa size")).to_be(true)
    q.ship.size = 1
    for _, x in ipairs({ { "mode", "foot", "on foot" }, { "site", 1, "inside a site" }, { "holo_run", {}, "in the holodeck" } }) do
      local old = q[x[1]]
      q[x[1]] = x[2]
      expect(select(2, galaxy.ready(st, q))).to_be(x[3])
      q[x[1]] = old
    end
    q.ship.morph = true
    expect(select(2, galaxy.ready(st, q))).to_be("reshaping")
    q.ship.morph = false
    local ch = q.ship.charge
    q.ship.charge = 1
    expect(select(2, galaxy.ready(st, q))).to_be("low Charge")
    q.ship.charge = ch
    run(st, nil, 60 * 4)
    expect(st.sector_id).to_be(to)
    expect(st.jump).to_be(false)
    expect(heard(p, "Fold jump complete")).to_be(true)
    expect(p.site).to_be(0)
    expect(st.visited["1"]).to_be_truthy()
    -- calling one off
    expect(galaxy.propose(st, p, 1, ctx)).to_be(true)
    panel.open(q, "map")
    pick(st, q, "Call off")
    expect(st.jump).to_be(false)
    -- an out-of-range pick from the map is refused with a message
    panel.open(p, "map")
    for i, r in ipairs(panel.rows(st, p)) do
      if r.sector and r.enabled == false and r.sector ~= st.sector_id then
        p.panel.sel = i
        r.act(st, p)
        break
      end
    end
    -- map links to the party and archive panels
    panel.open(p, "map")
    pick(st, p, "Party")
    expect(p.panel.kind).to_be("party")
    panel.open(p, "map")
    pick(st, p, "Xenoarchive")
    expect(p.panel.kind).to_be("archive")
    pick(st, p, "Close")
    -- going home brings the home sector's state back
    st.jump = false
    game.enter_sector(st, 1)
    expect(st.sector_id).to_be(1)
    expect(st.vault).to_be_truthy()
  end)
end)

describe("civilizations", function()
  it("generates unique, deterministic civs with music and kits", function()
    local u = civs.universe(42)
    expect(#u).to_be(civs.traits().count)
    local names = {}
    for _, c in ipairs(u) do
      expect(names[c.name]).to_be(nil)
      names[c.name] = true
      expect(c.music.tempo > 0).to_be(true)
      expect(#c.kits >= 1).to_be(true)
    end
    local a, b = civs.generate(42, 5, {}), civs.generate(42, 5, {})
    expect(a.name).to_be(b.name)
    local taken = { [a.id] = true }
    expect(civs.generate(42, 5, taken).id).to_be(a.id .. "5")
    expect(civs.describe(u[3])).to_contain(u[3].name)
    expect(civs.by_id(42, u[4].id)).to_be(u[4])
    expect(civs.by_id(42, "nobody")).to_be(nil)
  end)
end)

describe("xenoarchive and requests", function()
  it("files finds, rewards 25/50/100% and gives the blueprint bonus", function()
    local st = new_state()
    local p = st.players[1]
    local civ = civs.get(42, 3)
    local cat = archive.catalog(civ)
    expect(#cat > 0).to_be(true)
    expect(#archive.catalog(nil)).to_be(0)
    expect(archive.meet(p, civ)).to_be(true)
    expect(archive.meet(p, civ)).to_be(false)
    expect(archive.percent(st, p, civ.id)).to_be(0)
    for k = 1, #cat do
      local it = items.stamp(p, { type = cat[k], civ = civ.id }, 1, nil)
      archive.record(st, p, it, ctx)
      archive.record(st, p, it, ctx) -- twice files once
    end
    expect(archive.percent(st, p, civ.id)).to_be(100)
    expect(archive.best(st, civ.id)).to_be(100)
    expect(archive.has_blueprint(p, civ.id)).to_be(true)
    local books = require("sim.books")
    expect(books.resolve(p, "lore:" .. civ.id) ~= nil).to_be(true)
    local rows = archive.rows(st, p)
    expect(rows[1].text).to_contain(civ.name)
    local fresh = { met = nil }
    expect(archive.rows(st, fresh)[1].text).to_contain("No civilizations")
    -- an item with no civ or out of catalog does not count
    expect(archive.record(st, p, { type = "nothing" }, ctx)).to_be(false)
  end)
  it("posts requests, pays double for a match, raises reputation and sells upgrades and decoys", function()
    local st = new_state()
    local p = st.players[1]
    local tr = st.traders[1]
    expect(#tr.requests).to_be(requests.PER_TRADER)
    local r = tr.requests[1]
    expect(requests.label(st, r)).to_contain(r.cat)
    expect(requests.level(0)).to_be("Stranger")
    local it = items.stamp(p, { type = "x", category = r.cat, civ = r.civ, tier = 2, value = 100 }, 2, r.civ)
    it.ident = true
    p.hold[#p.hold + 1] = it
    expect(requests.matches(r, it)).to_be(true)
    expect(requests.matches(r, { echo = 1 })).to_be(false)
    expect(requests.matches(r, { category = "zzz" })).to_be(false)
    expect(requests.matches({ cat = r.cat, civ = "other", tier = 1 }, { category = r.cat, civ = "x" })).to_be(false)
    local c0 = p.credits
    local ok, pay = requests.deliver(st, p, 1, 1, it.uid, ctx)
    expect(ok).to_be(true)
    expect(pay >= requests.MIN_PAY).to_be(true)
    expect(p.credits).to_be(c0 + pay)
    expect(requests.rep(st, p, 1)).to_be(1)
    expect(requests.best_rep(p)).to_be(1)
    expect(#tr.requests).to_be(requests.PER_TRADER)
    expect(requests.deliver(st, p, 1, 1, 999, ctx)).to_be(false)
    expect(requests.price_factor(st, p, 1, nil)).to_be_near(1.05, 1e-9)
    -- terminal rows: decoys and the tier 2 Fold Core
    p.credits = 5000
    p.decoys = 0
    local rows = requests.rows(st, p, 1, ctx)
    local function act(prefix)
      for _, row in ipairs(rows) do if row.text:find(prefix, 1, true) and row.enabled ~= false then row.act(st, p) return true end end
      return false
    end
    expect(act("Decoy flares")).to_be(true)
    expect(p.decoys).to_be(3)
    expect(act("Fold Core tier 2")).to_be(true)
    expect(p.fold_tier).to_be(2)
    expect(galaxy.core(p).hops).to_be(2)
    -- a deliverable request row
    local r2 = tr.requests[1]
    local it2 = items.stamp(p, { type = "x", category = r2.cat, civ = r2.civ, tier = 2, value = 50 }, 2, r2.civ)
    p.hold[#p.hold + 1] = it2
    rows = requests.rows(st, p, 1, ctx)
    expect(act("Request:")).to_be(true)
    expect(requests.rep(st, p, 1)).to_be(2)
  end)
end)

describe("local co-op", function()
  it("joins slots in order on their first button press, beside player 1", function()
    local st = new_state(1)
    run(st, nil, 1)
    game.step(st, { cmd(), cmd(), cmd({ pressed = { "use" } }) }, 1 / 60)
    expect(#st.players).to_be(1) -- slot 3 cannot jump the queue
    game.step(st, { cmd(), cmd({ pressed = { "use" } }) }, 1 / 60)
    expect(#st.players).to_be(2)
    expect(vec.dist(st.players[1].ship.pos, st.players[2].ship.pos) > 20).to_be(true)
    expect(heard(st.players[1], "Player 2 joined")).to_be(true)
    expect(coop.wants_join(cmd())).to_be(false)
    -- a far join (P1 inside a site) uses the formation
    st.players[1].site = 1
    local pos = coop.spawn_spot(st, 3)
    expect(pos[1] ~= nil).to_be(true)
  end)
  it("ejects gifts, beams them up, docks, visits and hands over at the gift table", function()
    local st = new_state(2)
    local p, q = st.players[1], st.players[2]
    local it = items.stamp(p, { type = "x", name = "Spoon", value = 10 }, 1, nil)
    p.hold[#p.hold + 1] = it
    local echo = items.stamp(p, mystery.item(st.mystery, 1), 1, nil)
    p.hold[#p.hold + 1] = echo
    expect(select(2, coop.eject(st, p, 999, 2, ctx))).to_be("gone")
    expect(select(2, coop.eject(st, p, echo.uid, 2, ctx))).to_be("echo")
    p.mode = "foot"
    expect(select(2, coop.eject(st, p, it.uid, 2, ctx))).to_be("on foot")
    p.mode = "helm"
    panel.open(p, "party")
    pick(st, p, "Eject for P2")
    expect(#st.gifts).to_be(1)
    expect(#coop.candidates(st, p, 0)).to_be(0)
    local c = coop.candidates(st, q, 0)
    expect(#c).to_be(1)
    expect(c[1].kind).to_be("gift")
    local got = coop.receive(st, q, c[1].index, ctx)
    expect(got.name).to_be("Spoon")
    expect(coop.receive(st, q, 5, ctx)).to_be(nil)
    -- docking
    q.ship.pos = vec.add(p.ship.pos, { 30, 0, 0 })
    expect(coop.can_dock(st, p, p)).to_be(false)
    expect(coop.can_dock(st, p, q)).to_be(true)
    expect(coop.dock(st, p, q, ctx)).to_be(false)
    panel.open(q, "party")
    expect(panel.rows(st, q)[1].text).to_contain("Accept dock")
    panel.open(p, "party")
    expect(panel.rows(st, p)[1].text).to_contain("waiting")
    pick(st, q, "Accept dock")
    expect(coop.docked(st, p, q)).to_be(true)
    panel.open(q, "party")
    pick(st, q, "Visit P1")
    expect(q.visiting).to_be(1)
    local eye = game.viewpoint(q, st)
    expect(vec.dist(eye, p.ship.pos) < 20).to_be(true)
    expect(#coop.guests(st, p)).to_be(1)
    -- the view shows the guest in the host's dome
    local v = fake_view()
    p.mode = "walk"
    p.body = require("sim.avatar").new(require("sim.avatar").layout(), { -2, 0.6, -1 }, 0)
    render.render(v, saucer.util.readonly(st), 1)
    expect(v.texts).to_contain("") -- renders without touching the state
    local v2 = fake_view({ player = 2, index = 2 })
    render.render(v2, saucer.util.readonly(st), 1)
    expect(v2.texts).to_contain("VISITING P1")
    -- walking the dome; Use at the table opens the gift table
    run(st, { cmd(), cmd({ axes = { move_z = 1 } }) }, 30)
    run(st, { cmd(), cmd({ pressed = { "use" } }) }, 1)
    expect(q.panel and q.panel.kind).to_be("gift_table")
    pick(st, q, "Leave for P1")
    expect(items.find(p, p.next_uid).name).to_be("Spoon")
    panel.open(q, "gift_table")
    expect(panel.rows(st, q)[1].text).to_contain("Nothing")
    -- a full hold refuses
    for _ = 1, 40 do p.hold[#p.hold + 1] = { uid = -1, name = "Junk", ident = true } end
    local it3 = items.stamp(q, { type = "x", name = "Cup" }, 1, nil)
    q.hold[#q.hold + 1] = it3
    expect(coop.give(st, q, p, it3.uid, ctx)).to_be(false)
    -- home via the map's party panel, then drifting apart undocks
    panel.open(q, "party")
    pick(st, q, "Return")
    expect(q.visiting).to_be(false)
    q.ship.pos = vec.add(p.ship.pos, { 400, 0, 0 })
    coop.step(st, ctx)
    expect(coop.docked(st, p, q)).to_be(false)
    expect(coop.undock(st, p, q, ctx)).to_be(false)
    expect(coop.return_home(st, p, ctx)).to_be(false)
    expect(coop.visit(st, p, q, ctx)).to_be(false)
    q.ship.pos = vec.add(p.ship.pos, { 30, 0, 0 })
    coop.dock(st, p, q, ctx)
    coop.dock(st, q, p, ctx)
    panel.open(p, "party")
    pick(st, p, "Undock")
    expect(coop.docked(st, p, q)).to_be(false)
    q.site = 1
    expect(coop.dock(st, p, q, ctx)).to_be(false)
    -- alone: the party panel says how to join
    local solo = new_state(1)
    panel.open(solo.players[1], "party")
    solo.players[1].hold = {}
    expect(panel.rows(solo, solo.players[1])[1].text).to_contain("Nobody else")
  end)
end)

-- the first far site with a Clamp and a Lockdown
local function far_state(n)
  local st = new_state(n)
  local g = galaxy.generate(42)
  game.enter_sector(st, g.spine[2])
  for si = 1, #st.sector.sites do
    local c, l
    for k, d in ipairs(game.sentries(si)) do
      if d.kind == "clamp" and not c then c = k end
      if d.kind == "lockdown" then l = k end
    end
    if c and l then return st, si, c, l end
  end
  error("no site with a Clamp and a Lockdown")
end

describe("advanced sentries and tools", function()
  it("lays out Clamps and a Lockdown only in danger 2+ sites", function()
    local st = new_state()
    local w, s, c, l = sentry.summary(game.sentries(2))
    expect(c + l).to_be(0)
    expect(w + s > 0).to_be(true)
    local st2, si = far_state()
    local _, _, c2, l2 = sentry.summary(game.sentries(si))
    expect(c2 >= 1 and l2 == 1).to_be(true)
    expect(st2.sentries[si] ~= nil).to_be(true)
  end)
  it("a Clamp chases, grips, drains, blocks folds and is shaken off with Boost", function()
    local st, si, ci = far_state()
    local p = st.players[1]
    local def, dyn = game.sentries(si)[ci], st.sentries[si][ci]
    local t = sentry.tune()
    p.site = si
    p.ship.size = 2
    p.ship.pos = vec.add(def.pos, { 0, 0, 6 })
    p.ship.vel = { 0, 0, 0 }
    adv.step_clamp(st, def, dyn, 1 / 60, ctx, t)
    expect(dyn.st).to_be("chase")
    for _ = 1, 120 do adv.step_clamp(st, def, dyn, 1 / 60, ctx, t) end
    expect(dyn.st).to_be("clamped")
    expect(p.clamped_by ~= nil).to_be(true)
    local ch = p.ship.charge
    adv.step_clamp(st, def, dyn, 1, ctx, t)
    expect(p.ship.charge < ch).to_be(true)
    -- no folding while clamped
    run(st, { cmd({ pressed = { "size1" } }) }, 1)
    expect(heard(p, "Clamped")).to_be(true)
    p.shake = t.clamp.shake_time
    adv.step_clamp(st, def, dyn, 1 / 60, ctx, t)
    expect(dyn.st).to_be("disabled")
    expect(p.clamped_by).to_be(nil)
    p.site = 0
    for _ = 1, 60 * 13 do adv.step_clamp(st, def, dyn, 1 / 60, ctx, t) end
    expect(dyn.st).to_be("dormant")
    p.site = si
    -- lost target: back to dormant; target leaving the site releases
    dyn.st, dyn.target = "chase", 1
    p.shroud = true
    expect(adv.shrouded(p, t)).to_be(true)
    for _ = 1, 60 * (t.lose_time + 1) do adv.step_clamp(st, def, dyn, 1 / 60, ctx, t) end
    expect(dyn.st).to_be("dormant")
    p.shroud = false
    dyn.st, dyn.target = "clamped", 1
    p.site = 0
    adv.step_clamp(st, def, dyn, 1 / 60, ctx, t)
    expect(dyn.st).to_be("dormant")
    -- a decoy draws it
    p.site = si
    st.decoys = { { site = si, pos = vec.add(dyn.pos, { 0, 0, 2 }), life = 5 } }
    adv.step_clamp(st, def, dyn, 1 / 60, ctx, t)
    expect(dyn.st).to_be("decoyed")
    st.decoys = {}
    adv.step_clamp(st, def, dyn, 1 / 60, ctx, t)
    expect(dyn.st ~= "decoyed").to_be(true)
    -- jamming frees and disables; off stays off
    dyn.st, dyn.target = "clamped", 1
    expect(adv.jammed(st, def, dyn, t, game.seal)).to_be(true)
    expect(dyn.st).to_be("disabled")
    dyn.st = "off"
    expect(adv.jammed(st, def, dyn, t, game.seal)).to_be(false)
    adv.step_clamp(st, def, dyn, 1, ctx, t)
    expect(dyn.st).to_be("off")
  end)
  it("the Warden patrols the deep halls, hunts, wakes Snatchers and only the Jammer stops it", function()
    local warden = require("sim.warden")
    local st = new_state()
    local g = galaxy.generate(42)
    local deep
    for _, id in ipairs(g.spine) do if g.sectors[id].danger >= 3 then deep = id break end end
    game.enter_sector(st, deep)
    local si, wi
    for s2 = 1, #st.sector.sites do
      for k, d in ipairs(game.sentries(s2)) do
        if d.kind == "warden" and not wi then si, wi = s2, k end
      end
    end
    expect(wi ~= nil).to_be(true)
    local def, dyn = game.sentries(si)[wi], st.sentries[si][wi]
    expect(select(5, sentry.summary(game.sentries(si)))).to_be(1)
    expect(#def.route).to_be_greater(0)
    expect(dyn.st).to_be("patrol")
    local t = sentry.tune()
    local p = st.players[1]
    p.mode = "helm"
    p.site = 0
    -- patrol: it walks its route
    local start = vec.copy(dyn.pos)
    for _ = 1, 600 do warden.step(st, def, dyn, 1 / 60, ctx, t) end
    expect(dyn.st).to_be("patrol")
    if #def.route > 1 then expect(vec.dist(start, dyn.pos) > 0.5 or dyn.wp ~= 1).to_be(true) end
    -- a hull in sight, inside its halls: the hunt
    p.site = si
    p.ship.pos = vec.add(dyn.pos, { 0, 0, 0.5 })
    p.ship.vel = { 0, 0, 0 }
    -- the Shroud hides a still hull
    p.shroud = true
    expect(warden.sees(def, dyn, p, t)).to_be(false)
    p.shroud = false
    expect(warden.sees(def, dyn, p, t)).to_be(true)
    local before = #(st.bolts or {})
    st.bolts = st.bolts or {}
    warden.step(st, def, dyn, 1 / 60, ctx, t)
    expect(dyn.st).to_be("hunt")
    expect(dyn.target).to_be(1)
    expect(last()).to_contain("WARDEN")
    for _ = 1, 60 do warden.step(st, def, dyn, 1 / 60, ctx, t) end
    expect(#st.bolts).to_be_greater(before)
    expect(hud.alarm(st, p)).to_be("WARDEN")
    -- it woke the site's Snatchers
    for k, d in ipairs(game.sentries(si)) do
      if d.kind == "snatcher" then expect(st.sentries[si][k].woke).to_be_greater(st.tick) end
    end
    -- far away: it follows, but never leaves its halls
    p.ship.pos = vec.add(def.leash[2], { 50, 0, 0 })
    for _ = 1, 30 do warden.step(st, def, dyn, 1 / 60, ctx, t) end
    expect(adv.decoy_for(st, def, dyn.pos, t)).to_be(nil)
    -- out of sight long enough: back on patrol
    for _ = 1, math.ceil(t.lose_time * 3 * 60) + 2 do warden.step(st, def, dyn, 1 / 60, ctx, t) end
    expect(dyn.st).to_be("patrol")
    -- a Decoy takes its attention
    st.decoys = { { site = si, pos = vec.add(dyn.pos, { 0, 0, 2 }), life = 8 } }
    warden.step(st, def, dyn, 1 / 60, ctx, t)
    expect(dyn.st).to_be("decoyed")
    st.decoys = {}
    warden.step(st, def, dyn, 1 / 60, ctx, t)
    expect(dyn.st).to_be("patrol")
    -- the Jammer stuns it; the spike can then finish it
    local n = sentry.jam(st, si, game.sentries(si), vec.add(dyn.pos, { 0, 0, -2 }), { 0, 0, 1 }, p)
    expect(n).to_be_greater(0)
    expect(dyn.st).to_be("disabled")
    p.mode = "foot"
    p.excursion = { body = { pos = vec.add(dyn.pos, { 0, -1.6, 0 }), yaw = 0, pitch = 0 } }
    expect(adv.spike_target(st, p, t)).to_be(wi)
    p.mode, p.excursion = "helm", nil
    warden.step(st, def, dyn, t.disabled_time + 1, ctx, t)
    expect(dyn.st).to_be("patrol")
    dyn.st = "off"
    warden.step(st, def, dyn, 1, ctx, t)
    expect(dyn.st).to_be("off")
    -- a hunting Warden sounds the Lockdown alarm; the view draws it
    dyn.st, dyn.target = "hunt", 1
    local A = require("view.assets").init()
    local v = fake_view()
    p.scan_until = st.tick + 100
    render.draw_sentries(v, A, st, p)
    expect(v.calls.mesh).to_be_greater(0)
    expect(#render.radar_targets(st, p)).to_be_greater(0)
  end)
  it("the Cutter slices a Lockdown's seals (add-home-among-stars)", function()
    local tools = require("sim.tools")
    local st, si, _, li = far_state()
    local p = st.players[1]
    local def, dyn = game.sentries(si)[li], st.sentries[si][li]
    p.site = si
    game.seal(def, dyn, true)
    expect(#dyn.sealed).to_be_greater(0)
    local bx = def.boxes[dyn.sealed[1]]
    p.mode = "foot"
    p.suit = 80
    p.excursion = { body = { pos = { bx[3][1], bx[3][2] - 1.6, bx[3][3] }, yaw = 0, pitch = 0, crouch = false } }
    local tg = tools.cut_target(st, p)
    expect(tg.kind).to_be("seal")
    local n = 0
    while tools.cut_step(st, p, n == 0, 1 / 60, ctx) and dyn.st ~= "rest" do n = n + 1 if n > 1000 then break end end
    expect(dyn.st).to_be("rest")
    expect(#dyn.sealed).to_be(0)
    expect(game.sealed_count(def)).to_be(0)
    expect(last()).to_contain("Lockdown seals")
    p.mode, p.excursion = "helm", nil
  end)
  it("Lockdown seals the hall's big doors on a lock, rests, and the Jammer opens it", function()
    local st, si, _, li = far_state()
    local p = st.players[1]
    local def, dyn = game.sentries(si)[li], st.sentries[si][li]
    local t = sentry.tune()
    p.site = si
    expect(#def.boxes > 0).to_be(true)
    adv.step_lockdown(st, def, dyn, 1 / 60, ctx, t, game.seal)
    expect(dyn.st).to_be("dormant")
    for k, d in ipairs(game.sentries(si)) do
      if d.kind == "watcher" then st.sentries[si][k].st = "locked" break end
    end
    adv.step_lockdown(st, def, dyn, 1 / 60, ctx, t, game.seal)
    expect(dyn.st).to_be("sealing")
    expect(#dyn.sealed > 0).to_be(true)
    local n = game.sealed_count(def)
    expect(n).to_be(#dyn.sealed)
    local any = false
    for _, t0 in ipairs(said) do if t0:find("LOCKDOWN", 1, true) then any = true end end
    expect(any).to_be(true)
    expect(game.box_has_hull(st, def.boxes[1])).to_be(false)
    -- a restore while sealed puts the same seals back
    game.rebuild(st)
    expect(game.sealed_count(def)).to_be(n)
    expect(#dyn.sealed).to_be(n)
    adv.step_lockdown(st, def, dyn, t.lockdown.seal_time + 1, ctx, t, game.seal)
    expect(dyn.st).to_be("rest")
    expect(#dyn.sealed).to_be(0)
    adv.step_lockdown(st, def, dyn, t.lockdown.rest + 1, ctx, t, game.seal)
    expect(dyn.st).to_be("dormant")
    adv.step_lockdown(st, def, dyn, 1 / 60, ctx, t, game.seal)
    expect(adv.jammed(st, def, dyn, t, game.seal)).to_be(true)
    expect(#dyn.sealed).to_be(0)
    adv.step_lockdown(st, def, dyn, t.disabled_time + 1, ctx, t, game.seal)
    expect(dyn.st).to_be("dormant")
    dyn.st = "off"
    adv.step_lockdown(st, def, dyn, 1, ctx, t, game.seal)
    expect(dyn.st).to_be("off")
  end)
  it("decoys, the Shroud and the Override spike", function()
    local st, si, ci, li = far_state()
    local p = st.players[1]
    local t = sentry.tune()
    -- decoys only inside a site, three of them
    expect(game.decoy(st, p)).to_be(false)
    p.site = si
    p.ship.pos = vec.copy(game.sentries(si)[ci].pos)
    for _ = 1, 3 do expect(game.decoy(st, p)).to_be(true) end
    expect(game.decoy(st, p)).to_be(false)
    expect(#st.decoys).to_be(3)
    run(st, nil, 60 * 9)
    expect(#st.decoys).to_be(0)
    -- Shroud toggles at the helm, refused on foot, drains Charge
    run(st, { cmd({ pressed = { "shroud" } }) }, 1)
    expect(p.shroud).to_be(true)
    local ch = p.ship.charge
    run(st, nil, 60)
    expect(p.ship.charge < ch).to_be(true)
    p.ship.charge = 0
    run(st, nil, 2)
    expect(p.shroud).to_be(false)
    p.mode = "foot"
    expect(game.shroud(st, p)).to_be(false)
    p.mode = "helm"
    -- the spike: a disabled Clamp next to a person on foot
    local def, dyn = game.sentries(si)[ci], st.sentries[si][ci]
    dyn.st, dyn.t = "disabled", 99
    p.mode, p.excursion = "foot", { body = { pos = vec.copy(dyn.pos), yaw = 0, pitch = 0, vel = { 0, 0, 0 } } }
    p.hands = {}
    local saved_vp = game.viewpoint
    game.viewpoint = function(q, s) if q == p then return vec.copy(dyn.pos), 0, 0 end return saved_vp(q, s) end
    expect(adv.spike_target(st, p, t)).to_be(ci)
    game.spike_step(st, p, cmd({ buttons = { "spike" } }), 1)
    expect(p.spike.t).to_be(1)
    game.spike_step(st, p, cmd({ buttons = { "spike" } }), t.spike.time)
    expect(dyn.st).to_be("off")
    expect(st.overrides[adv.key(def)] ~= nil).to_be(true)
    expect(adv.overridden(st, def)).to_be(true)
    expect(p.hands[1].name).to_be("Sentry core")
    game.spike_step(st, p, cmd({ buttons = { "spike" }, pressed = { "spike" } }), 1)
    expect(p.spike).to_be(false)
    game.spike_step(st, p, cmd(), 1)
    -- a Lockdown node can be spiked any time
    local ld = st.sentries[si][li]
    ld.sealed = {}
    local ldef = game.sentries(si)[li]
    game.viewpoint = function(q, s) if q == p then return vec.copy(ldef.pos), 0, 0 end return saved_vp(q, s) end
    for k = 1, 4 do p.hands[k] = p.hands[k] or { uid = -k } end
    game.spike_step(st, p, cmd({ buttons = { "spike" } }), t.spike.time + 0.1)
    expect(ld.st).to_be("off")
    game.viewpoint = saved_vp
    -- overrides persist through a save: the sentry comes back off
    local rec = save.record(st)
    local st2 = { players = { {} } }
    save.apply(st2, rec, game)
    expect(st2.sector_id).to_be(st.sector_id)
    expect(st2.sentries[si][ci].st).to_be("off")
    p.mode, p.excursion = "helm", nil
    expect(adv.spike_target(st, p, t)).to_be(nil)
  end)
  it("jamming your own Clamp at the helm frees you", function()
    local st, si, ci = far_state()
    local p = st.players[1]
    local def, dyn = game.sentries(si)[ci], st.sentries[si][ci]
    p.site = si
    p.ship.pos = vec.copy(def.pos)
    dyn.st, dyn.target = "clamped", 1
    p.clamped_by = { site = si, id = def.id }
    p.ship.charge = 100
    run(st, { cmd({ pressed = { "jam" } }) }, 1)
    expect(p.clamped_by).to_be(nil)
  end)
end)

describe("the Heart", function()
  it("opens to the Heart Key, votes with the tie to the last Key, ends and pays out", function()
    local st = new_state(2)
    local p, q = st.players[1], st.players[2]
    local m = st.mystery
    local g = galaxy.generate(42)
    expect(m.heart_sector).to_be(g.spine[4])
    expect(mystery.open_heart(m, 1)).to_be(false) -- not in Act III yet
    for i, e in ipairs(m.echoes) do
      if (e.sector or 1) == 1 then
        mystery.found(m, i, 1)
        if mystery.decodable(m, i) then mystery.decode(m, i) end
      end
    end
    mystery.open_vault(m)
    m.mode = "hints"
    expect(mystery.hint(m)).to_contain("sector")
    local wi, ki = mystery.index_of(m, "witness"), mystery.index_of(m, "heart_key")
    expect(mystery.decodable(m, ki)).to_be(false)
    mystery.found(m, wi, 1)
    expect(mystery.hint(m)).to_contain("Decode")
    mystery.decode(m, wi)
    expect(m.act).to_be(3)
    expect(mystery.resonant_sectors(m)[m.heart_sector]).to_be(true)
    mystery.found(m, ki, 2)
    expect(mystery.hint(m)).to_contain("Heart Key")
    local key = items.stamp(q, mystery.item(m, ki), 1, nil)
    q.hold[#q.hold + 1] = key
    expect(heart.key_item(st, q)).to_be(key)
    game.enter_sector(st, m.heart_sector)
    local core, hi = heart.core(st)
    expect(hi).to_be(1)
    -- view: the core beats
    local v = fake_view()
    render.render(v, saucer.util.readonly(st), 1)
    q.site, q.ship.pos, q.ship.size = hi, vec.copy(core), 2
    p.site = hi
    expect(heart.near_core(st, q)).to_be(true)
    heart.step(st, ctx)
    expect(m.heart_open).to_be(true)
    expect(m.last_key_by).to_be(2)
    expect(mystery.hint(m)).to_contain("Vote")
    expect(heart.can_vote(st, p)).to_be(true)
    expect(#heart.present(st)).to_be(2)
    local hv = fake_view()
    render.render(hv, saucer.util.readonly(st), 1)
    expect(hv.texts).to_contain("TAB TO VOTE")
    -- vote through the map
    panel.open(p, "map")
    pick(st, p, "Vote on an ending")
    expect(p.panel.kind).to_be("heart")
    local e1, e2 = m.endings[1], m.endings[2]
    pick(st, p, e1.title)
    expect(mystery.vote(m, 1, "nope")).to_be(false)
    heart.step(st, ctx)
    expect(m.ending).to_be(false)
    panel.open(q, "heart")
    expect(panel.rows(st, q)[#panel.rows(st, q) - 1].text).to_contain("1 of 2")
    pick(st, q, e2.title)
    heart.step(st, ctx)
    expect(m.ending).to_be(e2.id)
    expect(m.act).to_be(4)
    expect(mystery.hint(m)).to_be(nil)
    expect(heard(p, "ENDING")).to_be(true)
    expect(mystery.vote(m, 1, e1.id)).to_be(false)
    expect(heart.resolve(st, e1.id, ctx)).to_be(false)
    local cp = mystery.centerpiece(m).name
    local function has(x) for _, it in ipairs(x.hold) do if it.name == cp then return true end end return false end
    expect(has(p) and has(q)).to_be(true)
    -- the ending persists through a save
    local rec = save.record(st)
    local st2 = { players = { {} } }
    save.apply(st2, rec, game)
    expect(st2.mystery.ending).to_be(e2.id)
    expect(#st2.players).to_be(2)
    -- effects
    for _, id in ipairs({ "seal", "restore", "take" }) do
      expect(mystery.effect({ ending = id }, id == "seal" and "watcher_range" or "none")).to_be_truthy()
    end
    expect(mystery.effect({ ending = "seal" }, "watcher_range")).to_be(0.8)
    expect(mystery.effect(nil, "x")).to_be(1)
    expect(mystery.tally(m, {})).to_be(nil)
    expect(mystery.ending_of(m, "nope")).to_be(nil)
  end)
  it("the translation gate refuses the Witness until 25% of its civ is archived", function()
    local st = new_state()
    local p = st.players[1]
    local m = st.mystery
    for i, e in ipairs(m.echoes) do
      if (e.sector or 1) == 1 then mystery.found(m, i, 1) if mystery.decodable(m, i) then mystery.decode(m, i) end end
    end
    mystery.open_vault(m)
    local wi = mystery.index_of(m, "witness")
    mystery.found(m, wi, 1)
    local it = items.stamp(p, mystery.item(m, wi), 1, nil)
    p.hold[#p.hold + 1] = it
    local lab = require("sim.lab")
    p.ship.charge = 100
    expect(lab.pick(st, p, it.uid, ctx)).to_be(false)
    expect(last()).to_contain("Xenoarchive needs 25%")
    local civ = civs.by_id(42, m.echoes[wi].gate_civ)
    local cat = archive.catalog(civ)
    for k = 1, math.ceil(#cat / 4) do archive.record(st, p, items.stamp(p, { type = cat[k], civ = civ.id }, 1, nil), ctx) end
    expect(lab.pick(st, p, it.uid, ctx)).to_be(true)
  end)
end)

describe("hive kit, map, HUD and music", function()
  it("hive ruins generate", function()
    for s = 1, 6 do
      local r = ruinm.generate(saucer.seed_child(42, "hivecheck", s), "hive", civs.get(42, 1), { 0, 0, 0 })
      expect(r.kit).to_be("hive")
      expect(#r.rooms > 3).to_be(true)
    end
  end)
  it("draws the map, the spare quarter, new HUD lines and new sentries without touching the state", function()
    local st, si, ci, li = far_state(3)
    local p = st.players[1]
    p.site = si
    p.clamped_by = { site = si, id = ci }
    p.shroud = true
    p.decoys = 2
    st.decoys = { { site = si, pos = vec.copy(p.ship.pos), life = 4 } }
    st.gifts = { { pos = vec.copy(p.ship.pos), item = { name = "x", size = 1, value = 1 }, to = 0, from = 2, site = si } }
    st.sentries[si][li].sealed = { true }
    st.sentries[si][ci].st = "chase"
    galaxy.propose(st, st.players[2], 1, ctx)
    st.jump.spool = 1.5
    panel.open(p, "map")
    local before = require("lib.meshkit").copy(st)
    local v = fake_view()
    render.render(v, saucer.util.readonly(st), 1)
    expect(v.texts).to_contain("CLAMPED")
    expect(v.texts).to_contain("SHROUD")
    expect(v.texts).to_contain("DECOYS 2")
    expect(v.texts).to_contain("SECTOR MAP")
    expect(v.texts).to_contain("SPOOLING")
    st.jump.spool = -1
    local v2 = fake_view({ player = 2, index = 2 })
    render.render(v2, saucer.util.readonly(st), 1)
    local v3 = fake_view({ player = 3, index = 3 })
    render.render(v3, saucer.util.readonly(st), 1)
    expect(v3.texts).to_contain("TAB TO AGREE")
    -- a split-screen quarter: shorter prompts, moved out of the top rows
    local v4 = fake_view({ player = 3, index = 3, width = 256, height = 144 })
    render.render(v4, saucer.util.readonly(st), 1)
    expect(v4.texts).to_contain("TAB AGREES")
    -- a four-way quarter: only the essentials
    local v5 = fake_view({ width = 256, height = 144 })
    render.render(v5, saucer.util.readonly(st), 1)
    expect(v5.texts).to_contain("CLAMPED - BOOST")
    expect(v5.texts:find("DECOYS", 1, true)).to_be(nil)
    expect(v5.texts:find("HOLD ", 1, true)).to_be(nil)
    local spare = fake_view({ player = 0, index = 4, width = 240, height = 135 })
    render.render(spare, saucer.util.readonly(st), 1)
    expect(spare.texts).to_contain("JOIN")
    expect(spare.texts).to_contain("P3")
    st.jump.spool = 1.5
    expect(st).to_equal(before)
  end)
  it("plays civ music: stems, scales, beats, pitches", function()
    local st = new_state()
    local p = st.players[1]
    music.reset()
    expect(music.ratio(12)).to_be_near(2, 1e-9)
    local stem, civ = music.stem(st, p)
    expect(stem).to_be("space")
    p.site = 2
    expect((music.stem(st, p))).to_be("site")
    for _, s in ipairs({ "space", "site", "alert" }) do
      local any = 0
      for n = 0, 31 do any = any + #music.notes(s, civ, n) end
      expect(any > 0).to_be(true)
    end
    expect(#music.notes("site", nil, 0) > 0).to_be(true)
    expect(music.beat(st, "alert", civ) >= music.beat(st, "space", civ)).to_be(true)
    local n = 0
    for k = 1, 600 do
      st.tick = k
      n = n + music.update(st, p)
    end
    expect(n > 0).to_be(true)
    p.mode = "wake"
    expect(music.update(st, p)).to_be(0)
    music.enabled = false
    p.mode = "helm"
    expect(music.update(st, p)).to_be(0)
    music.enabled = true
    expect(music.hash(1, 2, 3)).to_be(music.hash(1, 2, 3))
    local v = fake_view({ width = 240, height = 135 })
    mapv.draw(v, st, 0, 0, 120, 100, p)
    expect(v.calls.rect > 7).to_be(true)
  end)
end)
