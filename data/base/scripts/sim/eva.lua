-- SPDX-License-Identifier: MIT
-- The EVA kit (OpenSpec add-dock-land-eva slice 4). On foot outside a standing
-- Villa (ex.home is set) the helmet goes on by itself in vacuum or toxic air,
-- and the suit tracks oxygen, integrity and jetpack fuel. The jetpack flies in
-- all six directions in zero-g and boosts or hovers in a pull; oxygen, fuel
-- and integrity refill beside the Villa. The return assist flies you home; the
-- emergency teleport pulls you to the Villa after a short charge-up, at the
-- price of half of what you carry (left behind as a cache) and a long
-- cooldown. Low oxygen (or a failed suit) fires the same teleport on its own.
-- Nothing is lethal.
--
-- p.eva = { o2, integrity, fuel, vel, jet, assist, tele (0..1 charging or false), cool (s), warned_o2,
--   warned_int, refill, flash (tick), stuck, helmet }; ex.home = { pos, yaw } where the Villa stood.
local vec = require("lib.vec")
local data = require("lib.data")
local sm = saucer.math
local M = {}

function M.tune() return data.load("saucer/eva.lua") end
local function game() return require("sim.game") end
local function avatar() return require("sim.avatar") end
local function excursion() return require("sim.excursion") end

-- the kit is for a Villa expedition: outside, with a home to return to
function M.active(p)
  return p.mode == "foot" and p.excursion and p.excursion.home and true or false
end

function M.ensure(p)
  local T = M.tune()
  if not p.eva then
    p.eva = { o2 = T.o2_max, integrity = T.integrity_max, fuel = T.fuel_max, vel = { 0, 0, 0 }, jet = false, assist = false,
              tele = false, cool = 0, warned_o2 = 0, warned_int = 0, refill = false, flash = -9999, stuck = 0, helmet = false }
  end
  return p.eva
end

-- remember where the Villa stands
function M.set_home(p)
  local ship = p.ship
  p.excursion.home = { pos = vec.copy(ship.pos), yaw = ship.yaw }
  M.ensure(p)
end

-- where "home" is for the assist and the teleport: the stairs' foot of the standing Villa, or the spot it stood
function M.target(state, p)
  local ex = p.excursion
  if ex.coin == "stand" and p.berth then
    local hd = require("sim.hulldoor")
    hd.ensure(p)
    return hd.foot_world(state, p), true
  end
  return vec.copy(ex.home.pos), false
end

-- the numbers for the HUD and the wrist -> table
function M.status(state, p)
  local T = M.tune()
  local e = M.ensure(p)
  local env = require("sim.env").at(state, p)
  local b = p.excursion.body
  local tgt = M.target(state, p)
  local d = vec.sub(tgt, b.pos)
  local hz = sm.sqrt(d[1] * d[1] + d[3] * d[3])
  local rel = sm.wrap(sm.atan2(d[1], d[3]) - b.yaw)
  local hands = p.hands or {}
  return {
    o2 = e.o2, o2_max = T.o2_max, integrity = e.integrity, integrity_max = T.integrity_max,
    fuel = e.fuel, fuel_max = T.fuel_max, jet = e.jet, assist = e.assist, tele = e.tele, cool = e.cool,
    dist = vec.len(d), hz = hz, dy = d[2], bearing = rel, g = env.g, temp = env.temp, rad = env.rad, env = env.name,
    breathable = env.breathable, loot = #hands, helmet = p.suited and true or false, refill = e.refill,
    flash = e.flash,
  }
end

-- ---- the jetpack ----

