-- SPDX-License-Identifier: MIT
-- Sentries (concept §8.2): robots only, nothing lethal. Every sentry runs
-- Dormant -> Alert (at least alert_time) -> Locked -> Disabled -> Dormant and
-- is leashed to its derelict. Watchers are ceiling turrets in great halls
-- with a sweeping cone; they ignore hulls below their civ's size band (the
-- Seat), and when Locked fire slow stun bolts that drain shields, then hull.
-- Snatchers patrol ducts, latch only onto a Seat carrying hot items, siphon
-- one in latch_time and carry it to their nest, where it can be tractored
-- back. Placement is derived from the ruin layout (rebuilt, not saved); the
-- live state is in state.sentries[site][i] and state.bolts.
local data = require("lib.data")
local vec = require("lib.vec")
local ruinm = require("sim.ruin")
local configs = require("sim.config")
local items = require("sim.items")
local hull = require("sim.hull")
local adv = require("sim.advsentry")
local sm = saucer.math
local M = {}

-- gameplay gaps: a Loud saucer module is heard from farther (metres, per module)
M.LOUD_WATCHER = 25
M.LOUD_SNATCHER = 8

function M.tune() return data.load("sentries/sentries.lua") end

-- add-wider-dark: the tuning with the mystery ending's universe changes
-- applied (a sealed Heart makes sentries drowsy, a taken one makes them keen)
local tuned = {}
function M.tuned(state)
  local t = M.tune()
  local m = state and state.mystery
  local wr = require("sim.mystery").effect(m, "watcher_range")
  local ss = require("sim.mystery").effect(m, "snatcher_sense")
  if wr == 1 and ss == 1 then return t end
  local key = wr .. ":" .. ss
  if tuned.key == key and tuned.base == t then return tuned.t end
  local c = {}
  for k, v in pairs(t) do c[k] = v end
  c.watcher, c.snatcher = {}, {}
  for k, v in pairs(t.watcher) do c.watcher[k] = v end
  for k, v in pairs(t.snatcher) do c.snatcher[k] = v end
  c.watcher.range = t.watcher.range * wr
  c.watcher.foot_range = (t.watcher.foot_range or 45) * wr
  c.snatcher.sense = t.snatcher.sense * ss
  tuned.key, tuned.base, tuned.t = key, t, c
  return c
end

local function dark_of(ruin, r) return require("sim.cities").dark(ruin, r) end

