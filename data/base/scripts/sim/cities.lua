-- SPDX-License-Identifier: MIT
-- Cities at run time (OpenSpec add-cities): the district power grid, the gates it holds shut, the
-- tractor targets that restore it, the gravity of the body under the saucer and the map rows the
-- panel and the HUD read. The city itself is a ruin-shaped table from sim/citygen.lua, so physics,
-- the beam, sentries, saves and the renderer treat it like any other site.
--
-- State is lazy plain data: a restored district is one entry in state.locks (the hand-lock table,
-- already saved, diffed, stashed and replayed), keyed "<site>:power<district>". Nothing is added to
-- the state of a game that never touches a city.
local vec = require("lib.vec")
local M = {}

M.REACH = 160      -- loot slots farther than this from the saucer are not rolled this tick
M.HOVER_COST = 5.0 -- extra Charge per second to hover under a body's pull, per g above 1
M.SINK = 2.2       -- m/s the hull settles at when the Charge is gone under a strong pull

function M.is_city(ruin) return ruin ~= nil and ruin.city ~= nil end

local function lockkey(site, d) return tostring(site) .. ":power" .. tostring(d) end
M.lockkey = lockkey

-- is district d of the city at `site` live?
function M.powered(state, site, ruin, d)
  local pd = ruin.city.districts[d]
  if not pd then return true end
  return pd.powered or (state.locks ~= nil and state.locks[lockkey(site, d)] ~= nil)
end

