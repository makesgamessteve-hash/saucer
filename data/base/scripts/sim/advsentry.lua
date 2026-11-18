-- SPDX-License-Identifier: MIT
-- Advanced sentries and tools (concept §8.2-8.3; OpenSpec add-wider-dark).
-- Robots only, nothing lethal:
--   * Clamp: a drone in a great hall that grabs your hull. While it holds on
--     you cannot change size and it drains Charge. Hold Boost to shake it
--     off, or Jam it.
--   * Lockdown node: a wall unit that wakes when any Watcher of its site
--     locks on and seals the big doors of its hall for 60 s. Jam it, or
--     Override it for good.
--   * Decoy flare (tool): every sentry of the site that can see it tracks it
--     for 8 s instead of you.
--   * Shroud (saucer utility): while you hover still, Watchers and Clamps
--     cannot see you; it drains Charge.
--   * Override spike (on-foot tool): 3 s at a Disabled sentry or a Lockdown
--     node shuts it down for good and drops a sentry core.
-- Placement is derived from the ruin (not saved); live state rides in
-- state.sentries like the other sentries; decoys in state.decoys, overridden
-- sentries in state.overrides (both kept per sector).
local vec = require("lib.vec")
local ruinm = require("sim.ruin")
local meshkit = require("lib.meshkit")
local volume = require("lib.volume")
local configs = require("sim.config")
local M = {}

local function ap() return require("sim.autopilot") end

-- the seal box of one door hole
function M.door_box(d, ruin, kit, origin, thick)
  local c = ap().door_center(d, ruin.rooms, kit, origin)
  local dw = kit.doors[d.class]
  local half = { 0, 0, 0 }
  if d.axis == 2 then
    half = { dw[1] / 2 + 0.5, thick / 2, dw[1] / 2 + 0.5 }
  else
    local l = d.axis == 1 and 3 or 1
    half[l], half[2], half[d.axis] = dw[1] / 2 + 0.5, dw[2] / 2 + 0.5, thick / 2
  end
  return { vec.sub(c, half), vec.add(c, half), c }
end

