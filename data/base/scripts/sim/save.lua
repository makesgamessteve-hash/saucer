-- SPDX-License-Identifier: MIT
-- Saves (concept §13.4, spec save-system): the universe seed, the mod set with
-- versions, world diffs and one record per player (keyed by join order,
-- record 0 = the universe owner). Generated content (sector, derelicts,
-- items still in their slots) is never stored: loading regenerates it from
-- the seed and applies the diffs. Files go through saucer.save, which writes
-- a temp file and renames it atomically.
local mystery = require("sim.mystery")
local M = {}

M.SLOT = "slot1"
M.FORMAT = 2 -- 2: true 3D layouts; format-1 positions point into the old flat world
-- per-player fields that are transient UI and never saved
M.SKIP = { msgs = true, fx = true, panel = true, tractor = true, ghost = true, ghost_size = true, ghost_pos = true,
           help = true, latched_by = true, jam_flash = true, scan_until = true, docked = true,
           beam_console = true, hatch = true, holo_run = true, tv = true, reading = true, cooking = true }
-- world diffs copied as-is when present (filled by later systems)
M.WORLD_KEYS = { "traders", "nests", "caches", "vault", "clock" }

local function copy(v)
  if type(v) ~= "table" then return v end
  local r = {}
  for k, x in pairs(v) do r[k] = copy(x) end
  return r
end
M.copy = copy

function M.mods()
  local out = {}
  for _, m in ipairs(saucer.mods.list()) do
    if m.ok then out[#out + 1] = { id = m.id, version = m.version } end
  end
  return out
end

-- same mod ids and versions in the same order?
function M.same_mods(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    if a[i].id ~= b[i].id or a[i].version ~= b[i].version then return false end
  end
  return true
end

function M.record(state)
  local rec = { format = M.FORMAT, version = state.version, seed = state.seed, mods = M.mods(),
                world = { tick = state.tick, mystery = mystery.progress(state.mystery) }, players = {} }
  for _, k in ipairs(M.WORLD_KEYS) do
    if state[k] ~= nil then rec.world[k] = copy(state[k]) end
  end
  for i, p in ipairs(state.players) do
    local r = {}
    for k, v in pairs(p) do
      if not M.SKIP[k] then r[k] = copy(v) end
    end
    rec.players[i] = r
  end
  return rec
end

function M.write(state)
  return saucer.save.write(M.SLOT, M.record(state))
end

-- -> record or nil, reason ("none" | "corrupt" | "format")
function M.read()
  local rec, err = saucer.save.read(M.SLOT)
  if rec == nil and err == nil then return nil, "none" end
  if type(rec) ~= "table" then return nil, "corrupt" end
  if rec.format ~= M.FORMAT or type(rec.players) ~= "table" or type(rec.world) ~= "table" then return nil, "format" end
  return rec
end

-- apply(state, rec, game): rebuild the universe from rec.seed for the current
-- number of local players and lay the saved diffs over it. Records beyond the
-- saved ones start fresh (a single-player save loaded with two players).
function M.apply(state, rec, game)
  local n = #state.players
  if n < 1 then n = 1 end
  for k in pairs(state) do state[k] = nil end
  game.init(state, { seed = rec.seed, players = n })
  state.tick = rec.world.tick or 0
  mystery.restore(state.mystery, rec.world.mystery)
  for _, k in ipairs(M.WORLD_KEYS) do
    if rec.world[k] ~= nil then state[k] = copy(rec.world[k]) end
  end
  for i = 1, n do
    local r = rec.players[i]
    if r then
      local fresh = state.players[i]
      local p = copy(r)
      for k in pairs(M.SKIP) do p[k] = fresh[k] end
      p.msgs, p.fx, p.panel, p.tractor, p.ghost = {}, {}, false, false, 0
      state.players[i] = p
    end
  end
  game.rebuild(state)
  return true
end

return M
