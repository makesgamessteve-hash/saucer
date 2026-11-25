-- SPDX-License-Identifier: MIT
-- add-relic-stations: relic play (design civs-and-relics §5.4-§6, first slice §9). The relic's layout comes from
-- sim/relicgen.lua; this module is what the saucer does in it:
--  * fold bays with dormant civ power cradles: regrowing from the Seat to the Villa in a cradle bay costs no
--    Charge, and a Villa-sized saucer resting in one regenerates 1 Charge a second (half the open-space rate)
--  * the Seat-lock on the reliquary door: nose the Seat up to its socket and hold Use; the shutter opens for good
--  * the XL idol in the Core: a class-4 find only the Villa's beam lifts; the reliquary's finds pay double
--  * the debug entry (--relic-slice): the Vyrr relic is added to the first sector and the party starts at its maw
-- No sentries in the slice. Nothing here runs unless a relic site exists, so other games keep their hashes.
local data = require("lib.data")
local configs = require("sim.config")
local shipm = require("sim.ship")
local M = {}

M.KIT = "relic"
M.LOCK_REACH = 3.5      -- m from the socket the Seat's nose may be
M.LOCK_TIME = 1.5       -- s of holding Use to turn a Seat-lock
M.CRADLE_REGEN = 0.5    -- x the open-space Charge rate (2/s): 1 Charge a second
M.WARREN_VALUE = 2.0    -- reliquary finds pay this much more than a hall find of the same roll
M.SLICE_OFFSET = { 0, -4000, 0 } -- the slice's relic sits far below the sector's plane, clear of every site

function M.civ() return require("sim.civs").vyrr() end
function M.materials() return data.load("civs/materials.lua") end
function M.is_relic(ruin) return ruin ~= nil and ruin.relic ~= nil end

local function game() return require("sim.game") end

-- the relic site's index in this sector (or nil)
function M.site_index(state)
  for i, s in ipairs(state.sector.sites) do
    if s.kit == M.KIT then return i end
  end
  return nil
end

-- the fold bay whose box holds pos (a little above the 20 m clearance counts: the Villa hovers in it), or nil
function M.bay_at(ruin, pos)
  if not M.is_relic(ruin) then return nil end
  for _, b in ipairs(ruin.relic.bays) do
    if pos[1] >= b.lo[1] and pos[1] <= b.hi[1] and pos[3] >= b.lo[3] and pos[3] <= b.hi[3] and pos[2] >= b.lo[2] - 1
        and pos[2] <= b.hi[2] + 10 then
      return b
    end
  end
  return nil
end

-- the cradle bay this player's saucer is in (any size), with its site, or nil
function M.cradle_of(state, p)
  local site = p.site or 0
  if site == 0 then return nil end
  local r = game().ruin(site)
  local b = r and M.bay_at(r, p.ship.pos)
  return b, site
end

-- growing out of the Seat inside a cradle bay is free
function M.free_regrow(state, p, to)
  return to < p.ship.size and M.cradle_of(state, p) ~= nil
end

-- regeneration factor of a Villa resting in a cradle bay (nil elsewhere)
function M.cradle_regen(state, p)
  local ship = p.ship
  if ship.size ~= 1 or ship.morph or p.berth then return nil end
  if not M.cradle_of(state, p) then return nil end
  return M.CRADLE_REGEN
end

local function key(site, id) return site .. ":" .. id end
function M.lock_open(state, site, id) return state.relic_locks ~= nil and state.relic_locks[key(site, id)] == true end

-- the closed Seat-lock whose socket the Seat's nose is at -> lock, site (nil when none)
function M.socket_near(state, p)
  local site = p.site or 0
  if site == 0 or configs.get(p.ship.size).interior then return nil end
  local r = game().ruin(site)
  if not M.is_relic(r) then return nil end
  local eye = shipm.eye_world(p.ship.pos, p.ship.yaw, p.ship.size)
  for _, l in ipairs(r.relic.locks) do
    if not M.lock_open(state, site, l.id) then
      local d = 0
      for k = 1, 3 do d = d + (l.socket[k] - eye[k]) ^ 2 end
      if d <= M.LOCK_REACH * M.LOCK_REACH then return l, site end
    end
  end
  return nil
end

-- every tick at the helm: holding Use at a socket turns it; the lock opens after LOCK_TIME
function M.lock_step(state, p, cmd, dt, ctx)
  local l, site = M.socket_near(state, p)
  if not l or not cmd:held("use") then
    if p.relic_turn then p.relic_turn = nil end
    return false
  end
  p.relic_turn = (p.relic_turn or 0) + dt
  if p.relic_turn + 1e-9 < M.LOCK_TIME then return false end
  p.relic_turn = nil
  state.relic_locks = state.relic_locks or {}
  state.relic_locks[key(site, l.id)] = true
  game().open_relic_lock(site, l.id)
  if ctx then
    ctx.msg(state, p, "The Seat-lock turns: the reliquary opens")
    ctx.fx(state, p, "door")
  end
  return true
end

-- the fixed XL idol (class 4): chrome grown through an amethyst core
function M.idol_item(s, iseed)
  local kit = require("sim.ruin").kit_of(M.KIT)
  local rng = saucer.rng.new(iseed)
  return { type = "relic_idol", name = "Vyrr Chrome Idol", size = 4, rarity = "relic", affixes = {}, quirk = false,
           category = "curio", value = kit.loot.idol_value + rng:int(0, 200), xl = true }
