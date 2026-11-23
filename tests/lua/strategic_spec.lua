-- SPDX-License-Identifier: MIT
-- add-strategic-sentries: suspicion meters and signatures, the site alarm, sweep patterns,
-- cover and guarded finds, power-cell sabotage, the Spotter drone, the HUD arc and the scan.
local game = require("sim.game")
local sentry = require("sim.sentry")
local stealth = require("sim.stealth")
local spotter = require("sim.spotter")
local tractor = require("sim.tractor")
local adv = require("sim.advsentry")
local configs = require("sim.config")
local vec = require("lib.vec")
local hud = require("view.hud")
local render = require("view.render")
local assets = require("view.assets")

local function cmd(t) return saucer.input.command(t or {}) end
local function run(st, c, n)
  for _ = 1, n or 1 do
    local cs = {}
    for i = 1, #st.players do cs[i] = c or cmd() end
    game.step(st, cs, 1 / 60)
  end
end
local said = {}
local ctx = { msg = function(_, p, t)
  said[#said + 1] = t
  if p and p.msgs then p.msgs[#p.msgs + 1] = { tick = 0, text = t } end
end, fx = function() end, seal = function() end }
local function heard(s)
  for _, t in ipairs(said) do if t:find(s, 1, true) then return true end end
  return false
end
local function new_state(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  for _, p in ipairs(st.players) do p.mode, p.panel = "helm", false end
  return st
end
local function fake_view(w, h)
  local v = { calls = {}, width = w or 480, height = h or 270, player = 1, index = 1, xr = false, rects = {}, texts = {} }
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image", "vignette" }) do
    v[m] = function(self, ...)
      self.calls[m] = (self.calls[m] or 0) + 1
      if m == "rect" then self.rects[#self.rects + 1] = { ... } end
      if m == "text" then
        self.texts[#self.texts + 1] = tostring((select(3, ...)))
        return 8 * #tostring((select(3, ...)))
      end
    end
  end
  return v
end
local function seat_size()
  for i = 1, configs.count() do if configs.get(i).name == "Seat" then return i end end
  return 2
end
-- a hall Watcher of site 2 with a cell, and the site's Spotter
local function hall_watcher(site)
  for i, d in ipairs(game.sentries(site or 2)) do
    if d.kind == "watcher" and d.cell then return d, i end
  end
end
local function spotter_of(site)
  for i, d in ipairs(game.sentries(site or 2)) do if d.kind == "spotter" then return d, i end end
end

describe("signature: how readable you are", function()
  it("grows with the hull, the speed, the beam and Loud modules", function()
    local st = new_state()
    local p = st.players[1]
    local S = stealth.tune()
    p.ship.vel = { 0, 0, 0 }
    local villa_still = stealth.signature(p)
    expect(villa_still).to_be_near(S.hull.villa * S.still, 1e-9)
    p.ship.vel = { S.speed_ref, 0, 0 }
    expect(stealth.signature(p)).to_be_near(1.0, 1e-9)
    p.ship.vel = { 1000, 0, 0 }
    expect(stealth.signature(p)).to_be_near(S.still + (1 - S.still) * S.speed_cap, 1e-9)
    p.ship.vel = { 0, 0, 0 }
    p.ship.size = seat_size()
    expect(stealth.signature(p)).to_be_less(villa_still)
    p.site = 2
    p.tractor = { site = 2, kind = "slot" }
    expect(stealth.signature(p)).to_be_near(S.hull.seat * S.still + S.beam, 1e-9)
    p.tractor = false
    p.ship.loud = 2
    expect(stealth.signature(p)).to_be_near(S.hull.seat * S.still + 2 * S.loud, 1e-9)
    p.ship.loud = nil
    p.mode, p.excursion = "foot", { body = {} }
    expect(stealth.signature(p, S)).to_be_near(S.hull.foot * S.still, 1e-9)
  end)
end)

describe("the suspicion meter", function()
  it("fills faster up close and with the alarm up, slower for a light sentry; drains out of sight", function()
    local st = new_state()
    local p = st.players[1]
    local def = hall_watcher(2)
    local far = stealth.fill(st, def, p, 90, 100)
    local near = stealth.fill(st, def, p, 5, 100)
    expect(near).to_be_greater(far)
    stealth.raise(st, 2, 1, ctx)
    expect(stealth.fill(st, def, p, 90, 100)).to_be_greater(far)
    st.alarm = {}
    local light = { site = 1, light = true, kind = "watcher" }
    expect(stealth.fill(st, light, p, 90, 100)).to_be_less(far)
    local spot = { site = 2, kind = "spotter" }
    expect(stealth.fill(st, spot, p, 90, 100)).to_be_greater(far)
    local dyn = {}
    stealth.step_meter(st, def, dyn, p, 50, 100, 0.1)
    expect(dyn.meter).to_be_greater(0)
    expect(dyn.sus).to_be(p.index)
    for _ = 1, 200 do stealth.step_meter(st, def, dyn, p, 5, 100, 0.1) end
    expect(dyn.meter).to_be(1)
    for _ = 1, 100 do stealth.step_meter(st, def, dyn, nil, 0, 1, 0.1) end
    expect(dyn.meter).to_be(0)
    expect(dyn.sus).to_be(nil)
  end)
  it("a Watcher goes Alert at half and Locked only at full; a glimpse slips away", function()
    local st = new_state()
    local p = st.players[1]
    local def, i = hall_watcher(2)
    local T = sentry.tune()
    p.site, p.ship.size = 2, seat_size()
    p.ship.vel = { 0, 0, 0 }
    local dyn = st.sentries[2][i]
    -- hold the turret still on its axis and put the Seat in front of it
    def.pattern_save, def.period_save = def.pattern, def.period
    local dir = sentry.dir_of(def.yaw, def.pitch)
    p.ship.pos = vec.add(def.pos, vec.scale(dir, 18))
    local states, slipped = {}, false
    local function tick() sentry.step(st, 2, game.sentries(2), 1 / 60, ctx) states[dyn.st] = true end
    -- force its sweep to look straight at the Seat for a while
    local saved = stealth.sweep
    stealth.sweep = function(d, dy) return d.yaw end
    for _ = 1, 30 do tick() end
    expect(dyn.meter).to_be_greater(0)
    expect(dyn.st == "dormant" or dyn.st == "alert").to_be(true)
    for _ = 1, 600 do tick() if dyn.st == "locked" then break end end
    expect(states.alert).to_be(true)
    expect(dyn.st).to_be("locked")
    expect(stealth.level(st, 2)).to_be_greater(0)
    expect(heard("SITE ALARM")).to_be(true)
    -- the Seat ducks away: the lock drops, the meter keeps a memory below Alert
    p.ship.pos = vec.add(def.pos, { 0, 500, 0 })
    for _ = 1, 120 do tick() end
    expect(dyn.st).to_be("dormant")
    expect(dyn.meter <= T.stealth.after_lock).to_be(true)
    -- a short glimpse: Alert, then lost before the lock
    dyn.meter = 0
    p.ship.pos = vec.add(def.pos, vec.scale(dir, 18))
    for _ = 1, 600 do tick() if dyn.st == "alert" then break end end
    expect(dyn.st).to_be("alert")
    p.ship.pos = vec.add(def.pos, { 0, 500, 0 })
    for _ = 1, 120 do tick() if dyn.st == "dormant" then slipped = true break end end
    expect(slipped).to_be(true)
    stealth.sweep = saved
  end)
  it("without stealth tuning the meter is all or nothing, as before", function()
    local st = new_state()
    local p = st.players[1]
    local def, i = hall_watcher(2)
    local T = sentry.tune()
    local S = T.stealth
    T.stealth = nil
    p.site, p.ship.size = 2, 1
    local dir = sentry.dir_of(def.yaw, def.pitch)
    p.ship.pos = vec.add(def.pos, vec.scale(dir, 30))
    local dyn = st.sentries[2][i]
    dyn.yaw = def.yaw
    sentry.step(st, 2, game.sentries(2), 1 / 60, ctx)
    T.stealth = S
    expect(dyn.meter == 0 or dyn.meter == 1).to_be(true)
  end)
  it("the Snatcher senses a working beam from farther", function()
    local st = new_state()
    local p = st.players[1]
    local def, i
    for k, d in ipairs(game.sentries(2)) do if d.kind == "snatcher" then def, i = d, k break end end
    local dyn = st.sentries[2][i]
    local T = sentry.tune()
    p.site, p.ship.size = 2, seat_size()
    p.hold = { { uid = 1, hot = true, name = "x", size = 1, value = 1, type = "plate" } }
    local q = vec.copy(dyn.pos)
    q[1] = q[1] + T.snatcher.sense * 1.15
    p.ship.pos = q
    local inbox = (not def.leash) or (q[1] >= def.leash[1][1] and q[1] <= def.leash[2][1])
    expect(sentry.snatcher_wants(def, dyn, p, T)).to_be(false)
    p.tractor = { site = 2, kind = "slot" }
    expect(sentry.snatcher_wants(def, dyn, p, T)).to_be(inbox)
  end)
end)

describe("the site alarm", function()
  it("rises per lock to its max, wakes the Snatchers at 2, trips the Lockdown, cools down", function()
    local st = new_state()
    local p = st.players[1]
    local S = stealth.tune()
    p.site = 2
    said = {}
    expect(stealth.level(st, 2)).to_be(0)
    expect(stealth.raise(st, 2, 1, ctx, "test")).to_be(1)
    expect(heard("(test)")).to_be(true)
    expect(stealth.raise(st, 2, 1, ctx)).to_be(2)
    expect(heard("The alarm wakes")).to_be(true)
    local woke = false
    for k, d in ipairs(game.sentries(2)) do
      if d.kind == "snatcher" and (st.sentries[2][k].woke or 0) > st.tick then woke = true end
    end
    expect(woke).to_be(true)
    expect(stealth.raise(st, 2, 5, ctx)).to_be(S.alarm_max)
    expect(stealth.max_level(2)).to_be(S.alarm_max)
    -- the tutorial derelict's alarm stops low
    expect(stealth.max_level(1)).to_be(S.light_alarm_max)
    expect(stealth.raise(st, 1, 3, ctx)).to_be(S.light_alarm_max)
    -- faster fire with the alarm up, never for a light Watcher
    local def = hall_watcher(2)
    expect(stealth.fire_every(st, def, 1.6)).to_be_less(1.6)
    expect(stealth.fire_every(st, { site = 1, light = true }, 1.6)).to_be(1.6)
    -- cooling: nobody seen, you inside: one level per cool_in
    for _, dyn in ipairs(st.sentries[2]) do if dyn.st ~= "off" then dyn.st = "dormant" end end
    stealth.step_alarm(st, S.cool_in, ctx)
    expect(stealth.level(st, 2)).to_be(S.alarm_max - 1)
    expect(heard("eases to")).to_be(true)
    -- nobody inside: faster
    p.site = 0
    stealth.step_alarm(st, S.cool_out, ctx)
    expect(stealth.level(st, 2)).to_be(S.alarm_max - 2)
    -- someone hunted: it holds
    st.sentries[2][1].st = "alert"
    stealth.step_alarm(st, S.cool_out * 5, ctx)
    expect(stealth.level(st, 2)).to_be(S.alarm_max - 2)
    st.sentries[2][1].st = "dormant"
    for _ = 1, 10 do stealth.step_alarm(st, S.cool_out, ctx) end
    expect(st.alarm["2"]).to_be(nil)
    expect(st.alarm["1"]).to_be(nil)
    stealth.step_alarm({ players = {} }, 1, ctx)
  end)
  it("trips a Lockdown node when it reaches lockdown_at", function()
    local st = new_state()
    local defs = { { kind = "lockdown", site = 2, id = 1 } }
    local dyn = { st = "dormant", sealed = {} }
    local T = sentry.tune()
    -- a fake site with one Lockdown node
    local saved = game.sentries
    game.sentries = function(i) if i == 9 then return defs end return saved(i) end
    st.sentries[9] = { dyn }
    stealth.raise(st, 9, T.stealth.lockdown_at, ctx)
    expect(dyn.trip).to_be(true)
    local sealed = 0
    adv.step_lockdown(st, defs[1], dyn, 1 / 60, ctx, T, function() sealed = sealed + 1 end)
    expect(dyn.st).to_be("sealing")
    expect(dyn.trip).to_be(nil)
    expect(sealed).to_be(1)
    game.sentries = saved
    st.sentries[9] = nil
  end)
end)

describe("sweep patterns", function()
  it("three shapes, picked per turret, a light one always smooth", function()
    expect(stealth.shape("sine", 0.25)).to_be_near(1, 1e-9)
    expect(stealth.shape("hold", 0.2)).to_be(1)
    expect(stealth.shape("hold", 0.7)).to_be(-1)
    expect(stealth.shape("step", 0.0)).to_be(-1)
    expect(stealth.shape("step", 0.1)).to_be_near(-1, 1e-9)
    local mid = stealth.shape("step", (0 + 0.85) / 6)
    expect(mid > -1 and mid < -1 / 3).to_be(true)
    expect(stealth.shape("step", 4.5 / 6)).to_be_near(1 / 3, 1e-9)
    expect(stealth.shape("sine", 1.25)).to_be_near(1, 1e-9)
    expect(stealth.pattern_of(1, 3, true)).to_be("sine")
    local seen = {}
    for site = 1, 6 do for room = 1, 6 do seen[(stealth.pattern_of(site, room))] = true end end
    expect(seen.sine and seen.step and seen.hold).to_be(true)
    -- the alarm makes it sweep faster
    local st = new_state()
    local def = hall_watcher(2)
    local T = sentry.tune()
    local a, b = { yaw = 0 }, { yaw = 0 }
    stealth.sweep(def, a, st, 1, T)
    stealth.raise(st, 2, 2, ctx)
    stealth.sweep(def, b, st, 1, T)
    expect(b.ph - (st.tick / 60) / (T.watcher.sweep_period * def.period)).to_be_greater(
      a.ph - (st.tick / 60) / (T.watcher.sweep_period * def.period))
    local c = { ph = 0.999 }
    stealth.sweep(def, c, st, 1, T)
    expect(c.ph < 1).to_be(true)
  end)
end)

describe("cover and guarded finds", function()
  it("every hall Watcher's room has pillars and a guarded find in its sweep", function()
    local r = game.ruin(2)
    local defs = game.sentries(2)
    local cover, guarded = 0, 0
    for _, d in ipairs(r.debris) do if d.cover then cover = cover + 1 end end
    for _, s in ipairs(r.slots) do if s.guarded then guarded = guarded + 1 end end
    local halls = 0
    for _, d in ipairs(defs) do if d.kind == "watcher" and not d.shaft then halls = halls + 1 end end
    expect(guarded).to_be(halls)
    expect(cover).to_be_greater(0)
    -- decorating again changes nothing
    local site = game.state_ref.sector.sites[2]
    expect(stealth.decorate(site, r, defs)).to_be(0)
    expect(stealth.decorate(site, nil, defs)).to_be(0)
    -- the guarded find lies inside its Watcher's cone (with the sweep on its axis)
    local T = sentry.tune()
    for _, s in ipairs(r.slots) do
      if s.guarded then
        local d = defs[s.guarded]
        local dir = sentry.dir_of(d.yaw, d.pitch)
        local to = vec.sub(s.pos, d.pos)
        local cosang = vec.dot(to, dir) / vec.len(to)
        expect(cosang >= math.cos(T.watcher.half_angle)).to_be(true)
        expect(s.max_size).to_be(1)
        expect(s.premium).to_be(T.stealth.guard.premium)
      end
    end
    -- a guarded find is worth the premium
    local st = game.state_ref
    local p = st.players[1]
    local cands = tractor.candidates(st, p, 2, r)
    local g
    for _, c in ipairs(cands) do if c.guarded then g = c end end
    expect(g ~= nil).to_be(true)
    local loot = require("sim.loot")
    local sl
    for _, s in ipairs(r.slots) do if s.guarded == g.guarded then sl = s end end
    local plain = loot.roll(loot.instance_seed(sl.seed, p.record_index), sl.max_size, sl.tier)
    expect(g.item.value).to_be(math.floor(plain.value * sl.premium))
    expect(#stealth.guarded(r, p, 2)).to_be(guarded)
    p.looted["2:" .. sl.id] = true
    expect(#stealth.guarded(r, p, 2)).to_be(guarded - 1)
    p.looted["2:" .. sl.id] = nil
    expect(#stealth.guarded(nil, nil, 2)).to_be(0)
  end)
  it("under its guard's eye (Alert or Lock) a guarded find drops back out of the beam", function()
    local st = new_state()
    local p = st.players[1]
    local r = game.ruin(2)
    local g
    for _, c in ipairs(tractor.candidates(st, p, 2, r)) do if c.guarded then g = c end end
    local defs = game.sentries(2)
    local i
    for k, d in ipairs(defs) do if d.id == g.guarded then i = k end end
    local dyn = st.sentries[2][i]
    expect(sentry.guard_on(st, 2, defs, p, g.guarded)).to_be(false)
    dyn.st, dyn.target = "alert", p.index
    expect(sentry.guard_on(st, 2, defs, p, g.guarded)).to_be(true)
    dyn.st = "locked"
    expect(sentry.guard_on(st, 2, defs, p, g.guarded)).to_be(true)
    dyn.target = 2
    expect(sentry.guard_on(st, 2, defs, p, g.guarded)).to_be(false)
    expect(sentry.guard_on(st, 9, defs, p, g.guarded)).to_be(false)
    expect(sentry.guard_on(st, 2, defs, p, nil)).to_be(false)
    -- the game drops the pull
    dyn.target, dyn.st = p.index, "alert"
    p.site, p.ship.size = 2, 1
    p.ship.pos = vec.add(g.pos, { 0, 6, 0 })
    p.tractor = { key = g.key, kind = g.kind, site = 2, t = 0, total = 3, from = g.pos, size = 1 }
    run(st, cmd(), 1)
    expect(p.tractor).to_be(false)
    local why = false
    for _, m in ipairs(p.msgs) do if m.text:find("The guard saw the beam", 1, true) then why = true end end
    expect(why).to_be(true)
  end)
end)

describe("a hit shakes the beam loose", function()
  it("a bolt on the hull mid-pull makes the beam let go", function()
    local st = new_state()
    local p = st.players[1]
    p.mode = "helm"
    p.tractor = { key = "nope", kind = "slot", site = 2, t = 0, total = 3, from = { 0, 0, 0 }, size = p.ship.size }
    st.bolts = { { pos = vec.copy(p.ship.pos), vel = { 0, 0, 0 }, life = 1, site = p.site, dmg = 1 } }
    sentry.step_bolts(st, 1 / 60)
    expect(p.tractor.shaken).to_be(true)
    local r = game.ruin(2)
    local c = tractor.candidates(st, p, 2, r)[1]
    p.site = 2
    p.tractor = { key = c.key, kind = c.kind, site = 2, t = 0, total = 3, from = c.pos, size = p.ship.size, shaken = true }
    p.ship.pos = vec.add(c.pos, { 0, 6, 0 })
    run(st, cmd(), 1)
    expect(p.tractor).to_be(false)
    local why = false
    for _, m in ipairs(p.msgs) do if m.text:find("shook the beam loose", 1, true) then why = true end end
    expect(why).to_be(true)
  end)
end)

describe("power-cell sabotage", function()
  it("a cell lies behind each hall Watcher, out of its cone", function()
    local T = sentry.tune()
    for _, d in ipairs(game.sentries(2)) do
      if d.cell then
        local to = vec.sub(d.cell, d.pos)
        -- out of its cone wherever the sweep turns it
        for k = -4, 4 do
          local dir = sentry.dir_of(d.yaw + k / 4 * T.watcher.sweep, d.pitch)
          expect(vec.dot(to, dir) / vec.len(to) < math.cos(T.watcher.half_angle)).to_be(true)
        end
      end
    end
  end)
  it("beaming it out takes cell.time, shuts the Watcher off for good and sells", function()
    local st = new_state()
    local p = st.players[1]
    local def, i = hall_watcher(2)
    local cells = tractor.cells(st, 2)
    expect(#cells).to_be_greater(0)
    local c
    for _, x in ipairs(cells) do if x.def == def then c = x end end
    expect(c.kind).to_be("cell")
    expect(tractor.pull_time(p.ship, 1, "cell")).to_be(sentry.tune().stealth.cell.time)
    expect(tractor.pull_time(p.ship, 1)).to_be_less(sentry.tune().stealth.cell.time)
    game.pick_up(st, p, c, 2)
    expect(st.sentries[2][i].st).to_be("off")
    expect(st.overrides[adv.key(def)]).to_be(st.tick)
    expect(p.hold[#p.hold].name).to_be("Watcher power cell")
    expect(require("sim.items").sellable(p.hold[#p.hold])).to_be(true)
    expect(p.sabotaged).to_be(1)
    -- gone from the candidates, and it stays off in a fresh sentry state
    for _, x in ipairs(tractor.cells(st, 2)) do expect(x.def ~= def).to_be(true) end
    expect(sentry.new_state(game.sentries(2), st)[i].st).to_be("off")
    expect(#tractor.cells({}, 2)).to_be(0)
  end)
  it("seen while pulling: the Watcher locks at once, the alarm rises and the beam lets go", function()
    local st = new_state()
    local p = st.players[1]
    local def, i = hall_watcher(2)
    p.site, p.ship.size = 2, 1
    p.ship.vel = { 0, 0, 0 }
    local dir = sentry.dir_of(def.yaw, def.pitch)
    p.ship.pos = vec.add(def.pos, vec.scale(dir, 40))
    p.tractor = { key = "cell:2:99", kind = "cell", site = 2, t = 0, total = 3, from = { 0, 0, 0 }, size = 1 }
    local dyn = st.sentries[2][i]
    local saved = stealth.sweep
    stealth.sweep = function(d) return d.yaw end
    said = {}
    for _ = 1, 300 do sentry.step(st, 2, game.sentries(2), 1 / 60, ctx) if dyn.st == "locked" then break end end
    stealth.sweep = saved
    expect(dyn.st).to_be("locked")
    expect(heard("caught at the power cell")).to_be(true)
    expect(stealth.level(st, 2)).to_be_greater(0)
    -- the game lets go of the beam
    p.mode = "helm"
    run(st, cmd(), 1)
    expect(p.tractor).to_be(false)
  end)
  it("on foot the Override spike takes a cell too", function()
    local st = new_state()
    local p = st.players[1]
    local def, i = hall_watcher(2)
    p.mode, p.excursion, p.site = "foot", { body = { pos = vec.copy(def.cell) } }, 2
    local saved = game.viewpoint
    game.viewpoint = function() return vec.copy(def.cell) end
    expect(adv.spike_target(st, p, sentry.tune())).to_be(i)
    st.sentries[2][i].st = "off"
    expect(adv.spike_target(st, p, sentry.tune())).to_be(nil)
    game.viewpoint = saved
  end)
end)

describe("the Spotter drone", function()
  it("is laid out where a site keeps two Watchers, and in the tutorial derelict (light)", function()
    local d = spotter_of(2)
    expect(d ~= nil).to_be(true)
    expect(#d.route).to_be_greater(2)
    expect(d.len).to_be_greater(0)
    local d1 = spotter_of(1)
    expect(d1.light).to_be(true)
    local out = {}
    local site = game.state_ref.sector.sites[2]
    local r = game.ruin(2)
    local T = sentry.tune()
    spotter.layout(out, site, r, require("sim.ruin").kit_of(r.kit), T)
    expect(#out).to_be(0) -- no Watchers in `out`
    local S = T.stealth
    T.stealth = nil
    spotter.layout(out, site, r, require("sim.ruin").kit_of(r.kit), T, true)
    expect(#out).to_be(0)
    T.stealth = S
    -- a lone hall: a square route
    local lone = { rooms = { { id = 1, kind = "hall", class = 4, faces = {} } }, doors = {} }
    local saved = require("sim.warden").route
    require("sim.warden").route = function() return { { 0, 0, 0 } }, { 0, 0, 0 }, { 1, 1, 1 }, lone.rooms[1] end
    spotter.layout(out, { id = 7, pos = { 0, 0, 0 } }, lone, { big = 4 }, T, true)
    expect(#out[1].route).to_be(5)
    require("sim.warden").route = function() return nil end
    spotter.layout(out, { id = 7, pos = { 0, 0, 0 } }, lone, { big = 4 }, T, true)
    expect(#out).to_be(1)
    require("sim.warden").route = saved
    -- along its route
    local pos, yaw = spotter.at(d, 0)
    expect(vec.dist(pos, d.route[1])).to_be_near(0, 1e-6)
    expect(type(yaw)).to_be("number")
    local p2 = spotter.at(d, d.len * 2 + 1)
    expect(p2 ~= nil).to_be(true)
    local z = { route = { { 0, 0, 0 }, { 0, 0, 0 } }, len = 1 }
    expect(select(2, spotter.at(z, 0.5))).to_be(0)
  end)
  it("tags you when its meter fills: every Watcher jumps, the alarm rises", function()
    local st = new_state()
    local p = st.players[1]
    local d, i = spotter_of(2)
    local dyn = st.sentries[2][i]
    p.site, p.ship.size = 2, 1
    p.ship.vel = { 0, 0, 0 }
    local T = sentry.tune()
    -- park the Villa right in front of it, and keep it from moving on
    local saved_at = spotter.at
    spotter.at = function() return vec.copy(dyn.pos), dyn.yaw end
    local f = sentry.dir_of(dyn.yaw, -0.35)
    p.ship.pos = vec.add(dyn.pos, vec.scale(f, 15))
    said = {}
    local states = {}
    for _ = 1, 600 do
      spotter.step(st, d, dyn, 1 / 60, ctx, T)
      states[dyn.st] = true
      if dyn.st == "tagged" then break end
    end
    expect(states.alert).to_be(true)
    expect(dyn.st).to_be("tagged")
    expect(heard("TAGGED by a Spotter")).to_be(true)
    expect(stealth.level(st, 2)).to_be(1)
    local w, wi = hall_watcher(2)
    expect(st.sentries[2][wi].meter).to_be_greater(T.stealth.alert)
    expect(st.sentries[2][wi].sus).to_be(1)
    -- HUD: tagged
    local v = fake_view()
    local al = hud.alerts(st, p, 480)
    local has = false
    for _, a in ipairs(al) do if a[1]:find("TAGGED", 1, true) then has = true end end
    expect(has).to_be(true)
    -- it rests, then patrols again
    for _ = 1, math.floor(T.stealth.spotter.rest * 60) + 2 do spotter.step(st, d, dyn, 1 / 60, ctx, T) end
    expect(dyn.st).to_be("dormant")
    -- lost from sight while Alert: back to patrol
    dyn.st, dyn.target, dyn.meter = "alert", 1, 0.6
    p.ship.pos = vec.add(dyn.pos, { 0, 900, 0 })
    for _ = 1, 120 do spotter.step(st, d, dyn, 1 / 60, ctx, T) end
    expect(dyn.st).to_be("dormant")
    spotter.at = saved_at
  end)
  it("a Decoy takes it, the Jammer stuns it, off stays off, the Shroud hides a still hull", function()
    local st = new_state()
    local p = st.players[1]
    local d, i = spotter_of(2)
    local dyn = st.sentries[2][i]
    local T = sentry.tune()
    st.decoys = { { site = 2, pos = vec.add(dyn.pos, { 3, 0, 3 }), life = 5 } }
    spotter.step(st, d, dyn, 1 / 60, ctx, T)
    expect(dyn.st).to_be("decoyed")
    st.decoys = {}
    spotter.step(st, d, dyn, 1 / 60, ctx, T)
    expect(dyn.st).to_be("dormant")
    -- the Jammer
    p.site = 2
    local n = sentry.jam(st, 2, game.sentries(2), vec.sub(dyn.pos, { 0, 0, 2 }), { 0, 0, 1 }, p)
    expect(n).to_be_greater(0)
    expect(dyn.st).to_be("disabled")
    for _ = 1, math.floor(T.disabled_time * 60) + 2 do spotter.step(st, d, dyn, 1 / 60, ctx, T) end
    expect(dyn.st).to_be("dormant")
    dyn.st = "off"
    spotter.step(st, d, dyn, 1 / 60, ctx, T)
    expect(dyn.st).to_be("off")
    -- sees: other site, asleep, shrouded, on foot
    dyn.st = "dormant"
    p.site = 1
    expect(spotter.sees(d, dyn, p, T)).to_be(false)
    p.site = 2
    p.mode = "wake"
    expect(spotter.sees(d, dyn, p, T)).to_be(false)
    p.mode, p.shroud, p.ship.vel = "helm", true, { 0, 0, 0 }
    expect(spotter.sees(d, dyn, p, T)).to_be(false)
    p.shroud = false
    p.mode = "foot"
    expect(spotter.sees(d, dyn, p, T)).to_be(false)
    p.excursion = { body = {} }
    p.ship.pos = vec.add(dyn.pos, vec.scale(sentry.dir_of(dyn.yaw, -0.35), 5))
    local ok, range = spotter.sees(d, dyn, p, T)
    expect(range).to_be(T.stealth.spotter.foot_range)
    p.mode, p.excursion = "helm", false
    p.ship.size = seat_size()
    ok, range = spotter.sees(d, dyn, p, T)
    expect(range).to_be(T.stealth.spotter.small_range)
  end)
end)

describe("the HUD and the Scanner", function()
  it("draws the suspicion arc and the site alarm", function()
    local st = new_state()
    local p = st.players[1]
    local def, i = hall_watcher(2)
    p.site = 2
    local v = fake_view()
    expect(hud.suspicion(v, st, p, false)).to_be(0)
    st.sentries[2][i].sus, st.sentries[2][i].meter = 1, 0.6
    expect(stealth.meter_on(st, p)).to_be(0.6)
    expect(hud.suspicion(v, st, p, false)).to_be(math.floor(0.6 * hud.ARC_SEGS + 0.999))
    local found = false
    for _, t in ipairs(v.texts) do if t:find("SEEN 60%", 1, true) then found = true end end
    expect(found).to_be(true)
    local v2 = fake_view()
    st.sentries[2][i].st, st.sentries[2][i].target = "locked", 1
    expect(hud.suspicion(v2, st, p, true)).to_be(hud.ARC_SEGS)
    expect(#v2.texts).to_be(0)
    local sd, si = spotter_of(2)
    st.sentries[2][i].st, st.sentries[2][i].meter, st.sentries[2][i].sus, st.sentries[2][i].target = "dormant", 0, nil, 0
    st.sentries[2][si].sus, st.sentries[2][si].meter = 1, 0.3
    local _, kind = stealth.meter_on(st, p)
    expect(kind).to_be("spotter")
    p.site = 0
    expect(stealth.meter_on(st, p)).to_be(0)
    expect(stealth.meter_on(st, nil)).to_be(0)
    p.site = 2
    stealth.raise(st, 2, 2, ctx)
    local al = hud.alerts(st, p, 480)
    local line
    for _, a in ipairs(al) do if a[1]:find("SITE ALARM", 1, true) then line = a[1] end end
    expect(line).to_be("SITE ALARM ##-")
    hud.draw(fake_view(), st, p, nil)
  end)
  it("the Scanner names the Spotter, the guarded finds and the alarm", function()
    local st = new_state()
    local p = st.players[1]
    local site = st.sector.sites[2]
    p.ship.pos = vec.copy(site.pos)
    p.site = 2
    stealth.raise(st, 2, 1, ctx)
    run(st, cmd({ pressed = { "scan" } }), 1)
    local text = {}
    for _, m in ipairs(p.msgs) do text[#text + 1] = m.text end
    text = table.concat(text, "|")
    expect(text:find("Spotter", 1, true) ~= nil).to_be(true)
    expect(text:find("GUARDED", 1, true) ~= nil).to_be(true)
    expect(text:find("site alarm 1/3", 1, true) ~= nil).to_be(true)
  end)
  it("draws floor light pools, the Spotter and the scan marks", function()
    local st = new_state()
    local p = st.players[1]
    local A = assets.init()
    local def, i = hall_watcher(2)
    p.site = 2
    p.ship.pos = vec.copy(def.pos)
    local v = fake_view()
    local T = sentry.tune()
    local n = render.floor_cone(v, A, def, st.sentries[2][i], def.pos, def.pitch, T, { 1, 1, 1, 1 })
    expect(n).to_be_greater(0)
    expect(render.floor_cone(v, A, def, { yaw = def.yaw }, def.pos, 0.9, T, { 1, 1, 1, 1 })).to_be(0)
    p.scan_until = st.tick + 100
    local v2 = fake_view()
    render.draw_sentries(v2, A, st, p)
    expect(v2.calls.billboard).to_be_greater(20)
    expect(v2.calls.mesh).to_be_greater(0)
  end)
end)
