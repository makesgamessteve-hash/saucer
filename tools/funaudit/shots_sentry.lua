-- SPDX-License-Identifier: MIT
-- add-strategic-sentries: the "after" frames at derelict 2: the suspicion arc, the scan's cones and
-- guarded marks, the floor light pool and pillar cover, power-cell sabotage, the Spotter and its tag,
-- and the site alarm escalating.
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --script REPO/tools/funaudit/shots_sentry.lua
-- (SHOTS env-free: frames go to SENTRY_SHOTS or /workspace/saucer/shots_sentry/)
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local sentry = require("sim.sentry")
local stealth = require("sim.stealth")
local vec = require("lib.vec")
local sm = saucer.math
local get = function() return T.state().players[1] end
local D = SENTRY_SHOTS or "/workspace/saucer/shots_sentry/"
local function snap(name) T.screenshot(D .. name .. ".png") print("SENTRYSHOT " .. T.state().tick .. " " .. name) end
local function look_at(q)
  local e = game.viewpoint(get())
  ap.look(T, 1, get, sm.atan2(q[1] - e[1], q[3] - e[3]), ap.pitch_to(e, q), 160)
end
local function put(pos)
  local p = get()
  p.ship.pos, p.ship.vel = vec.copy(pos), { 0, 0, 0 }
end

T.wait(30) ap.wake(T, 1, get) T.wait(20) ap.take_helm(T, 1, get)
local site = 2
local defs = game.sentries(site)
local ruin, origin = game.ruin(site), T.state().sector.sites[site].pos
local function dyn(i) return T.state().sentries[site][i] end
local hw, hi, sp, si
for i, d in ipairs(defs) do
  if d.kind == "watcher" and d.cell and not hw then hw, hi = d, i end
  if d.kind == "spotter" and not sp then sp, si = d, i end
end
local g
for _, s in ipairs(ruin.slots) do if s.guarded == hw.id then g = s end end
ap.travel(T, 1, get, ap.route(ruin, origin, hw.room)[1].pos, 4, 6000)
ap.resize(T, 1, get, 2)

-- the hall from behind the guarded find, looking up at the turret: floor pool, pillars, scan marks
local back = vec.sub(g.pos, hw.pos)
back[2] = 0
back = vec.scale(vec.norm(back), 12)
-- keep it out of the cone while framing (hold the meter down)
local function calm() for i, d in ipairs(defs) do if d.kind == "watcher" then dyn(i).meter = 0 end end end
put(vec.add(vec.add(g.pos, back), { 0, 6, 0 }))
calm()
look_at(g.pos)
T.wait(2) calm()
snap("04_floor_light_cone_and_cover")
T.press(1, "scan")
T.wait(20) calm()
look_at(hw.pos) calm()
T.wait(2)
snap("03_scan_cones_cells_guarded")
look_at(g.pos) T.wait(2)
snap("03b_scan_guarded_find_mark")

-- the meter: the Seat in the sweep (the Spotter held off); frame the arc while it climbs
dyn(si).st, dyn(si).t = "disabled", 600
put(vec.add(hw.pos, vec.scale(sentry.dir_of(hw.yaw, hw.pitch), 18)))
look_at(hw.pos)
ap.wait_until(T, 1, function() return (dyn(hi).meter or 0) >= 0.55 end, 900)
snap("01_suspicion_meter_arc")
print("SENTRYSHOT meter " .. tostring(dyn(hi).meter) .. " " .. dyn(hi).st)

-- sabotage: out of sight, then the cell from behind the turret
put(vec.add(origin, { 0, 400, 0 }))
ap.wait_until(T, 1, function() return dyn(hi).st == "dormant" and (dyn(hi).meter or 0) < 0.05 end, 1200)
local behind = vec.add(hw.pos, vec.scale(sentry.dir_of(hw.yaw + math.pi, 0), 2))
behind[2] = hw.pos[2] + 1
put(behind)
local n = ap.grab(T, 1, get, site, ruin, hw.room, nil, function(c) return c.kind == "cell" and c.def == hw end)
look_at(hw.cell)
T.wait(2)
snap("05_sabotage_cell_out_watcher_dark")
print("SENTRYSHOT cells " .. n .. " st " .. dyn(hi).st)
dyn(si).st, dyn(si).t = "dormant", 0

-- the Spotter: the Villa in front of it
put(vec.add(origin, { 0, 400, 0 }))
T.wait(2)
ap.resize(T, 1, get, 1)
local shot_alert = false
ap.wait_until(T, 1, function()
  local d = dyn(si)
  if d.st ~= "tagged" then put(vec.add(d.pos, vec.scale(sentry.dir_of(d.yaw, -0.35), 26))) end
  if d.st == "alert" and not shot_alert and (d.meter or 0) > 0.5 then
    look_at(d.pos) snap("06_spotter_eye_on_you") shot_alert = true
  end
  return d.st == "tagged"
end, 60 * 20)
look_at(dyn(si).pos)
T.wait(2)
snap("06b_spotter_tagged")

-- escalation: more Watcher locks until the alarm wakes the Snatchers
ap.wait_until(T, 1, function()
  if stealth.level(T.state(), site) >= 2 then return true end
  for i, d in ipairs(defs) do
    if d.kind == "watcher" and dyn(i).st ~= "off" and dyn(i).st ~= "locked" then
      put(vec.add(d.pos, vec.scale(sentry.dir_of(d.yaw, d.pitch), 22)))
      break
    end
  end
  return false
end, 60 * 30)
T.wait(10)
snap("02_site_alarm_escalation")
print("SENTRYSHOT done alarm " .. stealth.level(T.state(), site) .. " hull " .. get().ship.hull)
