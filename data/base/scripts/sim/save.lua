-- SPDX-License-Identifier: MIT
-- Saves (concept §13.4, spec save-system): the universe seed, the mod set with
-- versions, world diffs and one record per player (keyed by join order,
-- record 0 = the universe owner). Generated content (sector, derelicts,
-- items still in their slots) is never stored: loading regenerates it from
-- the seed and applies the diffs. Files go through saucer.save, which writes
-- a temp file and renames it atomically.
--
-- Format 3 (add-remaining-saves) stores the world and each player record as a
-- DIFF against what the seed alone regenerates (sim.diff): an untouched
-- universe is a few lines. Format 2 saves (full world tables and full player
-- tables, state version 10) still load: M.expand upgrades them in memory.
local mystery = require("sim.mystery")
local diff = require("sim.diff")
local trade = require("sim.trade")
local clock = require("sim.clock")
local M = {}

M.SLOT = "slot1"
M.FORMAT = 3 -- 3: seed plus diffs; 2: full tables (true 3D layouts); format-1 positions point into the old flat world
M.OLDEST = 2 -- the oldest format that still loads
-- per-player fields that are transient UI and never saved
M.SKIP = { msgs = true, fx = true, panel = true, tractor = true, ghost = true, ghost_size = true, ghost_pos = true,
           help = true, latched_by = true, jam_flash = true, scan_until = true, docked = true,
           beam_console = true, hatch = true, holo_run = true, tv = true, reading = true, cooking = true,
           lifeline = true, spike = true, visiting = true, vbody = true, shake = true, clamped_by = true,
           cut = true, beam_queue = true }
-- world state saved as diffs (filled by later systems)
M.WORLD_KEYS = { "traders", "nests", "caches", "vault", "clock", "locks", "grids",
                 -- add-wider-dark: the sector you are in, the ones you left, overrides, decoys, gifts
                 "sector_id", "visited", "overrides", "decoys", "gifts",
                 -- add-on-foot-excursions / twin vaults / Hardcore: per-site diffs and the difficulty
                 "lockdowns", "twins", "hardcore" }

local copy = diff.copy
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

-- what the seed alone gives the world of sector `sector` (a pure function of
-- the sector, so the same on the saving and the loading side)
local function baseline_world(seed, sector, sid)
  -- every trader's three posted requests are a function of the seed too
  local traders = trade.new_traders(sector)
  require("sim.requests").ensure({ seed = seed, sector_id = sid, traders = traders, players = {} })
  return { traders = traders, nests = {}, caches = {}, locks = {}, grids = {},
           decoys = {}, gifts = {}, visited = {}, overrides = {}, clock = clock.new(), sector_id = 1,
           vault = sid == 1 and { pos = copy(sector.vault.pos), taken = false } or false }
end

local function world_of(state)
  local w = {}
  for _, k in ipairs(M.WORLD_KEYS) do w[k] = state[k] end
  return w
end

-- a fresh player record without the transient fields
local function baseline_player(i)
  local p = require("sim.game").new_player(i, { 0, 0, 0 }, 0)
  for k in pairs(M.SKIP) do p[k] = nil end
  return p
end

local function persistent(p)
  local r = {}
  for k, v in pairs(p) do
    if not M.SKIP[k] then r[k] = v end
  end
  return r
end

function M.record(state)
  local rec = { format = M.FORMAT, version = state.version, seed = state.seed, mods = M.mods(),
                world = { tick = state.tick, mystery = mystery.progress(state.mystery),
                          diff = diff.diff(baseline_world(state.seed, state.sector, state.sector_id or 1), world_of(state)) or {} },
                players = {} }
  for i, p in ipairs(state.players) do
    rec.players[i] = { record_index = p.record_index or (i - 1),
                       diff = diff.diff(baseline_player(i), persistent(p)) or {} }
  end
  return rec
end

function M.write(state)
  return saucer.save.write(M.SLOT, M.record(state))
end

-- -> record or nil, reason ("none" | "corrupt" | "format" | "newer")
function M.read()
  local rec, err = saucer.save.read(M.SLOT)
  if rec == nil and err == nil then return nil, "none" end
  if type(rec) ~= "table" then return nil, "corrupt" end
  if type(rec.format) ~= "number" or rec.format < M.OLDEST or rec.format > M.FORMAT or type(rec.players) ~= "table"
      or type(rec.world) ~= "table" then
    return nil, "format"
  end
  if type(rec.version) == "number" and rec.version > require("sim.game").VERSION then return nil, "newer" end
  return rec
end

-- the sector id a save was made in
function M.sector_id(rec)
  if rec.format < 3 then return rec.world.sector_id or 1 end
  local d = rec.world.diff.d
  return d and d.sector_id and d.sector_id.v or 1
end

-- The full saved world (a table of WORLD_KEYS) of a save, whatever its
-- format. sector: the regenerated sector M.sector_id(rec), the baseline of
-- the diffs of format 3.
function M.world(rec, sector)
  if rec.format < 3 then -- migration: format 2 holds full tables already
    local w = {}
    for _, k in ipairs(M.WORLD_KEYS) do
      if rec.world[k] ~= nil then w[k] = copy(rec.world[k]) end
    end
    return w
  end
  return diff.patch(baseline_world(rec.seed, sector, M.sector_id(rec)), rec.world.diff)
end

-- The full player records (join order) of a save, whatever its format.
function M.players(rec)
  local ps = {}
  for i, r in ipairs(rec.players) do
    ps[i] = rec.format < 3 and copy(r) or diff.patch(baseline_player(i), r.diff)
  end
  return ps
end

-- the full player record number i (1-based, join order) of a save
function M.player(rec, i) return M.players(rec)[i] end

-- one line per record for the title card and logs
function M.summary(rec)
  return string.format("seed %s, tick %d, %d player%s", tostring(rec.seed), rec.world.tick or 0, #rec.players,
    #rec.players == 1 and "" or "s")
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
  -- the sector the diffs are relative to: home as generated by init, else the saved one
  local sector, sid = state.sector, M.sector_id(rec)
  if sid ~= 1 then
    local g = require("sim.galaxy").generate(rec.seed)
    sector = require("sim.sector").generate(rec.seed, sid, g.sectors[sid])
  end
  local world, players = M.world(rec, sector), M.players(rec)
  for _, k in ipairs(M.WORLD_KEYS) do
    if rec.format >= 3 or world[k] ~= nil then state[k] = world[k] end
  end
  -- add-wider-dark: the save may be in a far sector (and may hold more players)
  if #players > n then
    for i = n + 1, math.min(#players, 4) do state.players[i] = game.new_player(i, { 0, 0, 0 }, 0) end
    n = math.min(#players, 4)
  end
  for i = 1, n do
    local r = players[i]
    if r then
      local fresh = state.players[i]
      local p = r
      for k in pairs(M.SKIP) do p[k] = fresh[k] end
      p.msgs, p.fx, p.panel, p.tractor, p.ghost = {}, {}, false, false, 0
      state.players[i] = p
    end
  end
  if (state.sector_id or 1) ~= 1 then
    game.load_sector(state, state.sector_id)
  else
    game.rebuild(state)
    require("sim.requests").ensure(state)
  end
  return true
end

return M
