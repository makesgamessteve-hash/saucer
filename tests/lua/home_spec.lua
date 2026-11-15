-- SPDX-License-Identifier: MIT
-- Milestone 2: the live-in Villa (wake-up, doors, stations, panels, saving)
-- and the fold packing, driven through the sim with synthetic commands.
local game = require("sim.game")
local avatar = require("sim.avatar")
local home = require("sim.home")
local panel = require("sim.panel")
local save = require("sim.save")
local fold = require("sim.fold")
local shipm = require("sim.ship")
local ap = require("sim.autopilot")
local render = require("view.render")
local L = avatar.layout()

local function cmd(t) return saucer.input.command(t or {}) end
local function new_state(n)
  local st = {}
  game.init(st, { seed = 42, players = n or 1 })
  return st
end
local function run(st, c, n)
  for _ = 1, n or 1 do game.step(st, { c or cmd(), c or cmd(), c or cmd(), c or cmd() }, 1 / 60) end
end
local function texts(p)
  local t = {}
  for _, m in ipairs(p.msgs) do t[#t + 1] = m.text end
  return table.concat(t, "|")
end
local function stand(p, node)
  p.mode, p.panel = "walk", false
  p.body = avatar.new(L, L.nav.nodes[node], 0)
end

describe("nav graph", function()
  it("finds paths between stations and the nearest node on the same deck", function()
    local path = avatar.nav_path(L, "bed", "helm")
    expect(#path).to_be_greater(5)
    expect(path[1]).to_equal(L.nav.nodes.bed)
    expect(path[#path]).to_equal(L.nav.nodes.helm)
    expect(avatar.nav_path(L, "bed", "nowhere")).to_be(nil)
    local L2 = { nav = { nodes = { a = { 0, 0, 0 }, b = { 1, 0, 0 } }, links = {} } }
    expect(avatar.nav_path(L2, "a", "b")).to_be(nil)
    expect(avatar.nav_nearest(L, avatar.new(L, { 2.5, -3.0, 4.1 }, 0))).to_be("bed")
    expect(avatar.station_by_id(L, "kitchen").kind).to_be("kitchen")
    expect(avatar.station_by_id(L, "nope")).to_be(nil)
    expect(avatar.sorted_keys({ b = 1, a = 2 })).to_equal({ "a", "b" })
  end)
  it("every station is reachable from the bed", function()
    for _, st in ipairs(L.stations) do
      expect(avatar.nav_path(L, "bed", st.id)).to_be_truthy()
    end
  end)
end)

describe("wake-up and panels", function()
  it("navigates the title card with the stick and picks rows with Use", function()
    local st = new_state()
    local p = st.players[1]
    expect(panel.title(st, p)).to_be("SAUCER")
    run(st, cmd({ axes = { move_z = -1 } }))
    expect(p.panel.sel).to_be(2)
    run(st, cmd({ axes = { move_z = -1 } })) -- held: no repeat
    expect(p.panel.sel).to_be(2)
    run(st, cmd())
    run(st, cmd({ axes = { move_z = -1 } })) -- wraps
    expect(p.panel.sel).to_be(1)
    run(st, cmd({ axes = { move_z = 1 } }))
    expect(p.panel.sel).to_be(2)
    expect(panel.find(st, p, "Get")).to_be(1)
    expect(panel.find(st, p, "Zzz")).to_be(nil)
    run(st, cmd())
    run(st, cmd({ axes = { move_z = 1 } }))
    run(st, cmd({ pressed = { "use" } }))
    expect(p.mode).to_be("walk")
    expect(texts(p)).to_contain("Good morning")
  end)
  it("handles disabled rows, empty and unknown panels", function()
    local st = new_state()
    local p = st.players[1]
    panel.register("test", { rows = function() return { { text = "Off", enabled = false, act = function() end } } end })
    panel.open(p, "test")
    expect(panel.title(st, p)).to_be("test")
    expect(select(2, panel.step(st, p, cmd({ pressed = { "use" } })))).to_be("disabled")
    panel.register("dyn", { title = function() return "DYN" end, rows = function() return {} end })
    panel.open(p, "dyn")
    expect(panel.title(st, p)).to_be("DYN")
    expect(panel.step(st, p, cmd())).to_be(false)
    expect(p.panel).to_be(false)
    expect(panel.step(st, p, cmd())).to_be(false)
    panel.open(p, "missing")
    expect(#panel.rows(st, p)).to_be(0)
    expect(panel.title(st, p)).to_be("")
    p.panel = false
    expect(panel.title(st, p)).to_be("")
  end)
end)

describe("home", function()
  it("slides doors open near them and treats closed ones as solid", function()
    local st = new_state()
    local p = st.players[1]
    stand(p, "bed_door_n")
    expect(#home.solids(L, p)).to_be(#L.doors)
    run(st, cmd(), 30)
    expect(p.doors[1]).to_be(1)
    expect(p.doors[2]).to_be(0)
    expect(#home.solids(L, p)).to_be(#L.doors - 1)
    stand(p, "kitchen")
    run(st, cmd(), 30)
    expect(p.doors[1]).to_be(0)
    -- a closed door blocks a body walking through it
    local q = { doors = home.new_doors(L) }
    local cx, cz = home.door_center(L.doors[1])
    expect(avatar.blocked(L, 2, cx, cz, home.solids(L, q))).to_be(true)
    local L2 = { doors = nil }
    expect(#home.new_doors(L2)).to_be(0)
  end)
  it("lets you use the kitchen, shower, engine, lab and trade terminal", function()
    local st = new_state()
    local p = st.players[1]
    local all = {}
    for _, id in ipairs({ "kitchen", "shower", "engine", "lab", "trade" }) do
      stand(p, id)
      run(st, cmd({ pressed = { "use" } }))
      all[#all + 1] = texts(p)
    end
    local t = table.concat(all, "|")
    expect(t).to_contain("quick meal")
    expect(t).to_contain("hot shower")
    expect(t).to_contain("(well fed)")
    expect(p.panel ~= nil or t:find("No trader", 1, true) ~= nil).to_be(true)
    expect(t).to_contain("No trader in range")
    expect(p.showers).to_be(1)
    expect(home.regen_factor(st, p)).to_be(home.FED_FACTOR)
    st.tick = p.fed_until
    expect(home.regen_factor(st, p)).to_be(1)
  end)
  it("sleeps (refill and save) only outside derelicts", function()
    local st = new_state()
    local p = st.players[1]
    local ctx = game.ctx
    local slept = 0
    home.hooks.sleep[#home.hooks.sleep + 1] = function(_, _, minutes) slept = minutes end
    p.site = 1
    expect(home.sleep(st, p, ctx)).to_be(false)
    expect(texts(p)).to_contain("Too restless")
    p.site = 0
    p.ship.charge = 5
    local ok = home.sleep(st, p, ctx)
    expect(ok).to_be(true)
    expect(p.ship.charge).to_be(require("sim.config").all().max_charge)
    expect(slept).to_be(home.SLEEP_MINUTES)
    home.hooks.sleep[#home.hooks.sleep] = nil
    local real = save.write
    save.write = function() return false end
    home.sleep(st, p, ctx)
    save.write = real
    expect(texts(p)).to_contain("could not be saved")
  end)
  it("loads only for player 1, explains missing or bad saves, confirms a mod mismatch", function()
    local st = new_state(2)
    local ctx = game.ctx
    local p2 = st.players[2]
    expect(home.load(st, p2, ctx, game)).to_be(false)
    expect(texts(p2)).to_contain("Only player 1")
    local p = st.players[1]
    local real_read, real_mods = save.read, save.mods
    save.read = function() return nil, "none" end
    expect(home.load(st, p, ctx, game)).to_be(false)
    expect(texts(p)).to_contain("No saved game yet")
    save.read = function() return nil, "corrupt" end
    home.load(st, p, ctx, game)
    expect(texts(p)).to_contain("could not be read")
    local rec = save.record(st)
    rec.players[1].sleeps = 7
    save.read = function() return rec end
    save.mods = function() return { { id = "other", version = "9" } } end
    expect(home.load(st, p, ctx, game)).to_be(false)
    expect(texts(p)).to_contain("different mod set")
    expect(home.load(st, p, ctx, game)).to_be(true)
    save.read, save.mods = real_read, real_mods
    expect(st.players[1].sleeps).to_be(7)
    expect(#st.players).to_be(2)
    expect(texts(st.players[1])).to_contain("Loaded the save")
  end)
end)

describe("fold packing", function()
  it("keeps rooms out or packed when no reconfiguration crosses the Villa", function()
    local s = shipm.new({ 0, 0, 0 }, 0, 2)
    for _, a in pairs(fold.amounts(s, L)) do expect(a).to_be(1) end
    expect(fold.rooms_out(s)).to_be(false)
    shipm.request(s, 3, function() return false end)
    for _, a in pairs(fold.amounts(s, L)) do expect(a).to_be(1) end
    local v = shipm.new({ 0, 0, 0 }, 0, 1)
    expect(fold.rooms_out(v)).to_be(true)
    expect(fold.group_of(L, 1, 6, 0)).to_be("1:Kitchen")
  end)
  it("lets later milestones add radar targets", function()
    local st = new_state()
    render.extra_radar[1] = function() return { { pos = { 1, 2, 3 }, color = { 1, 0, 0, 1 } } } end
    local list = render.radar_targets(st, st.players[1])
    render.extra_radar[1] = nil
    expect(list[#list].pos).to_equal({ 1, 2, 3 })
  end)
end)

describe("autopilot helpers for the home", function()
  it("wakes, walks the nav graph and picks panel rows through an input API", function()
    local st = new_state()
    local p = st.players[1]
    local get = function() return st.players[1] end
    local pending = {}
    local fake = {
      state = function() return st end,
      press = function(_, a) pending.pressed = { a } end,
      axis = function(_, a, v) pending.axes = { [a] = v } end,
      wait = function(n)
        for _ = 1, n or 1 do
          run(st, cmd(pending))
          pending = { axes = pending.axes }
        end
      end,
    }
    fake.hold = function(_, axes) pending.axes = axes end
    expect(ap.wake(fake, 1, get)).to_be(true)
    expect(ap.wake(fake, 1, get)).to_be(true) -- already up
    expect(ap.walk_to(fake, 1, get, "nowhere")).to_be(false)
    p = get()
    p.body = avatar.new(L, L.nav.nodes.bed, 0)
    run(st, cmd({ pressed = { "use" } }))
    expect(ap.pick(fake, 1, get, "Close")).to_be(true)
    expect(ap.pick(fake, 1, get, "Close")).to_be(false) -- no panel
    panel.open(get(), "bed")
    expect(ap.pick(fake, 1, get, "Nope")).to_be(false)
  end)
end)