local function move_body(state, p, b, delta)
  local B = excursion().tune().body
  local hh = b.crouch and B.crouch / 2 or B.stand / 2
  local c = { b.pos[1], b.pos[2] + hh + 1e-6, b.pos[3] }
  -- one axis at a time, so a wall stops only what runs into it
  local cur = c
  local blocked = { false, false, false }
  for axis = 1, 3 do
    local d = { 0, 0, 0 }
    d[axis] = delta[axis]
    if d[axis] ~= 0 then
      local np, bl = saucer.physics.move(cur, B.radius, hh, d, 1)
      if bl > 0 then blocked[axis] = true end
      cur = np
    end
  end
  b.pos = { cur[1], cur[2] - hh, cur[3] }
  if p.berth then
    -- you cannot fly through the standing Villa or under its stairs
    local x, z = require("sim.landing").push_out(p, b.pos[1], b.pos[2], b.pos[3], b.pos[2] + B.stand)
    b.pos = { x, b.pos[2], z }
  end
  return blocked
end

-- fall damage and landing
local function touch_down(state, p, e, vy, ctx)
  local T = M.tune()
  local over = -vy - T.fall_safe
  if over > 0 then
    e.integrity = math.max(0, e.integrity - over * T.fall_k)
    ctx.msg(state, p, string.format("HARD LANDING: suit integrity -%d", (over * T.fall_k) // 1))
    ctx.fx(state, p, "alert")
  end
end

-- flying instead of walking? Called from excursion.move; -> true when this tick's movement is done here
function M.move(state, p, cmd, dt, ctx)
  if not M.active(p) then return false end
  local T = M.tune()
  local e = M.ensure(p)
  local ex = p.excursion
  local b = ex.body
  local env = require("sim.env").at(state, p)
  local A = avatar().layout()
  local B = excursion().tune().body
  local free = env.g < T.g_free
  local mx, mz, lift = cmd:axis("move_x"), cmd:axis("move_z"), cmd:axis("lift")
  -- the return assist owns the body while it flies you home
  if e.assist then return M.assist_move(state, p, cmd, dt, ctx) end
  if b.ground then
    if free and lift > 0.5 and e.fuel > 0 and not b.crouch then
      -- push off the deck: the jetpack takes over
      b.ground, e.jet, e.vel = false, true, { 0, 2.5, 0 }
    else
      e.jet = false
      e.vel = { 0, 0, 0 }
      return false
    end
  end
  if b.crouch then return false end
  b.yaw = require("sim.comfort").yaw(b.yaw, cmd, A.turn, dt)
  b.pitch = vec.clamp(b.pitch + cmd:axis("look") * A.look * dt, -A.pitch_limit, A.pitch_limit)
  local heading = b.yaw + avatar().head_yaw(cmd.aim)
  local f, rt = vec.fwd(heading), vec.right(heading)
  local thrust = math.max(math.abs(mx), math.abs(mz), math.abs(lift))
  local fuel = e.fuel > 0
  if free then
    -- zero-g: six directions, inertia, automatic braking when no thrust is asked for
    e.jet = true
    local aim = vec.aim(heading, b.pitch)
    local want = { 0, 0, 0 }
    if fuel then
      for i = 1, 3 do want[i] = (aim[i] * mz + rt[i] * mx) end
      want[2] = want[2] + lift
    end
    local wl = vec.len(want)
    if wl > 1 then want = vec.scale(want, 1 / wl) wl = 1 end
    if wl > 0.05 then
      for i = 1, 3 do e.vel[i] = e.vel[i] + want[i] * T.jet_accel * dt end
      e.fuel = math.max(0, e.fuel - T.fuel_free * wl * dt)
    else
      local sp = vec.len(e.vel)
      local k = sp > 1e-6 and math.max(0, 1 - T.brake * dt / sp) or 0
      e.vel = vec.scale(e.vel, k)
      if sp < 0.05 then e.vel = { 0, 0, 0 } end
    end
    local sp = vec.len(e.vel)
    if sp > T.jet_speed then e.vel = vec.scale(e.vel, T.jet_speed / sp) end
    local vy0 = e.vel[2]
    local bl = move_body(state, p, b, vec.scale(e.vel, dt))
    for i = 1, 3 do if bl[i] then e.vel[i] = 0 end end
    -- a deck under the boots: boots on again
    if bl[2] and vy0 < 0 then
      b.ground, e.jet, e.vel = true, false, { 0, 0, 0 }
    end
    b.vy = e.vel[2]
    return true
  end
  -- in a pull: gravity unless the jetpack is thrusting or hovering
  local g = T.gravity * env.g
  if lift > 0.5 and fuel and not e.jet then e.jet = true end
  if e.jet and not fuel then e.jet = false end
  local vy = b.vy or 0
  if e.jet then
    local burn
    if lift > 0.5 then
      vy = math.min(T.up_max, vy + (T.boost_up + g) * dt)
      burn = T.fuel_boost
    elseif lift < -0.5 then
      vy = math.max(-T.down_max, vy - 6 * dt)
      burn = T.fuel_hover * 0.5
    else
      vy = vy + (0 - vy) * math.min(1, 6 * dt)
      burn = T.fuel_hover
    end
    e.fuel = math.max(0, e.fuel - burn * dt)
  else
    vy = math.max(-B.max_fall, vy - g * dt)
  end
  local speed = A.walk_speed * (e.jet and T.air_speed or 1) * (cmd:held("boost") and A.run_factor or 1)
  local d = { (f[1] * mz + rt[1] * mx) * speed * dt, vy * dt, (f[3] * mz + rt[3] * mx) * speed * dt }
  local bl = move_body(state, p, b, d)
  if bl[2] then
    if vy < 0 then
      b.ground = true
      e.jet = false
      touch_down(state, p, e, vy, ctx)
    end
    vy = 0
  else
    b.ground = false
  end
  b.vy = vy
  return true
end

-- ---- the return assist ----

function M.set_assist(state, p, on, ctx, auto)
  local e = M.ensure(p)
  if on == e.assist then return end
  if on then
    if e.fuel <= 0 then
      ctx.msg(state, p, "Return assist: no fuel left")
      ctx.fx(state, p, "denied")
      return
    end
    e.assist, e.stuck = true, 0
    ctx.msg(state, p, auto and "OXYGEN CRITICAL: the return assist takes you home. Move to take over." or "RETURN ASSIST: flying you back to the Villa. Move to take over.")
    ctx.fx(state, p, "grow")
  else
    e.assist = false
  end
end

function M.assist_move(state, p, cmd, dt, ctx)
  local T = M.tune()
  local e = M.ensure(p)
  local b = p.excursion.body
  local A = avatar().layout()
  -- any real input takes over; no fuel ends it
  if math.abs(cmd:axis("move_x")) > 0.6 or math.abs(cmd:axis("move_z")) > 0.6 or math.abs(cmd:axis("lift")) > 0.6 then
    e.assist = false
    ctx.msg(state, p, "Return assist off: you have the controls")
    return false
  end
  if e.fuel <= 0 then
    e.assist = false
    ctx.msg(state, p, "Return assist: out of fuel. The emergency teleport is on Backspace.")
    ctx.fx(state, p, "denied")
    return false
  end
  local tgt = M.target(state, p)
  local d = vec.sub(tgt, b.pos)
  local dist = vec.len(d)
  local hz = sm.sqrt(d[1] * d[1] + d[3] * d[3])
  if hz <= T.assist_stop and math.abs(d[2]) < 3 then
    e.assist, e.vel = false, { 0, 0, 0 }
    ctx.msg(state, p, "Return assist: you are at the Villa")
    return false
  end
  b.yaw = sm.wrap(sm.atan2(d[1], d[3]))
  b.pitch = vec.clamp(-sm.atan2(d[2], hz) * 0.5, -0.5, 0.5)
  local step = math.min(dist, T.assist_speed * dt)
  local dir = vec.scale(d, 1 / math.max(dist, 1e-6))
  local before = vec.copy(b.pos)
  local bl = move_body(state, p, b, vec.scale(dir, step))
  e.fuel = math.max(0, e.fuel - T.fuel_assist * dt)
  e.vel = vec.scale(dir, T.assist_speed)
  b.vy = 0
  b.ground = false
  if vec.dist(before, b.pos) < step * 0.25 then e.stuck = e.stuck + 1 else e.stuck = 0 end
  if e.stuck > T.assist_blocked then
    e.assist = false
    ctx.msg(state, p, "Return assist: the way is blocked. Fly round it, or use the emergency teleport (Backspace)")
    ctx.fx(state, p, "denied")
  end
  return true
end

-- ---- the emergency teleport ----

-- pull the player home. why = "button" or "oxygen" or "suit"; -> true
function M.recall(state, p, ctx, why)
  local T = M.tune()
  local e = M.ensure(p)
  local ex = p.excursion
  local b = ex.body
  -- what you carry: half of it stays where you stood, as a cache you can come back for
  local hands = p.hands or {}
  local movable, keep = {}, {}
  for _, it in ipairs(hands) do
    if it.echo or it.unique then keep[#keep + 1] = it else movable[#movable + 1] = it end
  end
  local drop = math.ceil(#movable * T.tele_loss)
  local left = {}
  for i = 1, #movable do
    if i <= drop then left[#left + 1] = movable[i] else keep[#keep + 1] = movable[i] end
  end
  p.hands = keep
  if #left > 0 and require("sim.hardcore").on(state) then
    p.lost_for_good = (p.lost_for_good or 0) + #left
  elseif #left > 0 then
    state.caches = state.caches or {}
    state.caches[#state.caches + 1] = { site = ex.site, pos = { b.pos[1], b.pos[2] + 0.9, b.pos[3] }, owner = p.record_index, items = left }
  end
  -- the Villa is where it was left: bring it back out if you pocketed it
  if ex.coin ~= "stand" then
    local ship = p.ship
    ship.morph, ship.t_left = false, 0
    ship.size = 1
    ship.pos = vec.copy(ex.home.pos)
    ship.yaw = ex.home.yaw
    ship.vel = { 0, 0, 0 }
    ship.bank, ship.pitch = 0, 0
    ex.held = false
    excursion().stand_up(state, p, ctx)
  end
  local tgt = M.target(state, p)
  local o = avatar().rot(p.ship.yaw, { 0, 0, -1.2 })
  b.pos = { tgt[1] + o[1], tgt[2], tgt[3] + o[3] }
  b.vy, b.ground, b.crouch = 0, true, false
  e.vel, e.jet, e.assist, e.tele = { 0, 0, 0 }, false, false, false
  e.cool = T.tele_cool
  e.flash = state.tick
  e.warned_o2, e.warned_int = 0, 0
  local msg = {
    button = "EMERGENCY TELEPORT: you are back at the Villa",
    oxygen = "OUT OF OXYGEN: the suit teleports you home",
    suit = "SUIT FAILURE: the suit teleports you home",
  }
  ctx.msg(state, p, msg[why] or msg.button)
  if #left > 0 then ctx.msg(state, p, string.format("%d item%s left behind where you stood (a cache)", #left, #left == 1 and "" or "s")) end
  ctx.fx(state, p, "shrink")
  saucer.events.emit({ type = "eva_teleport", player = p.index, why = why, lost = #left })
  return true
end

function M.press_home(state, p, ctx)
  local T = M.tune()
  local e = M.ensure(p)
  if e.tele then
    e.tele = false
    ctx.msg(state, p, "Emergency teleport cancelled")
    return
  end
  if e.cool > 0 then
    ctx.msg(state, p, string.format("Emergency teleport recharging: %d s", math.ceil(e.cool)))
    ctx.fx(state, p, "denied")
    return
  end
  local _, standing = M.target(state, p)
  if not standing and (p.excursion.coin == "fold" or p.excursion.coin == "grow") then
    ctx.msg(state, p, "Wait for the saucer to finish folding")
    return
  end
  e.tele = 0
  ctx.msg(state, p, "EMERGENCY TELEPORT charging: press again to cancel")
  ctx.fx(state, p, "grow")
end

-- ---- one tick ----

local function warn_level(v, max)
  local pc = v / max * 100
  return pc <= 0 and 3 or (pc <= M.tune().warn[2] and 2 or (pc <= M.tune().warn[1] and 1 or 0))
end

function M.step(state, p, cmd, dt, ctx)
  if not M.active(p) then return end
  local T = M.tune()
  local e = M.ensure(p)
  local ex = p.excursion
  local env = require("sim.env").at(state, p)
  -- the helmet goes on by itself in vacuum or toxic air
  local need = not env.breathable
  if need ~= (p.suited and true or false) then
    p.suited = need
    ctx.msg(state, p, need and "Helmet on" or "Helmet off")
    ctx.fx(state, p, "door")
  end
  e.helmet = p.suited and true or false
  if e.cool > 0 then e.cool = math.max(0, e.cool - dt) end
  -- refuel and breathe beside the standing Villa
  local near = ex.coin == "stand" and vec.dist(p.ship.pos, excursion().center(ex.body)) <= T.refill_r
  if near then
    local k = T.refill_rate * dt
    local full = e.o2 >= T.o2_max and e.fuel >= T.fuel_max and e.integrity >= T.integrity_max
    e.o2 = math.min(T.o2_max, e.o2 + k)
    e.fuel = math.min(T.fuel_max, e.fuel + k)
    e.integrity = math.min(T.integrity_max, e.integrity + k * 0.2)
    if not e.refill and not full then ctx.msg(state, p, "Refilling oxygen and fuel at the Villa") end
    e.refill = not full
    if e.o2 > T.o2_max * 0.4 then e.warned_o2 = 0 end
    if e.integrity > T.integrity_max * 0.4 then e.warned_int = 0 end
  else
    e.refill = false
    if need then
      local k = 1
      if e.jet then k = k * T.o2_jet end
      if cmd:held("boost") then k = k * T.o2_run end
      e.o2 = math.max(0, e.o2 - T.o2_drain * k * dt)
      -- radiation and cold eat the suit
      local dmg = env.rad * T.rad_k + math.max(0, math.abs(env.temp - 21) - T.temp_safe) * T.temp_k
      e.integrity = math.max(0, e.integrity - dmg * dt)
    end
  end
  -- warnings
  local lo = warn_level(e.o2, T.o2_max)
  if lo > e.warned_o2 and lo < 3 then
    e.warned_o2 = lo
    ctx.msg(state, p, lo == 1 and string.format("OXYGEN LOW: %d%%", (e.o2 / T.o2_max * 100) // 1)
      or "OXYGEN CRITICAL: head for the Villa (Insert: return assist, Backspace: emergency teleport)")
    ctx.fx(state, p, "alert")
    if lo == 2 and not near then M.set_assist(state, p, true, ctx, true) end
  end
  local li = warn_level(e.integrity, T.integrity_max)
  if li > e.warned_int and li < 3 then
    e.warned_int = li
    ctx.msg(state, p, li == 1 and "SUIT INTEGRITY LOW" or "SUIT INTEGRITY CRITICAL: get back to the Villa")
    ctx.fx(state, p, "alert")
  end
  if e.o2 <= 0 and need then return M.recall(state, p, ctx, "oxygen") end
  if e.integrity <= 0 then return M.recall(state, p, ctx, "suit") end
  -- buttons
  if cmd:pressed("assist") then M.set_assist(state, p, not e.assist, ctx) end
  if cmd:pressed("home") then M.press_home(state, p, ctx) end
  if e.tele then
    e.tele = e.tele + dt / T.tele_charge
    if e.tele >= 1 then return M.recall(state, p, ctx, "button") end
  end
end

return M
