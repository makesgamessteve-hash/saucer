-- SPDX-License-Identifier: MIT
-- One player's saucer: position, size configuration, Charge and the
-- reconfiguration state machine (concept §3.1-3.2, spec saucer-size).
-- Config index 1 is the largest (Villa); higher index = smaller.
--
-- A size change happens around the pilot: the pilot's eye point stays fixed
-- in the world and the hull re-forms around it. The new size, pose and
-- collision hull apply at once; `morph` keeps the old pose for the fold
-- animation and blocks further changes until it has played out.
local configs = require("sim.config")
local sm = saucer.math
local M = {}

function M.new(pos, yaw, size)
  return {
    pos = { pos[1], pos[2], pos[3] },
    vel = { 0, 0, 0 },
    yaw = yaw or 0,
    pitch = 0,
    size = size or 1,
    morph = false,
    t_left = 0,
    charge = configs.all().max_charge,
    hull = 100, shield = 100, since_hit = 99,   -- milestone 3: stun bolts drain shields, then hull
  }
end

-- collision radius and half height of the current configuration
function M.dims(ship)
  return M.dims_of(ship.size)
end

function M.dims_of(size)
  local c = configs.get(size)
  return c.diameter / 2, c.height / 2
end

local function rot(yaw, v)
  local c, s = sm.cos(yaw), sm.sin(yaw)
  return { v[1] * c + v[3] * s, v[2], -v[1] * s + v[3] * c }
end
M.rot = rot

-- world position of the pilot's eyes in a given config and pose
function M.eye_world(pos, yaw, size)
  local e = rot(yaw, configs.get(size).pilot_eye)
  return { pos[1] + e[1], pos[2] + e[2], pos[3] + e[3] }
end

-- hull centre for config `size` whose pilot eye sits at `eye` facing `yaw`
function M.center_for_eye(eye, yaw, size)
  local e = rot(yaw, configs.get(size).pilot_eye)
  return { eye[1] - e[1], eye[2] - e[2], eye[3] - e[3] }
end

-- Charge cost to go from config `from` to config `to`. Shrinking pays each
-- smaller config's enter_cost; growing pays half of each config it leaves.
function M.cost(from, to)
  local all = configs.all()
  local cost = 0
  if to > from then
    for i = from + 1, to do cost = cost + all[i].enter_cost end
  else
    for i = to + 1, from do cost = cost + all[i].enter_cost / 2 end
  end
  return cost
end

-- request(ship, to, blocked, eye, yaw) -> ok, reason
-- eye/yaw: the pilot's eye point and facing to keep (default: the helm of the
-- current config). blocked(pos, r, hh, margin) must return true when a hull
-- of that size would not fit at pos (walls or other players' saucers); it is
-- only asked when growing.
function M.request(ship, to, blocked, eye, yaw)
  local all = configs.all()
  if to < 1 or to > #all then return false, "range" end
  if to == ship.size then return false, "same" end
  if ship.morph then return false, "busy" end
  local cost = M.cost(ship.size, to)
  if ship.charge < cost then return false, "charge" end
  yaw = yaw or ship.yaw
  eye = eye or M.eye_world(ship.pos, ship.yaw, ship.size)
  local center = M.center_for_eye(eye, yaw, to)
  if to < ship.size then
    local r, hh = M.dims_of(to)
    if blocked(center, r, hh, all.grow_margin) then return false, "clearance", center end
  end
  ship.charge = ship.charge - cost
  ship.morph = { from = ship.size, pos = { ship.pos[1], ship.pos[2], ship.pos[3] }, yaw = ship.yaw,
                 total = to > ship.size and all.shrink_time or all.grow_time, eye = { eye[1], eye[2], eye[3] } }
  ship.t_left = ship.morph.total
  ship.size = to
  ship.pos = center
  ship.yaw = yaw
  ship.vel = { 0, 0, 0 }
  return true
end

-- 0 at the start of a reconfiguration, 1 when it is done (or idle)
function M.progress(ship)
  if not ship.morph then return 1 end
  return 1 - ship.t_left / ship.morph.total
end

-- advance a reconfiguration; regenerate Charge when `regen` (open space).
-- regen may be a number: a multiplier on the regeneration rate (home comforts).
-- returns "done" on the tick a reconfiguration completes.
function M.update(ship, dt, regen)
  if ship.morph then
    ship.t_left = ship.t_left - dt
    if ship.t_left <= 1e-9 then
      ship.morph = false
      ship.t_left = 0
      return "done"
    end
  elseif regen then
    local all = configs.all()
    local k = type(regen) == "number" and regen or 1
    ship.charge = math.min(all.max_charge, ship.charge + all.charge_regen * k * dt)
  end
  return nil
end

return M
