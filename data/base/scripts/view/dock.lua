-- SPDX-License-Identifier: MIT
-- Drawing the station's hangar bay, its tractor beam and the pad's clamps
-- (OpenSpec add-dock-land-eva). Render-only: reads the sector, o.berth and
-- o.ship, writes nothing. Flat emissive boxes like view/gear.lua.
local vec = require("lib.vec")
local dock = require("sim.dock")
local landing = require("sim.landing")
local assets = require("view.assets")
local sm = saucer.math
local M = {}

M.NEAR = 700   -- bays this close to the camera are drawn

local WALL = { 0.34, 0.37, 0.45, 1 }
local FLOOR = { 0.26, 0.29, 0.34, 1 }
local STRIP = { 0.35, 0.9, 1.0, 1 }
local WARN = { 1.0, 0.75, 0.15, 1 }
local BEAM = { 0.35, 0.85, 1.0 }

local function box(v, a, b, tint, ghost)
  local c = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }
  local s = { math.max(0.02, b[1] - a[1]), math.max(0.02, b[2] - a[2]), math.max(0.02, b[3] - a[3]) }
  if ghost then
    v:mesh(assets.unit_box(true), { pos = c, scale = s, ghost = true, tint = tint })
  else
    v:mesh(assets.unit_box(true), { pos = c, scale = s, tint = tint })
  end
  return 1
end

-- a thin line between two world points
local function line(v, a, b, w, tint)
  local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
  local hz = sm.sqrt(dx * dx + dz * dz)
  local len = sm.sqrt(hz * hz + dy * dy)
  if len < 1e-3 then return 0 end
  v:mesh(assets.unit_box(true), { pos = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }, yaw = sm.atan2(dx, dz),
                                  pitch = sm.atan2(dy, hz), scale = { w, w, len }, ghost = true, tint = tint })
  return 1
end

-- is any saucer being towed in or out of this bay right now? -> the saucer or nil
local function towed(state, idx)
  for _, p in ipairs(state.players) do
    local b = p.berth
    if b and b.kind == "bay" and b.bay == idx and (b.phase == "guide" or b.phase == "descend" or b.phase == "release") then return p end
  end
  return nil
end

-- the front frame's four corners (the beam emitters)
function M.emitters(bay)
  local x = bay.hi[1]
  return { { x, bay.lo[2] + 0.4, bay.lo[3] + 0.5 }, { x, bay.lo[2] + 0.4, bay.hi[3] - 0.5 },
           { x, bay.hi[2] - 0.4, bay.lo[3] + 0.5 }, { x, bay.hi[2] - 0.4, bay.hi[3] - 0.5 } }
end

