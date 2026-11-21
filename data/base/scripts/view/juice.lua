-- SPDX-License-Identifier: MIT
-- add-fun-fixes: hit juice, view side only (the sim never reads any of it).
-- From the "hit" fx in p.fx:
--   trauma  sum over recent hits of max(0, 0.45 - 0.9 * age_s), capped at 1
--   shake   camera yaw/pitch/roll offset of SHAKE * trauma^2 rad (deterministic noise), none in XR
--   hitstop the camera holds its pose for HITSTOP ticks after a hit (none in XR)
--   flash   a red frame fading over FLASH ticks
local M = {}

M.SHAKE = 0.02     -- rad at trauma 1 (well under 4% of the view height at a 60-90 degree fov)
M.HITSTOP = 3      -- ticks (50 ms)
M.FLASH = 9        -- ticks
M.ENABLED = true

-- the tick of the newest "hit" fx of player p (nil: none)
function M.last_hit(p)
  local t
  for _, f in ipairs(p.fx or {}) do
    if f.sound == "hit" and (not t or f.tick > t) then t = f.tick end
  end
  return t
end

function M.trauma(p, tick)
  local tr = 0
  for _, f in ipairs(p.fx or {}) do
    if f.sound == "hit" and f.tick <= tick then
      tr = tr + math.max(0, 0.45 - 0.9 * (tick - f.tick) / 60)
    end
  end
  return math.min(tr, 1)
end

-- 0..1: the red hit frame
function M.flash(p, tick)
  if not M.ENABLED then return 0 end
  local h = M.last_hit(p)
  if not h or tick < h then return 0 end
  return math.max(0, 1 - (tick - h) / M.FLASH)
end

local function noise(t, k)
  return math.sin(t * (1.7 + 0.37 * k) + k * 2.1) * 0.6 + math.sin(t * (3.1 + 0.53 * k) + k) * 0.4
end

local held = {} -- [player index] = { cam = pose before the hit, hit = tick }
local prev = {}

local function copy(cam)
  local c = {}
  for k, x in pairs(cam) do c[k] = x end
  if cam.pos then c.pos = { cam.pos[1], cam.pos[2], cam.pos[3] } end
  return c
end

-- the camera for this frame, with hitstop and shake applied (cam itself is not changed)
function M.camera(cam, p, tick, xr)
  if xr or not M.ENABLED or not cam.yaw then return cam end
  local i = p.index or 1
  local h = M.last_hit(p)
  local out = cam
  if h and tick >= h and tick < h + M.HITSTOP and prev[i] then
    if not held[i] or held[i].hit ~= h then held[i] = { cam = prev[i], hit = h } end
    out = copy(held[i].cam)
  else
    prev[i] = copy(cam)
  end
  local tr = M.trauma(p, tick)
  if tr > 0 then
    if out == cam then out = copy(cam) end
    local a = M.SHAKE * tr * tr
    out.yaw = out.yaw + a * noise(tick, 1)
    out.pitch = (out.pitch or 0) + a * noise(tick, 2)
    out.roll = (out.roll or 0) + a * 0.5 * noise(tick, 3)
  end
  return out
end

function M.reset()
  held, prev = {}, {}
end

return M
