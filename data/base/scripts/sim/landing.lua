-- SPDX-License-Identifier: MIT
-- Landing the Villa (OpenSpec add-dock-land-eva). The Villa sets down on three
-- telescoping legs on any reasonably flat surface: the helm's Land button
-- probes the ground under the three feet and the hull's axis, refuses a slope
-- or a drop-off, and then takes over: the hull settles at a walking pace, the
-- gear swings out and the saucer is anchored (p.berth). While anchored it
-- holds its pose exactly, even when the surface it stands on moves. Land (or
-- thrust up) lifts it off again with the hatch shut.
--
-- p.berth = { phase = "descend" | "landed" | "lift", kind = "surface" | "bay",
--   legs = 0..1, ref = ground y, feet = { y1, y2, y3 }, at = { x, y, z } (rest pose),
--   yaw, site, t, frame = { ... } (moving surfaces, see M.frames) }
local vec = require("lib.vec")
local data = require("lib.data")
local configs = require("sim.config")
local avatar = require("sim.avatar")
local sm = saucer.math
local M = {}

function M.tune() return data.load("saucer/landing.lua") end
local function game() return require("sim.game") end

-- moving or turning surfaces: a frame function returns the offset and yaw a
-- surface has gained since the saucer touched down. Systems register theirs by
-- kind; nothing in the shipped sites moves yet (the hook is covered by tests).
M.frames = {}
function M.frame_pose(state, p, b)
  local f = b.frame and M.frames[b.frame.kind]
  if not f then return { 0, 0, 0 }, 0 end
  return f(state, p, b)
end

-- the three foot positions (world x, z) for a hull at pos with yaw
function M.feet_xz(pos, yaw)
  local T = M.tune()
  local out = {}
  for i, a in ipairs(T.azimuth) do
    local o = avatar.rot(yaw, { sm.sin(a) * T.foot_r, 0, sm.cos(a) * T.foot_r })
    out[i] = { pos[1] + o[1], pos[3] + o[3] }
  end
  return out
end

-- first surface under (x, y, z): height, normal y -> nil when nothing is in range
function M.ground(x, y, z, range)
  local hit = saucer.physics.raycast({ x, y, z }, { 0, -1, 0 }, range or M.tune().range, 1)
  if not hit then return nil end
  return y - hit.t, hit.normal and hit.normal[2] or 1
end

M.REASONS = {
  size = "Only the Villa has landing gear",
  busy = "Hull is still reshaping",
  beam = "Let go of the beam first",
  fast = "Too fast to land: slow down",
  void = "No ground within reach of the gear",
  wall = "Not a landing surface: the ground under the gear is not level",
  slope = "Too steep to land",
  room = "No room to set the Villa down here",
  clamped = "Clamped: shake the Clamp off first",
  hatch = "Close the hatch first",
  site = "Wait for the saucer to settle",
}

-- probe the ground under the hull at pos (default: where it is) -> report
-- { ok, why, ref, feet = {y1,y2,y3}, centre, spread, slope (deg), target = hull centre y, dist = hull centre height over ref }
function M.probe(state, p, pos, yaw)
  local T = M.tune()
  local ship = p.ship
  pos = pos or ship.pos
  yaw = yaw or ship.yaw
  local feet = M.feet_xz(pos, yaw)
  local ys, up = {}, 1
  for i, f in ipairs(feet) do
    local g, ny = M.ground(f[1], pos[2], f[2])
    if not g then return { ok = false, why = "void" } end
    ys[i] = g
    up = math.min(up, ny)
  end
  local gc, nyc = M.ground(pos[1], pos[2], pos[3])
  if not gc then return { ok = false, why = "void" } end
  up = math.min(up, nyc)
  local hi, lo = math.max(ys[1], ys[2], ys[3], gc), math.min(ys[1], ys[2], ys[3], gc)
  local spread = hi - lo
  local rep = { ref = hi, feet = ys, centre = gc, spread = spread, slope = sm.atan2(spread, T.span) * 180 / sm.pi,
                target = hi + T.leg_len, dist = pos[2] - (hi + T.leg_len), up = up }
  if up < T.min_up then rep.ok, rep.why = false, "wall"
  elseif spread > T.max_spread or rep.slope > T.max_slope_deg then rep.ok, rep.why = false, "slope"
  else rep.ok = true end
  return rep
