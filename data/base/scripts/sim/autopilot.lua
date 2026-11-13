-- SPDX-License-Identifier: MIT
-- Autopilot: turns a route through a derelict into stick inputs. Used by the
-- automated game tests (inputs still go through command frames) and usable
-- by mods for attract/demo modes. Pure functions; no state of its own.
local vec = require("lib.vec")
local ruinm = require("sim.ruin")
local configs = require("sim.config")
local M = {}

-- config index able to pass a door of size class c (largest that fits)
function M.config_for_class(c)
  local best
  for i, cfg in ipairs(configs.all()) do
    if cfg.class <= c and not best then best = i end
  end
  return best or configs.count()
end

local function door_center(d, rooms, kit, origin)
  local child = rooms[d.b]
  local mn, mx = ruinm.room_box(child, kit, origin)
  local p = { 0, mn[2] + kit.wall + kit.doors[d.class][2] / 2, 0 }
  local l = d.axis == 1 and 3 or 1
  p[l] = origin[l] + (d.lo + d.hi) / 2 * kit.cell
  p[d.axis] = d.sign > 0 and mn[d.axis] or mx[d.axis]
  return p
end
M.door_center = door_center

function M.room_center(r, kit, origin, hh)
  local mn, mx = ruinm.room_box(r, kit, origin)
  return { (mn[1] + mx[1]) / 2, mn[2] + kit.wall + math.max(hh + 0.3, 1.2), (mn[3] + mx[3]) / 2 }
end

-- route(ruin, origin, room_id) -> list of { pos, size } from outside the
-- entrance to the centre of room_id, shrinking before each smaller door.
function M.route(ruin, origin, room_id)
  local kit = ruinm.kit_of(ruin.kit)
  local chain, id = {}, room_id
  while id ~= 0 do
    table.insert(chain, 1, id)
    id = ruin.rooms[id].parent
  end
  local doors = {}
  for _, d in ipairs(ruin.doors) do doors[d.b] = d end
  local wps = {}
  for _, rid in ipairs(chain) do
    local d = doors[rid]
    local size = M.config_for_class(d.class)
    local r, hh = configs.get(size).diameter / 2, configs.get(size).height / 2
    local c = door_center(d, ruin.rooms, kit, origin)
    local step = { 0, 0, 0 }
    step[d.axis] = d.sign * (r + 1.0)
    wps[#wps + 1] = { pos = vec.sub(c, vec.scale(step, d.sign == 0 and 0 or 1)), size = size, tol = 0.6 }
    wps[#wps + 1] = { pos = vec.add(c, step), size = size, tol = 0.8 }
    local rc = M.room_center(ruin.rooms[rid], kit, origin, hh)
    rc[2] = c[2]
    wps[#wps + 1] = { pos = rc, size = size, tol = 1.0 }
  end
  -- the first waypoint stands well clear of the hull
  local first = wps[1]
  local d0 = doors[chain[1]]
  first.pos[d0.axis] = first.pos[d0.axis] - d0.sign * 12
  return wps
end

-- steer(ship, target) -> axes table for move_x, move_z, lift, turn and the distance
function M.steer(ship, target, face)
  local cfg = configs.get(ship.size)
  local d = vec.sub(target, ship.pos)
  local dist = vec.len(d)
  local look = face or target
  local ld = vec.sub(look, ship.pos)
  local want_yaw = saucer.math.atan2(ld[1], ld[3])
  local diff = saucer.math.wrap(want_yaw - ship.yaw)
  if not face and math.abs(ld[1]) + math.abs(ld[3]) < 2 then diff = 0 end
  local f, r = vec.fwd(ship.yaw), vec.right(ship.yaw)
  local gain = 1.2 / cfg.speed
  local damp = 0.9 / cfg.speed
  local lz = vec.dot(d, f) * gain - vec.dot(ship.vel, f) * damp
  local lx = vec.dot(d, r) * gain - vec.dot(ship.vel, r) * damp
  local ly = (d[2] * gain - ship.vel[2] * damp) / 0.6
  return {
    move_x = vec.clamp(lx, -1, 1), move_z = vec.clamp(lz, -1, 1), lift = vec.clamp(ly, -1, 1),
    turn = vec.clamp(-diff * 2.5, -1, 1),
  }, dist, diff
end


-- Drivers for scripted runs. `t` is an input API with axis(p, name, v, ticks,
-- nowait), press(p, name, ticks) and wait(n) (saucer.test in game tests);
-- `get` returns the live player table.
M.AXES = { "move_x", "move_z", "lift", "turn" }

function M.hold(t, pl, axes)
  for _, a in ipairs(M.AXES) do t.axis(pl, a, axes[a] or 0, 1, true) end
  t.wait(1)
end

function M.resize(t, pl, get, size)
  local guard = 0
  while get().ship.size ~= size and guard < 8 do
    local ship = get().ship
    if not ship.target then
      if ship.size < size then t.press(pl, "shrink") else t.press(pl, "grow") end
    end
    M.hold(t, pl, {})
    guard = guard + (ship.target and 0 or 1)
  end
  while get().ship.target do M.hold(t, pl, {}) end
  return get().ship.size == size
end

-- fly to a point; returns true when within tol before max_ticks
function M.fly(t, pl, get, pos, tol, max_ticks, face)
  for _ = 1, max_ticks or 1200 do
    local axes, dist = M.steer(get().ship, pos, face)
    if dist < (tol or 1) then
      M.hold(t, pl, {})
      return true
    end
    M.hold(t, pl, axes)
  end
  return false
end

-- follow a route, changing size before each leg
function M.follow(t, pl, get, wps, max_ticks)
  for i, wp in ipairs(wps) do
    if wp.size and get().ship.size ~= wp.size and not M.resize(t, pl, get, wp.size) then return false, i end
    if not M.fly(t, pl, get, wp.pos, wp.tol, max_ticks) then return false, i end
  end
  return true
end

-- turn toward a point while holding position
function M.face(t, pl, get, pos, max_ticks)
  local hold = get().ship.pos
  for _ = 1, max_ticks or 240 do
    local axes, _, diff = M.steer(get().ship, { hold[1], hold[2], hold[3] }, pos)
    if math.abs(diff) < 0.03 then return true end
    M.hold(t, pl, axes)
  end
  return false
end

return M
