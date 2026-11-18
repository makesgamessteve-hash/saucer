-- SPDX-License-Identifier: MIT
-- The Warden (OpenSpec add-home-among-stars, concept §8.2): the deepest
-- derelicts (danger 3) keep one big hunter. Robots only, nothing lethal:
--   * It patrols its great halls and moves between them through the big
--     doors - doors of its class; it never fits into ducts or side rooms.
--   * When it sees a hull (or a person on foot, closer) it hunts: it gives
--     chase inside its halls, fires stun bolts and wakes every Snatcher of
--     the site (they sense twice as far for 30 s).
--   * A Decoy flare takes its attention; the Shroud hides a still hull from
--     it; only the Jammer stuns it (an Override spike then shuts it down for
--     good). Clamps shake off, a Warden does not.
-- Placement is derived from the ruin (not saved); live state rides in
-- state.sentries like the other sentries.
local vec = require("lib.vec")
local ruinm = require("sim.ruin")
local M = {}

local function ap() return require("sim.autopilot") end
local function adv() return require("sim.advsentry") end

-- layout(out, site, ruin, kit, t): one Warden on a route through the great
-- halls joined by big doors (hall centre, door, hall centre, ...)
function M.layout(out, site, ruin, kit, t)
  local big = kit.big or 4
  local halls, by_id = {}, {}
  for _, r in ipairs(ruin.rooms) do
    if r.class >= big and r.kind ~= "entrance" and r.kind ~= "shaft" and not r.calm then
      halls[#halls + 1] = r
      by_id[r.id] = r
    end
  end
  if #halls == 0 then return end
  local function centre(r)
    local mn, mx = ruinm.room_box(r, kit, site.pos)
    return { (mn[1] + mx[1]) / 2, mn[2] + kit.wall + 3.0, (mn[3] + mx[3]) / 2 }, mn, mx
  end
  -- depth-first walk from the first hall through big doors, there and back
  local route, seen = {}, {}
  local lo, hi
  local function visit(r)
    seen[r.id] = true
    local c, mn, mx = centre(r)
    route[#route + 1] = c
    lo = lo and { math.min(lo[1], mn[1]), math.min(lo[2], mn[2]), math.min(lo[3], mn[3]) } or mn
    hi = hi and { math.max(hi[1], mx[1]), math.max(hi[2], mx[2]), math.max(hi[3], mx[3]) } or mx
    for _, d in ipairs(ruin.doors) do
      local other = (d.a == r.id and d.b) or (d.b == r.id and d.a) or nil
      if other and d.class >= big and by_id[other] and not seen[other] then
        local dc = ap().door_center(d, ruin.rooms, kit, site.pos)
        route[#route + 1] = { dc[1], dc[2], dc[3] }
        visit(by_id[other])
        route[#route + 1] = { dc[1], dc[2], dc[3] }
        route[#route + 1] = c
      end
    end
  end
  visit(halls[1])
  local pad = t.warden.leash
  out[#out + 1] = { id = #out + 1, kind = "warden", site = site.id, room = halls[1].id, pos = vec.copy(route[1]),
                    district = halls[1].district, dark = require("sim.cities").dark(ruin, halls[1]),
                    route = route, leash = { vec.sub(lo, { pad, pad, pad }), vec.add(hi, { pad, pad, pad }) } }
end

function M.new_state(def)
  return { st = "patrol", t = 0, lost = 0, target = 0, fire = 0, wp = 1, pos = vec.copy(def.pos) }
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

-- can the Warden see p from where it is?
function M.sees(def, dyn, p, t)
  if p.site ~= def.site or p.mode == "wake" or adv().shrouded(p, t) then return false end
  local foot = p.mode == "foot" and p.excursion
  if p.mode == "foot" and not foot then return false end
  local q = p.ship.pos
  if not in_box(def.leash, q) then return false end
  local range = foot and t.warden.foot_sense or t.warden.sense
  local d = vec.sub(q, dyn.pos)
  if vec.len(d) > range then return false end
  return not saucer.physics.raycast(dyn.pos, d, 0.95, 1)
end

-- wake the site's Snatchers: they sense twice as far for a while
function M.wake_snatchers(state, def, t)
  local game = require("sim.game")
  local n = 0
  for i, d in ipairs(game.sentries(def.site)) do
    local dyn = state.sentries[def.site] and state.sentries[def.site][i]
    if d.kind == "snatcher" and dyn and dyn.st ~= "off" then
      dyn.woke = state.tick + math.floor(t.warden.wake * 60)
      n = n + 1
    end
  end
  return n
end

-- slow: the site's grid is down (add-playtest-recs): it patrols and hunts
-- at `drowsy` of its speed, fires half as often and wakes no Snatchers
function M.step(state, def, dyn, dt, ctx, t, slow)
  local w = t.warden
  if slow then
    local k = w.drowsy or 0.5
    local s = {}
    for key, v in pairs(w) do s[key] = v end
    s.speed, s.chase_speed, s.fire_every = w.speed * k, w.chase_speed * k, w.fire_every / k
    w = s
  end
  dyn.drowsy = slow or nil
  if dyn.st == "off" then return end
  if dyn.st == "disabled" then
    dyn.t = dyn.t - dt
    if dyn.t <= 0 then dyn.st, dyn.t, dyn.lost, dyn.target = "patrol", 0, 0, 0 end
    return
  end
  local dec = t.decoy and adv().decoy_for(state, def, dyn.pos, t)
  if dec then
    dyn.st, dyn.target = "decoyed", 0
    dyn.pos = move_to(dyn.pos, dec.pos, w.chase_speed, dt)
    return
  end
  if dyn.st == "decoyed" then dyn.st = "patrol" end
  local target = dyn.target > 0 and state.players[dyn.target] or nil
  local seen
  if target and M.sees(def, dyn, target, t) then
    seen = target
  else
    for _, p in ipairs(state.players) do
      if M.sees(def, dyn, p, t) then seen = p break end
    end
  end
  if dyn.st == "patrol" then
    local goal = def.route[dyn.wp]
    local arrived
    dyn.pos, arrived = move_to(dyn.pos, goal, w.speed, dt)
    if arrived then dyn.wp = dyn.wp % #def.route + 1 end
    if seen then
      dyn.st, dyn.target, dyn.lost, dyn.fire = "hunt", seen.index, 0, slow and 1.2 or 0.6
      local woke = slow and 0 or M.wake_snatchers(state, def, t)
      ctx.fx(state, seen, "alert")
      ctx.msg(state, seen, woke > 0 and "THE WARDEN has seen you - and the Snatchers wake. Jam it, or break its line of sight"
        or "THE WARDEN has seen you. Jam it, or break its line of sight")
    end
    return
  end
  -- hunt
  if not seen then
    dyn.lost = dyn.lost + dt
    if dyn.lost >= t.lose_time * 3 then
      dyn.st, dyn.target, dyn.lost = "patrol", 0, 0
      -- back to the nearest point of its route
      local best, bd = 1, nil
      for i, q in ipairs(def.route) do
        local d = vec.dist(q, dyn.pos)
        if not bd or d < bd then best, bd = i, d end
      end
      dyn.wp = best
    end
    return
  end
  dyn.lost, dyn.target = 0, seen.index
  local q = seen.ship.pos
  -- keep a little distance and stay inside its halls
  local d = vec.sub(q, dyn.pos)
  if vec.len(d) > 8 then
    local np = move_to(dyn.pos, q, w.chase_speed, dt)
    if in_box(def.leash, np) then dyn.pos = np end
  end
  dyn.fire = dyn.fire - dt
  if dyn.fire <= 0 then
    dyn.fire = w.fire_every
    local l = vec.len(d)
    state.bolts[#state.bolts + 1] = { site = def.site, pos = vec.copy(dyn.pos),
      vel = vec.scale(d, t.watcher.bolt_speed / math.max(l, 1e-6)), life = t.watcher.bolt_life }
  end
end

return M