end

-- can p begin landing? -> ok, why, report
function M.can_land(state, p)
  local ship = p.ship
  local c = configs.get(ship.size)
  if not c.interior then return false, "size" end
  if ship.morph then return false, "busy" end
  if p.tractor then return false, "beam" end
  if p.clamped_by then return false, "clamped" end
  if vec.len(ship.vel) > M.tune().speed_max then return false, "fast" end
  if p.berth then return false, "site" end
  local rep = M.probe(state, p)
  if not rep.ok then return false, rep.why, rep end
  -- room for the hull at its resting height, not only a flat patch
  local r, hh = require("sim.ship").dims(ship)
  local rest = { ship.pos[1], rep.target, ship.pos[3] }
  if game().blocked(state, p, rest, r, hh, M.tune().clearance_margin) then return false, "room", rep end
  return true, nil, rep
end

-- begin landing (the helm's Land button)
function M.start(state, p, ctx)
  local ok, why, rep = M.can_land(state, p)
  if not ok then
    if why == "site" then return false end
    ctx.msg(state, p, M.REASONS[why] or "Cannot land here")
    ctx.fx(state, p, "denied")
    return false, why
  end
  local ship = p.ship
  p.berth = { phase = "descend", kind = "surface", legs = 0, t = 0, ref = rep.ref, feet = rep.feet,
              at = { ship.pos[1], rep.target, ship.pos[3] }, yaw = ship.yaw, site = p.site }
  ship.vel = { 0, 0, 0 }
  ship.bank = 0
  ctx.msg(state, p, string.format("LANDING: gear down, settling (%.0f m to the ground). Land again to abort.", rep.dist))
  ctx.fx(state, p, "grow")
  return true
end

function M.landed(p) return p.berth and p.berth.phase == "landed" or false end
function M.anchored(p) return p.berth ~= nil and p.berth ~= false end

local function smooth(t) return t * t * (3 - 2 * t) end

-- how far the legs are out (0..1) for the renderer and the door
function M.legs(p) return p.berth and p.berth.legs or 0 end

-- one tick of the berth state machine: moves the saucer. -> true when it owns the ship this tick
function M.step(state, p, dt, ctx)
  local b = p.berth
  if not b then return false end
  local T = M.tune()
  local ship = p.ship
  ship.vel = { 0, 0, 0 }
  b.t = b.t + dt
  if b.phase == "descend" then
    local d = ship.pos[2] - b.at[2]
    local v = vec.clamp(T.settle_speed[1] + d * 0.5, T.settle_speed[1], T.settle_speed[2])
    local y = math.max(b.at[2], ship.pos[2] - v * dt)
    ship.pos = { b.at[1], y, b.at[3] }
    ship.yaw = b.yaw
    -- the legs swing out as it gets close (and in any case within gear_time)
    local want = vec.clamp(1 - (y - b.at[2]) / 6, 0, 1)
    b.legs = math.min(1, math.max(b.legs, want, math.min(1, b.t / T.gear_time) * 0.5))
    if y <= b.at[2] + 1e-9 then
      b.phase, b.t, b.legs = "landed", 0, 1
      ship.pos = { b.at[1], b.at[2], b.at[3] }
      ctx.msg(state, p, "Touchdown. The Villa stands on its gear: walk aft to the hull hatch.")
      ctx.fx(state, p, "bank")
      saucer.events.emit({ type = "landed", player = p.index, site = p.site })
    end
    return true
  elseif b.phase == "landed" then
    local f, yaw = M.frame_pose(state, p, b)
    ship.pos = { b.at[1] + f[1], b.at[2] + f[2], b.at[3] + f[3] }
    ship.yaw = sm.wrap(b.yaw + yaw)
    b.legs = 1
    return true
  else -- lift
    b.target_y = b.target_y or (b.at[2] + T.lift_height)
    local y = math.min(b.target_y, ship.pos[2] + T.lift_speed * dt)
    ship.pos = { ship.pos[1], y, ship.pos[3] }
    b.legs = math.max(0, b.legs - dt / T.gear_time)
    if y >= b.target_y - 1e-9 and b.legs <= 0 then
      p.berth = false
      ctx.msg(state, p, "Gear up. The helm is yours.")
    end
    return true
  end
end

-- take off: needs the hatch shut and the pilot at the helm
function M.lift_off(state, p, ctx)
  local b = p.berth
  if not b or b.phase ~= "landed" then return false end
  local d = p.door
  if d and (d.open > 0 or d.stairs > 0 or d.goal ~= 0) then
    ctx.msg(state, p, M.REASONS.hatch)
    ctx.fx(state, p, "denied")
    return false
  end
  if p.mode ~= "helm" then return false end
  b.phase, b.t, b.target_y = "lift", 0, b.at[2] + M.tune().lift_height
  ctx.msg(state, p, "Lifting off: gear retracting.")
  ctx.fx(state, p, "grow")
  return true
end

-- the Land button at the helm
function M.press(state, p, ctx)
  local b = p.berth
  if not b then return M.start(state, p, ctx) end
  if b.phase == "landed" then return M.lift_off(state, p, ctx) end
  if b.phase == "descend" then
    b.phase, b.t, b.target_y = "lift", 0, p.ship.pos[2] + 2
    ctx.msg(state, p, "Landing aborted: gear up.")
    return true
  end
  return false
end

-- the player's own hull volume as seen from outside: radius of the hull at
-- height hy (hull-local), from the lathe profile of meshes/saucer.lua
local PROFILE = { { 2.7, -5.6 }, { 7.5, -4.9 }, { 11.6, -2.6 }, { 13.0, -0.9 } }
function M.hull_radius(hy)
  if hy < PROFILE[1][2] then return 0 end
  for i = 1, #PROFILE - 1 do
    local a, c = PROFILE[i], PROFILE[i + 1]
    if hy <= c[2] then return a[1] + (c[1] - a[1]) * (hy - a[2]) / (c[2] - a[2]) end
  end
  return 13.0
end

-- push a standing person (feet y, head y) out of the landed hull and the
-- stairs' footprint -> x, z
function M.push_out(p, x, y, z, head)
  local b = p.berth
  if not b or b.phase == "descend" then return x, z end
  local ship = p.ship
  -- the stairs' footprint: a person cannot stand under the treads (hull-local frame)
  local d = p.door
  if d and d.run and d.run > 0 and d.stairs > 0.05 then
    local T = M.tune().door
    local rel = avatar.rot(-ship.yaw, { x - ship.pos[1], 0, z - ship.pos[3] })
    local u = T.sill - rel[3]
    local half = T.width / 2 + 0.35
    if u > 0 and u < T.flat + d.run - 0.5 and math.abs(rel[1]) < half then
      local sx = rel[1] >= 0 and half or -half
      local o = avatar.rot(ship.yaw, { sx, 0, rel[3] })
      x, z = ship.pos[1] + o[1], ship.pos[3] + o[3]
    end
  end
  local dx, dz = x - ship.pos[1], z - ship.pos[3]
  local r = sm.sqrt(dx * dx + dz * dz)
  local hy = head - ship.pos[2]
  local lim = M.hull_radius(hy) + 0.35
  if hy > -5.6 and r < lim then
    local k = (r < 1e-6) and 0 or lim / r
    if k == 0 then dx, dz = lim, 0 else dx, dz = dx * k, dz * k end
    return ship.pos[1] + dx, ship.pos[3] + dz
  end
  return x, z
end

return M