-- layout(site, ruin, civ) -> list of sentry definitions (derived data).
-- The tutorial derelict (site 1) is unguarded.
function M.layout(site, ruin, civ)
  local out = {}
  if site.tutorial or (site.tutorial == nil and site.id == 1) or not ruin then return out end
  local kit = ruinm.kit_of(ruin.kit)
  local t = M.tune()
  local big = kit.big or 4
  local band = t.watcher.band[civ and civ.body or "human"] or { 2, 4 }
  for _, r in ipairs(ruin.rooms) do
    local mn, mx = ruinm.room_box(r, kit, site.pos)
    if r.calm then
      -- add-cities: a quiet hall of a city keeps no sentry
    elseif r.class >= big and r.kind ~= "entrance" then
      -- a ceiling turret at the far end of the hall, looking back at the door you
      -- come in by; in a vertical shaft it hangs at the top and looks down the shaft
      local door
      for _, d in ipairs(ruin.doors) do if d.b == r.id then door = d end end
      local ax, sg = door and door.axis or 3, door and door.sign or 1
      if ax == 2 then ax = 3 end -- entered through the floor or ceiling: sit at the +z end
      local c = { (mn[1] + mx[1]) / 2, mx[2] - kit.wall - 3.0, (mn[3] + mx[3]) / 2 }
      local tgt = { c[1], mn[2], c[3] }
      local pos = { c[1], c[2], c[3] }
      local near = sg > 0 and mn[ax] or mx[ax]
      local far = sg > 0 and mx[ax] or mn[ax]
      tgt[ax] = near
      local pitch = -0.32
      if r.kind == "shaft" then
        pos[ax] = far - sg * (kit.wall + 4.0)
        pitch = -1.15
      else
        pos[ax] = far - sg * (kit.wall + 6.0)
      end
      local yaw = sm.atan2(tgt[1] - pos[1], tgt[3] - pos[3])
      out[#out + 1] = { id = #out + 1, kind = "watcher", site = site.id, room = r.id, pos = pos, yaw = yaw,
                        pitch = pitch, band = band, glyph = civ and civ.glyph or nil, district = r.district,
                        dark = dark_of(ruin, r) }
    elseif r.class < big and r.kind == "duct" or (r.class < big and r.kind == "side" and ruin.rooms[r.parent]
        and ruin.rooms[r.parent].class >= big) then
      -- a Snatcher in the duct; its nest at the deepest small room of the branch
      local deepest = r
      for _, q in ipairs(ruin.rooms) do
        if q.parent == r.id and q.class < big then deepest = q end
      end
      local dmn, dmx = ruinm.room_box(deepest, kit, site.pos)
      local floor = mn[2] + kit.wall
      local cx, cz = (mn[1] + mx[1]) / 2, (mn[3] + mx[3]) / 2
      -- patrol along the duct's long axis (a vertical chute runs along y)
      local len = { mx[1] - mn[1], mx[2] - mn[2], mx[3] - mn[3] }
      local along = 1
      for k = 2, 3 do if len[k] > len[along] then along = k end end
      local cy = along == 2 and (mn[2] + mx[2]) / 2 or floor + 1.6
      local a, b = { cx, cy, cz }, { cx, cy, cz }
      local half = len[along] / 2 - 1.5
      a[along] = a[along] - half
      b[along] = b[along] + half
      local nest = { (dmn[1] + dmx[1]) / 2, dmn[2] + kit.wall + 0.6, (dmn[3] + dmx[3]) / 2 }
      if deepest == r then nest = { b[1], along == 2 and b[2] - 0.6 or floor + 0.6, b[3] } end
      -- leashed to its duct branch: leave it and the Snatcher gives up
      local lo, hi = {}, {}
      for k = 1, 3 do
        lo[k] = math.min(mn[k], dmn[k]) - 2
        hi[k] = math.max(mx[k], dmx[k]) + 2
      end
      out[#out + 1] = { id = #out + 1, kind = "snatcher", site = site.id, room = r.id, pos = { cx, cy, cz },
                        patrol = { a, b }, nest = nest, nest_room = deepest.id, leash = { lo, hi }, glyph = civ and civ.glyph or nil,
                        district = r.district, dark = dark_of(ruin, r) }
    end
  end
  -- add-wider-dark: deeper sectors add Clamps and a Lockdown node
  if (site.danger or 1) >= 2 then adv.layout(out, site, ruin, kit, t) end
  -- add-home-among-stars: the deepest derelicts keep a Warden
  if (site.danger or 1) >= 3 and t.warden then require("sim.warden").layout(out, site, ruin, kit, t) end
  return out
end

function M.new_state(defs, state)
  local out = {}
  for i, d in ipairs(defs) do
    if d.kind == "clamp" or d.kind == "lockdown" then
      out[i] = adv.new_state(d)
    elseif d.kind == "warden" then
      out[i] = require("sim.warden").new_state(d)
    elseif d.kind == "watcher" then
      out[i] = { st = "dormant", t = 0, lost = 0, fire = 0, target = 0, yaw = d.yaw, pitch = d.pitch }
    else
      out[i] = { st = "dormant", t = 0, lost = 0, target = 0, pos = vec.copy(d.pos), wp = 2, carry = false }
    end
    -- add-wider-dark: an Override spike shut it down for good
    if state and adv.overridden(state, d) then out[i].st = "off" end
  end
  return out