-- layout(out, site, ruin, kit, t): Clamps in the first great halls, one
-- Lockdown node in the hall with the most big doors
function M.layout(out, site, ruin, kit, t)
  local big = kit.big or 4
  local clamps, best, bestn = 0, nil, 0
  for _, r in ipairs(ruin.rooms) do
    if r.class >= big and r.kind ~= "entrance" and r.kind ~= "shaft" then
      local mn, mx = ruinm.room_box(r, kit, site.pos)
      if clamps < t.clamp.per_site then
        clamps = clamps + 1
        local home = { (mn[1] + mx[1]) / 2 + (mx[1] - mn[1]) / 5, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }
        local lo, hi = vec.sub(mn, { 6, 6, 6 }), vec.add(mx, { 6, 6, 6 })
        out[#out + 1] = { id = #out + 1, kind = "clamp", site = site.id, room = r.id, pos = home, leash = { lo, hi },
                          floor = mn[2] + kit.wall + 0.5 }
      end
      local n = 0
      for _, d in ipairs(ruin.doors) do
        if (d.a == r.id or d.b == r.id) and d.class >= big then n = n + 1 end
      end
      if n > bestn then best, bestn = r, n end
    end
  end
  if best then
    local mn, mx = ruinm.room_box(best, kit, site.pos)
    local boxes = {}
    for _, d in ipairs(ruin.doors) do
      if (d.a == best.id or d.b == best.id) and d.class >= big then
        boxes[#boxes + 1] = M.door_box(d, ruin, kit, site.pos, t.lockdown.thickness)
      end
    end
    -- the node sits on the hall's -x wall, at standing height above its floor
    local pos = { mn[1] + kit.wall + 0.4, mn[2] + kit.wall + 2.0, (mn[3] + mx[3]) / 2 }
    out[#out + 1] = { id = #out + 1, kind = "lockdown", site = site.id, room = best.id, pos = pos, boxes = boxes,
                      floor = mn[2] + kit.wall }
  end
end

function M.new_state(d)
  if d.kind == "clamp" then return { st = "dormant", t = 0, lost = 0, target = 0, pos = vec.copy(d.pos) } end
  return { st = "dormant", t = 0, target = 0, sealed = {} }
end

function M.key(def) return def.site .. ":" .. def.id end
function M.overridden(state, def) return (state.overrides or {})[M.key(def)] ~= nil end

-- the live decoy this sentry tracks (in its site, in range, in sight), or nil
function M.decoy_for(state, def, pos, t)
  for _, d in ipairs(state.decoys or {}) do
    if d.site == def.site and vec.dist(d.pos, pos) <= t.decoy.range then
      local dir = vec.sub(d.pos, pos)
      if not saucer.physics.raycast(pos, dir, 0.98, 1) then return d end
    end
  end
  return nil
end

-- is p hidden by the Shroud right now?
function M.shrouded(p, t)
  return p.shroud and p.mode ~= "foot" and vec.len(p.ship.vel) <= t.shroud.still or false
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

function M.clamp_wants(def, dyn, p, t)
  if p.site ~= def.site or p.mode == "foot" or M.shrouded(p, t) then return false end
  if not in_box(def.leash, p.ship.pos) then return false end
  if vec.dist(dyn.pos, p.ship.pos) > t.clamp.sense then return false end
  return not saucer.physics.raycast(dyn.pos, vec.sub(p.ship.pos, dyn.pos), 0.9, 1)
end

function M.release(state, dyn)
  local p = dyn.target > 0 and state.players[dyn.target] or nil
  if p then
    p.clamped_by = nil
    p.shake = 0
  end
end

function M.step_clamp(state, def, dyn, dt, ctx, t)
  if dyn.st == "off" then return end
  if dyn.st == "disabled" then
    -- a stunned Clamp sinks to the floor (where a person on foot can spike it)
    dyn.pos = move_to(dyn.pos, { dyn.pos[1], def.floor, dyn.pos[3] }, 4, dt)
    dyn.t = dyn.t - dt
    if dyn.t <= 0 then dyn.st, dyn.t, dyn.lost = "dormant", 0, 0 end
    return
  end
  local target = dyn.target > 0 and state.players[dyn.target] or nil
  if dyn.st == "clamped" then
    if not target or target.site ~= def.site or target.mode == "foot" then
      M.release(state, dyn)
      dyn.st, dyn.t, dyn.target = "dormant", 0, 0
      return
    end
    local _, hh = require("sim.ship").dims(target.ship)
    dyn.pos = { target.ship.pos[1], target.ship.pos[2] + hh + 0.4, target.ship.pos[3] }
    target.clamped_by = { site = def.site, id = def.id }
    target.ship.charge = math.max(0, target.ship.charge - t.clamp.drain * dt)
    if (target.shake or 0) >= t.clamp.shake_time then
      M.release(state, dyn)
      dyn.st, dyn.t, dyn.target = "disabled", t.disabled_time, 0
      ctx.msg(state, target, "You shook the Clamp off!")
      ctx.fx(state, target, "jam")
    end
    return
  end
  local dec = M.decoy_for(state, def, dyn.pos, t)
  if dec then
    dyn.st, dyn.target = "decoyed", 0
    dyn.pos = move_to(dyn.pos, dec.pos, t.clamp.chase_speed, dt)
    return
  end
  if dyn.st == "decoyed" then dyn.st = "dormant" end
  local seen
  if target and M.clamp_wants(def, dyn, target, t) then seen = target
  elseif dyn.st == "dormant" then
    for _, p in ipairs(state.players) do
      if M.clamp_wants(def, dyn, p, t) then seen = p break end
    end
  end
  if dyn.st == "dormant" then
    dyn.pos = move_to(dyn.pos, def.pos, 3, dt)
    if seen then
      dyn.st, dyn.target, dyn.lost = "chase", seen.index, 0
      ctx.fx(state, seen, "alert")
      ctx.msg(state, seen, "A Clamp drone comes for your hull!")
    end
    return
  end
  -- chase
  if not seen then
    dyn.lost = dyn.lost + dt
    if dyn.lost >= t.lose_time then dyn.st, dyn.target, dyn.lost = "dormant", 0, 0 end
    return
  end
  dyn.lost = 0
  local r = configs.get(seen.ship.size).diameter / 2
  dyn.pos = move_to(dyn.pos, seen.ship.pos, t.clamp.chase_speed, dt)
  if vec.dist(dyn.pos, seen.ship.pos) <= r + t.clamp.grip then
    dyn.st, dyn.t = "clamped", 0
    seen.clamped_by = { site = def.site, id = def.id }
    seen.shake = 0
    ctx.fx(state, seen, "locked")
    ctx.msg(state, seen, "CLAMPED: no folding. Hold Boost to shake it off, or Jam it")
  end
end

-- any Watcher of this site locked on?
local function alarm(state, site)
  local game = require("sim.game")
  for i, def in ipairs(game.sentries(site)) do
    local dyn = state.sentries[site] and state.sentries[site][i]
    if def.kind == "watcher" and dyn and dyn.st == "locked" then return true end
    if def.kind == "warden" and dyn and dyn.st == "hunt" then return true end -- add-home-among-stars
  end
  return false
end

function M.step_lockdown(state, def, dyn, dt, ctx, t, seal)
  if dyn.st == "off" then return end
  if dyn.st == "disabled" then
    if #dyn.sealed > 0 then seal(def, dyn, false) end
    dyn.t = dyn.t - dt
    if dyn.t <= 0 then dyn.st, dyn.t = "dormant", 0 end
    return
  end
  if dyn.st == "sealing" then
    dyn.t = dyn.t - dt
    if dyn.t <= 0 then
      seal(def, dyn, false)
      dyn.st, dyn.t = "rest", t.lockdown.rest
    end
    return
  end
  if dyn.st == "rest" then
    dyn.t = dyn.t - dt
    if dyn.t <= 0 then dyn.st, dyn.t = "dormant", 0 end
    return
  end
  if alarm(state, def.site) then
    dyn.st, dyn.t = "sealing", t.lockdown.seal_time
    seal(def, dyn, true)
    for _, p in ipairs(state.players) do
      if p.site == def.site then
        ctx.msg(state, p, "LOCKDOWN: the hall's doors are sealed for 60 s. Jam the node or find another way")
        ctx.fx(state, p, "alert")
      end
    end
  end
end

-- the Jammer hit a Clamp or a Lockdown node
function M.jammed(state, def, dyn, t, seal)
  if dyn.st == "off" then return false end
  if def.kind == "clamp" and dyn.st == "clamped" then M.release(state, dyn) end
  if def.kind == "lockdown" and #dyn.sealed > 0 then seal(def, dyn, false) end
  dyn.st, dyn.t, dyn.target = "disabled", t.disabled_time, 0
  return true
end

function M.pos_of(def, dyn) return dyn.pos or def.pos end

-- add-mesh-builder: how far point p is from a sentry's declared hit volumes (meshes/watcher.lua and
-- meshes/snatcher.lua: 0 inside them). Sentries without a recipe of their own count from their centre.
local HIT_RECIPE = { watcher = "watcher", snatcher = "snatcher" }
function M.reach(def, dyn, p)
  local id = HIT_RECIPE[def.kind]
  if not id then return vec.dist(M.pos_of(def, dyn), p) end
  local vols = meshkit.volumes(id, nil, def.glyph or 1)
  return (volume.nearest(vols, { pos = M.pos_of(def, dyn), yaw = dyn.yaw or def.yaw or 0 }, p))
end

-- Override spike target for p on foot: the nearest Disabled sentry or any
-- Lockdown node within reach -> site, index
function M.spike_target(state, p, t)
  local game = require("sim.game")
  if not (p.mode == "foot" and p.excursion) or p.site == 0 then return nil end
  local eye = game.viewpoint(p)
  local best, bd
  for i, def in ipairs(game.sentries(p.site)) do
    local dyn = state.sentries[p.site] and state.sentries[p.site][i]
    if dyn and dyn.st ~= "off" and (dyn.st == "disabled" or def.kind == "lockdown") then
      local d = M.reach(def, dyn, eye)
      if d <= t.spike.reach and (not bd or d < bd) then best, bd = i, d end
    end
  end
  return best
end

function M.core_item()
  return { type = "sentry_core", name = "Sentry core", size = 1, value = 55, rarity = "common", category = "material",
           ident = true }
end

return M
