-- SPDX-License-Identifier: MIT
-- Drawing the Villa's landing gear and hull door (OpenSpec add-dock-land-eva):
-- three telescoping legs that swing out and reach the ground, the hull door's
-- sliding leaves and belly plate, and the stairs that unfold from the belly.
-- Render-only: reads o.berth and o.door, writes nothing.
local vec = require("lib.vec")
local landing = require("sim.landing")
local avatar = require("sim.avatar")
local assets = require("view.assets")
local sm = saucer.math
local M = {}

local HULL = { 0.62, 0.64, 0.70, 1 }
local RIM = { 0.30, 0.32, 0.40, 1 }
local DARK = { 0.05, 0.05, 0.08, 1 }
local WARN = { 1.0, 0.75, 0.15, 1 }

-- a strut between two hull-local points as a stretched unit box
local function strut(v, A, d, a, b, w, tint)
  local R = require("view.render")
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local hz = sm.sqrt(dx * dx + dz * dz)
  local len = sm.sqrt(hz * hz + dy * dy)
  if len < 1e-4 then return 0 end
  local mid = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }
  local s = d.scale
  v:mesh(assets.unit_box(true), { pos = R.at(d, mid), yaw = d.yaw + sm.atan2(dx, dz), pitch = sm.atan2(dy, hz), roll = 0,
                   scale = { w * s, w * s, len * s }, tint = tint })
  return 1
end
M.strut = strut

-- the three legs; -> draws
function M.legs(v, A, o, d)
  local b = o.berth
  if not b or (b.legs or 0) <= 0.01 then return 0 end
  local T = landing.tune()
  local k = b.legs
  local ease = k * k * (3 - 2 * k)
  local R = require("view.render")
  local n = 0
  for i, a in ipairs(T.azimuth) do
    local sa, ca = sm.sin(a), sm.cos(a)
    local gy = (b.feet and b.feet[i] or (b.ref or 0)) - o.ship.pos[2]
    if b.phase == "descend" or b.phase == "lift" then gy = math.min(gy, -T.leg_len) end
    local top = { sa * 4.4, -5.0, ca * 4.4 }
    local fr = 4.4 + (T.foot_r - 4.4) * ease
    local fy = -5.0 + (gy + 5.0) * ease
    local foot = { sa * fr, fy, ca * fr }
    -- the upper sleeve (fat) and the piston (thin) that telescopes out of it
    local mid = { top[1] + (foot[1] - top[1]) * 0.45, top[2] + (foot[2] - top[2]) * 0.45, top[3] + (foot[3] - top[3]) * 0.45 }
    n = n + strut(v, A, d, top, mid, 0.95, HULL)
    n = n + strut(v, A, d, mid, foot, 0.6, RIM)
    -- a brace from higher up the hull
    local hi = { sa * 2.9, -4.7, ca * 2.9 }
    local bm = { top[1] + (foot[1] - top[1]) * 0.55, top[2] + (foot[2] - top[2]) * 0.55, top[3] + (foot[3] - top[3]) * 0.55 }
    n = n + strut(v, A, d, hi, bm, 0.32, RIM)
    -- the foot pad
    v:mesh(assets.unit_box(true), { pos = R.at(d, { foot[1], foot[2] - 0.08, foot[3] }), yaw = d.yaw, scale = { 2.6 * d.scale, 0.3 * d.scale, 2.6 * d.scale },
                     tint = RIM })
    v:mesh(assets.unit_box(true), { pos = R.at(d, { foot[1], foot[2] + 0.04, foot[3] }), yaw = d.yaw + a, scale = { 1.6 * d.scale, 0.06 * d.scale, 1.6 * d.scale },
                     tint = WARN })
    n = n + 2
  end
  return n
end

-- the hull door: the dark recess and sliding belly plate outside, the two leaves inside

