-- SPDX-License-Identifier: MIT
-- add-strategic-sentries: what turns a sentry encounter into a decision.
--   * Signature: how loud you are right now (hull, speed, the tractor beam, Loud modules).
--   * Suspicion meter: a Watcher or Spotter that can see you fills its meter by
--     fill x signature x closeness; out of sight it drains. Alert at half, Locked at full.
--   * Site alarm: every lock, Spotter tag or caught cell theft raises the site's alarm (0-3);
--     each level makes meters fill, sweeps turn and turrets fire faster; at 2 the Snatchers
--     wake and the Lockdown seals. It cools down while nobody is seen (faster with nobody inside).
--   * Sweep patterns: each turret sweeps in one of three patterns at its own period.
-- Tuning: data/base/sentries/sentries.lua `stealth`. The alarm is live state (state.alarm,
-- reset on load like the sentries themselves).
local vec = require("lib.vec")
local configs = require("sim.config")
local sm = saucer.math
local M = {}

local function tune() return require("sim.sentry").tune() end
function M.tune() return tune().stealth end

local function on_foot(p) return p.mode == "foot" and p.excursion and true or false end

-- signature(p) -> how readable you are to a sentry right now (Villa flying ~1, a still Seat ~0.2)
function M.signature(p, S)
  S = S or M.tune()
  local base
  if on_foot(p) then
    base = S.hull.foot
  else
    local c = configs.get(p.ship.size)
    base = S.hull[c.id] or 1
  end
  local speed = vec.len(p.ship.vel or { 0, 0, 0 })
  local k = math.min(speed / S.speed_ref, S.speed_cap)
  local sig = base * (S.still + (1 - S.still) * k)
  if p.tractor and p.tractor.site == p.site and p.site ~= 0 then sig = sig + S.beam end
  if not on_foot(p) and p.ship.loud then sig = sig + S.loud * p.ship.loud end
  return sig
end

-- ---------- the site alarm ----------
local function key(site) return tostring(site) end

function M.level(state, site)
  local a = state.alarm and state.alarm[key(site)]
  return a and a.lv or 0
end

local function each_at(state, site, fn)
  local game = require("sim.game")
  for i, def in ipairs(game.sentries(site)) do
    local dyn = state.sentries and state.sentries[site] and state.sentries[site][i]
    if dyn then fn(def, dyn, i) end
  end
end

-- the highest alarm a site can reach (the tutorial derelict, with its light sentries, stops low)
function M.max_level(site)
  local S = M.tune()
  local defs = require("sim.game").sentries(site)
  if defs[1] and defs[1].light then return S.light_alarm_max or S.alarm_max end
  return S.alarm_max
end

-- raise(state, site, n, ctx, why) -> the new level
function M.raise(state, site, n, ctx, why)
  local S = M.tune()
  state.alarm = state.alarm or {}
  local k = key(site)
  local a = state.alarm[k] or { lv = 0, cool = 0 }
  local before = a.lv
  a.lv = math.min(M.max_level(site), a.lv + (n or 1))
  a.cool = 0
  state.alarm[k] = a
  if a.lv > before then
    for _, p in ipairs(state.players) do
      if p.site == site then
        ctx.msg(state, p, string.format("SITE ALARM %d/%d%s: sentries here fill faster, sweep faster and fire sooner",
          a.lv, M.max_level(site), why and (" (" .. why .. ")") or ""))
        ctx.fx(state, p, "alert")
      end
    end
    if before < S.wake_at and a.lv >= S.wake_at then
      local wake = tune().warden.wake or 30
      local n_woke = 0
      each_at(state, site, function(def, dyn)
        if def.kind == "snatcher" and dyn.st ~= "off" then
          dyn.woke = state.tick + math.floor(wake * 60)
          n_woke = n_woke + 1
        end
      end)
      if n_woke > 0 then
        for _, p in ipairs(state.players) do
          if p.site == site then ctx.msg(state, p, string.format("The alarm wakes %d Snatcher%s: they sense twice as far", n_woke, n_woke == 1 and "" or "s")) end
        end
      end
    end
    if before < S.lockdown_at and a.lv >= S.lockdown_at then
      each_at(state, site, function(def, dyn)
        if def.kind == "lockdown" and dyn.st == "dormant" then dyn.trip = true end
      end)
    end
  end
  return a.lv
