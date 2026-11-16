-- SPDX-License-Identifier: MIT
-- Saucer flight, true 3D (OpenSpec add-true-3d-flight).
--
-- Six axes: forward/back thrust follows where the pilot looks (yaw AND
-- pitch, so you climb or dive by looking up or down), strafe left/right,
-- vertical thrust up/down (lift, along the hull's up axis), yaw (turn),
-- pitch (look) and a bank (roll) that leans the whole saucer into turns and
-- strafes. The hull itself never pitches or flips: gravity plating keeps the
-- deck level so the people walking around inside stay comfortable, and the
-- bank is capped at BANK_MAX. Velocity eases toward the commanded vector
-- (dampening); with no input the saucer brakes to a hover and holds altitude.
-- Movement is resolved by a caller-supplied mover.
local vec = require("lib.vec")
local configs = require("sim.config")
local M = {}

M.PITCH_LIMIT = 1.45     -- ~83 degrees: look (and fly) straight up or down a shaft
M.LOOK_RATE = 1.6
M.LIFT_FACTOR = 0.8      -- vertical thrust relative to forward thrust
M.BOOST = 1.8
M.BANK_MAX = 0.18        -- radians (~10 degrees) of visual bank, comfort-capped
M.BANK_RATE = 3.0        -- how fast the bank follows the stick (1/s)

-- the three thrust axes for a heading and pitch: forward (aim), right, up
function M.basis(yaw, pitch)
  return vec.aim(yaw, pitch), vec.right(yaw), { 0, 1, 0 }
end

-- commanded velocity for stick values (mx strafe, mz forward, my lift)
function M.want(ship, mx, mz, my, speed)
  local f, r, u = M.basis(ship.yaw, ship.pitch or 0)
  local out = {}
  for i = 1, 3 do out[i] = (f[i] * mz + r[i] * mx + u[i] * my * M.LIFT_FACTOR) * speed end
  return out
end

-- step(ship, cmd, dt, move) ; move(ship, delta) -> new_pos, blocked_count
function M.step(ship, cmd, dt, move)
  local c = configs.get(ship.size)
  local turn = cmd:axis("turn")
  ship.yaw = saucer.math.wrap(ship.yaw - turn * c.turn * dt)
  ship.pitch = vec.clamp(ship.pitch + cmd:axis("look") * M.LOOK_RATE * dt, -M.PITCH_LIMIT, M.PITCH_LIMIT)
  local mx, mz, my = cmd:axis("move_x"), cmd:axis("move_z"), cmd:axis("lift")
  local speed = c.speed
  if cmd:held("boost") then speed = speed * M.BOOST end
  local want = M.want(ship, mx, mz, my, speed)
  local k = math.min(1, c.accel * dt)
  for i = 1, 3 do ship.vel[i] = ship.vel[i] + (want[i] - ship.vel[i]) * k end
  -- bank into turns and strafes (right turn / right strafe dips the right side)
  local target = M.BANK_MAX * vec.clamp(turn * 0.7 + mx * 0.5, -1, 1)
  local b = ship.bank or 0
  ship.bank = b + (target - b) * math.min(1, M.BANK_RATE * dt)
  local delta = vec.scale(ship.vel, dt)
  local np, blocked = move(ship, delta)
  for i = 1, 3 do
    if math.abs((np[i] - ship.pos[i]) - delta[i]) > 1e-6 then ship.vel[i] = 0 end
  end
  ship.pos = np
  return blocked
end

-- add-tractor-beam: fine positioning from the Tractor Room's console. Slow
-- thrusters in the operator's frame (heading: where they face), a slow yaw
-- trim, and the bank settles level. -> blocked count from the mover
function M.trim(ship, input, heading, dt, move)
  local c = configs.get(ship.size)
  local b = c.beam or {}
  local speed, turn_rate = b.trim_speed or 3.0, b.trim_turn or 0.35
  ship.yaw = saucer.math.wrap(ship.yaw - (input.turn or 0) * turn_rate * dt)
  local f, r = vec.fwd(heading), vec.right(heading)
  local mx, mz, my = input.move_x or 0, input.move_z or 0, input.lift or 0
  local want = { (f[1] * mz + r[1] * mx) * speed, my * speed * 0.6, (f[3] * mz + r[3] * mx) * speed }
  local k = math.min(1, c.accel * 2 * dt)
  for i = 1, 3 do ship.vel[i] = ship.vel[i] + (want[i] - ship.vel[i]) * k end
  local bk = ship.bank or 0
  ship.bank = bk - bk * math.min(1, M.BANK_RATE * dt)
  local delta = vec.scale(ship.vel, dt)
  local np, blocked = move(ship, delta)
  for i = 1, 3 do
    if math.abs((np[i] - ship.pos[i]) - delta[i]) > 1e-6 then ship.vel[i] = 0 end
  end
  ship.pos = np
  return blocked
end

-- altitude band readout for the helm: the vertical offset of `pos` from the ship
function M.elevation(ship, pos)
  return pos[2] - ship.pos[2]
end

return M
