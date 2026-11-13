-- SPDX-License-Identifier: MIT
-- Saucer flight: yaw/pitch from turn/look axes, velocity eased toward the
-- commanded direction, movement resolved by a caller-supplied mover.
local vec = require("lib.vec")
local configs = require("sim.config")
local M = {}

M.PITCH_LIMIT = 1.2
M.LOOK_RATE = 1.6
M.LIFT_FACTOR = 0.6
M.BOOST = 1.8

-- step(ship, cmd, dt, move) ; move(ship, delta) -> new_pos, blocked_count
function M.step(ship, cmd, dt, move)
  local c = configs.get(ship.size)
  ship.yaw = saucer.math.wrap(ship.yaw - cmd:axis("turn") * c.turn * dt)
  ship.pitch = vec.clamp(ship.pitch + cmd:axis("look") * M.LOOK_RATE * dt, -M.PITCH_LIMIT, M.PITCH_LIMIT)
  local mx, mz, my = cmd:axis("move_x"), cmd:axis("move_z"), cmd:axis("lift")
  local speed = c.speed
  if cmd:held("boost") then speed = speed * M.BOOST end
  local f, r = vec.fwd(ship.yaw), vec.right(ship.yaw)
  local want = {
    (f[1] * mz + r[1] * mx) * speed,
    my * speed * M.LIFT_FACTOR,
    (f[3] * mz + r[3] * mx) * speed,
  }
  local k = math.min(1, c.accel * dt)
  for i = 1, 3 do ship.vel[i] = ship.vel[i] + (want[i] - ship.vel[i]) * k end
  local delta = vec.scale(ship.vel, dt)
  local np, blocked = move(ship, delta)
  for i = 1, 3 do
    if math.abs((np[i] - ship.pos[i]) - delta[i]) > 1e-6 then ship.vel[i] = 0 end
  end
  ship.pos = np
  return blocked
end

return M