end

-- is any sentry of the site after someone right now?
local function hot(state, site)
  local busy = false
  each_at(state, site, function(_, dyn)
    if dyn.st == "alert" or dyn.st == "locked" or dyn.st == "hunt" or dyn.st == "latched" or dyn.st == "chase" then busy = true end
  end)
  return busy
end

-- step_alarm(state, dt, ctx): cool every site's alarm down
function M.step_alarm(state, dt, ctx)
  if not state.alarm then return end
  local S = M.tune()
  for _, k in ipairs(saucer.util.sorted_keys(state.alarm)) do
    local a = state.alarm[k]
    local site = tonumber(k)
    local inside = false
    for _, p in ipairs(state.players) do if p.site == site then inside = true end end
    if hot(state, site) then
      a.cool = 0
    else
      a.cool = a.cool + dt
      if a.cool >= (inside and S.cool_in or S.cool_out) then
        a.lv, a.cool = a.lv - 1, 0
        for _, p in ipairs(state.players) do
          if p.site == site then ctx.msg(state, p, string.format("The site alarm eases to %d/%d", a.lv, M.max_level(site))) end
        end
      end
    end
    if a.lv <= 0 then state.alarm[k] = nil end
  end
end

-- ---------- the suspicion meter ----------
-- fill(state, def, p, d, range, S) -> meter per second for a sentry that sees p at distance d of its range
function M.fill(state, def, p, d, range, S)
  S = S or M.tune()
  local close = 1 + S.near * math.max(0, 1 - d / math.max(range, 1e-6))
  local rate = S.fill * M.signature(p, S) * close * (1 + S.alarm_fill * M.level(state, def.site))
  if def.light then rate = rate * S.light_fill end
  if def.kind == "spotter" then rate = rate * S.spotter.fill end
  return rate
end

-- step_meter(state, def, dyn, seen, d, range, dt) -> the meter after this tick
function M.step_meter(state, def, dyn, seen, d, range, dt)
  local S = M.tune()
  if seen then
    dyn.meter = math.min(1, (dyn.meter or 0) + M.fill(state, def, seen, d, range, S) * dt)
    dyn.sus = seen.index
  else
    dyn.meter = math.max(0, (dyn.meter or 0) - S.decay * dt)
    if dyn.meter == 0 then dyn.sus = nil end
  end
  return dyn.meter
end

-- meter_on(state, p) -> the highest meter of a sentry at p's site that suspects p, and that sentry's kind
function M.meter_on(state, p)
  local best, kind = 0, nil
  if not p or (p.site or 0) == 0 then return 0, nil end
  each_at(state, p.site, function(def, dyn)
    if dyn.st ~= "off" and dyn.st ~= "disabled" and (dyn.sus == p.index or dyn.target == p.index) then
      local m = dyn.st == "locked" and 1 or (dyn.meter or 0)
      if m > best then best, kind = m, def.kind end
    end
  end)
  return best, kind
end