end

local function dir_of(yaw, pitch)
  local cp = sm.cos(pitch)
  return { sm.sin(yaw) * cp, sm.sin(pitch), sm.cos(yaw) * cp }
end
M.dir_of = dir_of

-- add-on-foot-excursions: a person walking a derelict (the coin in their pocket)
local function on_foot(p) return p.mode == "foot" and p.excursion and true or false end
M.on_foot = on_foot

-- can this Watcher see player p's hull (or p, on foot) right now?
function M.watcher_sees(def, dyn, p, tick, t)
  local ship = p.ship
  if p.site ~= def.site then return false end
  if adv.shrouded(p, t) then return false end
  if on_foot(p) then
    -- whatever its size band, a turret sees a person on foot (closer in)
    local dir = dir_of(dyn.yaw, dyn.pitch or def.pitch)
    return saucer.physics.cone_visible(def.pos, dir, sm.cos(t.watcher.half_angle), t.watcher.foot_range or 45, ship.pos, 1)
  end
  local cls = configs.get(ship.size).class
  if cls < def.band[1] or cls > def.band[2] then return false end
  local yaw = dyn.yaw
  local dir = dir_of(yaw, dyn.pitch or def.pitch)
  local r = configs.get(ship.size).diameter / 2
  return saucer.physics.cone_visible(def.pos, dir, sm.cos(t.watcher.half_angle), t.watcher.range + r + (ship.loud or 0) * M.LOUD_WATCHER, ship.pos, 1)
end

local function sweep_yaw(def, tick, t)
  local w = t.watcher
  return def.yaw + w.sweep * sm.sin(sm.tau * tick / (w.sweep_period * 60))
end

local function step_watcher(state, def, dyn, dt, ctx, t)
  if dyn.st == "off" then return end
  if dyn.st == "disabled" then
    dyn.t = dyn.t - dt
    if dyn.t <= 0 then dyn.st, dyn.t, dyn.lost = "dormant", 0, 0 end
    return
  end
  -- add-wider-dark: a Decoy flare in sight takes all of its attention
  local dec = t.decoy and adv.decoy_for(state, def, def.pos, t)
  if dec then
    local d = vec.sub(dec.pos, def.pos)
    dyn.yaw = sm.atan2(d[1], d[3])
    dyn.pitch = sm.atan2(d[2], sm.sqrt(d[1] * d[1] + d[3] * d[3]))
    dyn.st, dyn.target, dyn.t, dyn.lost = "decoyed", 0, 0, 0
    return
  end
  if dyn.st == "decoyed" then dyn.st = "dormant" end
  local target = dyn.target > 0 and state.players[dyn.target] or nil
  if dyn.st == "locked" and target then
    -- true 3D: a locked turret tracks its target in yaw and pitch
    local d = vec.sub(target.ship.pos, def.pos)
    dyn.yaw = sm.atan2(d[1], d[3])
    dyn.pitch = sm.atan2(d[2], sm.sqrt(d[1] * d[1] + d[3] * d[3]))
  else
    dyn.yaw = sweep_yaw(def, state.tick, t)
    dyn.pitch = def.pitch
  end
  local seen
  if target and M.watcher_sees(def, dyn, target, state.tick, t) then
    seen = target
  elseif dyn.st == "dormant" then
    for _, p in ipairs(state.players) do
      if M.watcher_sees(def, dyn, p, state.tick, t) then seen = p break end
    end
  end
  if dyn.st == "dormant" then
    if seen then
      dyn.st, dyn.t, dyn.lost, dyn.target, dyn.alert_tick = "alert", 0, 0, seen.index, state.tick
      ctx.fx(state, seen, "alert")
      ctx.msg(state, seen, "A Watcher stirs: yellow light, rising tone")
    end
    return
  end
  if seen then dyn.lost = 0 else dyn.lost = dyn.lost + dt end
  if dyn.lost >= t.lose_time then
    dyn.st, dyn.t, dyn.target, dyn.lost = "dormant", 0, 0, 0
    return
  end
  dyn.t = dyn.t + dt
  if dyn.st == "alert" then
    if seen and dyn.t >= t.alert_time then
      dyn.st, dyn.t, dyn.fire, dyn.lock_tick = "locked", 0, 0, state.tick
      ctx.fx(state, seen, "locked")
      ctx.msg(state, seen, "Watcher LOCKED: stun bolts incoming")
      M.seat_hint(state, seen, ctx)
    end
  elseif dyn.st == "locked" and seen then
    dyn.fire = dyn.fire - dt
    if dyn.fire <= 0 then
      dyn.fire = t.watcher.fire_every
      local d = vec.sub(seen.ship.pos, def.pos)
      local l = vec.len(d)
      state.bolts[#state.bolts + 1] = { site = def.site, pos = vec.copy(def.pos),
        vel = vec.scale(d, t.watcher.bolt_speed / math.max(l, 1e-6)), life = t.watcher.bolt_life }
    end
  end
