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
    expect(texts(p)).to_contain("from the Tractor Room console")
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
              if s.room == sp.room then worst = math.min(worst, vec.dist(s.pos, sp.pos)) end
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
          expect(sp.pos[1]).to_be_greater(a[1])
          expect(sp.pos[1]).to_be_less(b[1])
          expect(sp.pos[3]).to_be_greater(a[3])
          expect(sp.pos[3]).to_be_less(b[3])
        end
        expect(mn[1] < mx[1]).to_be(true)
        expect(vec.dist(lay.vault.pos, lay.anchor.pos)).to_be_greater(twin.MIN_GAP - 1e-6)
      end
    end
  end)

  it("a ruin without an origin or a room has no spot, and so no twin pair", function()
    expect(twin.spot_of({ rooms = {}, slots = {} }, { room = 1, pos = { 0, 0, 0 } })).to_be(nil)
    expect(twin.spot_of({ rooms = { { id = 1 } }, slots = {} }, { room = 1, pos = { 0, 0, 0 } })).to_be(nil)
  end)
end)
