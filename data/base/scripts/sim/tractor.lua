-- SPDX-License-Identifier: MIT
-- The belly tractor beam (OpenSpec add-tractor-beam; concept §6.2, v0.6).
--
-- The beam is a cone from the emitter in the saucer's belly straight down the
-- hull's down axis. The hull never pitches, but it banks into turns, and the
-- bank tilts the beam. A target is captured only when the saucer fits it:
--   1. its size class fits the beam (tractor_class),
--   2. it lies between `min` and the beam's range below the emitter (depth
--      measured along the beam axis),
--   3. it is inside the cone (angle off the axis <= half_angle),
--   4. long scrap (size L and up) lies along the keel: the hull's heading
--      must match the item's axis within yaw_tol (either end first),
--   5. the hull is level (|bank| <= level) and holding still (speed <= still),
--   6. nothing solid lies between the emitter and the target.
-- The pull lifts the item up the beam axis to the belly hatch while it
-- shrinks (scale 1 -> beam.shrink), so big scrap fits the hold.
-- The Villa's beam is run from the Tractor Room's console (beam.console);
-- the Seat's mini beam fires straight from the seat.
-- Targets: this player's loot instances, the next Echo of the mystery, items
-- a Snatcher left in its nest, Fold Retreat caches, and (in open space) the
-- unique Curio of an opened Resonant vault.
local vec = require("lib.vec")
local data = require("lib.data")
local configs = require("sim.config")
local loot = require("sim.loot")
local mystery = require("sim.mystery")
local sm = saucer.math
local M = {}

M.LONG = 3            -- size class from which scrap is long and must be lined up with the keel
M.MIN_PULL = 0.6      -- seconds: even a target right under the hatch takes this long
M.SENSE = 1.6         -- the indicator tracks targets this many ranges deep...
M.SENSE_ANGLE = 3.0   -- ...and this many cone half-angles off the axis
M.DEFAULT = { emitter = nil, half_angle = 0.35, min = 1.0, pull_speed = 6.0, shrink = 0.2, still = 1.5, level = 0.07,
              yaw_tol = 0.3, console = false, trim_speed = 3.0, trim_turn = 0.35 }

-- the beam parameters of a configuration (mods that only know the old fields get defaults)
function M.beam(c)
  local b = c.beam or {}
  local out = {}
  for k, v in pairs(M.DEFAULT) do out[k] = v end
  for k, v in pairs(b) do out[k] = v end
  out.emitter = out.emitter or { 0, -c.height / 2, 0 }
  out.range = c.tractor_range
  out.class = c.tractor_class
  return out
end

function M.beam_of(ship) return M.beam(configs.get(ship.size)) end

-- hull-local -> world for a yaw and a bank (the renderer uses the same rotation)
local function rot3(yaw, roll, v)
  local c, s = sm.cos(roll), sm.sin(roll)
  local x, y = v[1] * c - v[2] * s, v[1] * s + v[2] * c
  local cy, sy = sm.cos(yaw), sm.sin(yaw)
  return { x * cy + v[3] * sy, y, -x * sy + v[3] * cy }
end
M.rot3 = rot3

-- emitter position (world) and the unit beam axis (down the hull, tilted by the bank)
function M.frame(ship)
  local b = M.beam_of(ship)
  local roll = ship.bank or 0
  local e = rot3(ship.yaw, roll, b.emitter)
  return { ship.pos[1] + e[1], ship.pos[2] + e[2], ship.pos[3] + e[3] }, rot3(ship.yaw, roll, { 0, -1, 0 })
end

-- wrap an angle difference into [-pi/2, pi/2]: a long item has no front or back
local function axis_err(a)
  local d = sm.wrap(a)
  if d > sm.pi / 2 then d = d - sm.pi elseif d < -sm.pi / 2 then d = d + sm.pi end
  return d
end
M.axis_err = axis_err