function M.door(v, A, o, d)
  local door = o.door
  if not door then return 0 end
  local T = landing.tune().door
  local R = require("view.render")
  local L = avatar.layout()
  local W, H = T.width, L.hatch_door and L.hatch_door.height or 2.4
  local s = d.scale
  local n = 0
  local glow = assets.unit_box(true)
  local open = door.open or 0
  local fl = L.decks[T.deck].floor
  -- inner leaves slide aside along the wall
  local x = W / 4 + open * (W / 2 + 0.1)
  for _, sx in ipairs({ -1, 1 }) do
    v:mesh(assets.unit_box(true), { pos = R.at(d, { sx * x, fl + H / 2, T.sill + 0.16 }), yaw = d.yaw, scale = { W / 2 * s, H * s, 0.07 * s }, tint = HULL })
    v:mesh(assets.unit_box(true), { pos = R.at(d, { sx * x - sx * (W / 4 - 0.06), fl + 1.2, T.sill + 0.12 }), yaw = d.yaw,
                     scale = { 0.07 * s, 0.4 * s, 0.05 * s }, tint = open >= 0.99 and { 0.3, 1, 0.6, 1 } or WARN })
    n = n + 2
  end
  -- the belly plates close the doorway in the hull skin (r 7.5 to the rim); each is two halves that
  -- slide apart sideways and under the skin
  local plates = { { 7.5, -4.9, 11.6, -2.6, 2.7 }, { 11.6, -2.6, 13.0, -0.9, 2.9 } }
  for _, pl in ipairs(plates) do
    local dr, dy = pl[3] - pl[1], pl[4] - pl[2]
    local tl = sm.sqrt(dr * dr + dy * dy)
    local tan = { 0, dy / tl, -dr / tl }
    local nrm = { 0, -dr / tl, -dy / tl } -- outward: down and aft
    local mid = { 0, (pl[2] + pl[4]) / 2, -(pl[1] + pl[3]) / 2 }
    local off = 0.05 - open * 0.35
    local hw = pl[5] / 2
    for _, sx in ipairs({ -1, 1 }) do
      local c = { sx * (hw / 2 + open * (hw + 0.15)), mid[2] + nrm[2] * off, mid[3] + nrm[3] * off }
      v:mesh(glow, { pos = R.at(d, c), yaw = d.yaw + sm.pi, pitch = sm.atan2(dy, dr),
                     scale = { hw * s, 0.1 * s, (tl - 0.05) * s }, tint = HULL })
      v:mesh(glow, { pos = R.at(d, { c[1] - sx * (hw / 2 - 0.1), c[2] + nrm[2] * 0.06, c[3] + nrm[3] * 0.06 }), yaw = d.yaw + sm.pi,
                     pitch = sm.atan2(dy, dr), scale = { 0.08 * s, 0.02 * s, (tl - 0.3) * s }, tint = WARN })
      n = n + 2
    end
  end
  return n
end

-- the stairs: treads slide out of the hull together and settle on the ground
function M.stairs(v, A, o, d)
  local door = o.door
  if not door or (door.stairs or 0) <= 0.01 or (door.run or 0) <= 0 then return 0 end
  local T = landing.tune().door
  local R = require("view.render")
  local L = avatar.layout()
  local hd = require("sim.hulldoor")
  local fl = L.decks[T.deck].floor
  local s = d.scale
  local k = door.stairs
  local ease = k * k * (3 - 2 * k)
  local n = 0
  local steps = door.steps
  local W = T.width - 0.3
  local function pt(u, x)
    local l = hd.local_at(o, u, x)
    -- the whole flight slides out along its own length as it unfolds
    return { l[1], fl + (l[2] - fl) * ease, T.sill - (u * ease) }
  end
  for i = 1, steps do
    local u = T.flat + (i - 0.5) * T.tread
    local c = pt(u, 0)
    v:mesh(assets.unit_box(true), { pos = R.at(d, { c[1], c[2] - 0.04, c[3] }), yaw = d.yaw, scale = { W * s, 0.08 * s, (T.tread - 0.03) * s }, tint = RIM })
    v:mesh(assets.unit_box(true), { pos = R.at(d, { c[1], c[2], c[3] + T.tread / 2 - 0.03 }), yaw = d.yaw, scale = { W * s, 0.05 * s, 0.05 * s }, tint = WARN })
    n = n + 2
  end
  -- a landing at the top, side rails and posts
  local top = pt(T.flat, 0)
  v:mesh(assets.unit_box(true), { pos = R.at(d, { top[1], top[2] - 0.04, top[3] + T.flat / 2 }), yaw = d.yaw, scale = { W * s, 0.08 * s, T.flat * s }, tint = RIM })
  for _, sx in ipairs({ -1, 1 }) do
    local a, b = pt(0.3, sx * (W / 2 + 0.05)), pt(T.flat + door.run, sx * (W / 2 + 0.05))
    a[2], b[2] = a[2] + 0.95, b[2] + 0.95
    n = n + strut(v, A, d, a, b, 0.07, WARN)
    for i = 0, steps, 3 do
      local c = pt(T.flat + i * T.tread, sx * (W / 2 + 0.05))
      n = n + strut(v, A, d, { c[1], c[2], c[3] }, { c[1], c[2] + 0.95, c[3] }, 0.05, RIM)
    end
  end
  return n + 1
end

-- everything for one saucer
function M.draw(v, A, o, d)
  return M.legs(v, A, o, d) + M.door(v, A, o, d) + M.stairs(v, A, o, d)
end

return M
