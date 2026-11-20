-- SPDX-License-Identifier: MIT
-- The hull door (OpenSpec add-dock-land-eva): a hatch in the lower deck's
-- aft wall with stairs that unfold from the belly to the ground. You walk out
-- and back in through it in first person.
--
-- Rules: only a landed saucer can open it (never while flying, reshaping or
-- on the beam); in vacuum or toxic air it opens only once you are suited (the
-- airlock cycle seals your helmet first). Like the home's sliding doors it
-- decides with hysteresis (opens within `reach_out` of the stairs' foot, only
-- starts to close once everyone is `close_margin` farther) and stays open for
-- at least `min_open` seconds, so a body swaying on the trigger edge cannot
-- make it flap. Opening sequence: leaves slide apart, then the treads slide
-- out; closing runs it backwards.
--
-- p.door = { open, stairs (0..1), goal (0/1), hold (s), on (walking the
--   stairs), cycle (airlock seconds or false), drop, run, steps (stairs
--   geometry for the ground at the berth) }
local vec = require("lib.vec")
local avatar = require("sim.avatar")
local landing = require("sim.landing")
local env = require("sim.env")
local sm = saucer.math
local M = {}

function M.tune() return landing.tune().door end

function M.ensure(p)
  if not p.door then p.door = { open = 0, stairs = 0, goal = 0, hold = 0, on = false, cycle = false, drop = 0, run = 0, steps = 0 } end
  return p.door
end

M.REASONS = {
  flying = "Land first: the hatch will not open while the saucer is flying",
  ground = "The stairs cannot reach the ground here",
  busy = "Hull is still reshaping",
  suit = "Sealing the suit...",
  air = "The air outside is not breathable: suit up first",
}

-- the geometry of the stairs for the ground under the berth -> { drop, run, steps } or nil, why
function M.geometry(state, p)
  local b = p.berth
  if not (b and b.phase == "landed") then return nil, "flying" end
  local T = M.tune()
  local ship = p.ship
  local L = avatar.layout()
  local deck_y = ship.pos[2] + L.decks[T.deck].floor
  local function ground_at(u)
    local o = avatar.rot(ship.yaw, { 0, 0, T.sill - u })
    return landing.ground(ship.pos[1] + o[1], deck_y + 0.5, ship.pos[3] + o[3], T.drop_max + 2)
  end
  local run = 6.0
  local g
  for _ = 1, 3 do
    g = ground_at(T.flat + run)
    if not g then return nil, "ground" end
    local n = math.ceil((deck_y - g) / T.rise - 1e-9)
    run = n * T.tread
  end
  g = ground_at(T.flat + run)
  if not g then return nil, "ground" end
  local drop = deck_y - g
  if drop < T.drop_min or drop > T.drop_max then return nil, "ground" end
  local n = math.max(1, math.ceil(drop / T.rise - 1e-9))
  return { drop = drop, run = n * T.tread, steps = n }
end

-- hull-local point on the stairs' axis at distance u past the sill, and its height
function M.local_at(p, u, x)
  local T = M.tune()
  local L = avatar.layout()
  local d = p.door
  local y = L.decks[T.deck].floor
  local v = u - T.flat
  if v > 0 and d.run > 0 then y = y - d.drop * math.min(1, v / d.run) end
  return { x or 0, y, T.sill - u }
end

function M.total(p) return M.tune().flat + p.door.run end

-- where the foot of the stairs is in the world (feet height)
function M.foot_world(state, p)
  local ship = p.ship
  local loc = M.local_at(p, M.total(p), 0)
  local o = avatar.rot(ship.yaw, loc)
  return { ship.pos[1] + o[1], ship.pos[2] + o[2], ship.pos[3] + o[3] }
end

-- can the hatch be opened now? -> ok, why
function M.can_open(state, p)
  local ship = p.ship
  if p.mode == "helm" then return false, "flying" end
  if ship.morph then return false, "busy" end
  if not landing.landed(p) then return false, "flying" end
  local g, why = M.geometry(state, p)
  if not g then return false, why end
  return true, nil, g
end

-- ask for the hatch to open (inside: the Use panel; outside: walking up)
function M.request_open(state, p, ctx, auto)
  local d = M.ensure(p)
  if d.goal == 1 then return true end
  local ok, why, g = M.can_open(state, p)
  if not ok then
    if not auto then
      ctx.msg(state, p, M.REASONS[why] or "The hatch will not open")
      ctx.fx(state, p, "denied")
    end
    return false
  end
  local air = env.at(state, p)
  -- the airlock cycle: in vacuum or toxic air the suit seals first
  if not air.breathable and not p.suited and not p.excursion then
    if not d.cycle then
      d.cycle = 0
      ctx.msg(state, p, "Airlock cycling: sealing your suit...")
      ctx.fx(state, p, "click")
    end
    return false
  end
  d.drop, d.run, d.steps = g.drop, g.run, g.steps
  d.goal, d.hold = 1, M.tune().min_open
  ctx.fx(state, p, "door")
  return true
end

function M.request_close(state, p, ctx)
  local d = M.ensure(p)
  if d.goal == 0 then return true end
  if d.on or d.hold > 0 then return false end
  d.goal = 0
  ctx.fx(state, p, "door")
  return true
end

-- the Use button at the hatch panel
function M.use(state, p, ctx)
  local d = M.ensure(p)
  if d.cycle then return end
  if d.goal == 0 then
    if M.request_open(state, p, ctx, false) then
      ctx.msg(state, p, "The hatch opens and the stairs unfold.")
    end
  elseif d.hold > 0 then
    ctx.msg(state, p, "The hatch has only just opened")
  elseif not M.request_close(state, p, ctx) then
    ctx.msg(state, p, "Someone is on the stairs")
  else
    ctx.msg(state, p, "The stairs fold away and the hatch closes.")
  end