-- geometry of a world point relative to the beam: depth along the axis,
-- lateral distance off it, the angle off it and the horizontal offset (world)
-- from the beam's centre line at that depth to the point
function M.measure(ship, pos)
  local e, a = M.frame(ship)
  local v = vec.sub(pos, e)
  local depth = vec.dot(v, a)
  local off = vec.sub(v, vec.scale(a, depth))
  local lateral = vec.len(off)
  return { depth = depth, lateral = lateral, angle = sm.atan2(lateral, math.max(depth, 1e-6)), off = off, emitter = e,
           axis = a }
end

local function hint_dir(off, heading)
  local f, r = vec.fwd(heading), vec.right(heading)
  local df, dr = vec.dot(off, f), vec.dot(off, r)
  if math.abs(df) >= math.abs(dr) then return df >= 0 and "FWD" or "BACK", math.abs(df) end
  return dr >= 0 and "RIGHT" or "LEFT", math.abs(dr)
end

-- check(ship, cand, heading) -> status, info. status is "lock" when the beam
-- can take it now, else the first rule that fails: "big", "far", "close",
-- "axis", "yaw", "tilt", "drift" or "blocked". info.hint is the HUD wording;
-- heading (default the hull's) orients the move hint for the person reading it.
function M.check(ship, cand, heading)
  local b = M.beam_of(ship)
  local m = M.measure(ship, cand.pos)
  heading = heading or ship.yaw
  local info = { depth = m.depth, lateral = m.lateral, angle = m.angle, off = m.off, emitter = m.emitter, axis = m.axis,
                 half = b.half_angle, range = b.range, min = b.min }
  info.max_lateral = math.max(0, m.depth) * sm.sin(b.half_angle) / sm.cos(b.half_angle)
  if cand.axis then info.yaw_err = axis_err(ship.yaw - cand.axis) end
  local function out(st, hint)
    info.hint = hint
    return st, info
  end
  if cand.item.size > b.class then
    return out("big", "NEEDS A SIZE " .. loot.size_name(cand.item.size) .. " BEAM")
  end
  if m.depth > b.range then return out("far", string.format("TOO HIGH - DESCEND %dM", (m.depth - b.range) // 1 + 1)) end
  if m.depth < b.min then
    if m.depth < 0 then return out("close", "ABOVE THE BELLY - CLIMB OVER IT") end
    return out("close", string.format("TOO CLOSE - CLIMB %dM", (b.min - m.depth) // 1 + 1))
  end
  if m.angle > b.half_angle then
    local dir, dist = hint_dir(m.off, heading)
    return out("axis", string.format("OFF AXIS - MOVE %s %dM", dir, (dist) // 1 + 1))
  end
  if info.yaw_err and math.abs(info.yaw_err) > b.yaw_tol then
    local deg = math.floor(math.abs(info.yaw_err) * 57.2958 + 0.5)
    return out("yaw", string.format("LONG SCRAP - TURN %s %d DEG", info.yaw_err > 0 and "RIGHT" or "LEFT", deg))
  end
  if math.abs(ship.bank or 0) > b.level then return out("tilt", "LEVEL THE HULL") end
  if vec.len(ship.vel) > b.still then return out("drift", "HOLD STILL") end
  local d = vec.sub(cand.pos, m.emitter)
  if saucer.physics.raycast(m.emitter, d, 0.98, 1) then return out("blocked", "BEAM BLOCKED") end
  return out("lock", "LOCK - READY TO PULL")
end

local function civ_id(state, site_idx)
  local site = state.sector.sites[site_idx]
  local civ = site and data.load("civs/civs.lua")[site.civ]
  return civ and civ.id or nil
end

-- candidates(state, p, site, ruin) -> list of {key, kind, pos, item, echo, room, axis}
function M.candidates(state, p, site_idx, ruin)
  local out = {}
  if ruin then
    local civ = civ_id(state, site_idx)
    for _, s in ipairs(ruin.slots) do
      local key = site_idx .. ":" .. s.id
      if not p.looted[key] then
        local iseed = loot.instance_seed(s.seed, p.record_index)
        local item = loot.roll(iseed, s.max_size, s.tier)
        item.tier, item.civ = s.tier, civ
        local c = { key = key, kind = "slot", pos = s.pos, room = s.room, item = item }
        -- long scrap lies at its own angle on the floor
        if item.size >= M.LONG then c.axis = (math.floor(math.abs(iseed)) % 180) * sm.pi / 180 end
        out[#out + 1] = c
      end
    end
    -- add-holodeck-home-life: data cores, modules, books and ingredients in vaults
    for _, c in ipairs(require("sim.finds").candidates(state, p, site_idx, ruin)) do out[#out + 1] = c end
    local echo = mystery.echo_at(state.mystery, site_idx)
    if echo then
      for _, r in ipairs(ruin.rooms) do
        if r.echo_pos then
          out[#out + 1] = { key = "echo:" .. echo, kind = "echo", pos = r.echo_pos, echo = echo, room = r.id,
            item = mystery.item(state.mystery, echo) }
        end
      end
    end
  end
  for i, n in ipairs(state.nests or {}) do
    if n.site == site_idx and n.owner == p.record_index then
      out[#out + 1] = { key = "nest:" .. i, kind = "nest", index = i, pos = n.pos, item = n.item }
    end
  end
  for i, c in ipairs(state.caches or {}) do
    if c.site == site_idx and c.owner == p.record_index and #c.items > 0 then
      out[#out + 1] = { key = "cache:" .. i, kind = "cache", index = i, pos = c.pos,
        item = { name = string.format("Cache (%d item%s)", #c.items, #c.items == 1 and "" or "s"), size = 1, value = 0,
                 type = "cache", ident = true } }
    end
  end
  local v = state.vault
  if site_idx == 0 and v and state.mystery.vault_open and not v.taken then
    out[#out + 1] = { key = "vault:curio", kind = "curio", pos = { v.pos[1], v.pos[2] + 2, v.pos[3] },
      item = mystery.curio(state.mystery) }
  end
  return out
end

-- the candidate with this key, or nil
function M.by_key(state, p, site_idx, ruin, key)
  for _, c in ipairs(M.candidates(state, p, site_idx, ruin)) do
    if c.key == key then return c end
  end
  return nil
end

local function ship_half(ship) return configs.get(ship.size).height / 2 end
M.ship_half = ship_half

-- scan(state, p, site, ruin, heading) -> { cand, status, info } for the target
-- the beam would take (a "lock" nearest the axis), else the one nearest the
-- axis within sensing range (for the alignment indicator), else nil
function M.scan(state, p, site_idx, ruin, heading)
  local ship = p.ship
  local b = M.beam_of(ship)
  local best, near
  for _, cand in ipairs(M.candidates(state, p, site_idx, ruin)) do
    local m = M.measure(ship, cand.pos)
    if m.depth > -ship_half(ship) and m.depth <= b.range * M.SENSE and m.angle <= b.half_angle * M.SENSE_ANGLE then
      local st, info = M.check(ship, cand, heading)
      local e = { cand = cand, status = st, info = info }
      if st == "lock" then
        if not best or info.angle < best.info.angle then best = e end
      elseif not near or info.angle < near.info.angle then
        near = e
      end
    end
  end
  return best or near
end

-- can this saucer lift it?
function M.can_lift(ship, item)
  return item.size <= configs.get(ship.size).tractor_class
end

-- seconds the beam takes to pull a target `depth` meters up into the hatch
function M.pull_time(ship, depth)
  return math.max(M.MIN_PULL, depth / M.beam_of(ship).pull_speed)
end

-- smoothstep 0..1
local function ease(t)
  t = vec.clamp(t, 0, 1)
  return t * t * (3 - 2 * t)
end
M.ease = ease

-- where a target riding the beam is and how big it is: it rises from where it
-- lay up the beam axis into the hatch, shrinking to beam.shrink on the way
-- -> pos, scale, f (0..1)
function M.pull_pose(ship, tr)
  local b = M.beam_of(ship)
  local f = vec.clamp(tr.t / tr.total, 0, 1)
  local e = M.frame(ship)
  local k = ease(f)
  local from = tr.from
  local pos = { from[1] + (e[1] - from[1]) * k, from[2] + (e[2] - from[2]) * k, from[3] + (e[3] - from[3]) * k }
  return pos, 1 - (1 - b.shrink) * k, f
end

return M
