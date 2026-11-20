-- SPDX-License-Identifier: MIT
-- The station's hangar bay and its tractor beam (OpenSpec add-dock-land-eva).
--
-- Every trader station carries a fixed hangar cell (saucer/dock.lua) above its
-- ring: floor, walls, a ceiling, a force field across the front and a door in
-- the back wall that leads into the station proper (sim/visit.lua). Approach
-- the cell slowly and the station's tractor beam takes over (p.berth with
-- kind "bay", phase "guide"): it tows the saucer along a smooth curve to the
-- mouth, in, and over the dock pad, then the usual settle puts it down on its
-- gear and the pad's clamps close. Pulling away (steering and thrusting out of
-- the bay for a moment) or pressing Land lets go. At lift-off the clamps open
-- and the beam carries the saucer out ("release") before the helm is yours.
local vec = require("lib.vec")
local data = require("lib.data")
local configs = require("sim.config")
local sm = saucer.math
local M = {}

function M.tune() return data.load("saucer/dock.lua") end
local function landing() return require("sim.landing") end
local function game() return require("sim.game") end

local function traders(state) return state.sector.traders or { state.sector.trader } end
M.traders = traders

-- the cell of trader idx in world coordinates
function M.bay(state, idx)
  local T = M.tune()
  local tp = (traders(state)[idx] or traders(state)[1]).pos
  local fy = tp[2] + T.floor_y
  local leg = landing().tune().leg_len
  return {
    idx = idx,
    lo = { tp[1] + T.back_x, fy, tp[3] - T.half_w },
    hi = { tp[1] + T.front_x, fy + T.height, tp[3] + T.half_w },
    floor = fy,
    pad = { tp[1] + T.pad[1], fy, tp[3] + T.pad[2] },
    rest = { tp[1] + T.pad[1], fy + leg, tp[3] + T.pad[2] },
    mouth = { tp[1] + T.mouth_x, fy + leg, tp[3] + T.pad[2] },
    door = { x = tp[1] + T.back_x, z = tp[3], half = T.door.half, height = T.door.height },
    yaw = T.yaw,
  }
end

function M.count(state) return #traders(state) end

