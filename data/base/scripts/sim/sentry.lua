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
local sm = saucer.math
local M = {}

function M.tune() return data.load("sentries/sentries.lua") end

-- layout(site, ruin, civ) -> list of sentry definitions (derived data).
-- The tutorial derelict (site 1) is unguarded.
function M.layout(site, ruin, civ)
  local out = {}
  if site.id == 1 or not ruin then return out end
  local kit = ruinm.kit_of(ruin.kit)
  local t = M.tune()
  local big = kit.big or 4
  local band = t.watcher.band[civ and civ.body or "human"] or { 2, 4 }
  for _, r in ipairs(ruin.rooms) do
    local mn, mx = ruinm.room_box(r, kit, site.pos)
    if r.class >= big and r.kind ~= "entrance" then
      -- a ceiling turret at the far end of the hall, looking back at the door you come in by
      local door
      for _, d in ipairs(ruin.doors) do if d.b == r.id then door = d end end
      local c = { (mn[1] + mx[1]) / 2, mx[2] - kit.wall - 3.0, (mn[3] + mx[3]) / 2 }
      local tgt = { c[1], mn[2], c[3] }
      local pos = { c[1], c[2], c[3] }
      local ax, sg = door and door.axis or 3, door and door.sign or 1
      local near = sg > 0 and mn[ax] or mx[ax]
      local far = sg > 0 and mx[ax] or mn[ax]
      tgt[ax] = near
      pos[ax] = far - sg * (kit.wall + 6.0)
      local yaw = sm.atan2(tgt[1] - pos[1], tgt[3] - pos[3])
      out[#out + 1] = { id = #out + 1, kind = "watcher", site = site.id, room = r.id, pos = pos, yaw = yaw,
                        pitch = -0.32, band = band }
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
      local along = (mx[1] - mn[1]) > (mx[3] - mn[3]) and 1 or 3
      local a, b = { cx, floor + 1.6, cz }, { cx, floor + 1.6, cz }
      local half = ((along == 1) and (mx[1] - mn[1]) or (mx[3] - mn[3])) / 2 - 1.5
      a[along] = a[along] - half
      b[along] = b[along] + half
      local nest = { (dmn[1] + dmx[1]) / 2, dmn[2] + kit.wall + 0.6, (dmn[3] + dmx[3]) / 2 }
      if deepest == r then nest = { b[1], floor + 0.6, b[3] } end
      -- leashed to its duct branch: leave it and the Snatcher gives up
      local lo, hi = {}, {}
      for k = 1, 3 do
        lo[k] = math.min(mn[k], dmn[k]) - 2
        hi[k] = math.max(mx[k], dmx[k]) + 2
      end
      out[#out + 1] = { id = #out + 1, kind = "snatcher", site = site.id, room = r.id, pos = { cx, floor + 1.6, cz },
                        patrol = { a, b }, nest = nest, nest_room = deepest.id, leash = { lo, hi } }
    end
  end
  return out
end

function M.new_state(defs)
  local out = {}
  for i, d in ipairs(defs) do
    if d.kind == "watcher" then
      out[i] = { st = "dormant", t = 0, lost = 0, fire = 0, target = 0, yaw = d.yaw }
    else
      out[i] = { st = "dormant", t = 0, lost = 0, target = 0, pos = vec.copy(d.pos), wp = 2, carry = false }
    end
  end
  return out
end

local function dir_of(yaw, pitch)
  local cp = sm.cos(pitch)
  return { sm.sin(yaw) * cp, sm.sin(pitch), sm.cos(yaw) * cp }
end
M.dir_of = dir_of

-- can this Watcher see player p's hull right now?
function M.watcher_sees(def, dyn, p, tick, t)
  local ship = p.ship
  if p.site ~= def.site then return false end
  local cls = configs.get(ship.size).class
  if cls < def.band[1] or cls > def.band[2] then return false end
  local yaw = dyn.yaw
  local dir = dir_of(yaw, def.pitch)
  local r = configs.get(ship.size).diameter / 2
  return saucer.physics.cone_visible(def.pos, dir, sm.cos(t.watcher.half_angle), t.watcher.range + r, ship.pos, 1)
end

local function sweep_yaw(def, tick, t)
  local w = t.watcher
  return def.yaw + w.sweep * sm.sin(sm.tau * tick / (w.sweep_period * 60))
end

local function step_watcher(state, def, dyn, dt, ctx, t)
  if dyn.st == "disabled" then
    dyn.t = dyn.t - dt
    if dyn.t <= 0 then dyn.st, dyn.t, dyn.lost = "dormant", 0, 0 end
    return
  end
  local target = dyn.target > 0 and state.players[dyn.target] or nil
  if dyn.st == "locked" and target then
    local d = vec.sub(target.ship.pos, def.pos)
    dyn.yaw = sm.atan2(d[1], d[3])
  else
    dyn.yaw = sweep_yaw(def, state.tick, t)
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

-- the Seat is the only hull a Snatcher can latch onto
local function seat(p) return not configs.get(p.ship.size).interior and configs.get(p.ship.size).class <= 1 end

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
  if p.site ~= def.site or not seat(p) or #items.losable(p) == 0 then return false end
  if def.leash and not in_box(def.leash, p.ship.pos) then return false end
  return vec.dist(dyn.pos, p.ship.pos) <= t.snatcher.sense
end

local function step_snatcher(state, def, dyn, dt, ctx, t)
  local s = t.snatcher
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
      local lost = items.losable(target)
      local it = lost[#lost]
      target.latched_by = nil
      if it then
        items.remove(target, it.uid)
        dyn.carry, dyn.carry_owner = { item = it, owner = target.record_index }, target.index
        dyn.st, dyn.t, dyn.target = "flee", 0, 0
        ctx.fx(state, target, "denied")
        ctx.msg(state, target, "A Snatcher siphoned " .. items.label(it) .. " and flees to its nest")
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

-- one tick for every sentry of a site, then the bolts
function M.step(state, site_idx, defs, dt, ctx)
  local t = M.tune()
  local dyns = state.sentries[site_idx]
  if not dyns then return end
  for i, def in ipairs(defs) do
    local dyn = dyns[i]
    if def.kind == "watcher" then step_watcher(state, def, dyn, dt, ctx, t)
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
        local rr = c.diameter / 2 + t.watcher.bolt_radius
        if alive and dx * dx + dz * dz <= rr * rr and math.abs(b.pos[2] - s.pos[2]) <= c.height / 2 + t.watcher.bolt_radius then
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
    local ok = l <= (t.jammer.near or 0) or l <= t.jammer.range and ( vec.dot(d, dir) / (l * vec.len(dir)) >= sm.cos(t.jammer.half_angle))
    if p and dyn.st == "latched" and dyn.target == p.index then ok = true end
    if ok and dyn.st == "disabled" then
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
  local w, s = 0, 0
  for _, d in ipairs(defs) do if d.kind == "watcher" then w = w + 1 else s = s + 1 end end
  return w, s
end

return M