end

local function body_dist(p, foot)
  local b = p.excursion.body
  local dx, dz, dy = b.pos[1] - foot[1], b.pos[3] - foot[3], b.pos[2] - foot[2]
  return sm.sqrt(dx * dx + dz * dz + dy * dy * 0.25)
end

-- one tick: the airlock cycle, the hysteresis, the leaves and the treads
function M.step(state, p, dt, ctx)
  local d = p.door
  if not d then return end
  local T = M.tune()
  -- the airlock cycle seals the suit, then the hatch opens
  if d.cycle then
    d.cycle = d.cycle + dt
    if d.cycle >= T.cycle_time then
      d.cycle = false
      p.suited = true
      ctx.msg(state, p, "Helmet sealed.")
      M.request_open(state, p, ctx, false)
    end
  end
  local landed = landing.landed(p)
  -- flying, or the helm taken: the hatch shuts (only possible when nobody is on the stairs)
  if (p.mode == "helm" or not landed) and d.goal == 1 and not d.on then d.goal, d.hold = 0, 0 end
  d.hold = math.max(0, d.hold - dt)
  -- outside: walking up to the stairs opens it, walking away closes it (hysteresis)
  local ex = p.excursion
  if landed and ex and ex.coin == "stand" and not p.door.on then
    local foot = M.foot_world(state, p)
    if d.goal == 0 and d.run > 0 and body_dist(p, foot) <= T.reach_out then
      M.request_open(state, p, ctx, true)
    elseif d.goal == 1 and d.hold <= 0 and body_dist(p, foot) > T.reach_out + T.close_margin then
      d.goal = 0
    end
  elseif d.goal == 1 and d.hold <= 0 and not d.on and landed and p.mode == "walk" then
    -- aboard: close behind you once you are well away from the stairs
    local L = avatar.layout()
    local sill = T.sill
    local bx, bz = p.body.pos[1], p.body.pos[3]
    if avatar.deck_of(L, p.body) == T.deck and sm.sqrt(bx * bx + (bz - sill) ^ 2) > T.reach_out + T.close_margin + 2 then
      d.goal = 0
    end
  end
  -- sequence: leaves, then treads (and back)
  if d.goal == 1 then
    d.open = math.min(1, d.open + dt / T.open_time)
    if d.open >= 1 then d.stairs = math.min(1, d.stairs + dt / T.stairs_time) end
  else
    if d.stairs > 0 then d.stairs = math.max(0, d.stairs - dt / T.stairs_time)
    else d.open = math.max(0, d.open - dt / T.open_time) end
  end
  -- sealed again: the suit comes off aboard once the hatch is shut
  if p.suited and d.open == 0 and p.mode == "walk" and not d.cycle and d.goal == 0 then p.suited = false end
end

-- is the stairs' top clear for walking (fully out)?
function M.passable(p)
  local d = p.door
  return d and d.open >= 0.95 and d.stairs >= 0.95 and d.goal == 1
end

-- after the avatar moved: a body pushing aft through the open hatch steps onto the stairs
function M.after_walk(state, p)
  local d = p.door
  if not (d and M.passable(p)) or d.on then return end
  local T = M.tune()
  local b = p.body
  if avatar.deck_of(avatar.layout(), b) ~= T.deck then return end
  if b.pos[3] <= T.trigger and math.abs(b.pos[1]) <= T.width / 2 then
    d.on = true
    b.pos = { vec.clamp(b.pos[1], -T.width / 2 + 0.35, T.width / 2 - 0.35), b.pos[2], b.pos[3] }
  end
end

-- walk the stairs (hull-local, the same heading maths as the deck). -> "out" when at the foot
function M.stairs_step(state, p, cmd, dt, ctx)
  local d = p.door
  local T = M.tune()
  local A = avatar.layout()
  local b = p.body
  b.yaw = require("sim.comfort").yaw(b.yaw, cmd, A.turn, dt)
  b.pitch = vec.clamp(b.pitch + cmd:axis("look") * A.look * dt, -A.pitch_limit, A.pitch_limit)
  local mx, mz = cmd:axis("move_x"), cmd:axis("move_z")
  local u = T.sill - b.pos[3]
  local x = b.pos[1]
  if mx ~= 0 or mz ~= 0 then
    local heading = b.yaw + avatar.head_yaw(cmd.aim)
    local f, r = vec.fwd(heading), vec.right(heading)
    local speed = A.walk_speed * (cmd:held("boost") and A.run_factor or 1) * 0.8
    local dx = (f[1] * mz + r[1] * mx) * speed * dt
    local dz = (f[3] * mz + r[3] * mx) * speed * dt
    x = vec.clamp(x + dx, -T.width / 2 + 0.35, T.width / 2 - 0.35)
    u = u - dz
  end
  if not M.passable(p) then
    -- the stairs are folding: you cannot be on them (they refuse to fold while you are, so this is a guard)
    u = math.max(u, -0.1)
  end
  if u < -1.0 then
    -- back on the deck
    d.on = false
    b.pos = { x, A.decks[T.deck].floor, T.trigger + 0.3 }
    return nil
  end
  local total = M.total(p)
  local loc = M.local_at(p, math.min(u, total + 1.0), x)
  b.pos = loc
  if u >= total + 1.0 then return "out" end
  return nil
end

return M
