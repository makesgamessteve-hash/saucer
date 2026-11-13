-- SPDX-License-Identifier: MIT
-- One player's saucer: position, size configuration, Charge and the
-- size-transition state machine (concept §3.1, spec saucer-size).
-- Config index 1 is the largest (Villa); higher index = smaller.
local configs = require("sim.config")
local M = {}

function M.new(pos, yaw, size)
  return {
    pos = { pos[1], pos[2], pos[3] },
    vel = { 0, 0, 0 },
    yaw = yaw or 0,
    pitch = 0,
    size = size or 1,
    target = false,
    t_left = 0,
    charge = configs.all().max_charge,
  }
end

-- collision radius and half height; during a transition the larger hull counts
function M.dims(ship)
  local c = configs.get(ship.size)
  local r, hh = c.diameter / 2, c.height / 2
  if ship.target then
    local t = configs.get(ship.target)
    if t.diameter / 2 > r then r = t.diameter / 2 end
    if t.height / 2 > hh then hh = t.height / 2 end
  end
  return r, hh
end

function M.dims_of(size)
  local c = configs.get(size)
  return c.diameter / 2, c.height / 2
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

-- request(ship, to, blocked) -> ok, reason
-- blocked(ship, r, hh, margin) must return true when a hull of that size
-- would not fit at the ship's position (walls or other players' saucers).
function M.request(ship, to, blocked)
  local all = configs.all()
  if to < 1 or to > #all then return false, "range" end
  if to == ship.size then return false, "same" end
  if ship.target then return false, "busy" end
  local cost = M.cost(ship.size, to)
  if ship.charge < cost then return false, "charge" end
  if to < ship.size then
    local r, hh = M.dims_of(to)
    if blocked(ship, r, hh, all.grow_margin) then return false, "clearance" end
  end
  ship.charge = ship.charge - cost
  ship.t_left = to > ship.size and all.shrink_time or all.grow_time
  ship.target = to
  return true
end

-- advance a transition; regenerate Charge when `regen` (open space).
-- returns "done" on the tick a transition completes.
function M.update(ship, dt, regen)
  if ship.target then
    ship.t_left = ship.t_left - dt
    if ship.t_left <= 1e-9 then
      ship.size = ship.target
      ship.target = false
      ship.t_left = 0
      return "done"
    end
  elseif regen then
    local all = configs.all()
    ship.charge = math.min(all.max_charge, ship.charge + all.charge_regen * dt)
  end
  return nil
end

return M
