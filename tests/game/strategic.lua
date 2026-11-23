-- SPDX-License-Identifier: MIT
-- add-strategic-sentries: at derelict 2, through the full game loop. The Scanner marks the
-- guarded finds (on the floor in a Watcher's cone); the Seat in a Watcher's sweep fills its
-- suspicion meter and the meter drains again once it ducks out, with no lock; the Seat beams
-- out a Watcher's rear power cell (it goes dark for good, the cell sells); a Spotter tags the
-- Villa (every Watcher meter jumps, the alarm rises); Watcher locks escalate the site alarm
-- (the Snatchers wake at 2, the Lockdown trips) and, away from the site, it cools back down.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local sentry = require("sim.sentry")
local stealth = require("sim.stealth")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs or {}) do if m.text:find(s, 1, true) then return true end end
  return false
end
local S = sentry.tune().stealth
T.assert(S ~= nil, "stealth tuning is loaded")

T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")

local site = 2
local ruin, origin = game.ruin(site), T.state().sector.sites[site].pos
local defs = game.sentries(site)
local function dyn(i) return T.state().sentries[site][i] end
local hw, hi, sp, si
for i, d in ipairs(defs) do
  if d.kind == "watcher" and d.cell and not hw then hw, hi = d, i end
  if d.kind == "spotter" and not sp then sp, si = d, i end
end
T.assert(hw and sp, "derelict 2 has a hall Watcher with a power cell and a Spotter")

-- 1. guarded loot: the Scanner marks it; it lies in its Watcher's room, inside the cone
local first = ap.route(ruin, origin, hw.room)[1]
T.assert(ap.travel(T, 1, get, first.pos, 4, 6000), "flew to derelict 2")
T.press(1, "scan")
T.wait(1)
T.assert(said("GUARDED find"), "the Scanner counts the guarded finds")
local g
for _, s in ipairs(ruin.slots) do if s.guarded == hw.id then g = s end end
T.assert(g and g.room == hw.room and g.premium > 1, "the hall Watcher guards a find in its room, worth more")
local to = vec.sub(g.pos, hw.pos)
local best = -1
for k = -8, 8 do
  best = math.max(best, vec.dot(to, sentry.dir_of(hw.yaw + k / 8 * sentry.tune().watcher.sweep, hw.pitch)) / vec.len(to))
end
T.assert(best > math.cos(sentry.tune().watcher.half_angle), "the guarded find lies inside the sweep cone")

-- 2. the meter: the Seat sits in the sweep, the meter climbs; out of sight it drains; no lock
T.assert(ap.resize(T, 1, get, 2), "folded to the Seat")
local p = get()
local locks0 = dyn(hi).lock_tick or -1
p.ship.pos = vec.add(hw.pos, vec.scale(sentry.dir_of(hw.yaw, hw.pitch), 18))
p.ship.vel = { 0, 0, 0 }
T.assert(ap.wait_until(T, 1, function() return (dyn(hi).meter or 0) >= 0.2 end, 600),
  "the Watcher's meter climbs on the Seat (" .. tostring(dyn(hi).meter) .. ")")
local peak = dyn(hi).meter
p = get()
p.ship.pos = vec.add(hw.pos, vec.scale(sentry.dir_of(hw.yaw + math.pi, 0), 2))
p.ship.pos[2] = hw.pos[2] + 1
p.ship.vel = { 0, 0, 0 }
T.assert(ap.wait_until(T, 1, function() return (dyn(hi).meter or 0) <= 0.01 end, 60 * 8),
  "out of its sight the meter drains (" .. tostring(dyn(hi).meter) .. ")")
T.assert(peak < 1 and (dyn(hi).lock_tick or -1) == locks0 and dyn(hi).st ~= "locked", "and no lock came of it")

