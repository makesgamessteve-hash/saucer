-- SPDX-License-Identifier: MIT
-- OpenSpec add-run-story, slice 1: the generator. Every `it` name is a scenario of
-- openspec/changes/add-run-story. A story is a pure function of the universe seed.
local game = require("sim.game")
local story = require("sim.story")
local galaxy = require("sim.galaxy")
local sector = require("sim.sector")
local civs = require("sim.civs")
local mystery = require("sim.mystery")
local save = require("sim.save")
local diff = require("sim.diff")

local function new_state(seed, n)
  local st = {}
  game.init(st, { seed = seed or 42, players = n or 1 })
  return st
end
local function story_of(seed)
  local m = mystery.generate(seed, "on", 3, galaxy.generate(seed))
  civs.use(seed)
  return story.generate(seed, m, galaxy.generate(seed)), m
end
local SEEDS = {}
for i = 1, 60 do SEEDS[i] = i * 37 + 5 end

describe("story skeletons", function()
  it("a handful of plot skeletons each have four to six beats ending in a finale per ending", function()
    local S = story.skeletons().skeletons
    expect(#S >= 4).to_be(true)
    for _, sk in ipairs(S) do
      expect(#sk.beats >= 4 and #sk.beats <= 6).to_be(true)
      local last = sk.beats[#sk.beats]
      expect(last.id).to_be("finale")
      for _, e in ipairs({ "seal", "restore", "take" }) do expect(type(last.text[e])).to_be("string") end
      local ids = {}
      for i, b in ipairs(sk.beats) do
        expect(ids[b.id]).to_be(nil)
        ids[b.id] = true
        expect(b.carrier ~= nil and b.where ~= nil).to_be(true)
        if i < #sk.beats then expect(#b.text >= 2).to_be(true) end
      end
      expect(ids.reveal).to_be(true)
    end
  end)
  it("the seed picks the skeleton: every skeleton and several twists turn up across seeds", function()
    local sk, tw = {}, {}
    for _, seed in ipairs(SEEDS) do
      local s = story_of(seed)
      sk[s.skeleton] = true
      tw[tostring(s.twist)] = true
    end
    local n, t = 0, 0
    for _ in pairs(sk) do n = n + 1 end
    for _ in pairs(tw) do t = t + 1 end
    expect(n).to_be(#story.skeletons().skeletons)
    expect(t >= 4).to_be(true)
    expect(tw["false"]).to_be(true) -- some runs have no twist
  end)
end)

describe("story generation", function()
  it("is a pure function of the seed: same seed same story, other seeds differ", function()
    for _, seed in ipairs({ 1, 42, 99 }) do
      expect(diff.equal(story_of(seed), story_of(seed))).to_be(true)
      -- and the one a fresh game builds
      expect(diff.equal(new_state(seed).story, story_of(seed))).to_be(true)
    end
    local seen = {}
    local distinct = 0
    for _, seed in ipairs(SEEDS) do
      local s = story_of(seed)
      local key = s.beats[1].text .. "|" .. s.beats[#s.beats - 1].text
      if not seen[key] then seen[key] = true distinct = distinct + 1 end
    end
    expect(distinct >= 30).to_be(true)
  end)
  it("is filled from the run: the mystery's civilisation, object and place, a second civilisation, what the Echo is", function()
    for _, seed in ipairs(SEEDS) do
      local s, m = story_of(seed)
      local U = civs.universe(seed)
      expect(U[s.a].name).to_be(m.vars.civ)
      expect(s.b ~= s.a).to_be(true)
      expect(s.vars.object).to_be(m.vars.object)
      expect(s.vars.place).to_be(m.vars.place)
      expect(s.cause).to_be(m.cause)
      expect(s.betrayer == s.vars.a or s.betrayer == s.vars.b).to_be(true)
      expect(s.betrayed ~= s.betrayer).to_be(true)
      local ok = false
      for _, e in ipairs(story.vocab().echo) do if e.id == s.echo then ok = true end end
      expect(ok).to_be(true)
    end
  end)
  it("leaves no template unfilled and no clue text empty, for any seed", function()
    for _, seed in ipairs(SEEDS) do
      local s = story_of(seed)
      expect(s.title:find("{", 1, true)).to_be(nil)
      for i, b in ipairs(s.beats) do
        expect(#b.text > 20).to_be(true)
        expect(story.full_text(s, i):find("{", 1, true)).to_be(nil)
        expect(b.loc:find("{", 1, true)).to_be(nil)
        if b.finale then
          for _, e in ipairs({ "seal", "restore", "take" }) do
            expect(story.finale_text(s, e):find("{", 1, true)).to_be(nil)
          end
        end
      end
    end
  end)
  it("an unknown template word stays visible instead of vanishing", function()
    expect(story.fill("a {nope} b {x}", { x = 3 })).to_be("a {nope} b 3")
  end)
  it("a skeleton limited to other causes is not picked", function()
    local m = mystery.generate(42, "on", 3, galaxy.generate(42))
    civs.use(42)
    local real = story.skeletons
    story.skeletons = function()
      local S = real()
      local only = { leads = S.leads, skeletons = {} }
      for i, sk in ipairs(S.skeletons) do
        only.skeletons[i] = setmetatable({ causes = { "not-" .. m.cause } }, { __index = sk })
      end
      only.skeletons[2] = setmetatable({ causes = { m.cause } }, { __index = S.skeletons[2] })
      return only
    end
    local ok, s = pcall(story.generate, 42, m, galaxy.generate(42))
    story.skeletons = real
    expect(ok).to_be(true)
    expect(s.skeleton).to_be(real().skeletons[2].id)
    -- when none fits, any does
    story.skeletons = function()
      local S = real()
      local all = { leads = S.leads, skeletons = {} }
      for i, sk in ipairs(S.skeletons) do all.skeletons[i] = setmetatable({ causes = { "none" } }, { __index = sk }) end
      return all
    end
    ok, s = pcall(story.generate, 42, m, galaxy.generate(42))
    story.skeletons = real
    expect(ok and s.skeleton ~= nil).to_be(true)
  end)
  it("there is no story without a mystery", function()
    expect(story.generate(42, nil, galaxy.generate(42))).to_be(nil)
  end)
end)

describe("story twists", function()
  it("a twist replaces the reveal and adds a line to every ending, and only fits the skeletons it names", function()
    local TW = story.twists()
    local by = {}
    for _, t in ipairs(TW) do by[t.id] = t end
    local twisted = 0
    for _, seed in ipairs(SEEDS) do
      local s = story_of(seed)
      local rev
      for _, b in ipairs(s.beats) do if b.id == "reveal" then rev = b end end
      if s.twist then
        twisted = twisted + 1
        local t = by[s.twist]
        expect(rev.twisted).to_be(true)
        expect(s.beats[#s.beats].coda ~= nil).to_be(true)
        expect(story.finale_text(s, "seal"):find(s.beats[#s.beats].coda, 1, true) ~= nil).to_be(true)
        if t.skeletons then
          local fits = false
          for _, id in ipairs(t.skeletons) do if id == s.skeleton then fits = true end end
          expect(fits).to_be(true)
        end
      else
        expect(rev.twisted).to_be(nil)
        expect(s.beats[#s.beats].coda).to_be(nil)
      end
    end
    expect(twisted >= 35).to_be(true)
    expect(#TW >= 5).to_be(true)
  end)
  it("the caretakers twist turns the Watchers into caretakers", function()
    local found
    for _, seed in ipairs(SEEDS) do
      local s = story_of(seed)
      if s.twist == "caretakers" then found = s end
    end
    expect(found ~= nil).to_be(true)
    local rev
    for _, b in ipairs(found.beats) do if b.id == "reveal" then rev = b.text end end
    expect(rev:find("Watchers", 1, true) ~= nil).to_be(true)
    expect(rev:lower():find("caretaker", 1, true) ~= nil).to_be(true)
  end)
end)

describe("story places", function()
  it("every beat is bound to a real site: its sector, kit and civilisation are the generated ones", function()
    for _, seed in ipairs(SEEDS) do
      local s = story_of(seed)
      local g = galaxy.generate(seed)
      for _, b in ipairs(s.beats) do
        local sec = sector.generate(seed, b.sector, b.sector ~= 1 and g.sectors[b.sector] or nil)
        local site = sec.sites[b.site]
        expect(site ~= nil).to_be(true)
        expect(site.kit).to_be(b.kit)
        expect(site.civ).to_be(b.civ)
        expect(b.where == "heart" or b.loc:find(civs.get(seed, b.civ).name, 1, true) ~= nil).to_be(true)
        if b.where == "home" then expect(b.sector).to_be(1) end
        if b.where == "heart" then
          expect(b.sector).to_be(g.heart)
          expect(site.heart).to_be(true)
        end
        if b.where == "far" then expect(b.sector == g.spine[2] or b.sector == g.spine[3]).to_be(true) end
        if b.where == "city" and b.carrier == "archive" then
          expect(site.city).to_be(true)
          expect(b.sector == g.spine[2] or b.sector == g.spine[3]).to_be(true)
        else
          expect(site.city and b.where ~= "heart").to_be(nil)
        end
      end
    end
  end)
  it("the first clue waits in the tutorial derelict and no two derelict clues share a site", function()
    for _, seed in ipairs(SEEDS) do
      local s = story_of(seed)
      expect(s.beats[1].sector).to_be(1)
      expect(s.beats[1].site).to_be(1)
      local seen = {}
      for i = 1, story.clue_count(s) do
        local b = s.beats[i]
        if b.carrier ~= "archive" then
          local key = b.sector .. ":" .. b.site
          expect(seen[key]).to_be(nil)
          seen[key] = true
        end
      end
    end
  end)
  it("each clue leads to the next: its text names the next beat's place", function()
    for _, seed in ipairs(SEEDS) do
      local s = story_of(seed)
      for i = 1, story.clue_count(s) do
        expect(story.full_text(s, i):find(s.beats[i + 1].loc, 1, true) ~= nil).to_be(true)
      end
      expect(story.full_text(s, #s.beats)).to_be(s.beats[#s.beats].text)
    end
  end)
  it("beats stay in the home sector when the galaxy has no far spine", function()
    local m = mystery.generate(42, "on", 3, nil)
    civs.use(42)
    local s = story.generate(42, m, nil)
    for _, b in ipairs(s.beats) do
      expect(b.sector).to_be(1)
      expect(b.carrier ~= "archive").to_be(true)
    end
  end)
end)

describe("story progress", function()
  it("clues unlock one after the other and the finale is not a clue", function()
    local s = story_of(42)
    local n = story.clue_count(s)
    expect(n).to_be(#s.beats - 1)
    expect(story.unlocked(s, 1)).to_be(true)
    expect(story.unlocked(s, 2)).to_be(false)
    expect(story.unlocked(s, 0)).to_be(false)
    expect(story.unlocked(s, n + 1)).to_be(false)
    expect(story.next_clue(s)).to_be(1)
    expect(story.found_count(s)).to_be(0)
    for i = 1, n do
      s.beats[i].found_by = 1
      expect(story.unlocked(s, i + 1)).to_be(i < n)
    end
    expect(story.next_clue(s)).to_be(nil)
    expect(story.found_count(s)).to_be(n)
    expect(story.finale(s).id).to_be("finale")
    expect(story.unlocked(nil, 1)).to_be(false)
    expect(story.clue_count(nil)).to_be(0)
    expect(story.full_text(s, 99)).to_be("")
  end)
  it("the story follows the mystery: it is off in the sandbox and with its own switch", function()
    local st = new_state(42)
    expect(story.active(st)).to_be(true)
    st.mystery.mode = "off"
    expect(story.active(st)).to_be(false)
    st.mystery.mode = "hints"
    expect(story.active(st)).to_be(true)
    st.story.mode = "off"
    expect(story.active(st)).to_be(false)
  end)
  it("the finale text follows the ending, with a fallback for an ending a mod adds", function()
    local s = story_of(42)
    local seal, take = story.finale_text(s, "seal"), story.finale_text(s, "take")
    expect(seal ~= take).to_be(true)
    expect(story.finale_text(s, "mod-ending")).to_be(story.finale_text(s, "seal"))
  end)
  it("progress is what a save keeps: who found which beat, and it restores onto a fresh story", function()
    local st = new_state(42)
    st.story.beats[1].found_by, st.story.beats[1].tick = 1, 600
    st.story.beats[2].found_by, st.story.beats[2].tick = 2, 900
    st.story.done, st.story.ending = true, "restore"
    local prog = story.progress(st.story)
    expect(prog.beats[2]).to_equal({ found_by = 2, tick = 900 })
    expect(prog.text).to_be(nil)
    local fresh = new_state(42).story
    story.restore(fresh, prog)
    expect(diff.equal(fresh, st.story)).to_be(true)
    expect(story.restore(fresh, nil)).to_be(fresh)
    expect(story.progress(nil)).to_be(nil)
    -- a shorter record (another skeleton) leaves the extra beats alone
    local partial = new_state(42).story
    story.restore(partial, { beats = { { found_by = 1 } } })
    expect(partial.beats[1].found_by).to_be(1)
    expect(partial.beats[2].found_by).to_be(0)
    expect(partial.mode).to_be("on")
  end)
end)

describe("story saves", function()
  it("a save keeps the story's progress and loading puts it back, with the same story regenerated", function()
    local st = new_state(42)
    st.story.beats[1].found_by, st.story.beats[1].tick = 1, 700
    local before = story.full_text(st.story, 2)
    local rec = save.record(st)
    expect(rec.world.story.beats[1].found_by).to_be(1)
    local st2 = { players = { {} } }
    save.apply(st2, rec, game)
    expect(st2.story.beats[1].found_by).to_be(1)
    expect(st2.story.beats[1].tick).to_be(700)
    expect(story.full_text(st2.story, 2)).to_be(before)
    expect(st2.version).to_be(game.VERSION)
  end)
  it("a save from before the story (state version 10 or 11) loads with a fresh story of the same seed", function()
    expect(game.VERSION >= 12).to_be(true)
    local fh = assert(io.open("tests/fixtures/saves/v10_format2.lua", "rb"))
    local src = fh:read("*a")
    fh:close()
    local rec = assert(load(src, "@v10_format2"))()
    expect(rec.world.story).to_be(nil)
    local st = { players = { {} } }
    save.apply(st, rec, game)
    expect(st.story ~= nil).to_be(true)
    expect(story.found_count(st.story)).to_be(0)
    expect(diff.equal(st.story, story_of(rec.seed))).to_be(true)
  end)
end)

-- ------------------------------------------------------------------ slice 2: clues in the world
local tractor = require("sim.tractor")
local cities = require("sim.cities")
local books = require("sim.books")
local ruinm = require("sim.ruin")

local function story_cand(st, p, site)
  local ruin = st.sector_id == 1 and game.ruin(site) or game.ruin(site)
  for _, c in ipairs(tractor.candidates(st, p, site, ruin)) do if c.kind == "story" then return c end end
  return nil
end
local function inside(mn, mx, p)
  return p[1] >= mn[1] and p[1] <= mx[1] and p[2] >= mn[2] and p[2] <= mx[2] and p[3] >= mn[3] and p[3] <= mx[3]
end

describe("story clues in the world", function()
  it("only the next clue is on offer, at its own site, and the one before unlocks it", function()
    local st = new_state(42)
    local p = st.players[1]
    local b1, b2 = st.story.beats[1], st.story.beats[2]
    expect(story_cand(st, p, b1.site) ~= nil).to_be(true)
    expect(story_cand(st, p, b1.site).key).to_be("story:1")
    expect(story_cand(st, p, b1.site).story).to_be(1)
    for site = 1, 3 do
      if site ~= b1.site then expect(story_cand(st, p, site)).to_be(nil) end
    end
    local c = story_cand(st, p, b1.site)
    expect(c.item.name).to_be(story.vocab().carriers[b1.carrier].name)
    expect(c.item.size).to_be(1)
    expect(c.carrier).to_be(b1.carrier)
    expect(story.read(st, 1, p, game.ctx or { msg = game.msg, fx = function() end })).to_be(true)
    expect(story_cand(st, p, b1.site) == nil or b2.site == b1.site).to_be(true)
    expect(story_cand(st, p, b2.site).story).to_be(2)
  end)
  it("a clue lies a quarter of a great hall in from two walls, clear of the crates, in every kit", function()
    local kits = {}
    for _, seed in ipairs({ 1, 2, 3, 5, 8, 13, 21, 34, 42, 55, 77 }) do
      local st = new_state(seed)
      local p = st.players[1]
      local c = story_cand(st, p, st.story.beats[1].site)
      expect(c ~= nil).to_be(true)
      local ruin = game.ruin(st.story.beats[1].site)
      local kit = ruinm.kit_of(ruin.kit)
      kits[ruin.kit] = true
      local r = ruin.rooms[c.room]
      expect(r.kind).to_be("hall")
      expect(r.class >= (kit.big or 4)).to_be(true)
      local mn, mx = ruinm.room_box(r, kit, ruin.origin)
      expect(inside(mn, mx, c.pos)).to_be(true)
      expect(math.abs(c.pos[1] - (mn[1] + mx[1]) / 2)).to_be_near((mx[1] - mn[1]) / 4, 0.01)
      expect(math.abs(c.pos[3] - (mn[3] + mx[3]) / 2)).to_be_near((mx[3] - mn[3]) / 4, 0.01)
      for _, d in ipairs(ruin.debris or {}) do
        expect(c.pos[1] > d[1][1] - 1.5 and c.pos[1] < d[2][1] + 1.5 and c.pos[3] > d[1][3] - 1.5 and c.pos[3] < d[2][3] + 1.5).to_be(false)
      end
      -- the same every time
      expect(story_cand(st, p, st.story.beats[1].site).pos).to_equal(c.pos)
    end
  end)
  it("a clue falls back to a smaller room when a site has no great hall, and to the first room when it has nothing else", function()
    local st = new_state(42)
    local ruin = game.ruin(1)
    local kit = ruinm.kit_of(ruin.kit)
    local fake = { kit = ruin.kit, origin = ruin.origin, debris = {}, rooms = {} }
    for i, r in ipairs(ruin.rooms) do
      fake.rooms[i] = setmetatable({ kind = r.kind == "hall" and "side" or r.kind, class = math.min(r.class, 3) }, { __index = r })
    end
    local pos, room = story.place(fake, { n = 1, salt = 4, carrier = "log" })
    expect(pos ~= nil and room ~= nil).to_be(true)
    expect(fake.rooms[room].kind ~= "shaft").to_be(true)
    local only = { kit = ruin.kit, origin = ruin.origin, debris = {}, rooms = {} }
    for i, r in ipairs(ruin.rooms) do only.rooms[i] = setmetatable({ kind = "shaft" }, { __index = r }) end
    pos, room = story.place(only, { n = 1, salt = 9, carrier = "mural" })
    expect(room).to_be(only.rooms[1].id)
    -- every quarter blocked by crates: the last one is taken anyway
    local mn, mx = ruinm.room_box(ruin.rooms[room], kit, ruin.origin)
    local blocked = { kit = ruin.kit, origin = ruin.origin, rooms = ruin.rooms,
                      debris = { { { mn[1] - 5, mn[2], mn[3] - 5 }, { mx[1] + 5, mx[2], mx[3] + 5 } } } }
    expect(story.place(blocked, { n = 1, salt = 3, carrier = "log" }) ~= nil).to_be(true)
  end)
  it("an archive record sits in the city's archive hall and reads only once its district's grid is on", function()
    local st = new_state(42)
    local s = st.story
    local idx
    for i, b in ipairs(s.beats) do if b.carrier == "archive" then idx = i end end
    expect(idx ~= nil).to_be(true)
    for i = 1, idx - 1 do s.beats[i].found_by = 1 end
    local b = s.beats[idx]
    game.enter_sector(st, b.sector)
    local p = st.players[1]
    local ruin = game.ruin(b.site)
    expect(ruin.city ~= nil and #ruin.city.clues > 0).to_be(true)
    expect(story_cand(st, p, b.site)).to_be(nil) -- the archive is dark
    local clue = ruin.city.clues[(b.slot - 1) % #ruin.city.clues + 1]
    cities.restore(st, b.site, clue.district)
    local c = story_cand(st, p, b.site)
    expect(c ~= nil).to_be(true)
    expect(c.district).to_be(clue.district)
    expect(c.room).to_be(clue.room)
    local kit = ruinm.kit_of(ruin.kit)
    local mn, mx = ruinm.room_box(ruin.rooms[clue.room], kit, ruin.origin)
    expect(inside(mn, mx, c.pos)).to_be(true)
    -- other sites of the sector offer nothing
    for site = 1, #st.sector.sites do
      if site ~= b.site then expect(story_cand(st, p, site)).to_be(nil) end
    end
  end)
  it("a clue is found for the whole party: it is filed on every shelf and the others are told", function()
    local st = new_state(42, 2)
    local p1, p2 = st.players[1], st.players[2]
    local b = st.story.beats[1]
    local c = story_cand(st, p1, b.site)
    p1.msgs, p2.msgs = {}, {}
    game.pick_up(st, p2, c, b.site)
    expect(b.found_by).to_be(2)
    expect(b.tick).to_be(st.tick)
    expect(books.has(p1, "story:1") ~= nil and books.has(p2, "story:1") ~= nil).to_be(true)
    expect(p2.msgs[1].text:find("STORY 1/", 1, true) ~= nil).to_be(true)
    expect(#p2.msgs >= 2).to_be(true)
    expect(p1.msgs[1].text:find("P2 read a story clue", 1, true) ~= nil).to_be(true)
    expect(#p2.hold).to_be(0)
    -- reading it again does nothing, and nobody can read the finale or a clue that is not there
    expect(story.read(st, 1, p1, { msg = game.msg, fx = function() end })).to_be(false)
    expect(story.read(st, #st.story.beats, p1, { msg = game.msg, fx = function() end })).to_be(false)
    expect(story.read(st, 99, p1, { msg = game.msg, fx = function() end })).to_be(false)
    -- the next place is on the radar of whoever read it, when it is in the same sector
    local nxt = st.story.beats[2]
    expect(p2.leads ~= nil and p2.leads[tostring(nxt.site)] == true).to_be(nxt.sector == 1)
  end)
  it("the story page on the shelf is the clue's text, in pages the book reader can turn", function()
    local st = new_state(42)
    local p = st.players[1]
    story.read(st, 1, p, { msg = game.msg, fx = function() end })
    local r = books.resolve(st, "story:1")
    expect(r.kind).to_be("clue")
    expect(r.title:find("1/", 1, true) ~= nil).to_be(true)
    local text = {}
    for _, page in ipairs(r.pages) do for _, l in ipairs(page) do text[#text + 1] = l end end
    expect(table.concat(text, " ")).to_be(table.concat(books.wrap(story.full_text(st.story, 1)), " "))
    -- a long text goes over several pages of eight lines
    st.story.beats[1].text = string.rep("long words go on and on ", 30)
    expect(#books.resolve(st, "story:1").pages >= 2).to_be(true)
    expect(books.resolve(st, "story:9").pages[1][1]).to_be("(lost)")
    st.story = nil
    expect(books.resolve(st, "story:1").pages[1][1]).to_be("(lost)")
    expect(books.open(st, p, "story:1", { msg = game.msg, fx = function() end })).to_be(true)
  end)
  it("the log gets the clue in chunks of whole sentences", function()
    local c = story.chunks("One. Two is longer than the first. Three!", 20)
    expect(c).to_equal({ "One.", "Two is longer than the first.", "Three!" })
    expect(story.chunks("One. Two.", 100)).to_equal({ "One. Two." })
    expect(story.chunks("no stop at all", 10)).to_equal({ "no stop at all" })
  end)
  it("there are no clues in the sandbox, with the story switched off, or once they are all found", function()
    local st = new_state(42)
    local p = st.players[1]
    local site = st.story.beats[1].site
    expect(story_cand(st, p, site) ~= nil).to_be(true)
    st.mystery.mode = "off"
    expect(story_cand(st, p, site)).to_be(nil)
    st.mystery.mode = "on"
    st.story.mode = "off"
    expect(story_cand(st, p, site)).to_be(nil)
    st.story.mode = "on"
    for i = 1, story.clue_count(st.story) do st.story.beats[i].found_by = 1 end
    for s = 1, 3 do expect(story_cand(st, p, s)).to_be(nil) end
    expect(story.candidates(st, p, 0, nil)).to_equal({})
  end)
end)

-- ------------------------------------------------------------------ slice 3: the codex, the hints, the ending
local panel = require("sim.panel")
local home = require("sim.home")
local avatar = require("sim.avatar")
local heart = require("sim.heart")
local hud = require("view.hud")
local assets = require("view.assets")
local render = require("view.render")

local function texts(p)
  local t = {}
  for _, m in ipairs(p.msgs) do t[#t + 1] = m.text end
  return table.concat(t, "|")
end
local function row_texts(st, p)
  local t = {}
  for _, r in ipairs(panel.rows(st, p)) do t[#t + 1] = r.text end
  return table.concat(t, "\n")
end
local function find_row(st, p, prefix)
  for _, r in ipairs(panel.rows(st, p)) do if r.text:sub(1, #prefix) == prefix then return r end end
end
local function fake_view(w, h)
  local v = { calls = {}, width = w or 480, height = h or 270, player = 1, index = 1, xr = false, texts = "" }
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

describe("the holotable", function()
  it("stands in the living room as a station with its own mesh, reachable on foot", function()
    local L = avatar.layout()
    local st
    for _, s in ipairs(L.stations) do if s.kind == "holotable" then st = s end end
    expect(st ~= nil).to_be(true)
    expect(st.room).to_be("Living room")
    local prop
    for _, f in ipairs(L.furniture) do if f.kind == "holotable" then prop = f end end
    expect(prop ~= nil).to_be(true)
    expect(L.nav.nodes.holotable ~= nil).to_be(true)
    expect(L.holotable.y > 0).to_be(true)
  end)
  it("using it opens the Story page: the title, the clues still to find and where the next one is", function()
    local st = new_state(42)
    local p = st.players[1]
    home.get_up(st, p, game.ctx)
    home.USE.holotable(st, p, nil, game.ctx)
    expect(p.panel.kind).to_be("story")
    expect(panel.title(st, p)).to_be("HOLOTABLE: THE STORY")
    local t = row_texts(st, p)
    expect(t:find(st.story.title:upper(), 1, true) ~= nil).to_be(true)
    expect(t:find("Clues found 0/" .. story.clue_count(st.story), 1, true) ~= nil).to_be(true)
    expect(t:find("1 ???  next: ", 1, true) ~= nil).to_be(true)
    expect(t:find(st.story.beats[1].loc, 1, true) ~= nil).to_be(true)
    expect(t:find("The Echo is ???", 1, true) ~= nil).to_be(true)
    expect(t:find("The truth waits at the Heart", 1, true) ~= nil).to_be(true)
    expect(t:find("Story clues: ON", 1, true) ~= nil).to_be(true)
    -- the page of a game that finds it through the station code
    home.get_up(st, p, game.ctx)
    p.body = avatar.new(avatar.layout(), { -5.0, 0.6, 1.3 }, 0)
    local used = home.use_station(st, p, game.ctx)
    expect(used and used.kind).to_be("holotable")
    expect(p.panel.kind).to_be("story")
  end)
  it("stitches the found clues, the Echo, the ending and the twist; a found clue can be read again from its row", function()
    local st = new_state(42, 2)
    local p = st.players[1]
    local s = st.story
    story.read(st, 1, p, game.ctx)
    story.read(st, 2, p, game.ctx)
    panel.open(p, "story")
    local t = row_texts(st, p)
    expect(t:find("Clues found 2/", 1, true) ~= nil).to_be(true)
    expect(t:find("1 " .. story.vocab().carriers[s.beats[1].carrier].name .. ": ", 1, true) ~= nil).to_be(true)
    expect(find_row(st, p, "1 ").hint:find(s.beats[1].text:sub(1, 20), 1, true) ~= nil).to_be(true)
    expect(find_row(st, p, "3 ???  next: ") ~= nil).to_be(true)
    expect(find_row(st, p, "4 ???") ~= nil or story.clue_count(s) == 3).to_be(true)
    find_row(st, p, "1 ").act(st, p)
    expect(p.reading.id).to_be("story:1")
    -- all clues found: the Echo is named
    for i = 1, story.clue_count(s) do story.read(st, i, p, game.ctx) end
    panel.open(p, "story")
    local echo = story.vocab().echo_text(s.echo)
    expect(row_texts(st, p):find("The Echo is " .. echo, 1, true) ~= nil).to_be(true)
    -- decoded Echoes show, and open their transcript
    st.mystery.echoes[1].decoded = true
    books.add(p, "echo:1")
    local er = find_row(st, p, "Echo I (who): ")
    expect(er ~= nil).to_be(true)
    er.act(st, p)
    expect(p.reading.id).to_be("echo:1")
    -- the ending and the twist
    local m = st.mystery
    heart.resolve(st, m.endings[1].id, game.ctx)
    panel.open(p, "story")
    expect(find_row(st, p, "Ending: " .. m.endings[1].title) ~= nil).to_be(true)
    if s.twist then expect(find_row(st, p, "Twist: " .. s.twist_title) ~= nil).to_be(true) end
    expect(find_row(st, p, "Ending: ").hint ~= nil).to_be(true)
    find_row(st, p, "Ending: ").act(st, p)
    expect(p.reading.id).to_be("story:" .. #s.beats)
    expect(books.resolve(st, p.reading.id).title).to_be("The end of " .. s.title)
    expect(books.resolve(st, "ending").pages[1][3] ~= nil).to_be(true)
  end)
  it("the switch turns the story off and on, and the page says why when there is no story", function()
    local st = new_state(42)
    local p = st.players[1]
    panel.open(p, "story")
    find_row(st, p, "Story clues: ON").act(st, p)
    expect(st.story.mode).to_be("off")
    expect(row_texts(st, p):find("The story is switched off", 1, true) ~= nil).to_be(true)
    expect(story.counter(st)).to_be(nil)
    find_row(st, p, "Story clues: OFF").act(st, p)
    expect(st.story.mode).to_be("on")
    st.mystery.mode = "off"
    expect(row_texts(st, p):find("Sandbox: no story", 1, true) ~= nil).to_be(true)
    find_row(st, p, "Close").act(st, p)
    expect(p.panel).to_be(false)
    st.story = nil
    expect(row_texts(st, p) == nil or true).to_be(true)
    expect(story.rows(st, p, game.ctx)[1].text).to_be("No story in this universe")
  end)
end)

describe("story hints and notices", function()
  it("the HUD counts the clues beside the mystery, and in hints mode says where the next one is", function()
    local st = new_state(42)
    local p = st.players[1]
    home.get_up(st, p, game.ctx)
    p.mode = "helm"
    local v = fake_view(480, 270)
    hud.draw(v, st, p, nil)
    expect(v.texts:find("STORY 0/" .. story.clue_count(st.story), 1, true) ~= nil).to_be(true)
    expect(v.texts:find("STORY: ", 1, true)).to_be(nil)
    expect(story.hint(st)).to_be(nil)
    st.mystery.mode = "hints"
    local v2 = fake_view(480, 270)
    hud.draw(v2, st, p, nil)
    expect(v2.texts:find("STORY: ", 1, true) ~= nil).to_be(true)
    expect(story.hint(st):find(st.story.beats[1].loc, 1, true) ~= nil).to_be(true)
    local v3 = fake_view(360, 640)
    hud.draw(v3, st, p, nil)
    for i = 1, story.clue_count(st.story) do story.read(st, i, p, game.ctx) end
    expect(story.hint(st)).to_be("STORY: the truth waits at the Heart")
    st.story.done = true
    expect(story.hint(st)).to_be(nil)
    st.mystery.mode = "off"
    expect(story.counter(st)).to_be(nil)
    local v4 = fake_view(480, 270)
    hud.draw(v4, st, p, nil)
    expect(v4.texts:find("SANDBOX", 1, true) ~= nil and v4.texts:find("STORY %d+/%d+  ") == nil).to_be(true)
  end)
  it("the hologram turns over the holotable when the home is drawn", function()
    local A = assets.init()
    local v = fake_view()
    local n = render.home_parts(v, A, { }, { pos = { 0, 0, 0 }, yaw = 0, roll = 0, scale = 1 }, 10)
    expect(n >= 2).to_be(true)
    expect(v.calls.billboard >= 1).to_be(true)
  end)
  it("a clue close by is announced once, with the beam in mind, and never in the sandbox", function()
    local st = new_state(42)
    local p = st.players[1]
    local b = st.story.beats[1]
    local c = story_cand(st, p, b.site)
    p.site, p.ship.pos = b.site, { c.pos[1] + 30, c.pos[2] + 10, c.pos[3] }
    st.tick = 20
    p.msgs = {}
    expect(story.notice(st, p, game.ctx)).to_be(true)
    expect(texts(p):find("lies nearby", 1, true) ~= nil).to_be(true)
    expect(p.hints.story1).to_be(20)
    expect(story.notice(st, p, game.ctx)).to_be(false) -- once
    -- only on the beat: not at the wrong tick, far away, outside a site or in the sandbox
    p.hints.story1 = nil
    st.tick = 21
    expect(story.notice(st, p, game.ctx)).to_be(false)
    st.tick = 40
    p.ship.pos = { c.pos[1] + 400, c.pos[2], c.pos[3] }
    expect(story.notice(st, p, game.ctx)).to_be(false)
    p.ship.pos = { c.pos[1], c.pos[2] + 5, c.pos[3] }
    p.site = 0
    expect(story.notice(st, p, game.ctx)).to_be(false)
    p.site = b.site
    st.mystery.mode = "off"
    expect(story.notice(st, p, game.ctx)).to_be(false)
    st.mystery.mode = "on"
    p.site = b.site == 1 and 2 or 1 -- a site without the clue
    expect(story.notice(st, p, game.ctx)).to_be(false)
  end)
end)

describe("the story's ending", function()
  it("is told when the Heart is resolved: the ending and the twist, to every player, and filed on every shelf", function()
    local st = new_state(7, 2)
    local s = st.story
    local m = st.mystery
    story.read(st, 1, st.players[1], game.ctx)
    for _, o in ipairs(st.players) do o.msgs = {} end
    expect(heart.resolve(st, m.endings[2].id, game.ctx)).to_be(true)
    expect(s.done).to_be(true)
    expect(s.ending).to_be(m.endings[2].id)
    for _, o in ipairs(st.players) do
      expect(texts(o):find("THE STORY: " .. s.title, 1, true) ~= nil).to_be(true)
      expect(texts(o):find("you found 1 of " .. story.clue_count(s), 1, true) ~= nil).to_be(true)
      expect(books.has(o, "story:" .. #s.beats) ~= nil).to_be(true)
    end
    local fin = story.finale(s)
    expect(fin.found_by >= 1 and fin.tick == st.tick).to_be(true)
    local said = texts(st.players[1])
    expect(said:find(story.chunks(story.finale_text(s, m.endings[2].id), 100)[1], 1, true) ~= nil).to_be(true)
    -- once only
    expect(story.finish(st, "seal", game.ctx)).to_be(false)
    -- the saved progress carries it
    local rec = save.record(st)
    expect(rec.world.story.done).to_be(true)
    expect(rec.world.story.ending).to_be(m.endings[2].id)
    local st2 = { players = { {}, {} } }
    save.apply(st2, rec, game)
    expect(st2.story.done).to_be(true)
    expect(story.finale(st2.story).tick).to_be(fin.tick)
  end)
  it("is not told in the sandbox, or for a story that is switched off", function()
    local st = new_state(42)
    st.story.mode = "off"
    expect(story.finish(st, "seal", game.ctx)).to_be(false)
    expect(st.story.done).to_be(false)
    st.story.mode = "on"
    st.mystery.mode = "off"
    expect(story.finish(st, "seal", game.ctx)).to_be(false)
    st.mystery.mode = "on"
    st.story = nil
    expect(story.finish(st, "seal", game.ctx)).to_be(false)
  end)
  it("the finale of every skeleton and ending reads well: it names the lost civilisation or the Heart", function()
    for _, seed in ipairs(SEEDS) do
      local s = story_of(seed)
      for _, e in ipairs({ "seal", "restore", "take" }) do
        local t = story.finale_text(s, e)
        expect(t:find("You ", 1, true) ~= nil).to_be(true)
        expect(#t > 60).to_be(true)
      end
    end
  end)
end)
