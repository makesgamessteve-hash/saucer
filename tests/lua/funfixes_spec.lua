-- SPDX-License-Identifier: MIT
-- add-fun-fixes: the six fixes of the 2026-11-21 fun audit (docs/funaudit/2026-11-21.md):
-- retreat costs, Watchers that see the Seat up close and a light sentry at site 1, the
-- beam relay from the start, the saucer-shaped bolt collider, hit juice and readable HUD
-- text, and tools with a job (scan finds, tips, denied feedback, loot condition).
local game = require("sim.game")
local sentry = require("sim.sentry")
local hull = require("sim.hull")
local items = require("sim.items")
local loot = require("sim.loot")
local upgrades = require("sim.upgrades")
local configs = require("sim.config")
local vec = require("lib.vec")
local juice = require("view.juice")
local hud = require("view.hud")
local audio = require("view.audio")

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
local function fake_view(w, h)
  local v = { calls = {}, width = w or 480, height = h or 270, player = 1, index = 1, xr = false, rects = {} }
  for _, m in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image", "vignette" }) do
    v[m] = function(self, ...)
      self.calls[m] = (self.calls[m] or 0) + 1
      if m == "rect" then self.rects[#self.rects + 1] = { ... } end
      if m == "text" then return 8 * #tostring((select(3, ...))) end
    end
  end
  return v
end
local function seat_size()
  for i = 1, configs.count() do
    if configs.get(i).name == "Seat" then return i end
  end
  return 2
end

describe("fun fix 1: a Fold Retreat costs", function()
  it("tears away half the hot cargo, bills the tow at home in credits only", function()
    local st = new_state()
    local p = st.players[1]
    local T = sentry.tune()
    expect(T.retreat_lose).to_be(0.5)
    expect(T.retreat_bill[1] > 0).to_be(true)
    for k = 1, 4 do p.hold[#p.hold + 1] = items.stamp(p, { type = "plate", name = "P" .. k, size = 1, hot = true, value = 10 }, 1) end
    p.site = 2
    p.credits = 1000
    local cache = hull.retreat(st, p, st.sector.trader.pos)
    expect(p.retreat_lost).to_be(2)
    expect(#cache.items).to_be(2)
    -- the newest finds are the ones torn away
    expect(cache.items[1].name).to_be("P1")
    -- one hot item alone is lost, no cache
    p.hold[#p.hold + 1] = items.stamp(p, { type = "plate", name = "Solo", size = 1, hot = true, value = 10 }, 1)
    expect(hull.retreat(st, p, st.sector.trader.pos)).to_be(nil)
    expect(p.retreat_lost).to_be(1)
    -- nothing hot: nothing lost
    expect(hull.retreat(st, p, st.sector.trader.pos)).to_be(nil)
    expect(p.retreat_lost).to_be(0)
  end)
  it("says what the fold took", function()
    local st = new_state()
    local p = st.players[1]
    local b = game.site_bounds(2)
    local inside = { (b[1][1] + b[2][1]) / 2, (b[1][2] + b[2][2]) / 2, (b[1][3] + b[2][3]) / 2 }
    p.ship.pos, p.site = vec.copy(inside), 2
    p.hold[#p.hold + 1] = items.stamp(p, { type = "plate", name = "A", size = 1, hot = true, value = 10 }, 1)
    p.hold[#p.hold + 1] = items.stamp(p, { type = "plate", name = "B", size = 1, hot = true, value = 10 }, 1)
    p.ship.hull = 0
    run(st, nil, 1)
    expect(pheard(p, "The fold tore away 1 hot item for good")).to_be(true)
    expect(pheard(p, "1 hot item stayed behind")).to_be(true)
    p.hold[#p.hold + 1] = items.stamp(p, { type = "plate", name = "C", size = 1, hot = true, value = 10 }, 1)
    p.hold[#p.hold + 1] = items.stamp(p, { type = "plate", name = "D", size = 1, hot = true, value = 10 }, 1)
    p.hold[#p.hold + 1] = items.stamp(p, { type = "plate", name = "E", size = 1, hot = true, value = 10 }, 1)
    p.site, p.ship.hull, p.ship.pos = 2, 0, vec.copy(inside)
    run(st, nil, 1)
    expect(pheard(p, "2 hot items for good")).to_be(true)
  end)
end)

describe("fun fix 2: Watchers see the Seat up close, and site 1 keeps a light sentry", function()
  it("lays out one light Watcher in the tutorial derelict", function()
    local defs = game.sentries(1)
    expect(#defs).to_be(1)
    expect(defs[1].kind).to_be("watcher")
    expect(defs[1].light).to_be(true)
    local room = game.ruin(1).rooms[defs[1].room]
    expect(room.kind ~= "entrance").to_be(true)
    expect(sentry.light_room({ rooms = { { kind = "entrance", class = 9 } } })).to_be(nil)
    local r = sentry.light_room({ rooms = { { id = 1, kind = "shaft", class = 5 }, { id = 2, kind = "wing", class = 4 } } })
    expect(r.kind).to_be("wing")
    -- a hall on the way to the vault beats a shaft and a hall off the path
    r = sentry.light_room({ rooms = { { id = 1, kind = "entrance", class = 4, parent = 0 },
      { id = 2, kind = "shaft", class = 4, parent = 1 }, { id = 3, kind = "hall", class = 4, parent = 2 },
      { id = 4, kind = "vault", class = 4, parent = 3 }, { id = 5, kind = "hall", class = 4, parent = 1 } } })
    expect(r.id).to_be(3)
    expect(room.kind).to_be("hall")
    -- no light tuning: the tutorial derelict is bare as before
    local T = sentry.tune()
    local lt = T.watcher.light
    T.watcher.light = nil
    local site = { id = 1, tutorial = true, pos = { 0, 0, 0 } }
    expect(#sentry.layout(site, game.ruin(1), nil)).to_be(0)
    T.watcher.light = lt
    expect(#sentry.layout(site, game.ruin(1), nil)).to_be(1)
    expect(#sentry.layout(site, nil, nil)).to_be(0)
  end)
  it("sees a Seat inside the small range only, a light Watcher closer still", function()
    local st = new_state()
    local p = st.players[1]
    local T = sentry.tune()
    local def = game.sentries(1)[1]
    local dyn = { yaw = def.yaw, pitch = def.pitch, st = "dormant", t = 0 }
    local dir = sentry.dir_of(def.yaw, def.pitch)
    p.site = 1
    p.ship.size = seat_size()
    local function at(d) p.ship.pos = vec.add(def.pos, vec.scale(dir, d)) end
    at(10)
    expect(sentry.watcher_sees(def, dyn, p, st.tick, T)).to_be(true)
    at(T.watcher.light.small_range + 5)
    expect(sentry.watcher_sees(def, dyn, p, st.tick, T)).to_be(false)
    local heavy = {}
    for k, x in pairs(def) do heavy[k] = x end
    heavy.light = nil
    local sees = sentry.watcher_sees(heavy, dyn, p, st.tick, T)
    expect(type(sees)).to_be("boolean")
    -- without small_range a Seat is never seen
    local sr = T.watcher.small_range
    T.watcher.small_range = nil
    at(5)
    expect(sentry.watcher_sees(heavy, dyn, p, st.tick, T)).to_be(false)
    T.watcher.small_range = sr
    -- a Villa at 10 m is seen by the light Watcher too
    p.ship.size = 1
    at(10)
    expect(sentry.watcher_sees(def, dyn, p, st.tick, T)).to_be(true)
  end)
  it("locks sooner than it would, and its bolts sting less", function()
    local st = new_state()
    local p = st.players[1]
    local T = sentry.tune()
    expect(T.watcher.light.alert_time < T.alert_time + 1).to_be(true)
    local def = game.sentries(1)[1]
    local dir = sentry.dir_of(def.yaw, def.pitch)
    p.site, p.ship.size = 1, 1
    p.ship.pos = vec.add(def.pos, vec.scale(dir, 10))
    st.sentries[1] = { { st = "alert", t = T.watcher.light.alert_time, target = 1, yaw = def.yaw, pitch = def.pitch } }
    sentry.step(st, 1, { def }, 1 / 60, ctx)
    expect(st.sentries[1][1].st).to_be("locked")
    -- fire: the bolt carries the light damage
    st.bolts = {}
    for _ = 1, 240 do
      sentry.step(st, 1, { def }, 1 / 60, ctx)
      if #st.bolts > 0 then break end
    end
    expect(#st.bolts > 0).to_be(true)
    expect(st.bolts[1].dmg).to_be(T.watcher.light.bolt_damage)
    -- a bolt on the hull deals its own damage
    p.ship.shield, p.ship.hull = 0, 100
    st.bolts = { { site = 1, pos = vec.copy(p.ship.pos), vel = { 0, 0, 0.001 }, life = 1, dmg = 4 } }
    sentry.step_bolts(st, 1 / 60)
    expect(p.ship.hull).to_be_near(96, 1e-6)
  end)
end)

describe("fun fix 3: the helm beam relay comes fitted", function()
  it("is level 1 on a new pilot and the shop calls it maxed", function()
    local st = new_state()
    local p = st.players[1]
    expect(upgrades.level(p, "beam_relay")).to_be(1)
    expect(select(2, upgrades.buy(p, "beam_relay"))).to_be("max")
    expect(game.VERSION).to_be(16)
  end)
end)

describe("fun fix 4: the saucer-shaped bolt collider", function()
  it("is an ellipsoid shrunk by hurt_scale, a cylinder without it", function()
    local c = { diameter = 10, height = 4 }
    local w = { bolt_radius = 0.2, hurt_scale = 0.8 }
    expect(sentry.bolt_hits_hull(c, 0, 0, 0, w)).to_be(true)
    expect(sentry.bolt_hits_hull(c, 4.1, 0, 0, w)).to_be(true)
    -- the rim corner of the old cylinder is no longer a hit
    expect(sentry.bolt_hits_hull(c, 4.5, 1.8, 0, w)).to_be(false)
    w.hurt_scale = nil
    expect(sentry.bolt_hits_hull(c, 4.5, 1.8, 0, w)).to_be(true)
    expect(sentry.bolt_hits_hull(c, 6, 0, 0, w)).to_be(false)
    expect(sentry.tune().watcher.hurt_scale).to_be(0.8)
  end)
end)

describe("fun fix 5: hit juice and readable text", function()
  it("builds trauma from recent hits and fades the flash", function()
    local p = { index = 1, fx = {} }
    expect(juice.trauma(p, 100)).to_be(0)
    expect(juice.flash(p, 100)).to_be(0)
    p.fx = { { tick = 100, sound = "hit" }, { tick = 100, sound = "scan" } }
    expect(juice.trauma(p, 100)).to_be_near(0.45, 1e-9)
    expect(juice.trauma(p, 130)).to_be_near(0.0, 1e-9)
    expect(juice.flash(p, 100)).to_be(1)
    expect(juice.flash(p, 100 + juice.FLASH)).to_be(0)
    expect(juice.flash(p, 99)).to_be(0)
    for k = 1, 4 do p.fx[#p.fx + 1] = { tick = 100, sound = "hit" } end
    expect(juice.trauma(p, 100)).to_be(1)
    juice.ENABLED = false
    expect(juice.flash(p, 100)).to_be(0)
    juice.ENABLED = true
  end)
  it("holds the camera for the hitstop, then shakes it; never in XR", function()
    juice.reset()
    local p = { index = 1, fx = {} }
    local cam1 = { pos = { 0, 0, 0 }, yaw = 0, pitch = 0, roll = 0 }
    expect(juice.camera(cam1, p, 99, false)).to_be(cam1)
    p.fx = { { tick = 100, sound = "hit" } }
    local cam2 = { pos = { 5, 0, 0 }, yaw = 1, pitch = 0, roll = 0 }
    local c = juice.camera(cam2, p, 100, false)
    expect(c.pos[1]).to_be(0) -- held at the pose before the hit
    c = juice.camera(cam2, p, 101, false)
    expect(c.pos[1]).to_be(0)
    c = juice.camera(cam2, p, 100 + juice.HITSTOP, false)
    expect(c.pos[1]).to_be(5)
    expect(math.abs(c.yaw - 1) <= juice.SHAKE).to_be(true)
    expect(cam2.yaw).to_be(1) -- the input pose is untouched
    expect(juice.camera(cam2, p, 101, true)).to_be(cam2)
    expect(juice.camera({ pos = { 0, 0, 0 } }, p, 101, false).yaw).to_be(nil)
    juice.ENABLED = false
    expect(juice.camera(cam2, p, 101, false)).to_be(cam2)
    juice.ENABLED = true
  end)
  it("frames the HUD red after a hit and plates its text", function()
    local st = new_state()
    local p = st.players[1]
    local v = fake_view()
    expect(hud.hit_flash(v, st, p)).to_be(false)
    p.fx[#p.fx + 1] = { tick = st.tick, sound = "hit" }
    expect(hud.hit_flash(v, st, p)).to_be(true)
    expect(#v.rects).to_be(4)
    local px = hud.plated(v)
    expect(hud.plated(v)).to_be(px)
    v.rects = {}
    expect(px:text(10, 10, "HELLO", { 1, 1, 1, 1 })).to_be(40)
    expect(#v.rects).to_be(1)
    expect(v.rects[1][3]).to_be(42)
    px:text(10, 10, "", { 1, 1, 1, 1 })
    px:text(10, 10, "faint", { 1, 1, 1, 0.1 })
    expect(#v.rects).to_be(1)
    px:rect(0, 0, 1, 1, { 1, 1, 1, 1 })
    expect(#v.rects).to_be(2)
    expect(px.width).to_be(480)
    hud.PLATES = false
    expect(hud.plated(v)).to_be(v)
    hud.PLATES = true
    local v2 = fake_view()
    hud.draw(v2, st, p, nil)
    expect(v2.calls.rect > 10).to_be(true)
  end)
  it("varies one-shot pitch by up to 8%", function()
    local lo, hi = 2, 0
    for _ = 1, 200 do
      local x = audio.pitch()
      lo, hi = math.min(lo, x), math.max(hi, x)
    end
    expect(lo >= 1 - audio.PITCH_SPREAD - 1e-9 and hi <= 1 + audio.PITCH_SPREAD + 1e-9).to_be(true)
    expect(hi - lo > 0.1).to_be(true)
  end)
end)

describe("fun fix 6: tools with a job", function()
  it("the scanner reports what is left and where the best find lies", function()
    local st = new_state()
    local p = st.players[1]
    local n, best = game.scan_finds(st, p, 2)
    expect(n > 0).to_be(true)
    expect(best.item.value > 0).to_be(true)
    expect(game.scan_finds(st, p, 999)).to_be(nil)
    for _, s in ipairs(game.ruin(2).slots) do p.looted["2:" .. s.id] = true end
    expect((game.scan_finds(st, p, 2))).to_be(0)
    p.scan_ready, p.ship.charge = 0, 100
    p.site = 1
    run(st, cmd({ pressed = { "scan" } }))
    expect(pheard(p, "find")).to_be(true)
    p.site = 2
    p.ship.pos = game.ruin(2) and st.sector.sites[2].pos
    p.scan_ready, p.ship.charge = 0, 100
    run(st, cmd({ pressed = { "scan" } }))
    expect(pheard(p, "nothing left to find")).to_be(true)
  end)
  it("teaches the Decoy and the Jammer once, when they matter", function()
    local st = new_state()
    local p = st.players[1]
    expect(sentry.tip(st, p, ctx, "decoy", "TIP: decoy")).to_be(true)
    expect(sentry.tip(st, p, ctx, "decoy", "TIP: decoy")).to_be(false)
    expect(sentry.tip(st, nil, ctx, "jam", "x")).to_be(false)
    p.mode = "wake"
    expect(sentry.tip(st, p, ctx, "jam", "x")).to_be(false)
    expect(heard("TIP: decoy")).to_be(true)
  end)
  it("answers a dead press with a denied sound and, now and then, why", function()
    local st = new_state()
    local p = st.players[1]
    p.mode = "walk"
    local n0 = #p.fx
    run(st, cmd({ pressed = { "grapple" } }))
    expect(p.fx[#p.fx].sound).to_be("denied")
    expect(pheard(p, "Grapple: on foot only")).to_be(true)
    local m0 = #p.msgs
    run(st, cmd({ pressed = { "grapple" } }))
    expect(p.fx[#p.fx].sound).to_be("denied")
    expect(#p.msgs).to_be(m0) -- rate-limited
    expect(#p.fx > n0).to_be(true)
    -- a press that does something is left alone
    p.mode = "helm"
    p.scan_ready, p.ship.charge = 0, 100
    run(st, cmd({ pressed = { "scan" } }))
    expect(p.fx[#p.fx].sound).to_be("scan")
    -- every tool button has a reason
    for _, a in ipairs(game.TOOL_BUTTONS) do expect(type(game.DENY_WHY[a])).to_be("string") end
    expect(type(game.react_sig(p))).to_be("string")
  end)
  it("spreads loot values by condition", function()
    expect(loot.condition(0)).to_be_near(0.6, 1e-9)
    expect(loot.condition(100)).to_be_near(1.8, 1e-9)
    local lo, hi = math.huge, 0
    for sd = 1, 300 do
      local it = loot.roll(sd, 2, 1)
      local base = it.value
      lo, hi = math.min(lo, base), math.max(hi, base)
    end
    expect(hi / math.max(lo, 1) > 3).to_be(true)
  end)
end)
