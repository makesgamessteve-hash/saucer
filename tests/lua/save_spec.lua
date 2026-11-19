-- SPDX-License-Identifier: MIT
-- OpenSpec add-save-system, group "Saves": seed plus diffs (format 3), the
-- format-2 migration, player records and the mod-set warning.
local game = require("sim.game")
local save = require("sim.save")
local diff = require("sim.diff")
local home = require("sim.home")
local panel = require("sim.panel")
local trade = require("sim.trade")

local function new_state(n, seed)
  local st = {}
  game.init(st, { seed = seed or 42, players = n or 1 })
  return st
end
local function texts(p)
  local t = {}
  for _, m in ipairs(p.msgs) do t[#t + 1] = m.text end
  return table.concat(t, "|")
end
local function reload(rec, n)
  local st2 = { players = {} }
  for i = 1, n or 1 do st2.players[i] = {} end
  save.apply(st2, rec, game)
  return st2
end

describe("sim.diff", function()
  it("is nil for equal values and rebuilds what changed", function()
    local base = { a = 1, b = { c = 2, d = { 1, 2, 3 } }, gone = true, keep = { x = 1 } }
    expect(diff.diff(base, diff.copy(base))).to_be(nil)
    local cur = { a = 1, b = { c = 5, d = { 1, 2, 4 } }, keep = { x = 1 }, added = { y = 1 } }
    local p = diff.diff(base, cur)
    expect(p.d.a).to_be(nil)
    expect(p.d.keep).to_be(nil)
    expect(p.d.b.d.c.v).to_be(5)
    expect(p.d.b.d.d.v).to_equal({ 1, 2, 4 })
    expect(p.x).to_equal({ "gone" })
    expect(diff.patch(base, p)).to_equal(cur)
    expect(base.b.c).to_be(2)
  end)
  it("replaces plain values and arrays whole, copies when there is nothing to apply", function()
    expect(diff.diff(1, 2).v).to_be(2)
    expect(diff.diff(false, true).v).to_be(true)
    expect(diff.diff(true, false).v).to_be(false)
    expect(diff.patch(1, diff.diff(1, 2))).to_be(2)
    expect(diff.patch(true, diff.diff(true, false))).to_be(false)
    expect(diff.diff({ 1, 2 }, { 1, 2, 3 }).v).to_equal({ 1, 2, 3 })
    expect(diff.diff({ a = 1 }, { 1 }).v).to_equal({ 1 })
    expect(diff.diff(5, { a = 1 }).v).to_equal({ a = 1 })
    local b = { k = { 1 } }
    local c = diff.patch(b, nil)
    expect(c).to_equal(b)
    c.k[1] = 9
    expect(b.k[1]).to_be(1)
    expect(diff.patch(nil, { d = { a = { v = 1 } } })).to_equal({ a = 1 })
    expect(diff.patch({ a = 1 }, {})).to_equal({ a = 1 })
  end)
  it("handles numeric keys and removals of numbered keys", function()
    local base = { [5] = "x", [7] = "y", s = 1 }
    local cur = { [7] = "z", s = 1 }
    local p = diff.diff(base, cur)
    expect(p.x).to_equal({ 5 })
    expect(diff.patch(base, p)).to_equal(cur)
  end)
  it("counts what a patch carries", function()
    expect(diff.size(nil)).to_be(0 + 1)
    expect(diff.size({ d = { a = { v = 1 } }, x = { "b" } })).to_be(2)
  end)
  it("compares nested tables, even when one side has extra keys", function()
    expect(diff.equal({ a = { 1 } }, { a = { 1 } })).to_be(true)
    expect(diff.equal({ a = 1 }, { a = 1, b = 2 })).to_be(false)
    expect(diff.equal({ a = 1, b = 2 }, { a = 1 })).to_be(false)
    expect(diff.equal({ a = 1 }, 1)).to_be(false)
  end)
end)

describe("seed plus diffs (save-system)", function()
  it("a fresh universe saves as the seed and almost nothing else", function()
    local st = new_state(1)
    local rec = save.record(st)
    expect(rec.format).to_be(3)
    expect(rec.seed).to_be(42)
    expect(rec.version).to_be(13)
    expect(rec.mods[1].id).to_be("base")
    expect(next(rec.world.diff)).to_be(nil)
    expect(diff.size(rec.players[1].diff)).to_be_less(60)
  end)
  it("stores no generated geometry: sector, ruins, sentries and meshes are not in the file", function()
    local st = new_state(2)
    local rec = save.record(st)
    local function has_key(t, name, seen)
      seen = seen or {}
      if type(t) ~= "table" or seen[t] then return false end
      seen[t] = true
      for k, v in pairs(t) do
        if k == name or has_key(v, name, seen) then return true end
      end
      return false
    end
    for _, k in ipairs({ "sector", "sites", "sentries", "ruins", "mesh", "bolts" }) do
      expect(has_key(rec, k)).to_be(false)
    end
    local full = 0
    for _, p in ipairs(st.players) do full = full + diff.size(diff.diff({}, p)) end
    local small = 0
    for _, r in ipairs(rec.players) do small = small + diff.size(r.diff) end
    expect(small).to_be_less(full // 3)
  end)
  it("saves only what changed and loads it back over the regenerated universe", function()
    local st = new_state(1)
    local p = st.players[1]
    p.credits = 321
    p.sleeps = 4
    st.traders[1].demand["curio:velari"] = { sold = 3, tick = 100 }
    st.vault.taken = true
    st.clock.skipped = 12
    st.tick = 777
    local rec = save.record(st)
    expect(rec.players[1].diff.d.credits.v).to_be(321)
    expect(rec.players[1].diff.d.hold).to_be(nil)
    expect(rec.world.diff.d.vault.d.taken.v).to_be(true)
    expect(rec.world.diff.d.clock.d.skipped.v).to_be(12)
    expect(rec.world.diff.d.nests).to_be(nil)
    local st2 = reload(rec)
    expect(st2.tick).to_be(777)
    expect(st2.players[1].credits).to_be(321)
    expect(st2.players[1].sleeps).to_be(4)
    expect(st2.vault.taken).to_be(true)
    expect(st2.clock.skipped).to_be(12)
    expect(st2.traders[1].demand["curio:velari"].sold).to_be(3)
    expect(#st2.traders[1].requests).to_be(3)
    expect(st2.sector.sites[1].pos).to_equal(st.sector.sites[1].pos)
  end)
  it("round-trips through the real save file and keeps per-site diffs (twins, lockdowns, hardcore)", function()
    local st = new_state(1)
    st.twins = { ["1:1"] = { done = true, by = 1 } }
    st.lockdowns = { ["1:2"] = { 1, 2 } }
    st.locks["1:1"] = 5
    st.hardcore = true
    st.players[1].looted = { [3] = true, [9] = true }
    expect(save.write(st)).to_be(true)
    local rec = save.read()
    expect(rec.format).to_be(3)
    local st2 = reload(rec)
    expect(st2.twins["1:1"].done).to_be(true)
    expect(st2.lockdowns["1:2"]).to_equal({ 1, 2 })
    expect(st2.locks["1:1"]).to_be(5)
    expect(st2.hardcore).to_be(true)
    expect(st2.players[1].looted[9]).to_be(true)
    -- an untouched universe stays untouched and Standard
    local rec0 = save.record(new_state(1))
    expect(reload(rec0).hardcore).to_be(nil)
  end)
  it("a save made in a far sector loads back there", function()
    local st = new_state(1)
    game.enter_sector(st, 2)
    st.players[1].credits = 55
    local rec = save.record(st)
    expect(save.sector_id(rec)).to_be(2)
    local st2 = reload(rec)
    expect(st2.sector_id).to_be(2)
    expect(st2.players[1].credits).to_be(55)
    expect(#st2.traders).to_be(#st.traders)
    expect(st2.vault).to_be(false)
    expect(st2.visited["1"]).to_be_truthy()
  end)
  it("reads and refuses save files by format", function()
    expect(save.write(new_state(1))).to_be(true)
    expect(save.read().format).to_be(3)
    saucer.save.write(save.SLOT, { format = 1, players = {}, world = {} })
    local _, why = save.read()
    expect(why).to_be("format")
    saucer.save.write(save.SLOT, { format = 4, players = {}, world = {} })
    _, why = save.read()
    expect(why).to_be("format")
    saucer.save.write(save.SLOT, { format = 3, players = {} })
    _, why = save.read()
    expect(why).to_be("format")
    saucer.save.write(save.SLOT, { format = 3, version = 99, players = {}, world = {} })
    _, why = save.read()
    expect(why).to_be("newer")
    local st, p = new_state(1), nil
    p = st.players[1]
    expect(home.load(st, p, game.ctx, game)).to_be(false)
    expect(texts(p)).to_contain("newer version")
    saucer.save.write(save.SLOT, 5)
    _, why = save.read()
    expect(why).to_be("corrupt")
  end)
  it("summarises a save in one line", function()
    local rec = save.record(new_state(2))
    expect(save.summary(rec)).to_contain("2 players")
    expect(save.summary(save.record(new_state(1)))).to_contain("1 player")
  end)
end)

describe("older saves migrate (state version 10, format 2)", function()
  local function fixture()
    local fh = assert(io.open("tests/fixtures/saves/v10_format2.lua", "rb"))
    local src = fh:read("a")
    fh:close()
    return assert(load(src, "@v10_format2"))()
  end
  it("loads a version 10 format 2 save into the current game", function()
    local rec = fixture()
    expect(rec.format).to_be(2)
    expect(rec.version).to_be(10)
    saucer.save.write(save.SLOT, rec)
    local back, why = save.read()
    expect(why).to_be(nil)
    expect(back.format).to_be(2)
    local st = new_state(1, 7)
    local p = st.players[1]
    expect(home.load(st, p, game.ctx, game)).to_be(true)
    local q = st.players[1]
    expect(st.seed).to_be(42)
    expect(st.version).to_be(13)
    expect(q.credits).to_be(321)
    expect(q.sleeps).to_be(4)
    expect(st.vault.taken).to_be(true)
    expect(st.clock.skipped).to_be(12)
    expect(st.traders[1].demand["curio:velari"].sold).to_be(3)
    -- saving again writes the new format
    expect(save.write(st)).to_be(true)
    expect(save.read().format).to_be(3)
    expect(save.player(save.read(), 1).credits).to_be(321)
  end)
  it("a format 2 save keeps keys it never had at their defaults", function()
    local rec = fixture()
    rec.world.hardcore = nil
    local st = reload(rec)
    expect(st.hardcore).to_be(nil)
    expect(save.sector_id(rec)).to_be(1)
    expect(st.twins).to_be(nil)
  end)
end)

describe("player records (save-system)", function()
  it("one record per participant, keyed by record_index in join order", function()
    local st = new_state(3)
    st.players[2].credits = 22
    st.players[3].credits = 33
    local rec = save.record(st)
    expect(#rec.players).to_be(3)
    for i = 1, 3 do expect(rec.players[i].record_index).to_be(i - 1) end
    local st2 = reload(rec, 3)
    for i = 1, 3 do expect(st2.players[i].record_index).to_be(i - 1) end
    expect(st2.players[2].credits).to_be(22)
    expect(st2.players[3].credits).to_be(33)
  end)
  it("each record holds that player's saucer, hold, credits, archive, dome and hot/banked state", function()
    local st = new_state(2)
    local p = st.players[2]
    p.credits = 90
    p.banked_value = 40
    p.ship.size = 2
    p.hold = { { uid = 1, name = "Coil", hot = true, value = 30 } }
    p.archive = { velari = { words = 3 } }
    p.holo.mods.size = 2
    p.home_layout = { rooms = 2 }
    local rec = save.record(st)
    local full = save.player(rec, 2)
    expect(full.ship.size).to_be(2)
    expect(full.hold[1].hot).to_be(true)
    expect(full.credits).to_be(90)
    expect(full.banked_value).to_be(40)
    expect(full.archive.velari.words).to_be(3)
    expect(full.holo.mods.size).to_be(2)
    expect(full.home_layout.rooms).to_be(2)
    -- the other record is untouched
    expect(save.player(rec, 1).credits).to_be(0)
    expect(save.player(rec, 1).hold).to_equal({})
  end)
  it("a single-player save loaded with two local players keeps record 0 and starts record 1 with a starter saucer", function()
    local st = new_state(1)
    local p = st.players[1]
    p.credits = 500
    p.sleeps = 3
    p.hold = { { uid = 1, name = "Coil" } }
    p.next_uid = 1
    local rec = save.record(st)
    expect(#rec.players).to_be(1)
    local st2 = new_state(2, 99)
    save.apply(st2, rec, game)
    expect(#st2.players).to_be(2)
    local q0, q1 = st2.players[1], st2.players[2]
    expect(q0.record_index).to_be(0)
    expect(q0.credits).to_be(500)
    expect(q0.sleeps).to_be(3)
    expect(q0.hold[1].name).to_be("Coil")
    expect(q1.record_index).to_be(1)
    expect(q1.credits).to_be(0)
    expect(#q1.hold).to_be(0)
    expect(q1.ship.size).to_be(1)
    expect(q1.mode).to_be("wake")
    -- and the party request for two exists now
    expect(st2.traders[1].party).to_be_truthy()
  end)
  it("a two-player save loads into a single-local-player test build and keeps both records", function()
    local st = new_state(2)
    st.players[2].credits = 7
    local rec = save.record(st)
    local st2 = reload(rec, 1)
    expect(#st2.players).to_be(2)
    expect(st2.players[2].credits).to_be(7)
  end)
  it("a record is saved with no transient UI state", function()
    local st = new_state(1)
    local p = st.players[1]
    p.msgs[#p.msgs + 1] = { tick = 1, text = "hi" }
    p.tractor = true
    local full = save.player(save.record(st), 1)
    expect(full.msgs).to_be(nil)
    expect(full.tractor).to_be(nil)
    expect(full.panel).to_be(nil)
  end)
end)

describe("mod set (save-system)", function()
  it("a save made with another mod set warns that generation may differ, and can be cancelled", function()
    local st = new_state(1)
    local p = st.players[1]
    st.players[1].sleeps = 2
    local rec = save.record(st)
    rec.mods[#rec.mods + 1] = { id = "bigger_ruins", version = "1.0" }
    local real = save.read
    save.read = function() return rec end
    st.players[1].sleeps = 9
    p.panel = { kind = "title" }
    expect(home.load(st, p, game.ctx, game)).to_be(false)
    expect(texts(p)).to_contain("different mod set")
    expect(texts(p)).to_contain("generation may differ")
    expect(p.panel.confirm).to_be(true)
    -- cancel: close the card; nothing was loaded, and the warning comes back next time
    panel.close(p)
    expect(st.players[1].sleeps).to_be(9)
    p.panel = { kind = "title" }
    expect(home.load(st, p, game.ctx, game)).to_be(false)
    -- or carry on
    expect(home.load(st, p, game.ctx, game)).to_be(true)
    save.read = real
    expect(st.players[1].sleeps).to_be(2)
  end)
  it("the same mod set loads without a warning", function()
    local st = new_state(1)
    local p = st.players[1]
    expect(save.same_mods(save.mods(), save.mods())).to_be(true)
    save.write(st)
    expect(home.load(st, p, game.ctx, game)).to_be(true)
  end)
end)
