-- SPDX-License-Identifier: MIT
-- add-strategic-sentries: the Spotter drone. A small robot that patrols a derelict's great
-- halls (the Warden's kind of route) and never fires. It builds suspicion like a Watcher
-- (sim/stealth.lua), only with a wide cone that sees every hull size; when its meter is full it
-- TAGS you: every Watcher of the site jumps to tag_meter on you and the site alarm rises.
-- A Decoy flare takes its attention, the Jammer stuns it (then an Override spike ends it), the
-- Shroud hides a still hull from it. Placement is derived (not saved); live state rides in
-- state.sentries like the other sentries.
local vec = require("lib.vec")
local configs = require("sim.config")
local stealth = require("sim.stealth")
local sm = saucer.math
local M = {}

local function adv() return require("sim.advsentry") end

-- layout(out, site, ruin, kit, t, light): one Spotter where the site keeps min_watchers Watchers
-- (light: the tutorial derelict's, which fills its meter at light_fill)
function M.layout(out, site, ruin, kit, t, light)
  local S = t.stealth and t.stealth.spotter
  if not S then return end
  local n = 0
  for _, d in ipairs(out) do if d.kind == "watcher" and not d.light then n = n + 1 end end
  if n < S.min_watchers and not light then return end
  local route, _, _, first = require("sim.warden").route(site, ruin, kit)
  if not route then return end
  local pts = {}
  for _, q in ipairs(route) do pts[#pts + 1] = { q[1], q[2] + S.lift, q[3] } end
  if #pts < 3 then
    -- a lone hall: a square round its middle
    local c = pts[1]
    pts = { { c[1] - 15, c[2], c[3] - 15 }, { c[1] + 15, c[2], c[3] - 15 }, { c[1] + 15, c[2], c[3] + 15 },
            { c[1] - 15, c[2], c[3] + 15 }, { c[1] - 15, c[2], c[3] - 15 } }
  end
  local len = 0
  for k = 1, #pts - 1 do len = len + vec.dist(pts[k], pts[k + 1]) end
  out[#out + 1] = { id = #out + 1, kind = "spotter", site = site.id, room = first.id, pos = vec.copy(pts[1]),
                    route = pts, len = math.max(len, 1), speed = S.speed, phase = (site.id * 0.618) % 1,
                    district = first.district, dark = require("sim.cities").dark(ruin, first), light = light or nil }
end

-- where along its route it is at distance u -> pos, yaw
function M.at(def, u)
  local pts = def.route
  u = u % def.len
  for k = 1, #pts - 1 do
    local a, b = pts[k], pts[k + 1]
    local seg = vec.dist(a, b)
    if u <= seg and seg > 0 then
      local f = u / seg
      return { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f }, sm.atan2(b[1] - a[1], b[3] - a[3])
    end
    u = u - seg
  end
  return vec.copy(pts[1]), 0
end

function M.new_state(def)
  local u = def.phase * def.len
  local pos, yaw = M.at(def, u)
  return { st = "dormant", t = 0, lost = 0, target = 0, u = u, pos = pos, yaw = yaw, pitch = -0.35, meter = 0 }
end

-- can it see p? -> ok, range
function M.sees(def, dyn, p, t)
  local S = t.stealth.spotter
  if p.site ~= def.site or p.mode == "wake" then return false end
  if adv().shrouded(p, t) then return false end
  local foot = p.mode == "foot" and p.excursion
  if p.mode == "foot" and not foot then return false end
  local range
  if foot then range = S.foot_range
  else range = configs.get(p.ship.size).class < 2 and S.small_range or S.range end
  local dir = require("sim.sentry").dir_of(dyn.yaw, dyn.pitch or -0.35)
  return saucer.physics.cone_visible(dyn.pos, dir, sm.cos(S.half_angle), range, p.ship.pos, 1), range
end

local function tag(state, def, dyn, p, ctx, t)
  local S = t.stealth
  local game = require("sim.game")
  local n = 0
  for i, d in ipairs(game.sentries(def.site)) do
    local o = state.sentries[def.site][i]
    if d.kind == "watcher" and o and o.st ~= "off" and o.st ~= "disabled" then
      o.meter = math.max(o.meter or 0, S.spotter.tag_meter)
      o.sus = p.index
      n = n + 1
    end
  end
  dyn.st, dyn.t, dyn.lost = "tagged", S.spotter.rest, 0
  dyn.tags = (dyn.tags or 0) + 1
  p.tagged = (p.tagged or 0) + 1
  ctx.fx(state, p, "locked")
  ctx.msg(state, p, string.format("TAGGED by a Spotter: %d Watcher%s here know%s where you are", n, n == 1 and "" or "s",
    n == 1 and "s" or ""))
  stealth.raise(state, def.site, 1, ctx, "a Spotter tagged you")
  require("sim.sentry").tip(state, p, ctx, "spotter",
    "TIP: a Spotter never fires but tags you for every Watcher. Decoy (B) or Jam (T) it before its light goes red.")
end

function M.step(state, def, dyn, dt, ctx, t)
  local S = t.stealth.spotter
  if dyn.st == "off" then return end
  if dyn.st == "disabled" then
    dyn.t = dyn.t - dt
    dyn.meter = 0
    if dyn.t <= 0 then dyn.st, dyn.t, dyn.lost = "dormant", 0, 0 end
    return
  end
  local dec = t.decoy and adv().decoy_for(state, def, dyn.pos, t)
  if dec then
    local d = vec.sub(dec.pos, dyn.pos)
    dyn.yaw = sm.atan2(d[1], d[3])
    dyn.st, dyn.target, dyn.t, dyn.lost = "decoyed", 0, 0, 0
    dyn.meter = math.max(0, (dyn.meter or 0) - t.stealth.decay * dt)
    return
  end
  if dyn.st == "decoyed" then dyn.st = "dormant" end
  local target = dyn.target > 0 and state.players[dyn.target] or nil
  if dyn.st == "alert" and target then
    -- it stops and stares
    local d = vec.sub(target.ship.pos, dyn.pos)
    dyn.yaw = sm.atan2(d[1], d[3])
    dyn.pitch = sm.atan2(d[2], sm.sqrt(d[1] * d[1] + d[3] * d[3]))
  else
    dyn.u = (dyn.u + def.speed * dt) % def.len
    dyn.pos, dyn.yaw = M.at(def, dyn.u)
    dyn.pitch = -0.35
  end
  if dyn.st == "tagged" then
    dyn.t = dyn.t - dt
    dyn.meter = math.max(0, (dyn.meter or 0) - t.stealth.decay * dt)
    if dyn.t <= 0 then dyn.st, dyn.t, dyn.target, dyn.lost = "dormant", 0, 0, 0 end
    return
  end
  local seen, range
  local ok, rr
  if target then ok, rr = M.sees(def, dyn, target, t) end
  if ok then
    seen, range = target, rr
  elseif dyn.st == "dormant" then
    for _, p in ipairs(state.players) do
      ok, rr = M.sees(def, dyn, p, t)
      if ok then seen, range = p, rr break end
    end
  end
  stealth.step_meter(state, def, dyn, seen, seen and vec.dist(seen.ship.pos, dyn.pos) or 0, range or 1, dt)
  if dyn.st == "dormant" then
    if seen and dyn.meter >= t.stealth.alert then
      dyn.st, dyn.t, dyn.lost, dyn.target = "alert", 0, 0, seen.index
      ctx.fx(state, seen, "alert")
      ctx.msg(state, seen, "A Spotter stirs: blue eye on you, its meter climbing")
    end
    return
  end
  if seen then dyn.lost = 0 else dyn.lost = dyn.lost + dt end
  if dyn.lost >= t.lose_time then
    dyn.st, dyn.t, dyn.target, dyn.lost = "dormant", 0, 0, 0
    return
  end
  dyn.t = dyn.t + dt
  if seen and dyn.meter >= 1 and dyn.t >= t.alert_time then tag(state, def, dyn, seen, ctx, t) end
end

return M
