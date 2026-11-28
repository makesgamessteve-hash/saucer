-- SPDX-License-Identifier: MIT
-- Living in the Villa (milestone 2, concept §3.3): waking up, sliding doors,
-- and the things you can Use around the home (kitchen, bed, shower, engine
-- console, lab bench, trade terminal). The dome is safe: nothing here can be
-- reached by sentries or hazards. Pure functions over the player table.
local avatar = require("sim.avatar")
local configs = require("sim.config")
local panel = require("sim.panel")
local save = require("sim.save")
local clock = require("sim.clock")
local buffs = require("sim.buffs")
local M = {}

M.FED_TICKS = 5 * 60 * 60      -- a meal: faster Charge regeneration for five sim minutes
M.FED_FACTOR = 1.5
M.SLEEP_MINUTES = 480
M.USE = {}                     -- kind -> function(state, p, station, ctx); systems add their own
M.hooks = { sleep = {} }       -- functions(state, p, minutes) run when a player sleeps

local function say(ctx, state, p, text, sound)
  ctx.msg(state, p, text)
  if sound then ctx.fx(state, p, sound) end
end

-- the player wakes up sitting on their bed; the title panel offers to load
function M.wake(p)
  p.mode = "wake"
  panel.open(p, "title")
end

function M.get_up(state, p, ctx)
  local L = avatar.layout()
  p.mode = "walk"
  p.body = avatar.new(L, L.spawn.pos, L.spawn.yaw)
  panel.close(p)
  say(ctx, state, p, "Good morning. The helm is upstairs at the front of the dome.")
end

-- doors: open fraction per layout door, sliding toward open while a body is near.
-- fix-bedroom-door: a door decides with hysteresis (it opens inside `reach` but
-- only starts to close once every body is past `reach + door_close_margin`),
-- stays open for at least `door_min_open` seconds, and never turns solid under a
-- body that is standing in it, so a body swaying on the trigger edge (a thumb on
-- a touch stick, a walk that stops there) cannot make it flap.
function M.new_doors(L)
  local d = {}
  for i = 1, #(L.doors or {}) do d[i] = 0 end
  return d
end