end

-- a reliquary (warren) find pays more than a hall find of the same roll
function M.warren_value(v) return math.floor(v * M.WARREN_VALUE) end

-- the ghost Villa a Seat would grow into here (the HUD shows it green or red in a Villa-class space): -> pos, fits
-- (nil when the Seat is not in a relic's Villa space)
function M.ghost(state, p)
  local site = p.site or 0
  if site == 0 or p.ship.size ~= 2 then return nil end
  local r = game().ruin(site)
  if not M.is_relic(r) then return nil end
  local room = require("sim.ruin").room_at(r, r.origin, p.ship.pos)
  if not room or room.class < 4 then return nil end
  local ship = p.ship
  local eye = shipm.eye_world(ship.pos, ship.yaw, ship.size)
  local c = shipm.center_for_eye(eye, ship.yaw, 1)
  local rr, hh = shipm.dims_of(1)
  return c, not game().blocked(state, p, c, rr, hh, configs.all().grow_margin)
end

-- add-relic-stations (plan phase 8): what a relic in normal play remembers, in the state (state v20):
--  * state.relic_rooms["sector:site:room"] = true for every room a saucer has been in (the radar's map of it)
--  * state.relics_found["sector:site"] = { found = tick, heart = tick or nil }: the approach scan picked it up (at
--    SCAN_RANGE from its box: one message with whose relic it is and its size), and the heart hall was reached
-- Checked every NOTE_EVERY ticks per player; nothing runs in a sector without a relic.
M.SCAN_RANGE = 2500
M.NOTE_EVERY = 10

local function skey(state, site) return (state.sector_id or 1) .. ":" .. site end
M.skey = skey

function M.room_seen(state, site, id)
  return state.relic_rooms ~= nil and state.relic_rooms[skey(state, site) .. ":" .. id] == true
end

-- the rooms of relic site `site` (this sector) a saucer has been in, sorted
function M.rooms_seen(state, site)
  local out, pre = {}, skey(state, site) .. ":"
  for k in pairs(state.relic_rooms or {}) do
    if k:sub(1, #pre) == pre then out[#out + 1] = tonumber(k:sub(#pre + 1)) end
  end
  table.sort(out)
  return out
end

function M.found(state, site) return state.relics_found ~= nil and state.relics_found[skey(state, site)] or nil end

-- the scanner's line about a relic: whose it is, how it is built and how big
function M.signature(state, site)
  local g = game()
  local r = g.ruin(site)
  local civ = g.civ_of(state.sector.sites[site])
  local name = civ and (civ.exonym or civ.name) or "unknown builders"
  local R = r and r.relic
  local halls = R and #R.halls or 0
  return string.format("Relic signature: %s, a %s relic - %d halls round a heart engine", name, R and R.archetype or "warren", halls)
end

function M.play_step(state, p, ctx)
  if (state.tick or 0) % M.NOTE_EVERY ~= 0 then return end
  local g = game()
  for i, s in ipairs(state.sector.sites) do
    if s.kit == M.KIT and not s.relic_civ then
      local k = skey(state, i)
      state.relics_found = state.relics_found or {}
      local f = state.relics_found[k]
      if not f and g.site_distance(i, p.ship.pos) <= M.SCAN_RANGE then
        f = { found = state.tick }
        state.relics_found[k] = f
        if ctx then
          ctx.msg(state, p, M.signature(state, i))
          ctx.fx(state, p, "scan")
        end
      end
      if (p.site or 0) == i then
        local r = g.ruin(i)
        local room = r and require("sim.ruin").room_at(r, r.origin, p.ship.pos)
        if room then
          state.relic_rooms = state.relic_rooms or {}
          state.relic_rooms[k .. ":" .. room.id] = true
          if f and not f.heart and room.id == r.relic.core then
            f.heart = state.tick
            if ctx then ctx.msg(state, p, "The heart hall: the engine still turns, for no one") end
          end
        end
      end
    end
  end
end

-- add the Vyrr relic to this sector (the debug entry, --relic-slice) and put the party at its maw, facing in
function M.spawn_slice(state)
  local g = game()
  local i = M.site_index(state)
  if not i then
    local sites = state.sector.sites
    i = #sites + 1
    sites[i] = { id = i, kit = M.KIT, civ = 1, relic_civ = M.civ().id, seed = saucer.seed_child(state.seed, "relic", 1),
                 pos = { M.SLICE_OFFSET[1], M.SLICE_OFFSET[2], M.SLICE_OFFSET[3] }, tutorial = false, danger = 1 }
    g.rebuild(state)
    state.sentries[i] = require("sim.sentry").new_state(g.sentries(i), state)
  end
  M.to_maw(state, i)
  return i
end

-- every player's saucer outside the maw, 90 m out, side by side, facing the way in
function M.to_maw(state, i)
  local g = game()
  local r = g.ruin(i)
  local door = require("sim.ruin").entrance(r, state.sector.sites[i].pos)
  local n = #state.players
  for k, p in ipairs(state.players) do
    local ship = p.ship
    ship.pos = { door[1] + (k - 1 - (n - 1) / 2) * 32, door[2], door[3] - 90 }
    ship.vel = { 0, 0, 0 }
    ship.yaw = 0
    ship.pitch = 0
  end
end

return M
