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

-- doors: open fraction per layout door, sliding toward open while a body is near
function M.new_doors(L)
  local d = {}
  for i = 1, #(L.doors or {}) do d[i] = 0 end
  return d
end

function M.door_center(door)
  local b = door.box
  return (b[1] + b[3]) / 2, (b[2] + b[4]) / 2
end

-- add-wider-dark: guests walking your dome (bodies) open doors too
function M.doors_step(L, p, dt, guests)
  p.doors = p.doors or M.new_doors(L)
  local bodies = {}
  if p.mode == "walk" and not p.visiting then bodies[1] = p.body end
  for _, b in ipairs(guests or {}) do bodies[#bodies + 1] = b end
  for i, door in ipairs(L.doors or {}) do
    local want = 0
    for _, b in ipairs(bodies) do
      if avatar.deck_of(L, b) == door.deck then
        local cx, cz = M.door_center(door)
        local dx, dz = b.pos[1] - cx, b.pos[3] - cz
        if dx * dx + dz * dz <= door.reach * door.reach then want = 1 end
      end
    end
    local cur = p.doors[i] or 0
    local step = L.door_speed * dt
    if want > cur then cur = math.min(1, cur + step) else cur = math.max(0, cur - step) end
    p.doors[i] = cur
  end
end

-- closed doors as extra solids for avatar.step
function M.solids(L, p)
  local out = {}
  for i, door in ipairs(L.doors or {}) do
    if (p.doors and p.doors[i] or 0) < L.door_solid_below then out[#out + 1] = { deck = door.deck, box = door.box } end
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
  local L = avatar.layout()
  local st = avatar.station(L, p.body)
  if not st then return nil end
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
    rows = function(state)
      local rows = { { text = "Sleep until morning (save)", act = function(st, p) M.sleep(st, p, ctx) end } }
      -- add-home-among-stars: no loading from the bed in Hardcore
      if not require("sim.hardcore").on(state) then
        rows[#rows + 1] = { text = "Load saved game", act = function(st, p) M.load(st, p, ctx, game) end }
      end
      rows[#rows + 1] = { text = "Mod browser", act = function(_, p) panel.open(p, "mods") end }
      rows[#rows + 1] = { text = "Comfort settings", act = function(_, p) require("sim.comfort").open(p) end }
      rows[#rows + 1] = { text = "Close", act = function(_, p) panel.close(p) end }
      return rows
    end,
  })
  require("sim.modbrowser").register(ctx)
  require("sim.comfort").register(ctx)
end

return M