function M.bay(v, A, state, idx, bay, tick)
  local n = 0
  local lo, hi = bay.lo, bay.hi
  local boxes = dock.solids(state)
  local per = #boxes // dock.count(state)
  for k = (idx - 1) * per + 1, idx * per do
    local b = boxes[k]
    n = n + box(v, b[1], b[2], (k - (idx - 1) * per) == 1 and FLOOR or WALL)
  end
  -- the dock pad: a square plate with warning edges and a circle of lights
  local pd = bay.pad
  n = n + box(v, { pd[1] - 15, lo[2], pd[3] - 15 }, { pd[1] + 15, lo[2] + 0.12, pd[3] + 15 }, { 0.2, 0.22, 0.27, 1 })
  for _, s in ipairs({ -1, 1 }) do
    n = n + box(v, { pd[1] + s * 15 - 0.25, lo[2] + 0.12, pd[3] - 15 }, { pd[1] + s * 15 + 0.25, lo[2] + 0.2, pd[3] + 15 }, WARN)
    n = n + box(v, { pd[1] - 15, lo[2] + 0.12, pd[3] + s * 15 - 0.25 }, { pd[1] + 15, lo[2] + 0.2, pd[3] + s * 15 + 0.25 }, WARN)
  end
  -- lit strips along the ceiling and the floor's edges
  for i = 0, 5 do
    local x = lo[1] + 5 + i * 8
    n = n + box(v, { x, hi[2] - 0.1, lo[3] + 4 }, { x + 0.5, hi[2], hi[3] - 4 }, STRIP)
  end
  for _, z in ipairs({ lo[3] + 0.05, hi[3] - 0.25 }) do
    n = n + box(v, { lo[1], lo[2] + 0.1, z }, { hi[1], lo[2] + 0.3, z + 0.2 }, STRIP)
  end
  -- the station door in the back wall: a lit frame and a warm glow beyond
  local d = bay.door
  n = n + box(v, { lo[1] - 0.2, lo[2], d.z - d.half - 0.3 }, { lo[1] + 0.1, lo[2] + d.height + 0.3, d.z - d.half }, WARN)
  n = n + box(v, { lo[1] - 0.2, lo[2], d.z + d.half }, { lo[1] + 0.1, lo[2] + d.height + 0.3, d.z + d.half + 0.3 }, WARN)
  n = n + box(v, { lo[1] - 0.2, lo[2] + d.height, d.z - d.half }, { lo[1] + 0.1, lo[2] + d.height + 0.3, d.z + d.half }, WARN)
  n = n + box(v, { lo[1] - 3.4, lo[2] + 0.05, d.z - d.half }, { lo[1] - 3.3, lo[2] + d.height, d.z + d.half }, { 1.0, 0.85, 0.6, 1 })
  -- a bright frame round the mouth, amber while the beam is working
  local fcol = towed(state, idx) and WARN or STRIP
  n = n + box(v, { hi[1] - 0.3, lo[2] - 0.6, lo[3] - 1.2 }, { hi[1] + 0.8, lo[2] + 0.5, hi[3] + 1.2 }, fcol)
  n = n + box(v, { hi[1] - 0.3, hi[2] - 0.5, lo[3] - 1.2 }, { hi[1] + 0.8, hi[2] + 0.6, hi[3] + 1.2 }, fcol)
  n = n + box(v, { hi[1] - 0.3, lo[2], lo[3] - 1.2 }, { hi[1] + 0.8, hi[2], lo[3] + 0.2 }, fcol)
  n = n + box(v, { hi[1] - 0.3, lo[2], hi[3] - 0.2 }, { hi[1] + 0.8, hi[2], hi[3] + 1.2 }, fcol)
  -- the force field across the front
  local pulse = 0.10 + 0.04 * sm.sin(tick * 0.05)
  n = n + box(v, { hi[1] - 0.05, lo[2], lo[3] }, { hi[1] + 0.05, hi[2], hi[3] }, { 0.35, 0.8, 1, pulse }, true)
  -- the gantry back to the station's spire, and the beacons on the front corners
  local tp = state.sector.traders and state.sector.traders[idx].pos or state.sector.trader.pos
  n = n + box(v, { tp[1] + 6, lo[2] + 2, tp[3] - 2.5 }, { lo[1] - 3.5, lo[2] + 7, tp[3] + 2.5 }, WALL)
  local on = towed(state, idx)
  for i, e in ipairs(M.emitters(bay)) do
    n = n + box(v, { e[1] - 0.6, e[2] - 0.6, e[3] - 0.6 }, { e[1] + 0.6, e[2] + 0.6, e[3] + 0.6 }, on and WARN or STRIP)
    v:billboard(A.tex.glow, e, on and 9 or 4, { palette = A.pal.base, tint = on and { 1, 0.8, 0.3, 0.55 } or { 0.4, 0.9, 1, 0.35 } })
  end
  return n
end

-- the tractor beam: four rays from the front frame to the saucer it is holding
function M.beam(v, A, state, idx, bay, tick)
  local p = towed(state, idx)
  if not p then return 0 end
  local pos = p.ship.pos
  local n = 0
  local flick = 0.28 + 0.12 * sm.sin(tick * 0.2)
  for _, e in ipairs(M.emitters(bay)) do
    n = n + line(v, e, { pos[1], pos[2] - 2, pos[3] }, 0.5, { BEAM[1], BEAM[2], BEAM[3], flick })
  end
  return n
end

function M.draw(v, A, state, cam)
  local n = 0
  for i = 1, dock.count(state) do
    local bay = dock.bay(state, i)
    if vec.dist(cam.pos, bay.pad) < M.NEAR then
      n = n + M.bay(v, A, state, i, bay, state.tick) + M.beam(v, A, state, i, bay, state.tick)
    end
  end
  return n
end

-- the pad's clamps on a saucer's feet: two jaws per foot close in as b.clamp rises
function M.clamps(v, A, o)
  local b = o.berth
  if not b or b.kind ~= "bay" or (b.clamp or 0) <= 0.01 then return 0 end
  local ship = o.ship
  local k = b.clamp
  local ease = k * k * (3 - 2 * k)
  local n = 0
  for i, f in ipairs(landing.feet_xz(ship.pos, ship.yaw)) do
    local a = landing.tune().azimuth[i] + ship.yaw
    local tx, tz = sm.cos(a), -sm.sin(a)   -- the tangent at the foot
    for _, s in ipairs({ -1, 1 }) do
      local off = 1.5 + (1 - ease) * 1.7
      v:mesh(assets.unit_box(true), { pos = { f[1] + tx * off * s, b.ref + 0.5, f[2] + tz * off * s }, yaw = a,
                                      scale = { 0.7, 0.9, 2.2 }, tint = WARN })
      n = n + 1
    end
  end
  return n
end

return M