-- add-cities: does a sentry in room r start dark (its district's power out at the start)?
function M.dark(ruin, r)
  local pd = ruin.city and r.district and ruin.city.districts[r.district]
  return (pd and not pd.powered) or nil
end

function M.restore(state, site, d)
  state.locks = state.locks or {}
  state.locks[lockkey(site, d)] = state.tick
end

-- how brightly a district's lights burn as a whole (0 dark .. 1 full) at this tick: dark until its coupling is
-- restored, then a flicker for two thirds of a second and a quick ramp up. The beacons, spire lights and the
-- district's far glow follow this. Render only: a function of the tick.
M.RAMP = 100
function M.light(state, site, ruin, d)
  local pd = d and ruin.city.districts[d]
  if not pd or pd.powered then return 1 end
  local t0 = state.locks and state.locks[lockkey(site, d)]
  if not t0 then return 0 end
  local dt = state.tick - t0
  if dt >= M.RAMP then return 1 end
  if dt < 40 then return ((dt // 5 + d) % 3 == 0) and 0.8 or 0 end
  return (dt - 40) / (M.RAMP - 40)
end

-- add-cities-2 slice 5: the payoff. Once the beacon is up, a wave of light runs out from the coupling:
-- every window and sign inside the front is on, those outside are still dark.
M.WAVE_START = 40   -- ticks after the restore that the front leaves the coupling
M.WAVE_SPEED = 2.5  -- m per tick (150 m/s)
M.WAVE_EDGE = 30    -- m over which the front fades in
M.WAVE_REACH = 520  -- m: the front has passed every chunk of a district by then
M.WAVE_TICKS = M.WAVE_START + math.ceil(M.WAVE_REACH / M.WAVE_SPEED)
local couplings_of = setmetatable({}, { __mode = "k" })
local function coupling_pos(ruin, d)
  local by = couplings_of[ruin]
  if not by then
    by = {}
    for _, c in ipairs(ruin.city.couplings) do by[c.district] = c.pos end
    couplings_of[ruin] = by
  end
  return by[d]
end

-- how brightly the lights at `pos` (a chunk's centre) burn in district d
function M.light_at(state, site, ruin, d, pos)
  local pd = d and ruin.city.districts[d]
  if not pd or pd.powered then return 1 end
  local t0 = state.locks and state.locks[lockkey(site, d)]
  if not t0 then return 0 end
  local dt = state.tick - t0
  if dt >= M.WAVE_TICKS then return 1 end
  if dt < M.WAVE_START then return 0 end
  local c = coupling_pos(ruin, d)
  if not c then return M.light(state, site, ruin, d) end
  local dx, dy, dz = pos[1] - c[1], pos[2] - c[2], pos[3] - c[3]
  local dist = saucer.math.sqrt(dx * dx + dy * dy + dz * dz)
  local k = ((dt - M.WAVE_START) * M.WAVE_SPEED - dist) / M.WAVE_EDGE
  return k <= 0 and 0 or (k >= 1 and 1 or k)
end

-- districts restored in the last `window` ticks: -> { { id =, label =, age = ticks } } in district order
function M.fresh(state, site, ruin, window)
  local out = {}
  if not M.is_city(ruin) then return out end
  for _, pd in ipairs(ruin.city.districts) do
    local t0 = not pd.powered and state.locks and state.locks[lockkey(site, pd.id)]
    if t0 and state.tick >= t0 and state.tick - t0 < window then
      out[#out + 1] = { id = pd.id, label = pd.label, age = state.tick - t0 }
    end
  end
  return out
end

-- ------------------------------------------------------------------ weather and collapses
-- Everything here is a pure function of the tick and the city's seed: nothing is stored, so saves,
-- replays and co-op never see it. A storm front sweeps a planet city every STORM_PERIOD ticks and lasts
-- STORM_LEN of them; the sky-bridges tear loose at the peaks, one storm each, in a fixed order.
M.STORM_PERIOD = 7200
M.STORM_LEN = 2100
M.FALL_TICKS = 150     -- a torn bridge falls for this long (then it is gone)
M.WIND = 11            -- m/s of drift at the peak of a storm
M.BRIDGE_DAMAGE = 24   -- hull a falling bridge costs when it hits (once per bridge per saucer)

-- the tick of the first storm's start (never before 30 s in)
function M.phase(ruin) return 1800 + (ruin.seed or 0) % M.STORM_PERIOD end

-- the storm: -> intensity 0..1 and the number of the storm (0 before the first). Moons and rocks have none,
-- but the same clock times their tremors.
function M.storm(ruin, tick)
  local ph = M.phase(ruin)
  if tick < ph then return 0, 0 end
  local n = (tick - ph) // M.STORM_PERIOD
  local t = (tick - ph) % M.STORM_PERIOD
  if t >= M.STORM_LEN then return 0, n + 1 end
  local k = saucer.math.sin(saucer.math.pi * t / M.STORM_LEN)
  if not require("sim.ruin").kit_of(ruin.kit).city.storm then return 0, n + 1 end
  return k, n + 1
end

-- ticks until the next storm starts (nil when none ever comes)
function M.storm_in(ruin, tick)
  if not require("sim.ruin").kit_of(ruin.kit).city.storm then return nil end
  local ph = M.phase(ruin)
  if tick < ph then return ph - tick end
  local t = (tick - ph) % M.STORM_PERIOD
  if t < M.STORM_LEN then return 0 end
  return M.STORM_PERIOD - t
end

-- the drift of the wind at the peak of storm k: a heading that turns slowly, with gusts. -> dx, dz in m/s
function M.wind(ruin, tick)
  local k, n = M.storm(ruin, tick)
  if k <= 0.02 then return 0, 0, 0 end
  local a = n * 1.9 + 0.6 * saucer.math.sin(tick / 240)
  local gust = 0.65 + 0.35 * saucer.math.sin(tick / 23 + n)
  local s = M.WIND * k * gust
  return saucer.math.sin(a) * s, saucer.math.cos(a) * s, k
end

-- is this point inside a room's walls (the wind does not reach it)? Rooms of a city are few hundred boxes.
function M.sheltered(ruin, pos)
  local rm = require("sim.ruin")
  local k = rm.kit_of(ruin.kit)
  for _, r in ipairs(ruin.rooms) do
    local mn, mx = rm.room_box(r, k, ruin.origin)
    if pos[1] >= mn[1] and pos[1] <= mx[1] and pos[2] >= mn[2] and pos[2] <= mx[2] and pos[3] >= mn[3] and pos[3] <= mx[3] then return true end
  end
  return false
end

-- the tick a sky-bridge tears loose (nil when it never does): storm number `fall` at its peak
function M.fall_tick(ruin, s)
  if not s.fall then return nil end
  return M.phase(ruin) + (s.fall - 1) * M.STORM_PERIOD + M.STORM_LEN // 2
end

-- how far a bridge that tore loose at tick ft has dropped by now (m), nil if not falling right now
function M.fall_drop(ft, tick)
  local t = (tick - ft) / 60
  if t < 0 or t * 60 >= M.FALL_TICKS then return nil end
  return 0.5 * 9.8 * 1.6 * t * t
end

-- the box a falling bridge occupies right now -> mn, mx (or nil)
function M.fall_box(ruin, s, tick)
  local ft = M.fall_tick(ruin, s)
  local d = ft and M.fall_drop(ft, tick)
  if not d then return nil end
  return { s[1][1], s[1][2] - d, s[1][3] }, { s[2][1], s[2][2] - d, s[2][3] }
end

-- add-cities-2: a Watcher on the wing over the streets of every dark district, round its block at 18 m
-- above the roads. They are ordinary Watchers (cone, alert, stun bolts) whose position is a function of
-- the clock; they go home when their district's grid comes back. -> appended to `out`
M.PATROL_SPEED = 9
function M.patrols(out, site, ruin, band, civ)
  local city = ruin.city
  for _, pd in ipairs(city.districts) do
    if not pd.powered and pd.box then
      local b = pd.box
      local y = pd.pos[2] + 18
      local pts = { { b[1], y, b[2] }, { b[3], y, b[2] }, { b[3], y, b[4] }, { b[1], y, b[4] }, { b[1], y, b[2] } }
      local len = 0
      for k = 1, #pts - 1 do len = len + vec.dist(pts[k], pts[k + 1]) end
      out[#out + 1] = { id = #out + 1, kind = "watcher", site = site.id, room = 1, pos = vec.copy(pts[1]), yaw = 0, pitch = -0.4,
                        band = band, glyph = civ and civ.glyph or nil, district = pd.id, dark = true, roam = true,
                        route = pts, len = len, speed = M.PATROL_SPEED, phase = (pd.id * 0.2718) % 1 }
    end
  end
end

-- districts live / total
function M.grid(state, site, ruin)
  local on, n = 0, 0
  for _, pd in ipairs(ruin.city.districts) do
    n = n + 1
    if M.powered(state, site, ruin, pd.id) then on = on + 1 end
  end
  return on, n
end

-- the district whose centre is nearest this point (the city is a flat grid of districts)
function M.district_at(ruin, pos)
  local best, bd
  for _, pd in ipairs(ruin.city.districts) do
    local dx, dz = pos[1] - pd.pos[1], pos[3] - pd.pos[3]
    local d = dx * dx + dz * dz
    if not bd or d < bd then best, bd = pd, d end
  end
  return best
end

-- power couplings still to beam: one per dark district
function M.candidates(state, p, site, ruin)
  local out = {}
  if not M.is_city(ruin) then return out end
  for _, c in ipairs(ruin.city.couplings) do
    if not M.powered(state, site, ruin, c.district) then
      local pd = ruin.city.districts[c.district]
      out[#out + 1] = { key = "coupling:" .. site .. ":" .. c.district, kind = "coupling", pos = c.pos, district = c.district,
        item = { name = "Power coupling (" .. pd.label .. ")", type = "coupling", size = 1, value = 0, ident = true } }
    end
  end
  -- add-cities-2: the archive's records, one per archive district, read in place
  for _, c in ipairs(ruin.city.clues or {}) do
    local key = "clue:" .. site .. ":" .. c.district
    if not (p.looted or {})[key] and M.powered(state, site, ruin, c.district) then
      out[#out + 1] = { key = key, kind = "clue", pos = c.pos, district = c.district, room = c.room,
        item = { name = "Archive record", type = "clue", size = 1, value = 0, ident = true } }
    end
  end
  return out
end

-- add-cities-2: what an archive record says. A pure function of the mystery state: the next Echo's whereabouts
-- while the chain is open, else a line of the cause's lore.
function M.clue_text(state, site, ruin, district)
  local m = state.mystery
  local mys = require("sim.mystery")
  if m and mys.active(m) then
    for i, e in ipairs(m.echoes) do
      if e.found_by == 0 and mys.unlocked(m, i) then
        local sid = e.sector or 1
        if sid ~= state.sector_id then
          return string.format("Archive record: a ledger logs a resonance near site %d of sector %d", e.site, sid)
        end
        return string.format("Archive record: a ledger logs a resonance near site %d", e.site)
      end
    end
    if m.act >= 3 and not m.ending and m.heart_sector then
      return string.format("Archive record: a sealed index names sector %d, where the Heart beats", m.heart_sector)
    end
    local v = m.vars or {}
    return string.format("Archive record: the %s kept a ledger of the %s at %s", v.civ or "builders", v.object or "signal", v.place or "the dark")
  end
  return "Archive record: shelves of the builders' catalogues, long out of date"
end

-- where a body pulls: gravity in g (1 = the Earth-like pull the flight model is tuned for)
function M.gravity(ruin)
  if not M.is_city(ruin) then return 0 end
  local k = require("sim.ruin").kit_of(ruin.kit)
  return k.city.gravity or 0
end

-- the Charge a saucer spends this tick to hold its height under a pull above 1 g, and whether it sinks
-- (no Charge left). Below 1 g, and in the horizontal, flight is free: nothing can trap a hull.
function M.pull(ruin, charge, dt)
  local g = M.gravity(ruin)
  if g <= 1 then return 0, false end
  local cost = (g - 1) * M.HOVER_COST * dt
  if charge <= 0 then return 0, true end
  return math.min(cost, charge), false
end

-- is the saucer in the spaceport hangar (room 1 of a city)?
function M.in_hangar(ruin, pos)
  local r = ruin.rooms[1]
  local rm = require("sim.ruin")
  local mn, mx = rm.room_box(r, rm.kit_of(ruin.kit), ruin.origin)
  return pos[1] >= mn[1] and pos[1] <= mx[1] and pos[2] >= mn[2] and pos[2] <= mx[2] and pos[3] >= mn[3] and pos[3] <= mx[3]
end

-- the one-line summary of a body city for the map: "PLANET 16 districts, grid 3/16"
function M.summary(state, site, ruin)
  local on, n = M.grid(state, site, ruin)
  return string.format("%s CITY  grid %d/%d", string.upper(ruin.city.body), on, n), string.format("%d/%d", on, n)
end

-- the city map the holotable and the TV show: one row per district with its landmark and grid state
function M.rows(state, site, ruin)
  local out = {}
  for _, pd in ipairs(ruin.city.districts) do
    out[#out + 1] = { id = pd.id, label = pd.label, kind = pd.kind, pos = pd.pos, powered = M.powered(state, site, ruin, pd.id),
                      coupling = pd.coupling ~= nil }
  end
  return out
end

-- the beacon to follow: the nearest dark district's coupling, else the vault (the reactor's heart)
function M.beacon(state, site, ruin, from)
  local best, bd
  for _, c in ipairs(M.candidates(state, { index = 0 }, site, ruin)) do
    local d = vec.dist(from, c.pos)
    if c.kind == "coupling" and (not bd or d < bd) then best, bd = c, d end
  end
  if best then return { pos = best.pos, label = best.item.name, short = "COUPLING", dist = bd } end
  for _, r in ipairs(ruin.rooms) do
    if r.kind == "vault" then
      local k = require("sim.ruin").kit_of(ruin.kit)
      local mn, mx = require("sim.ruin").room_box(r, k, ruin.origin)
      local c = { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }
      return { pos = c, label = "Reactor vault", short = "VAULT", dist = vec.dist(from, c) }
    end
  end
  return nil
end

local COMPASS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
-- compass word for the horizontal direction from a to b (north is +z)
function M.compass(a, b)
  local ang = saucer.math.atan2(b[1] - a[1], b[3] - a[3])
  return COMPASS[(math.floor(ang / (saucer.math.tau / 8) + 0.5) % 8) + 1]
end

-- rows of the city-map panel: where you are, one row per district, then the way back to the sector map
function M.panel_rows(state, p, site, ruin, panel)
  if not M.is_city(ruin) then return { { text = "No city here", enabled = false } } end
  local pos = p.ship.pos
  local here = M.district_at(ruin, pos)
  local g = M.gravity(ruin)
  local on, n = M.grid(state, site, ruin)
  local rows = { { text = string.format("%s CITY grid %d/%d  %s", ruin.city.body:upper(), on, n,
    g > 1 and string.format("%.1f g, hovering costs Charge", g) or (g > 0 and "light pull" or "free flight")), enabled = false, hint = "You are over: " .. here.label } }
  for _, pd in ipairs(ruin.city.districts) do
    local live = M.powered(state, site, ruin, pd.id)
    local d = vec.dist(pos, pd.pos)
    local hint
    if not live then
      for _, c in ipairs(ruin.city.couplings) do
        if c.district == pd.id then hint = string.format("Power coupling %dm %s: beam it up to wake the district", vec.dist(pos, c.pos) // 1, M.compass(pos, c.pos)) end
      end
    end
    rows[#rows + 1] = { text = string.format("%-16s %-4s %5dm %s", pd.label, live and "LIVE" or "DARK", d // 1, M.compass(pos, pd.pos)),
                        enabled = false, hint = hint }
  end
  rows[#rows + 1] = { text = "Sector map", act = function(st, pl) panel.open(pl, "map") end }
  return rows
end

return M
