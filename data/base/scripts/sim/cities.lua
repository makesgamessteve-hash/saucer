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

-- how brightly a district's lights burn (0 dark .. 1 full) at this tick: dark until its coupling is
-- restored, then a flicker for a second and a half and a ramp up. Render only: a function of the tick.
M.RAMP = 150
function M.light(state, site, ruin, d)
  local pd = d and ruin.city.districts[d]
  if not pd or pd.powered then return 1 end
  local t0 = state.locks and state.locks[lockkey(site, d)]
  if not t0 then return 0 end
  local dt = state.tick - t0
  if dt >= M.RAMP then return 1 end
  if dt < 90 then return ((dt // 7 + d) % 3 == 0) and 0.8 or 0 end
  return (dt - 90) / (M.RAMP - 90)
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
  return out
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
    if not bd or d < bd then best, bd = c, d end
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