-- 3. sabotage: the Seat beams out the rear power cell
local cell0 = #get().hold
local stolen = ap.grab(T, 1, get, site, ruin, hw.room, nil, function(c) return c.kind == "cell" and c.def == hw end)
T.assert(stolen >= 1, "beamed out the Watcher's power cell")
T.assert(dyn(hi).st == "off", "that Watcher went dark")
T.assert(said("Power cell out"), "the game says so")
T.assert(#get().hold > cell0 and get().hold[#get().hold].name == "Watcher power cell", "the cell is in the hold")
T.assert((get().sabotaged or 0) >= 1, "counted as sabotage")
T.wait(120)
T.assert(dyn(hi).st == "off", "and stays dark")

-- 4. the Spotter tags the Villa: every Watcher here jumps, the alarm rises
do
  local q = get()
  q.ship.pos, q.ship.vel = vec.add(origin, { 0, 400, 0 }), { 0, 0, 0 }
end
T.wait(2)
T.assert(ap.resize(T, 1, get, 1), "unfolded to the Villa out in the open")
local lv0 = stealth.level(T.state(), site)
local tagged = ap.wait_until(T, 1, function()
  local q, d = get(), dyn(si)
  if d.st ~= "tagged" then
    q.ship.pos = vec.add(d.pos, vec.scale(sentry.dir_of(d.yaw, -0.35), 14))
    q.ship.vel = { 0, 0, 0 }
  end
  return d.st == "tagged"
end, 60 * 20)
T.assert(tagged, "the Spotter tagged the Villa")
T.assert(said("TAGGED by a Spotter"), "the game says so")
for i, d in ipairs(defs) do
  if d.kind == "watcher" and dyn(i).st ~= "off" then
    T.assert((dyn(i).meter or 0) >= S.spotter.tag_meter - 0.2 or dyn(i).st == "alert" or dyn(i).st == "locked",
      "Watcher " .. d.id .. " knows (" .. tostring(dyn(i).meter) .. ")")
  end
end
T.assert(stealth.level(T.state(), site) > lv0, "the tag raised the site alarm")

-- 5. escalation: the Villa in front of other Watchers until the alarm hits 2
local ok = ap.wait_until(T, 1, function()
  if stealth.level(T.state(), site) >= S.wake_at then return true end
  for i, d in ipairs(defs) do
    if d.kind == "watcher" and dyn(i).st ~= "off" and dyn(i).st ~= "locked" then
      local q = get()
      q.ship.pos = vec.add(d.pos, vec.scale(sentry.dir_of(d.yaw, d.pitch), 20))
      q.ship.vel = { 0, 0, 0 }
      break
    end
  end
  return false
end, 60 * 30)
T.assert(ok, "Watcher locks raised the alarm to " .. S.wake_at .. " (" .. stealth.level(T.state(), site) .. ")")
T.assert(said("SITE ALARM 2/"), "the HUD alert names the level")
local has = {}
for _, d in ipairs(defs) do has[d.kind] = true end
T.assert(said("The alarm wakes") or not has.snatcher, "the Snatchers woke")
local sealed = false
for i, d in ipairs(defs) do if d.kind == "lockdown" and dyn(i).st ~= "dormant" then sealed = true end end
T.assert(sealed or said("LOCKDOWN") or not has.lockdown, "the Lockdown tripped")

-- 6. cooldown: out in the dark the alarm eases a level per cool_out
local lv = stealth.level(T.state(), site)
local q = get()
q.ship.pos = vec.add(origin, { 0, 400, 0 })
q.ship.vel = { 0, 0, 0 }
T.assert(ap.wait_until(T, 1, function() return get().site == 0 end, 120), "left the site")
T.assert(ap.wait_until(T, 1, function() return stealth.level(T.state(), site) < lv end, 60 * (S.cool_out + 15)),
  "the alarm eased")
T.assert(ap.wait_until(T, 1, function() return stealth.level(T.state(), site) == 0 end,
  60 * (S.cool_out + 5) * S.alarm_max), "and cooled down to nothing")
print(string.format("strategic: alarm peak %d, tick %d", lv, T.state().tick))
