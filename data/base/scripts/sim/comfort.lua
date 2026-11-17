-- SPDX-License-Identifier: MIT
-- add-presentation-packaging: XR snap turning. The engine's comfort filter
-- turns a right-stick flick into one tick of snap_left / snap_right (client
-- setting, see saucer.xr.set_comfort); the sim turns by a fixed SNAP so the
-- command stream alone decides the result (replays stay deterministic).
local M = {}

M.SNAP = math.rad(30)

-- extra yaw (radians, + = left like a negative turn axis) for this command
function M.snap(cmd)
  local d = 0
  if cmd:pressed("snap_left") then d = d + M.SNAP end
  if cmd:pressed("snap_right") then d = d - M.SNAP end
  return d
end

-- yaw after this tick's smooth turn plus any snap turn
function M.yaw(yaw, cmd, rate, dt)
  return saucer.math.wrap(yaw - cmd:axis("turn") * rate * dt + M.snap(cmd))
end

return M