function M.door_center(door)
  local b = door.box
  return (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
end

-- the bodies that open the dome's doors: the player walking it, plus guests
local function door_bodies(p, guests)
  local bodies = {}
  if p.mode == "walk" and not p.visiting then bodies[1] = p.body end
  for _, b in ipairs(guests or {}) do bodies[#bodies + 1] = b end
  return bodies
end

-- is any of the bodies on the door's deck within r of its centre?
local function within(L, door, bodies, r)
  local cx, cz = M.door_center(door)
  for _, b in ipairs(bodies) do
    if avatar.deck_of(L, b) == door.deck then
      local dx, dz = b.pos[1] - cx, b.pos[3] - cz
      if dx * dx + dz * dz <= r * r then return true end
    end
  end
  return false
end

-- add-wider-dark: guests walking your dome (bodies) open doors too
function M.doors_step(L, p, dt, guests)
  p.doors = p.doors or M.new_doors(L)
  p.door_goal = p.door_goal or {}
  p.door_hold = p.door_hold or {}
  local bodies = door_bodies(p, guests)
  local margin = L.door_close_margin or 0.5
  for i, door in ipairs(L.doors or {}) do
    local goal = p.door_goal[i] or 0
    if goal == 0 then
      if within(L, door, bodies, door.reach) then
        goal = 1
        p.door_hold[i] = L.door_min_open or 0.8
      end
    else
      local hold = math.max(0, (p.door_hold[i] or 0) - dt)
      p.door_hold[i] = hold
      -- somebody still close (inside the wider close radius) keeps it open
      if hold <= 0 and not within(L, door, bodies, door.reach + margin) then goal = 0 end
    end
    p.door_goal[i] = goal
    local cur = p.doors[i] or 0
    local step = L.door_speed * dt
    -- move toward the goal and stop on it (the old `else` also ran when cur == goal == 1,
    -- so a fully open door slid shut a notch and back open every tick)
    if cur < goal then cur = math.min(goal, cur + step) elseif cur > goal then cur = math.max(goal, cur - step) end
    p.doors[i] = cur
  end
end

-- smooth ease for drawing a door at open fraction f (0..1); the sim stays linear
function M.door_ease(f)
  f = math.max(0, math.min(1, f or 0))
  return f * f * (3 - 2 * f)
end

-- closed doors as extra solids for avatar.step. A door never turns solid on a
-- body that overlaps it (`bodies`, default the player's own): it stays passable
-- until that body is out, so its collision cannot trap or shove anyone.
function M.solids(L, p, bodies)
  local out = {}
  bodies = bodies or door_bodies(p)
  for i, door in ipairs(L.doors or {}) do
    if (p.doors and p.doors[i] or 0) < L.door_solid_below then
      local b, hit = door.box, false
      local pad = (L.body_radius or 0.3) + 0.05
      for _, body in ipairs(bodies) do
        if avatar.deck_of(L, body) == door.deck and body.pos[1] > b[1] - pad and body.pos[1] < b[3] + pad
            and body.pos[3] > b[2] - pad and body.pos[3] < b[4] + pad then hit = true end
      end
      if not hit then out[#out + 1] = { deck = door.deck, box = door.box } end
    end
  end
  -- add-home-among-stars: placed furniture is solid (for guests too)
  for _, b in ipairs(require("sim.decor").solids(p)) do out[#out + 1] = b end
  return out
end

function M.fed(state, p) return (p.fed_until or 0) > state.tick or buffs.active(state, p, "fed") end

-- Charge regeneration factor from home comforts (add-holodeck-home-life:
-- every active buff that touches charge_regen, see home/buffs.lua)
function M.regen_factor(state, p)
  local f = buffs.factor(state, p, "charge_regen")
  if (p.fed_until or 0) > state.tick and not buffs.active(state, p, "fed") then f = f * M.FED_FACTOR end
  -- add-home-among-stars: a comfortable dome
  return f * require("sim.decor").regen_factor(state, p)
end

-- add-holodeck-home-life: the kitchen cooks recipes from the pantry
M.USE.kitchen = function(_, p) panel.open(p, "kitchen") end
M.USE.books = function(_, p) panel.open(p, "books") end
M.USE.tv = function(_, p) panel.open(p, "tv") end
M.USE.holodeck = function(_, p) panel.open(p, "holodeck") end
-- add-run-story: the holotable in the living room stitches the clues of the run's story together
M.USE.holotable = function(_, p) panel.open(p, "story") end

M.USE.shower = function(state, p, _, ctx)
  p.showers = (p.showers or 0) + 1
  say(ctx, state, p, "A hot shower under the stars. Refreshing.", "bank")
end

M.USE.engine = function(state, p, _, ctx)
  local all = configs.all()
  local s = string.format("Fold engine: Charge %d/%d, +%.1f/s in open space%s", p.ship.charge // 1,
    require("sim.ship").max_charge(p.ship), all.charge_regen * M.regen_factor(state, p) * require("sim.ship").mult(p.ship, "charge_regen"), M.fed(state, p) and " (well fed)" or "")
  say(ctx, state, p, s)
end

M.USE.bed = function(_, p) panel.open(p, "bed") end

-- add-dock-land-eva: the hull hatch panel
M.USE.hatch = function(state, p, _, ctx) require("sim.hulldoor").use(state, p, ctx) end

-- milestone 3: the lab bench identifies and decodes; the terminal trades when docked
M.USE.lab = function(_, p) panel.open(p, "lab") end

M.USE.trade = function(state, p, _, ctx)
  if not require("sim.trade").docked_at(state, p) then
    say(ctx, state, p, "No trader in range. Dock at a trader station first.", "denied")
    return
  end
  panel.open(p, "trade")
end

-- sleep until morning: only outside derelicts; refills Charge and saves
function M.sleep(state, p, ctx)
  if p.visiting then
    say(ctx, state, p, "Only the host can sleep here.", "denied")
    return false
  end
  if p.site ~= 0 then
    say(ctx, state, p, "Too restless to sleep inside a derelict. Leave the site first.", "denied")
    return false
  end
  p.ship.charge = require("sim.ship").max_charge(p.ship)
  p.slept_tick = state.tick
  p.sleeps = (p.sleeps or 0) + 1
  clock.skip(state, M.SLEEP_MINUTES)
  for _, h in ipairs(M.hooks.sleep) do h(state, p, M.SLEEP_MINUTES) end
  panel.close(p)
  local ok = save.write(state)
  say(ctx, state, p, ok and "You sleep through the night. Game saved." or "You sleep, but the game could not be saved.",
    ok and "bank" or "denied")
  return ok
end

-- load the last save (record 0 only: it reloads the whole universe)
function M.load(state, p, ctx, game)
  if p.record_index ~= 0 then
    say(ctx, state, p, "Only player 1 can load the universe", "denied")
    return false
  end
  local rec, why = save.read()
  if not rec then
    say(ctx, state, p, why == "none" and "No saved game yet. Sleep in your bed to save."
      or why == "newer" and "That save was made by a newer version of the game." or "The save could not be read.", "denied")
    return false
  end
  if not save.same_mods(rec.mods, save.mods()) and not (p.panel and p.panel.confirm) then
    p.panel.confirm = true
    say(ctx, state, p, "Saved with a different mod set: generation may differ. Pick Load again to continue.", "denied")
    return false
  end
  save.apply(state, rec, game)
  local np = state.players[1]
  ctx.msg(state, np, string.format("Loaded the save from tick %d.", state.tick))
  ctx.fx(state, np, "grow")
  return true
end

-- use(state, p, ctx) on foot: a station in reach, else nil (caller handles the helm)
function M.use_station(state, p, ctx)
  local layout = require("sim.layout")
  local homeedit = require("sim.homeedit")
  local host = layout.house(state, p)
  local L = layout.of(host)
  local body = layout.body(p)
  local st = avatar.station(L, body)
  if not st then return nil end
  if p.visiting and not homeedit.guest_may(st.kind) then
    say(ctx, state, p, "Only the host can use that.", "denied")
    return st
  end
  local fn = M.USE[st.kind]
  if fn then fn(state, p, st, ctx) end
  return st
end

function M.register_panels(game, ctx)
  panel.register("title", {
    title = "SAUCER",
    rows = function(st)
      local rows = {
        { text = "Get up", act = function(state, p) M.get_up(state, p, ctx) end },
        { text = "Load saved game", act = function(state, p) M.load(state, p, ctx, game) end },
      }
      -- add-home-among-stars: Hardcore is chosen before anyone gets up
      local hc = require("sim.hardcore")
      if st and hc.can_choose(st) then
        rows[#rows + 1] = { text = hc.on(st) and "Hardcore: ON (choose again for Standard)" or "Hardcore: off",
          act = function(state, p) hc.toggle(state, p, ctx) end }
      end
      rows[#rows + 1] = { text = "Mod browser", act = function(_, p) panel.open(p, "mods") end }
      rows[#rows + 1] = { text = "Comfort settings", act = function(_, p) require("sim.comfort").open(p) end }
      return rows
    end,
  })
  panel.register("lab", {
    title = "LAB BENCH",
    rows = function(state, p) return require("sim.lab").rows(state, p, ctx) end,
  })
  panel.register("trade", {
    title = "TRADE TERMINAL",
    rows = function(state, p) return require("sim.trade").rows(state, p, ctx) end,
  })
  panel.register("kitchen", {
    title = "KITCHEN",
    rows = function(state, p) return require("sim.kitchen").rows(state, p, ctx) end,
  })
  panel.register("books", {
    title = "BOOKSHELF",
    rows = function(state, p) return require("sim.books").rows(state, p, ctx) end,
  })
  panel.register("tv", {
    title = "TV",
    rows = function(state, p) return require("sim.tv").rows(state, p, ctx) end,
  })
  panel.register("holodeck", {
    title = "HOLODECK",
    rows = function(state, p) return require("sim.holo").rows(state, p, ctx) end,
  })
  panel.register("bed", {
    title = "BED",
    rows = function(state, p)
      local rows = {}
      -- add-home-layout: sleep-and-save stays host-only
      if not (p and p.visiting) then
        rows[#rows + 1] = { text = "Sleep until morning (save)", act = function(st, pl) M.sleep(st, pl, ctx) end }
        if not require("sim.hardcore").on(state) then
          rows[#rows + 1] = { text = "Load saved game", act = function(st, pl) M.load(st, pl, ctx, game) end }
        end
      else
        rows[#rows + 1] = { text = "This is the host's bunk.", enabled = false }
      end
      rows[#rows + 1] = { text = "Mod browser", act = function(_, pl) panel.open(pl, "mods") end }
      rows[#rows + 1] = { text = "Comfort settings", act = function(_, pl) require("sim.comfort").open(pl) end }
      rows[#rows + 1] = { text = "Close", act = function(_, pl) panel.close(pl) end }
      return rows
    end,
  })
  require("sim.modbrowser").register(ctx)
  require("sim.comfort").register(ctx)
end

return M
