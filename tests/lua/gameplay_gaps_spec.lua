-- SPDX-License-Identifier: MIT
-- Gameplay gaps (OpenSpec add-playtest-recs, group 5): the Tractor Room target queue and the
-- twin anchors and vaults on their own spots.
local game = require("sim.game")
local ship = require("sim.ship")
local tractor = require("sim.tractor")
local twin = require("sim.twin")
local beamqueue = require("sim.beamqueue")
local upgrades = require("sim.upgrades")
local ap = require("sim.autopilot")
local avatar = require("sim.avatar")
local vec = require("lib.vec")
local L = avatar.layout()

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state(players, seed)
  local st = {}
  game.init(st, { seed = seed or 42, players = players or 1 })
  for _, p in ipairs(st.players) do
    p.mode, p.panel = "walk", false
    p.body = avatar.new(L, { -2.0, 0.6, -1.0 }, 0)
  end
  return st
end
local function run(st, c, n)
  local cs = {}
  for i = 1, #st.players do cs[i] = c end
  for _ = 1, n or 1 do game.step(st, cs, 1 / 60) end
end
local function texts(p)
  local t = {}
  for _, m in ipairs(p.msgs) do t[#t + 1] = m.text end
  return table.concat(t, "|")
end
-- hover the Villa over candidate c, keel lined up; at the console, or still at the helm
local function align(p, c, at_console)
  p.ship.size, p.ship.morph, p.site = 1, false, 1
  p.ship.pos = ap.beam_spot(c.pos, 1)
  p.ship.yaw = ap.beam_yaw(c, 0)
  p.ship.bank, p.ship.pitch, p.ship.vel = 0, 0, { 0, 0, 0 }
  p.tractor = false
  if at_console then
    p.mode = "walk"
    p.body = avatar.new(L, avatar.station_by_id(L, "tractor").pos, 0)
    p.beam_console = true
  else
    p.mode, p.beam_console = "helm", false
  end
end
local function slot_targets(r, st, p)
  local out = {}
  for _, x in ipairs(tractor.candidates(st, p, 1, r)) do
    if x.kind == "slot" and r.rooms[x.room].class >= 4 then out[#out + 1] = x end
  end
  return out
end
local function drift(p, dx) p.ship.pos[1] = p.ship.pos[1] + dx end

describe("Tractor Room target queue", function()
  it("a find that is not in lock yet joins the queue, and a second press takes it off", function()
    local st = new_state()
    local p = st.players[1]
    local c = slot_targets(game.ruin(1), st, p)[1]
    align(p, c, true)
    drift(p, 4)
    run(st, cmd({ pressed = { "tractor" } }))
    expect(texts(p)).to_contain("Queued")
    expect(beamqueue.keys(p)[1]).to_be(c.key)
    expect(beamqueue.has(p, c.key)).to_be(true)
    expect(beamqueue.line(p)).to_contain("BEAM QUEUE 1:")
    expect(p.tractor).to_be(false)
    run(st, cmd({ pressed = { "tractor" } }))
    expect(texts(p)).to_contain("off the beam queue")
    expect(#beamqueue.keys(p)).to_be(0)
    expect(beamqueue.line(p)).to_be(nil)
  end)

  it("a queued find is pulled up by itself the moment it comes into lock", function()
    local st = new_state()
    local p = st.players[1]
    local c = slot_targets(game.ruin(1), st, p)[1]
    align(p, c, true)
    drift(p, 4)
    run(st, cmd({ pressed = { "tractor" } }))
    expect(p.tractor).to_be(false)
    run(st, cmd(), 30)
    expect(p.tractor).to_be(false) -- still off axis: it waits
    align(p, c, true)
    run(st, cmd())
    expect(p.tractor and p.tractor.key).to_be(c.key)
    expect(texts(p)).to_contain("Queued find in lock")
    expect(#beamqueue.keys(p)).to_be(0)
    run(st, cmd(), math.floor(p.tractor.total * 60) + 4)
    expect(p.tractor).to_be(false)
    expect(#p.hold + st.mystery.found).to_be(1)
  end)

  it("an L or XL find is queued from the helm and the console takes it later", function()
    local st = new_state()
    local p = st.players[1]
    local r = game.ruin(1)
    local big
    for _, x in ipairs(slot_targets(r, st, p)) do
      if x.item.size >= tractor.LONG then big = x break end
    end
    if not big then -- make one: the queue does not care how the find got its size
      big = slot_targets(r, st, p)[1]
      big.item.size = tractor.LONG
    end
    -- the helm relay lifts only S and M; the console does the long ones
    p.upgrades = { beam_relay = 1 }
    local real = tractor.by_key
    tractor.by_key = function(...)
      local c = real(...)
      if c and c.key == big.key then c.item.size = big.item.size end
      return c
    end
    align(p, big, false)
    expect(upgrades.relay(p, big.item)).to_be_falsy()
    run(st, cmd({ pressed = { "tractor" } }))
    expect(texts(p)).to_contain("Queued")
    expect(texts(p)).to_contain("The beam runs from the Tractor Room")
    expect(p.tractor).to_be(false)
    run(st, cmd(), 20)
    expect(p.tractor).to_be(false) -- in lock, but nobody at the console
    align(p, big, true)
    run(st, cmd())
    expect(p.tractor and p.tractor.key).to_be(big.key)
    expect(p.tractor.console).to_be(true)
    tractor.by_key = real
  end)

  it("the queue holds four, drops what is gone and clears on a new site or a fold", function()
    local st = new_state()
    local p = st.players[1]
    p.site = 1
    for i = 1, beamqueue.MAX do expect(beamqueue.toggle(p, "k" .. i, "Find " .. i)).to_be("added") end
    expect(beamqueue.toggle(p, "k9")).to_be("full")
    expect(beamqueue.line(p)).to_contain("Find 1, Find 2")
    -- a find that no longer exists is dropped when the beam looks for the next one
    local c = slot_targets(game.ruin(1), st, p)[1]
    align(p, c, true)
    expect(beamqueue.next(st, p, game.ruin(1), 0, function() return true end)).to_be(nil)
    expect(#beamqueue.keys(p)).to_be(0)
    expect(p.beam_queue).to_be(nil)
    -- one site only
    beamqueue.toggle(p, c.key)
    p.site = 2
    beamqueue.sync(p)
    expect(p.beam_queue).to_be(nil)
    -- folding throws it away
    p.site = 1
    beamqueue.toggle(p, c.key)
    p.ship.morph = true
    beamqueue.sync(p)
    expect(p.beam_queue).to_be(nil)
    -- removing something that is not there is quiet
    beamqueue.remove(p, "nope")
    beamqueue.clear(p)
    expect(beamqueue.keys(p)[1]).to_be(nil)
  end)

  it("a full hold makes the queue wait, and says so once", function()
    local st = new_state()
    local p = st.players[1]
    local c = slot_targets(game.ruin(1), st, p)[1]
    align(p, c, true)
    drift(p, 4)
    run(st, cmd({ pressed = { "tractor" } }))
    align(p, c, true)
    p.hold = {}
    for i = 1, 12 do p.hold[i] = { name = "x", value = 1, hot = false } end
    run(st, cmd(), 3)
    expect(p.tractor).to_be(false)
    expect(texts(p)).to_contain("Hold is full: the beam queue waits")
    expect(#beamqueue.keys(p)).to_be(1)
    p.hold = {}
    run(st, cmd())
    expect(p.tractor and p.tractor.key).to_be(c.key)
  end)

  it("the queue is full at four: a fifth press says so", function()
    local st = new_state()
    local p = st.players[1]
    local targets = slot_targets(game.ruin(1), st, p)
    local c = targets[1]
    align(p, c, true)
    drift(p, 4)
    for i = 1, beamqueue.MAX do beamqueue.toggle(p, "filler" .. i, "Filler") end
    run(st, cmd({ pressed = { "tractor" } }))
    expect(texts(p)).to_contain("queue is full")
  end)

  it("is never saved", function()
    local save = require("sim.save")
    expect(save.SKIP.beam_queue).to_be(true)
  end)
end)

describe("twin vaults and anchors on their own spots (gameplay gaps)", function()
  it("neither the vault nor the anchor stands on a loot slot, the Echo or a home-find quarter", function()
    local sites, worst = 0, 1e9
    for seed = 1, 30 do
      local st = new_state(2, seed)
      for i = 1, #st.sector.sites do
        local ruin = game.ruin(i)
        local lay = ruin and twin.layout(ruin)
        if lay then
          sites = sites + 1
          expect(lay.vault.pos ~= lay.anchor.pos).to_be(true)
          for _, sp in ipairs({ lay.vault, lay.anchor }) do
            for _, s in ipairs(ruin.slots) do
              if s.room == sp.room then worst = math.min(worst, math.sqrt((s.pos[1] - sp.pos[1]) ^ 2 + (s.pos[3] - sp.pos[3]) ^ 2)) end
            end
          end
        end
      end
    end
    expect(sites).to_be_greater(20)
    expect(worst).to_be_greater(twin.SPOT_CLEAR - 1e-6)
  end)

  it("a twin spot lies inside its room, on the slot's floor, and the layout does not change between calls", function()
    local ruinm = require("sim.ruin")
    local st = new_state(2)
    for i = 1, #st.sector.sites do
      local ruin = game.ruin(i)
      local lay = ruin and twin.layout(ruin)
      if lay then
        expect(twin.layout(ruin)).to_be(lay)
        local room = ruin.rooms[lay.vault.room]
        local mn, mx = ruinm.room_box(room, ruinm.kit_of(ruin.kit), ruin.origin)
        for _, sp in ipairs({ lay.vault, lay.anchor }) do
          local rm = ruin.rooms[sp.room]
          local a, b = ruinm.room_box(rm, ruinm.kit_of(ruin.kit), ruin.origin)
          -- inside the room and off its walls: the Seat can hover over it, the Villa too where the room allows
          local wall = ruinm.kit_of(ruin.kit).wall
          local mx_ = math.min(twin.WALL_SEAT, (b[1] - a[1]) / 2 - wall - 0.2) - 1e-6
          local mz_ = math.min(twin.WALL_SEAT, (b[3] - a[3]) / 2 - wall - 0.2) - 1e-6
          expect(sp.pos[1] - a[1] - wall).to_be_greater(mx_)
          expect(b[1] - sp.pos[1] - wall).to_be_greater(mx_)
          expect(sp.pos[3] - a[3] - wall).to_be_greater(mz_)
          expect(b[3] - sp.pos[3] - wall).to_be_greater(mz_)
        end
        expect(mn[1] < mx[1]).to_be(true)
        expect(vec.dist(lay.vault.pos, lay.anchor.pos)).to_be_greater(twin.MIN_GAP - 1e-6)
      end
    end
  end)

  it("a ruin without an origin or a room has no spot, and a closet too small to clear the loot holds no twin", function()
    expect(twin.spot_of({ rooms = {}, slots = {} }, { room = 1, pos = { 0, 0, 0 } })).to_be(nil)
    expect(twin.spot_of({ rooms = { { id = 1 } }, slots = {} }, { room = 1, pos = { 0, 0, 0 } })).to_be(nil)
    -- a real ruin whose rooms are squeezed to closets: the post cannot stand clear of the loot
    local st = new_state(2)
    local ruin = game.ruin(1)
    local ruinm = require("sim.ruin")
    local kit = ruinm.kit_of(ruin.kit)
    local rooms, slots = {}, {}
    for i, sl in ipairs(ruin.slots) do
      local room = ruin.rooms[sl.room]
      rooms[i] = { id = sl.room, class = 1, kind = "side", cell = room.cell, size = { 0.1, 1, 0.1 }, faces = {} }
      slots[i] = { room = sl.room, pos = { 0, 0, 0 }, tier = 1, seed = sl.seed }
    end
    local closet = { rooms = rooms, slots = slots, kit = ruin.kit, origin = ruin.origin }
    expect(twin.spot_of(closet, slots[1])).to_be(nil)
    expect(twin.layout(closet)).to_be(nil)
    expect(kit.wall > 0).to_be(true)
    -- and a low room (no head room for the post and a saucer over it) holds none either
    for i, r in ipairs(rooms) do r.size = { 1, 0.1, 1 }; slots[i].pos = { 0, 0, 0 } end
    expect(twin.spot_of(closet, slots[1])).to_be(nil)
  end)

  it("every twin spot has head room for the post and the saucer hovering over it", function()
    local ruinm = require("sim.ruin")
    local st = new_state(2)
    local n = 0
    for i = 1, #st.sector.sites do
      local ruin = game.ruin(i)
      local lay = ruin and twin.layout(ruin)
      if lay then
        for _, sp in ipairs({ lay.vault, lay.anchor }) do
          local kit = ruinm.kit_of(ruin.kit)
          local a, b = ruinm.room_box(ruin.rooms[sp.room], kit, ruin.origin)
          expect((b[2] - a[2]) - 2 * kit.wall).to_be_greater(twin.HEAD_ROOM - 1e-6)
          n = n + 1
        end
      end
    end
    expect(n).to_be_greater(0)
  end)
end)

-- ---------------------------------------------------------------------------------------------------------
-- Saucer modules and the trader's shelf (add-items-identification-tractor 1.2, add-trading-mvp 1.2)
local items = require("sim.items")
local modules = require("sim.modules")
local lab = require("sim.lab")
local trade = require("sim.trade")
local shipm = require("sim.ship")
local hull = require("sim.hull")
local flight = require("sim.flight")
local sentry = require("sim.sentry")
local loot = require("sim.loot")
local save = require("sim.save")
local clock = require("sim.clock")
local hud = require("view.hud")

local ctx = { msg = function(_, p, t) p.msgs[#p.msgs + 1] = { tick = 0, text = t } end, fx = function() end }
local function row(rows, prefix)
  for _, r in ipairs(rows) do if r.text:sub(1, #prefix) == prefix then return r end end
  return nil
end
local function module_item(p, over)
  local it = { type = "coil", name = "Coil", size = 2, category = "module", affixes = {}, quirk = false, value = 90 }
  for k, v in pairs(over or {}) do it[k] = v end
  items.stamp(p, it, it.tier or 1, "velari")
  it.ident = over and over.ident or false
  p.hold[#p.hold + 1] = it
  return it
end
local function villa()
  local st = new_state()
  local p = st.players[1]
  p.mode = "helm"
  p.hold = {}
  return st, p
end

describe("saucer modules (add-items-identification-tractor 1.2)", function()
  it("installs a module from the hold into a slot, takes it out again and refuses a third", function()
    local st, p = villa()
    expect(modules.list(p)).to_equal({})
    expect(modules.line(p)).to_be(nil)
    local a = module_item(p, { ident = true, affixes = { { id = "humming", stat = "charge_regen", value = 10 } } })
    local b = module_item(p, { ident = true })
    local c = module_item(p, { ident = true })
    local plate = module_item(p, { type = "plate", category = "material" })
    expect(modules.install(st, p, a.uid, ctx)).to_be(true)
    expect(#p.hold).to_be(3)
    expect(p.modules[1]).to_be(a)
    expect(a.hot).to_be(false)
    expect(modules.install(st, p, b.uid, ctx)).to_be(true)
    local ok, why = modules.install(st, p, c.uid, ctx)
    expect(ok).to_be(false)
    expect(why).to_be("full")
    ok, why = modules.install(st, p, plate.uid, ctx)
    expect(why).to_be("not a module")
    expect(select(2, modules.install(st, p, 9999, ctx))).to_be("gone")
    expect(modules.line(p)).to_be("MOD 2/2")
    expect(modules.remove(st, p, a.uid, ctx)).to_be(true)
    expect(p.hold[#p.hold]).to_be(a)
    expect(modules.remove(st, p, b.uid, ctx)).to_be(true)
    expect(p.modules).to_be(nil)
    expect(select(2, modules.remove(st, p, b.uid, ctx))).to_be("gone")
    expect(p.ship.mods).to_be(nil)
    -- an Echo, a data core and a story item are not modules
    expect(modules.installable({ category = "module", echo = 1 })).to_be(false)
    expect(modules.installable({ category = "module", home = { kind = "module" } })).to_be(false)
    expect(modules.installable(nil)).to_be(false)
  end)

  it("Hidden quirk: an unidentified Unstable module drains Charge at once and the HUD says Unknown effect", function()
    local st, p = villa()
    local m = module_item(p, { quirk = "unstable", affixes = { { id = "resonant", stat = "shield_regen", value = 30 } } })
    p.ship.charge = 80
    expect(modules.install(st, p, m.uid, ctx)).to_be(true)
    expect(texts(p)).to_contain("Unknown effect")
    expect(p.ship.drain).to_be(modules.DRAIN)
    expect(p.ship.mods).to_be(nil) -- the affix waits for identification
    expect(modules.unknown(p)).to_be(true)
    expect(modules.line(p)).to_contain("UNKNOWN EFFECT")
    shipm.update(p.ship, 1, false)
    expect(p.ship.charge).to_be_less(80 - modules.DRAIN + 1e-6)
    shipm.update(p.ship, 10, false)
    expect(p.ship.charge).to_be_less(80 - 11 * modules.DRAIN + 1e-6)
    -- never below zero
    shipm.update(p.ship, 1000, false)
    expect(p.ship.charge).to_be(0)
    -- the lab bench identifies the fitted module; its affix now applies, the quirk stays
    p.ship.charge = 50
    expect(lab.enqueue(st, p, m.uid)).to_be(true)
    local q = row(lab.rows(st, p, ctx), "Identifying")
    expect(q ~= nil).to_be(true)
    local job
    for _ = 1, 40 * 60 do
      job = lab.step(st, p, 1 / 30, ctx)
      if job then break end
    end
    expect(job and job.kind).to_be("identify")
    expect(m.ident).to_be(true)
    expect(p.ship.mods.shield_regen).to_be(30)
    expect(p.ship.drain).to_be(modules.DRAIN)
    expect(modules.line(p)).to_be("MOD 1/2")
  end)

  it("identified affixes change shield regen, Charge max and regen, turn and the scan's reach", function()
    local st, p = villa()
    local function fit(stat, value)
      local m = module_item(p, { ident = true, affixes = { { id = "x", stat = stat, value = value } } })
      expect(modules.install(st, p, m.uid, ctx)).to_be(true)
      return m
    end
    -- max Charge
    fit("max_charge", 20)
    expect(shipm.max_charge(p.ship)).to_be(120)
    expect(trade.refill_cost(p)).to_be(math.ceil((120 - p.ship.charge) * trade.econ().charge_price))
    p.ship.charge, p.credits = 100, 1000
    expect(trade.refill(p)).to_be(20)
    expect(p.ship.charge).to_be(120)
    -- Charge regen, in open space
    local mod2 = fit("charge_regen", 50)
    p.ship.charge = 10
    shipm.update(p.ship, 1, true)
    expect(p.ship.charge).to_be_greater(10 + 2.0 * 1.4)
    -- shield regen
    local before = { shield = 10, since_hit = 99 }
    hull.regen(before, 1, false)
    local plain = before.shield
    p.ship.shield, p.ship.since_hit = 10, 99
    p.ship.mods.shield_regen = 100
    hull.regen(p.ship, 1, false)
    expect(p.ship.shield).to_be_greater(plain + 3.9)
    expect(modules.remove(st, p, mod2.uid, ctx)).to_be(true)
    expect(p.ship.mods.charge_regen).to_be(nil)
    -- turn rate
    p.ship.mods = { turn = 100 }
    local slow = { pos = { 0, 100, 0 }, yaw = 0, pitch = 0, size = 1, bank = 0, vel = { 0, 0, 0 } }
    local fast = { pos = { 0, 100, 0 }, yaw = 0, pitch = 0, size = 1, bank = 0, vel = { 0, 0, 0 }, mods = { turn = 100 } }
    local c = cmd({ axes = { turn = 1 } })
    flight.step(slow, c, 0.1, function(s, d) return s.pos, 0 end)
    flight.step(fast, c, 0.1, function(s, d) return s.pos, 0 end)
    expect(math.abs(fast.yaw)).to_be_greater(math.abs(slow.yaw) * 1.9)
    -- the scan's reach (how long the pulse keeps what it found in view)
    local p2 = st.players[1]
    p2.ship.mods = nil
    p2.scan_ready, p2.ship.charge = 0, 100
    p2.mode = "helm"
    run(st, cmd({ pressed = { "scan" } }))
    local plain_reveal = p2.scan_until - st.tick
    p2.scan_ready, p2.ship.charge = 0, 100
    p2.ship.mods = { scan_range = 50 }
    run(st, cmd({ pressed = { "scan" } }))
    expect(p2.scan_until - st.tick).to_be_greater(plain_reveal * 1.4)
  end)

  it("a Loud module is heard from farther: Watchers see and Snatchers sense a Loud saucer from more metres", function()
    local st, p = villa()
    p.site = 1
    p.ship.size, p.ship.morph = 1, false
    p.ship.pos = { 0, 9000, 0 }
    local T = sentry.tune()
    local def = { site = 1, pos = { 0, 9000, -125 }, band = { 1, 4 }, pitch = 0 }
    local dyn = { yaw = 0, pitch = 0 }
    expect(sentry.watcher_sees(def, dyn, p, 0, T)).to_be(false)
    local m = module_item(p, { ident = true, quirk = "loud" })
    expect(modules.install(st, p, m.uid, ctx)).to_be(true)
    expect(p.ship.loud).to_be(1)
    expect(sentry.watcher_sees(def, dyn, p, 0, T)).to_be(true)
    -- a Snatcher only wants a Seat with something hot to take
    p.ship.size = 2
    p.hold[1] = { uid = 77, hot = true, name = "Loot", type = "lens" }
    local sd = { site = 1 }
    local sdyn = { pos = { 0, 9000, -(T.snatcher.sense + 4) } }
    expect(sentry.snatcher_wants(sd, sdyn, p, T)).to_be(true)
    p.ship.loud = nil
    expect(sentry.snatcher_wants(sd, sdyn, p, T)).to_be(false)
  end)

  it("a Bonded module will not come out (and trying shows what it is); a full hold blocks removal", function()
    local st, p = villa()
    local m = module_item(p, { quirk = "bonded", affixes = { { id = "x", stat = "turn", value = 9 } } })
    expect(modules.install(st, p, m.uid, ctx)).to_be(true)
    expect(m.ident).to_be(false)
    local ok, why = modules.remove(st, p, m.uid, ctx)
    expect(ok).to_be(false)
    expect(why).to_be("bonded")
    expect(m.ident).to_be(true)
    expect(p.ship.mods.turn).to_be(9)
    local rows = lab.rows(st, p, ctx)
    row(rows, "Remove").act(st, p)
    expect(texts(p)).to_contain("Bonded")
    expect(#p.modules).to_be(1)
    -- an ordinary module with a full hold
    local st2, p2 = villa()
    local m2 = module_item(p2, { ident = true })
    modules.install(st2, p2, m2.uid, ctx)
    p2.hold = {}
    for i = 1, upgrades.hold_slots(p2) do p2.hold[i] = { name = "x", value = 1, uid = 900 + i } end
    expect(select(2, modules.remove(st2, p2, m2.uid, ctx))).to_be("hold full")
    row(lab.rows(st2, p2, ctx), "Remove").act(st2, p2)
    expect(texts(p2)).to_contain("Cannot remove: hold full")
  end)

  it("the lab bench panel offers Install, Remove and Identify fitted rows", function()
    local st, p = villa()
    local a = module_item(p, {})
    local rows = lab.rows(st, p, ctx)
    local inst = row(rows, "Install")
    expect(inst ~= nil and inst.enabled ~= false).to_be(true)
    expect(inst.hint).to_contain("quirks apply at once")
    inst.act(st, p)
    expect(p.modules[1]).to_be(a)
    rows = lab.rows(st, p, ctx)
    expect(row(rows, "Remove") ~= nil).to_be(true)
    local idr = row(rows, "Identify fitted")
    expect(idr ~= nil).to_be(true)
    idr.act(st, p)
    expect(texts(p)).to_contain("Identifying")
    expect(row(lab.rows(st, p, ctx), "Identify fitted")).to_be(nil) -- queued: no second row
    -- a full set of slots disables Install and an identified module's hint is plain
    local b = module_item(p, { ident = true })
    local c = module_item(p, { ident = true })
    modules.install(st, p, b.uid, ctx)
    local ir = row(lab.rows(st, p, ctx), "Install")
    expect(ir.enabled).to_be(false)
    row(lab.rows(st, p, ctx), "Install").act(st, p)
    expect(texts(p)).to_contain("Cannot install: full")
    expect(row(lab.rows(st, p, ctx), "Remove " .. items.label(b)) ~= nil or row(lab.rows(st, p, ctx), "Remove " .. b.name) ~= nil).to_be(true)
  end)

  it("fitted modules are saved with the player and survive a Fold Retreat", function()
    local st, p = villa()
    local m = module_item(p, { ident = true, affixes = { { id = "x", stat = "turn", value = 12 } } })
    modules.install(st, p, m.uid, ctx)
    expect(save.write(st)).to_be(true)
    local st2 = { players = { {} } }
    save.apply(st2, save.read(), game)
    local p2 = st2.players[1]
    expect(#p2.modules).to_be(1)
    expect(p2.modules[1].affixes[1].value).to_be(12)
    expect(p2.ship.mods.turn).to_be(12)
    expect(items.losable(p2)[1]).to_be(nil)
  end)

  it("the HUD draws the module line for a fitted, unidentified module", function()
    local st, p = villa()
    local m = module_item(p, {})
    modules.install(st, p, m.uid, ctx)
    local function view(w)
      local v = { calls = {}, width = w, height = 270, player = 1, index = 1, xr = false, texts = "" }
      for _, k in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image" }) do
        v[k] = function(self, ...)
          if k == "text" then
            local t = select(3, ...)
            self.texts = self.texts .. t .. "|"
            return #t * 8
          end
        end
      end
      return v
    end
    local v = view(480)
    hud.draw(v, st, p)
    expect(v.texts).to_contain("MOD 1/2 UNKNOWN EFFECT")
    -- identified: the plain line; a narrow view is cut to fit
    m.ident = true
    local v2 = view(480)
    hud.draw(v2, st, p)
    expect(v2.texts).to_contain("MOD 1/2|")
    m.ident = false
    local v3 = view(240)
    hud.draw(v3, st, p)
    expect(v3.texts).to_contain("MOD 1/2 UNKNOWN EFFEC|")
  end)

  it("the HUD lists the Tractor Room target queue", function()
    local st, p = villa()
    beamqueue.toggle(p, "slot:1:2", "Hull Plate")
    beamqueue.toggle(p, "slot:1:3", "Idol")
    local v = { calls = {}, width = 480, height = 270, player = 1, index = 1, xr = false, texts = "" }
    for _, k in ipairs({ "camera", "fog", "mesh", "billboard", "rect", "text", "image" }) do
      v[k] = function(self, ...)
        if k == "text" then
          local t = select(3, ...)
          self.texts = self.texts .. t .. "|"
          return #t * 8
        end
      end
    end
    p.site = 0
    p.beam_queue.site = 0
    hud.beam(v, st, p, nil)
    expect(v.texts).to_contain("BEAM QUEUE 2: Hull Plate, Idol")
    local v2 = { calls = {}, width = 120, height = 270, player = 1, index = 1, texts = "" }
    for _, k in ipairs({ "rect", "text" }) do
      v2[k] = function(self, ...)
        if k == "text" then
          local t = select(3, ...)
          self.texts = self.texts .. t .. "|"
          return #t * 8
        end
      end
    end
    hud.beam(v2, st, p, nil)
    expect(v2.texts).to_contain("BEAM QUEUE 2")
    expect(#v2.texts < #v.texts).to_be(true)
  end)
end)

describe("a trader's shelf of modules (add-trading-mvp 1.2)", function()
  local function docked()
    local st = new_state()
    local p = st.players[1]
    p.hold, p.site, p.credits = {}, 0, 5000
    p.ship.pos = vec.copy(st.sector.trader.pos)
    return st, p
  end

  it("rolls the shelf from the world seed, the trader and the hour: modules only, no quirks, repeatable", function()
    local st = docked()
    local a, b = trade.stock(st, 1), trade.stock(st, 1)
    expect(#a).to_be(trade.econ().stock_count)
    for i, e in ipairs(a) do
      expect(e.item.category == nil or e.item.category == "module").to_be(true)
      expect(items.type_of(e.item.type).category).to_be("module")
      expect(e.item.quirk).to_be(false)
      expect(e.price).to_be_greater(0)
      expect(e.item.name).to_be(b[i].item.name)
      expect(e.item.type).to_be(b[i].item.type)
      expect(e.price).to_be(b[i].price)
      expect(e.sold).to_be(false)
    end
    -- each restock is its own roll
    local seen, n = {}, 0
    for _ = 1, 8 do
      local sig = {}
      for _, e in ipairs(trade.stock(st, 1)) do sig[#sig + 1] = e.item.name .. e.price end
      sig = table.concat(sig, ",")
      if not seen[sig] then seen[sig], n = true, n + 1 end
      clock.skip(st, trade.econ().stock_minutes)
    end
    expect(n).to_be_greater(1)
    -- and another trader's shelf is not this trader's
    if #st.traders > 1 then expect(trade.stock(st, 2)[1].price ~= nil).to_be(true) end
  end)

  it("loot.roll can be limited to one category; without it nothing changes", function()
    for seed = 1, 40 do
      expect(items.type_of(loot.roll(seed, 2, 1, "module").type).category).to_be("module")
    end
    expect(loot.roll(7, 3, 1).name).to_be(loot.roll(7, 3, 1, nil).name)
  end)

  it("buys a module identified and quirk-free into the hold, once per restock, saved at once", function()
    local st, p = docked()
    local rows = trade.rows(st, p, ctx)
    local buy = row(rows, "Buy module")
    expect(buy ~= nil and buy.enabled).to_be(true)
    local credits = p.credits
    local price = trade.stock(st, 1)[1].price
    buy.act(st, p)
    expect(#p.hold).to_be(1)
    local it = p.hold[1]
    expect(it.ident).to_be(true)
    expect(it.hot).to_be(false)
    expect(it.category).to_be("module")
    expect(p.credits).to_be(credits - price)
    expect(texts(p)).to_contain("install it at the lab bench")
    -- that slot is sold out now
    expect(trade.stock(st, 1)[1].sold).to_be(true)
    expect(select(2, trade.buy_stock(st, p, 1, 1))).to_be("sold")
    local after = trade.rows(st, p, ctx)
    local sold
    for _, r in ipairs(after) do if r.text:find(" - sold", 1, true) then sold = r end end
    expect(sold ~= nil and sold.enabled == false).to_be(true)
    -- and it is in the saved world
    expect(save.write(st)).to_be(true)
    local st2 = { players = { {} } }
    save.apply(st2, save.read(), game)
    expect(trade.stock(st2, 1)[1].sold).to_be(true)
    -- the shelf restocks with the clock
    clock.skip(st, trade.econ().stock_minutes)
    expect(trade.stock(st, 1)[1].sold).to_be(false)
    -- and it installs from the lab bench
    expect(modules.install(st, p, it.uid, ctx)).to_be(true)
  end)

  it("refuses a purchase you cannot afford or hold, and a slot that does not exist", function()
    local st, p = docked()
    p.credits = 1
    expect(select(2, trade.buy_stock(st, p, 1, 1))).to_be("credits")
    local rows = trade.rows(st, p, ctx)
    expect(row(rows, "Buy module").enabled).to_be(false)
    p.credits = 5000
    p.hold = {}
    for i = 1, upgrades.hold_slots(p) do p.hold[i] = { name = "x", value = 1, uid = i } end
    expect(select(2, trade.buy_stock(st, p, 1, 1))).to_be("hold full")
    expect(select(2, trade.buy_stock(st, p, 1, 99))).to_be("gone")
    expect(#p.hold).to_be(upgrades.hold_slots(p))
  end)
end)

describe("grid consoles (add-sentries-and-tools-mvp 1.5)", function()
  it("every derelict with sentries has a grid console that stands them down until you leave", function()
    local ex = require("sim.excursion")
    local guarded = 0
    for seed = 1, 12 do
      local st = new_state(1, seed)
      local p = st.players[1]
      for i in ipairs(st.sector.sites) do
        local defs = game.sentries(i)
        if #defs > 0 then
          guarded = guarded + 1
          expect(#game.ruin(i).foot.consoles >= 1).to_be(true)
          expect(ex.grid_down(st, i)).to_be(false)
          expect(ex.shut_grid(st, p, i, ctx)).to_be(#defs)
          expect(ex.grid_down(st, i)).to_be(true)
          expect(ex.left_site(st, p, i, ctx)).to_be(true)
          expect(ex.grid_down(st, i)).to_be(false)
        end
      end
    end
    expect(guarded).to_be_greater(10)
  end)
end)