-- ---------- sweep patterns ----------
local STOPS = { -1, -1 / 3, 1 / 3, 1, 1 / 3, -1 / 3 }
function M.shape(pattern, u)
  u = u - math.floor(u)
  if pattern == "hold" then
    return vec.clamp(1.5 * sm.sin(sm.tau * u), -1, 1)
  elseif pattern == "step" then
    local x = u * #STOPS
    local seg = math.floor(x)
    local f = x - seg
    local a, b = STOPS[seg + 1], STOPS[(seg + 1) % #STOPS + 1]
    if f < 0.7 then return a end
    local s = (f - 0.7) / 0.3
    s = s * s * (3 - 2 * s)
    return a + (b - a) * s
  end
  return sm.sin(sm.tau * u)
end

-- pattern and period factor of a turret (a pure function of its site and room)
function M.pattern_of(site_id, room_id, light)
  local S = M.tune()
  if light then return "sine", 1 end
  local pat = S.patterns[(site_id * 7 + room_id * 3) % #S.patterns + 1]
  local per = S.periods[(site_id + room_id * 2) % #S.periods + 1]
  return pat, per
end

-- sweep(def, dyn, state, dt, t) -> yaw this tick (advances the turret's sweep phase; an alarm speeds it)
function M.sweep(def, dyn, state, dt, t)
  local S = t.stealth or M.tune()
  local period = t.watcher.sweep_period * (def.period or 1)
  if not dyn.ph then dyn.ph = (state.tick / 60) / period end
  dyn.ph = dyn.ph + dt * (1 + S.alarm_sweep * M.level(state, def.site)) / period
  if dyn.ph >= 1 then dyn.ph = dyn.ph - math.floor(dyn.ph) end
  return ((dyn.base) or def.yaw) + t.watcher.sweep * M.shape(def.pattern or "sine", dyn.ph)
end

-- how much sooner a locked turret fires at this alarm level (a light one never speeds up)
function M.fire_every(state, def, every)
  if def.light then return every end
  return every / (1 + M.tune().alarm_fire * M.level(state, def.site))
end

-- ---------- cover and guarded loot (derived from the ruin and its Watchers) ----------
-- decorate(site, ruin, defs): once per (memoised) ruin, every hall Watcher's room gets two
-- pillar stacks by the side walls without a door (cover a Seat can hide behind; solid, drawn
-- as debris) and one guarded find on the floor in its sweep (worth guard.premium x)
function M.decorate(site, ruin, defs)
  local S = M.tune()
  if not ruin or ruin.city or ruin.decorated or not S then return 0 end
  ruin.decorated = true
  local ruinm = require("sim.ruin")
  local ap = require("sim.autopilot")
  local kit = ruinm.kit_of(ruin.kit)
  local n = 0
  for _, def in ipairs(defs) do
    if def.kind == "watcher" and not def.route and not def.shaft and def.axis then
      local r = ruin.rooms[def.room]
      local mn, mx = ruinm.room_box(r, kit, site.pos)
      local ax, sg = def.axis, def.sign
      local lat = ax == 1 and 3 or 1
      local far = sg > 0 and mx[ax] or mn[ax]
      local near = sg > 0 and mn[ax] or mx[ax]
      local floor = mn[2] + kit.wall
      local L = lat == 1 and "x" or "z"
      -- floor hatches of this room (a pillar must not stand on one)
      local hatches = {}
      for _, d in ipairs(ruin.doors) do
        if (d.a == r.id or d.b == r.id) and d.axis == 2 then hatches[#hatches + 1] = ap.door_center(d, ruin.rooms, kit, site.pos) end
      end
      local w = S.pillar.w
      local h = (mx[2] - mn[2]) * S.pillar.h
      for k, side in ipairs({ "-", "+" }) do
        if not (r.faces and r.faces[side .. L]) then
          local a = far + (near - far) * (k == 1 and 0.35 or 0.65)
          local l0 = side == "-" and mn[lat] + kit.wall + S.pillar.side or mx[lat] - kit.wall - S.pillar.side - w
          local bmn, bmx = {}, {}
          bmn[2], bmx[2] = floor, floor + h
          bmn[ax], bmx[ax] = a - w / 2, a + w / 2
          bmn[lat], bmx[lat] = l0, l0 + w
          local clear = true
          for _, c in ipairs(hatches) do
            if math.abs(c[ax] - a) < 22 and math.abs(c[lat] - (l0 + w / 2)) < 22 then clear = false end
          end
          if clear then
            ruin.debris[#ruin.debris + 1] = { bmn, bmx, room = r.id, cover = def.id }
            n = n + 1
          end
        end
      end
      -- the guarded find: on the floor along its gaze, guard.at of the way from its end to the door
      local pos = {}
      pos[2] = floor + 1.0
      pos[ax] = far + (near - far) * S.guard.at
      pos[lat] = def.pos[lat]
      ruin.slots[#ruin.slots + 1] = { id = #ruin.slots + 1, room = r.id, pos = pos, max_size = 1, tier = S.guard.tier,
        seed = saucer.seed_child(site.seed, "guard", def.id), guarded = def.id, premium = S.guard.premium }
    end
  end
  return n
end

-- the guarded slots of a site that are still there for p -> list of slots
function M.guarded(ruin, p, site)
  local out = {}
  for _, s in ipairs(ruin and ruin.slots or {}) do
    if s.guarded and not (p and p.looted[site .. ":" .. s.id]) then out[#out + 1] = s end
  end
  return out
end

return M