-- the eleven solid boxes of one hangar cell at anchor tp: floor, ceiling, side walls and a back wall with its doorway
function M.cell_solids(tp)
  local T = M.tune()
  local out = {}
  local fy = tp[2] + T.floor_y
  local lo = { tp[1] + T.back_x, fy, tp[3] - T.half_w }
  local hi = { tp[1] + T.front_x, fy + T.height, tp[3] + T.half_w }
  local w = T.wall
  local function box(a, c) out[#out + 1] = { a, c } end
  box({ lo[1], lo[2] - 2, lo[3] - w }, { hi[1], lo[2], hi[3] + w })           -- floor
  box({ lo[1], hi[2], lo[3] - w }, { hi[1], hi[2] + w, hi[3] + w })           -- ceiling
  box({ lo[1], lo[2], lo[3] - w }, { hi[1], hi[2], lo[3] })                    -- side walls
  box({ lo[1], lo[2], hi[3] }, { hi[1], hi[2], hi[3] + w })
  local dz, dh = T.door.half, T.door.height
  local dzc = tp[3]
  box({ lo[1] - w, lo[2], lo[3] }, { lo[1], hi[2], dzc - dz })            -- back wall, either side of the door
  box({ lo[1] - w, lo[2], dzc + dz }, { lo[1], hi[2], hi[3] })
  box({ lo[1] - w, lo[2] + dh, dzc - dz }, { lo[1], hi[2], dzc + dz })   -- lintel
  box({ lo[1] - 3.5, lo[2] - 0.01, dzc - dz }, { lo[1] - w, lo[2], dzc + dz })  -- the sill's tongue
  box({ lo[1] - 3.5, lo[2], dzc - dz - w }, { lo[1] - w, hi[2], dzc - dz })      -- the short passage behind the door
  box({ lo[1] - 3.5, lo[2], dzc + dz }, { lo[1] - w, hi[2], dzc + dz + w })
  box({ lo[1] - 3.5 - w, lo[2], dzc - dz - w }, { lo[1] - 3.5, hi[2], dzc + dz + w })
  return out
end

-- the solid boxes of every bay
function M.solids(state)
  local out = {}
  for i, tr in ipairs(traders(state)) do
    for _, b in ipairs(M.cell_solids(tr.pos)) do out[#out + 1] = b end
  end
  return out
end

-- which bay contains pos (inside the cell, or on its door passage)? -> idx, bay
function M.inside(state, pos, pad)
  pad = pad or 0
  for i = 1, M.count(state) do
    local b = M.bay(state, i)
    if pos[1] >= b.lo[1] - 3.5 - pad and pos[1] <= b.hi[1] + pad and pos[2] >= b.lo[2] - 3 - pad and pos[2] <= b.hi[2] + pad
       and pos[3] >= b.lo[3] - pad and pos[3] <= b.hi[3] + pad then
      return i, b
    end
  end
  return nil
end

local function smooth(t) t = vec.clamp(t, 0, 1) return t * t * (3 - 2 * t) end

local function lerp(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t } end

local function bezier(a, b, c, d, t)
  local u = 1 - t
  local k1, k2, k3, k4 = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
  return { a[1] * k1 + b[1] * k2 + c[1] * k3 + d[1] * k4, a[2] * k1 + b[2] * k2 + c[2] * k3 + d[2] * k4,
           a[3] * k1 + b[3] * k2 + c[3] * k3 + d[3] * k4 }
end

-- the tow's position at progress s (0..1): a curve to the mouth, then straight in
-- and over the pad. Pure function of the berth's recorded path.
function M.guide_pose(b, s)
  local P = b.path
  local split = P.split
  local pos
  local e = smooth(s)
  if e < split then
    pos = bezier(P.p0, P.p1, P.p2, P.mouth, e / split)
  else
    pos = lerp(P.mouth, P.hover, (e - split) / (1 - split))
  end
  local yaw = sm.wrap(P.yaw0 + sm.wrap(b.yaw - P.yaw0) * smooth(s / 0.75))
  return pos, yaw
end

-- is the saucer in a place the beam can take it from? -> idx or nil, why
function M.can_capture(state, p)
  local ship = p.ship
  local c = configs.get(ship.size)
  if not c.interior or ship.morph or p.berth or p.tractor or p.clamped_by or p.site ~= 0 or p.mode ~= "helm" then return nil end
  local T = M.tune()
  for i = 1, M.count(state) do
    local b = M.bay(state, i)
    local d = vec.dist(ship.pos, b.mouth)
    if d <= T.capture_r and ship.pos[1] >= b.mouth[1] - 20 and vec.len(ship.vel) <= T.capture_speed then
      -- the bay must be clear of other saucers
      local r, hh = require("sim.ship").dims(ship)
      if not game().blocked(state, p, b.rest, r, hh, 0) then return i, b end
    end
  end
  return nil
end

-- the tow begins
function M.start(state, p, idx, ctx, why)
  local T = M.tune()
  local ship = p.ship
  local b = M.bay(state, idx)
  local dist = vec.dist(ship.pos, b.mouth)
  local hover = { b.rest[1], b.rest[2] + T.approach_x, b.rest[3] }
  local lenA = dist * 1.1
  local lenB = vec.dist(b.mouth, hover)
  local total = vec.clamp((lenA + lenB) / T.guide_speed, T.guide_min, T.guide_max)
  local h = vec.fwd(ship.yaw)
  local leg = 0.3 * dist
  p.berth = {
    phase = "guide", kind = "bay", legs = 0, t = 0, bay = idx, clamp = 0, cancel = 0, site = 0,
    ref = b.floor, feet = { b.floor, b.floor, b.floor }, at = vec.copy(b.rest), yaw = b.yaw, total = total,
    path = { p0 = vec.copy(ship.pos), p1 = { ship.pos[1] + h[1] * leg, ship.pos[2], ship.pos[3] + h[3] * leg },
             p2 = { b.mouth[1] + math.min(30, dist * 0.4), b.mouth[2], b.mouth[3] }, mouth = b.mouth, hover = hover,
             split = lenA / (lenA + lenB), yaw0 = ship.yaw },
  }
  ship.vel = { 0, 0, 0 }
  ship.bank = 0
  p.dock_off = false
  ctx.msg(state, p, why or "STATION TRACTOR BEAM: you are being guided into the hangar bay. Pull away to cancel.")
  ctx.fx(state, p, "grow")
  saucer.events.emit({ type = "dock_capture", player = p.index, trader = idx })
  return true
end

-- every helm tick with no berth: should the beam take over?
function M.auto(state, p, dt, ctx)
  local ship = p.ship
  if p.dock_off then
    -- after a cancel: leave the beam's reach first
    local near = false
    for i = 1, M.count(state) do
      if vec.dist(ship.pos, M.bay(state, i).mouth) <= M.tune().capture_r + M.tune().recapture then near = true end
    end
    if not near then p.dock_off = false end
    return false
  end
  local idx = M.can_capture(state, p)
  if idx then return M.start(state, p, idx, ctx) end
  return false
end

-- pulling away: is the player's thrust carrying the saucer out of the bay?
local function pulling(state, p, cmd, b)
  local c = configs.get(p.ship.size)
  local flight = require("sim.flight")
  local want = flight.want(p.ship, cmd:axis("move_x"), cmd:axis("move_z"), cmd:axis("lift"), c.speed)
  local len = vec.len(want)
  if len < c.speed * 0.4 then return false end
  local bay = M.bay(state, b.bay)
  local away = vec.sub(p.ship.pos, bay.mouth)
  local al = vec.len(away)
  if al < 1e-6 then return false end
  return vec.dot(want, away) / (len * al) >= M.tune().cancel_dot
end

-- watch the stick while the beam holds the saucer
function M.watch(state, p, cmd, dt, ctx)
  local b = p.berth
  if not b or b.kind ~= "bay" or b.phase ~= "guide" or p.mode ~= "helm" then return end
  local T = M.tune()
  if pulling(state, p, cmd, b) then b.cancel = b.cancel + dt else b.cancel = math.max(0, b.cancel - dt) end
  if b.cancel >= T.cancel_hold then M.cancel(state, p, ctx) end
end

-- let go: the beam releases, the helm is yours (and it will not grab you again until you leave)
function M.cancel(state, p, ctx)
  local b = p.berth
  if not b or b.kind ~= "bay" or (b.phase ~= "guide" and b.phase ~= "descend") then return false end
  p.berth = false
  p.dock_off = true
  p.ship.vel = { 0, 0, 0 }
  ctx.msg(state, p, "You pull away: the station's beam lets go. Fly clear, or press Land to be towed in.")
  ctx.fx(state, p, "denied")
  saucer.events.emit({ type = "dock_cancel", player = p.index })
  return true
end

-- the berth state machine's bay phases; -> true when it owned the ship this tick
function M.step(state, p, dt, ctx)
  local b = p.berth
  local ship = p.ship
  local T = M.tune()
  if b.phase == "guide" then
    b.t = b.t + dt
    local s = vec.clamp(b.t / b.total, 0, 1)
    local pos, yaw = M.guide_pose(b, s)
    ship.pos, ship.yaw = pos, yaw
    ship.pitch = ship.pitch * (1 - math.min(1, dt * 2))
    if s >= 1 then
      b.phase, b.t = "descend", 0
      ship.pos = { b.at[1], b.at[2] + T.approach_x, b.at[3] }
      ctx.msg(state, p, "In the bay. Settling onto the dock pad...")
    end
    return true
  elseif b.phase == "release" then
    local bay = M.bay(state, b.bay)
    local x = ship.pos[1] + T.release_speed * dt
    ship.pos = { x, ship.pos[2], ship.pos[3] }
    b.legs = 0
    if x >= bay.hi[1] + T.release_reach then
      p.berth = false
      p.dock_off = true
      ctx.msg(state, p, "The beam lets go. The helm is yours.")
    end
    return true
  end
  return false
end

-- clamps: 0..1 closing on the feet while landed on the pad; the berth calls this each tick
function M.clamps(b, dt)
  local T = M.tune()
  if b.kind ~= "bay" then return end
  if b.phase == "landed" then b.clamp = math.min(1, (b.clamp or 0) + dt / T.clamp_time)
  else b.clamp = math.max(0, (b.clamp or 0) - dt / T.clamp_time) end
end

-- the HUD's line at the helm while the beam or the gear holds the saucer (or is near) -> where, hint or nil
function M.hint(state, p)
  local b = p.berth
  if b then
    if b.phase == "guide" then return "TRACTOR BEAM", "GUIDING YOU INTO THE BAY  PULL AWAY OR L: CANCEL" end
    if b.phase == "release" then return "TRACTOR BEAM", "CARRYING YOU OUT" end
    if b.phase == "descend" then return b.kind == "bay" and "DOCK PAD" or "LANDING", "SETTLING ON THE GEAR  L: ABORT" end
    if b.phase == "lift" then return b.kind == "bay" and "DOCK PAD" or "LANDED", "LIFTING OFF" end
    if b.kind == "bay" then return "DOCKED: THE CLAMPS ARE CLOSED", "L: LIFT OFF  USE: STAND UP" end
    return "LANDED ON ITS GEAR", "L: LIFT OFF  USE: STAND UP"
  end
  if p.site == 0 and p.mode == "helm" and configs.get(p.ship.size).interior then
    local idx = M.can_capture(state, p)
    if idx then return "AT THE HELM", "L: ASK THE STATION FOR A TOW  USE: STAND UP" end
  end
  return nil
end

-- ---- through the bay's back door into the station, and back ----

local EYE_DOOR = 1.5
-- on foot in a bay, walking into the doorway: into the station's concourse
function M.door_step(state, p, ctx)
  local ex = p.excursion
  if not ex or p.mode ~= "foot" or p.site ~= 0 then return false end
  local idx, bay = M.inside(state, ex.body.pos)
  if not idx then return false end
  local b = ex.body.pos
  if b[1] > bay.lo[1] + 0.9 or math.abs(b[3] - bay.door.z) > bay.door.half then return false end
  if ex.coin == "fold" or ex.coin == "grow" then
    ctx.msg(state, p, "Wait for the saucer to finish reshaping")
    return false
  end
  return M.enter_station(state, p, idx, bay, ctx)
end

function M.enter_station(state, p, idx, bay, ctx)
  local visit = require("sim.visit")
  local sg = require("sim.stationgen")
  local ex = p.excursion
  local ship = p.ship
  local seed = sg.seed_for(state, idx)
  local L = sg.get(seed)
  local h = sg.hangars(L)[1]
  local bs = visit.bays(state, ship, idx)
  local coin = ex.coin == "stand" and "docked" or ex.coin
  p.station = {
    trader = idx, seed = seed, t = 0, hand_t = 0, coin = coin, from = ship.size, held = false,
    body = { pos = { 0, 0, 2.4 }, yaw = 0, pitch = -0.05 },
    bays = bs, area = h and h.id or 1, stolen = 0, caught = 0, dock = idx,
    thief = { pos = { L.thief.home[1], L.thief.home[2] }, yaw = 0, mode = "lurk", t = 0, cool = 0,
              working = visit.thief_roll(state, p) },
  }
  p.excursion = false
  p.mode = "foot"
  p.suited = false
  ctx.msg(state, p, "Through the bay door into the station.")
  ctx.fx(state, p, "door")
  saucer.events.emit({ type = "dock_enter", player = p.index, trader = idx })
  return true
end

-- on foot in the station, back through the doorway to the bay (called by visit.step)
function M.station_door_step(state, p, ctx)
  local st = p.station
  if not st or not st.dock then return false end
  local b = st.body.pos
  if b[3] > 0.3 or math.abs(b[1]) > 2.5 then return false end
  if st.coin == "fold" or st.coin == "grow" or st.coin == "thief" or st.coin == "fence" then return false end
  local bay = M.bay(state, st.dock)
  local ship = p.ship
  local coin = st.coin == "docked" and "stand" or st.coin
  p.excursion = {
    site = 0, t = 0, coin = coin, from = ship.size, hand_t = 0, held = false,
    body = { pos = { bay.lo[1] + 2.4, bay.floor, bay.door.z }, yaw = sm.pi / 2, pitch = -0.05, vy = 0, crouch = false, ground = true },
    path = {}, work = false, warned = 0, area = "hall", deploy = false,
  }
  p.excursion.path[1] = vec.copy(p.excursion.body.pos)
  p.station = false
  p.mode = "foot"
  p.suited = false
  p.panel = false
  ctx.msg(state, p, coin == "stand" and "Back in the bay. The Villa waits on its pad: walk to the foot of its stairs to board."
    or "Back in the bay.")
  ctx.fx(state, p, "door")
  return true
end

return M