end

-- the Seat is the only hull a Snatcher can latch onto (and, on foot, you)
local function seat(p)
  return on_foot(p) or (not configs.get(p.ship.size).interior and configs.get(p.ship.size).class <= 1)
end

-- what a Snatcher can take: hot items in the hold, or on foot in your hands
local function losable(p)
  if not on_foot(p) then return items.losable(p) end
  local out = {}
  for _, it in ipairs(p.hands or {}) do
    if it.hot and not it.echo and not it.unique then out[#out + 1] = it end
  end
  return out
end
M.losable = losable

local function take(p, it)
  if not on_foot(p) then return items.remove(p, it.uid) end
  for i, h in ipairs(p.hands) do
    if h.uid == it.uid then return table.remove(p.hands, i) end
  end
  return nil
end

local function move_to(pos, goal, speed, dt)
  local d = vec.sub(goal, pos)
  local l = vec.len(d)
  local s = speed * dt
  if l <= s then return vec.copy(goal), true end
  return vec.add(pos, vec.scale(d, s / l)), false
end

local function in_box(b, q)
  return q[1] >= b[1][1] and q[1] <= b[2][1] and q[2] >= b[1][2] and q[2] <= b[2][2] and q[3] >= b[1][3]
    and q[3] <= b[2][3]
end

function M.snatcher_wants(def, dyn, p, t)
  if p.site ~= def.site or not seat(p) or #losable(p) == 0 then return false end
  if def.leash and not in_box(def.leash, p.ship.pos) then return false end
  -- add-home-among-stars: a Warden's alarm wakes them (twice the sense)
  local woke = dyn.woke and require("sim.game").state_ref and dyn.woke > (require("sim.game").state_ref.tick or 0)
  return vec.dist(dyn.pos, p.ship.pos) <= (on_foot(p) and t.snatcher.foot_sense or (t.snatcher.sense + (p.ship.loud or 0) * M.LOUD_SNATCHER)) * (woke and 2 or 1)
end

local function step_snatcher(state, def, dyn, dt, ctx, t)
  local s = t.snatcher
  if dyn.st == "off" then return end
  if dyn.st ~= "disabled" and dyn.st ~= "flee" and dyn.st ~= "latched" and t.decoy then
    local dec = adv.decoy_for(state, def, dyn.pos, t)
    if dec then
      dyn.st, dyn.target = "decoyed", 0
      dyn.pos = move_to(dyn.pos, dec.pos, s.chase_speed, dt)
      return
    end
    if dyn.st == "decoyed" then dyn.st = "dormant" end
  end
  if dyn.st == "disabled" then
    dyn.t = dyn.t - dt
    if dyn.t <= 0 then dyn.st, dyn.t, dyn.lost = dyn.carry and "flee" or "dormant", 0, 0 end
    return
  end
  if dyn.st == "flee" then
    local arrived
    dyn.pos, arrived = move_to(dyn.pos, def.nest, s.flee_speed, dt)
    if arrived then
      local c = dyn.carry
      state.nests[#state.nests + 1] = { site = def.site, sentry = def.id, pos = vec.copy(def.nest), item = c.item,
                                        owner = c.owner }
      local owner = state.players[dyn.carry_owner]
      if owner then ctx.msg(state, owner, "The Snatcher dropped your " .. items.label(dyn.carry.item) .. " in its nest") end
      dyn.carry, dyn.carry_owner, dyn.st, dyn.t = false, nil, "dormant", 0
    end
    return
  end
  local target = dyn.target > 0 and state.players[dyn.target] or nil
  if dyn.st == "latched" then
    if not target or not seat(target) or target.site ~= def.site then
      if target then ctx.msg(state, target, "The Snatcher lost its grip: it can't latch onto the Villa") end
      if target then target.latched_by = nil end
      dyn.st, dyn.t, dyn.target = "dormant", 0, 0
      return
    end
    dyn.pos = { target.ship.pos[1], target.ship.pos[2] + 0.9, target.ship.pos[3] }
    dyn.t = dyn.t + dt
    target.latched_by = { site = def.site, id = def.id, t = dyn.t }
    if dyn.t >= s.latch_time then
      local lost = losable(target)
      local it = lost[#lost]
      target.latched_by = nil
      if it then
        take(target, it)
        dyn.carry, dyn.carry_owner = { item = it, owner = target.record_index }, target.index
        dyn.st, dyn.t, dyn.target = "flee", 0, 0
        ctx.fx(state, target, "denied")
        ctx.msg(state, target, (on_foot(target) and "A Snatcher tore " .. items.label(it) .. " out of your hands"
          or "A Snatcher siphoned " .. items.label(it)) .. " and flees to its nest")
      else
        dyn.st, dyn.t, dyn.target = "dormant", 0, 0
      end
    end
    return
  end
  local seen
  if target and M.snatcher_wants(def, dyn, target, t) then
    seen = target
  elseif dyn.st == "dormant" then
    for _, p in ipairs(state.players) do
      if M.snatcher_wants(def, dyn, p, t) then seen = p break end
    end
  end
  if dyn.st == "dormant" then
    if seen then
      dyn.st, dyn.t, dyn.lost, dyn.target = "alert", 0, 0, seen.index
      ctx.fx(state, seen, "alert")
      ctx.msg(state, seen, "A Snatcher wakes up: it wants your hot cargo")
      return
    end
    local goal = def.patrol[dyn.wp]
    local arrived
    dyn.pos, arrived = move_to(dyn.pos, goal, s.patrol_speed, dt)
    if arrived then dyn.wp = dyn.wp % #def.patrol + 1 end
    return
  end
  -- alert / locked: chase, give up when the target is gone or too far from home
  local tp = target and target.ship.pos
  if not seen or vec.dist(tp, def.pos) > s.give_up then dyn.lost = dyn.lost + dt else dyn.lost = 0 end
  if dyn.lost >= t.lose_time then
    dyn.st, dyn.t, dyn.target, dyn.lost = "dormant", 0, 0, 0
    return
  end
  dyn.t = dyn.t + dt
  if dyn.st == "alert" then
    if seen and dyn.t >= t.alert_time then
      dyn.st, dyn.t = "locked", 0
      ctx.fx(state, seen, "locked")
      ctx.msg(state, seen, "Snatcher LOCKED: jam it or outrun it")
    end
  elseif seen then
    local arrived
    dyn.pos, arrived = move_to(dyn.pos, tp, s.chase_speed, dt)
    if arrived or vec.dist(dyn.pos, tp) <= s.latch_dist then
      dyn.st, dyn.t = "latched", 0
      target.latched_by = { site = def.site, id = def.id, t = 0 }
      ctx.msg(state, target, "The Snatcher latched on! Siphoning in 3 s: jam it!")
    end
  end
end

-- add-on-foot-excursions: a grid console shut this site's grid down. Every
-- sentry goes Disabled and stays so (its reboot timer held full) until the
-- grid comes back, then reboots as after a Jammer pulse. -> count
function M.grid_down(state, site_idx)
  local t = M.tune()
  local n = 0
  local defs = require("sim.game").sentries(site_idx)
  for i, dyn in ipairs(state.sentries[site_idx] or {}) do
    if defs[i] and defs[i].kind == "warden" then
      -- add-playtest-recs: the Warden stays awake (sentry.step slows it)
    elseif dyn.st ~= "off" then
      if dyn.st == "latched" and dyn.target > 0 and state.players[dyn.target] then state.players[dyn.target].latched_by = nil end
      if dyn.st == "clamped" then adv.release(state, dyn) end
      dyn.st, dyn.t, dyn.target, dyn.lost = "disabled", t.disabled_time, 0, 0
      n = n + 1
    end
  end
  return n
end

function M.grid_up(state, site_idx)
  return #(state.sentries[site_idx] or {})
end

-- add-playtest-recs (recommendation 4): the first time a Watcher locks on
-- to a Villa, say what to do about it. -> true when the hint was given
function M.seat_hint(state, p, ctx)
  if not p or p.ship.size ~= 1 or p.mode == "foot" then return false end
  p.hints = p.hints or {}
  if p.hints.seat then return false end
  p.hints.seat = state.tick
  ctx.msg(state, p, "TIP: Watchers ignore anything as small as the Seat. Fold down (2 or Q) to dive guarded sites.")
  return true
end

-- is a Watcher Locked onto player p?
function M.locked_on(state, p)
  for _, list in pairs(state.sentries or {}) do
    for _, dyn in ipairs(list) do
      if dyn.st == "locked" and dyn.target == p.index and dyn.fire ~= nil then return true end
    end
  end
  return false
end

-- one tick for every sentry of a site, then the bolts
function M.step(state, site_idx, defs, dt, ctx)
  local t = M.tuned(state)
  local dyns = state.sentries[site_idx]
  if not dyns then return end
  if state.grids and state.grids[tostring(site_idx)] then
    for i, dyn in ipairs(dyns) do
      if defs[i] and defs[i].kind == "warden" and dyn.st ~= "off" then
        -- add-playtest-recs (recommendation 8): the Warden runs on its own
        -- power: with the grid down it keeps patrolling, only slower
        require("sim.warden").step(state, defs[i], dyn, dt, ctx, t, true)
      elseif dyn.st ~= "off" then
        if dyn.st == "clamped" then adv.release(state, dyn) end
        if defs[i] and defs[i].kind == "lockdown" and #(dyn.sealed or {}) > 0 then ctx.seal(defs[i], dyn, false) end
        dyn.st, dyn.t = "disabled", t.disabled_time
      end
    end
    return
  end
  for i, def in ipairs(defs) do
    local dyn = dyns[i]
    if def.dark and not (state.locks and state.locks[site_idx .. ":power" .. def.district]) then
      -- add-cities: its district is dark: it sits dormant until the grid comes back
    elseif def.kind == "watcher" then step_watcher(state, def, dyn, dt, ctx, t)
    elseif def.kind == "clamp" then adv.step_clamp(state, def, dyn, dt, ctx, t)
    elseif def.kind == "lockdown" then adv.step_lockdown(state, def, dyn, dt, ctx, t, ctx.seal)
    elseif def.kind == "warden" then require("sim.warden").step(state, def, dyn, dt, ctx, t)
    else step_snatcher(state, def, dyn, dt, ctx, t) end
  end
end

-- stun bolts: fly straight, stop at walls, drain shields then hull of the first hull they touch
function M.step_bolts(state, dt)
  local t = M.tune()
  local keep = {}
  for _, b in ipairs(state.bolts) do
    local step = vec.scale(b.vel, dt)
    local hit = saucer.physics.raycast(b.pos, step, 1.0, 1)
    b.pos = vec.add(b.pos, step)
    b.life = b.life - dt
    local alive = b.life > 0 and not hit
    if alive then
      for _, p in ipairs(state.players) do
        local s = p.ship
        local c = configs.get(s.size)
        local dx, dz = b.pos[1] - s.pos[1], b.pos[3] - s.pos[3]
        local foot = on_foot(p)
        local rr = (foot and 0.35 or c.diameter / 2) + t.watcher.bolt_radius
        local hh = foot and 0.9 or c.height / 2
        if alive and foot and b.site == p.site and dx * dx + dz * dz <= rr * rr
            and math.abs(b.pos[2] - s.pos[2]) <= hh + t.watcher.bolt_radius then
          -- on foot a bolt bites the suit, never anything else
          require("sim.excursion").bolt(state, p)
          p.hits = (p.hits or 0) + 1
          p.fx[#p.fx + 1] = { tick = state.tick, sound = "hit" }
          alive = false
        elseif alive and not foot and dx * dx + dz * dz <= rr * rr and math.abs(b.pos[2] - s.pos[2]) <= c.height / 2 + t.watcher.bolt_radius then
          hull.damage(s, t.watcher.bolt_damage)
          p.hits = (p.hits or 0) + 1
          p.fx[#p.fx + 1] = { tick = state.tick, sound = "hit" }
          alive = false
        end
      end
    end
    if alive then keep[#keep + 1] = b end
  end
  state.bolts = keep
end

-- Jammer: every sentry of the site within range inside the cone goes Disabled,
-- and so does a Snatcher latched onto the jamming player's own hull
function M.jam(state, site_idx, defs, eye, dir, p)
  local t = M.tune()
  local dyns = state.sentries[site_idx]
  local n = 0
  if not dyns then return 0 end
  for i, def in ipairs(defs) do
    local dyn = dyns[i]
    local pos = dyn.pos or def.pos
    local d = vec.sub(pos, eye)
    local l = vec.len(d)
    -- add-mesh-builder: range is to the sentry's declared hit volumes, the cone is aimed at its centre
    local reach = adv.reach(def, dyn, eye)
    local ok = reach <= (t.jammer.near or 0) or reach <= t.jammer.range and
      (l <= 1e-6 or vec.dot(d, dir) / (l * vec.len(dir)) >= sm.cos(t.jammer.half_angle))
    if p and dyn.st == "latched" and dyn.target == p.index then ok = true end
    if p and dyn.st == "clamped" and dyn.target == p.index then ok = true end
    if dyn.st == "off" then ok = false end
    if ok and (def.kind == "clamp" or def.kind == "lockdown") and dyn.st ~= "disabled" then
      adv.jammed(state, def, dyn, t, M.seal_fn)
      n = n + 1
    elseif ok and dyn.st == "disabled" then
      dyn.t = t.disabled_time -- a fresh pulse restarts the reboot timer
      n = n + 1
    elseif ok then
      if dyn.st == "latched" and dyn.target > 0 and state.players[dyn.target] then
        state.players[dyn.target].latched_by = nil
      end
      dyn.st, dyn.t, dyn.target, dyn.lost = "disabled", t.disabled_time, 0, 0
      n = n + 1
    end
  end
  return n
end

-- for the scanner readout
function M.summary(defs)
  local w, s, c, l, wd = 0, 0, 0, 0, 0
  for _, d in ipairs(defs) do
    if d.kind == "watcher" then w = w + 1
    elseif d.kind == "clamp" then c = c + 1
    elseif d.kind == "lockdown" then l = l + 1
    elseif d.kind == "warden" then wd = wd + 1
    else s = s + 1 end
  end
  return w, s, c, l, wd
end

return M
