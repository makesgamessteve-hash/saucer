-- SPDX-License-Identifier: MIT
-- Autopilot: turns a route through a derelict into stick inputs. Used by the
-- automated game tests (inputs still go through command frames) and usable
-- by mods for attract/demo modes. Pure functions; no state of its own.
local vec = require("lib.vec")
local ruinm = require("sim.ruin")
local configs = require("sim.config")
local M = {}

-- config index able to pass a door of size class c (largest that fits)
function M.config_for_class(c)
  local best
  for i, cfg in ipairs(configs.all()) do
    if cfg.class <= c and not cfg.pocket and not best then best = i end
  end
  if best then return best end
  for i = configs.count(), 1, -1 do
    if not configs.get(i).pocket then return i end
  end
end

-- centre of a door hole (world). Side doors sit on the higher of the two
-- floors; floor/ceiling hatches are centred in the overlap of the two rooms.
local function door_center(d, rooms, kit, origin)
  local child = rooms[d.b]
  local mn, mx = ruinm.room_box(child, kit, origin)
  local p = { 0, 0, 0 }
  if d.axis == 2 then
    p[1] = origin[1] + (d.lo + d.hi) / 2 * kit.cell
    p[3] = origin[3] + (d.lo3 + d.hi3) / 2 * kit.cell
  else
    local l = d.axis == 1 and 3 or 1
    p[l] = origin[l] + (d.lo + d.hi) / 2 * kit.cell
    local floor = d.vlo and origin[2] + d.vlo * kit.cell or mn[2]
    p[2] = floor + kit.wall + kit.doors[d.class][2] / 2
  end
  p[d.axis] = d.sign > 0 and mn[d.axis] or mx[d.axis]
  return p
end
M.door_center = door_center

function M.room_center(r, kit, origin, hh)
  local mn, mx = ruinm.room_box(r, kit, origin)
  return { (mn[1] + mx[1]) / 2, mn[2] + kit.wall + math.max(hh + 0.3, 1.2), (mn[3] + mx[3]) / 2 }
end

-- room ids from the entrance to room_id
function M.chain(ruin, room_id)
  local chain, id = {}, room_id
  while id ~= 0 do
    table.insert(chain, 1, id)
    id = ruin.rooms[id].parent
  end
  return chain
end

-- the door you enter room_id through
function M.door_of(ruin, room_id)
  for _, d in ipairs(ruin.doors) do
    if d.b == room_id then return d end
  end
end

-- route(ruin, origin, room_id) -> list of { pos, size } from outside the
-- entrance to the centre of room_id, shrinking before each smaller door.
-- Three waypoints per room: before its door, just through it, its centre.
function M.route(ruin, origin, room_id, min_size)
  local kit = ruinm.kit_of(ruin.kit)
  local chain = M.chain(ruin, room_id)
  local doors = {}
  for _, d in ipairs(ruin.doors) do doors[d.b] = d end
  local wps = {}
  for _, rid in ipairs(chain) do
    local d = doors[rid]
    local size = math.max(M.config_for_class(d.class), min_size or 1)
    local r, hh = configs.get(size).diameter / 2, configs.get(size).height / 2
    local c = door_center(d, ruin.rooms, kit, origin)
    local step = { 0, 0, 0 }
    local hatch = d.axis == 2
    -- through a floor or ceiling hatch the hull clears it by its half height
    step[d.axis] = d.sign * ((hatch and hh or r) + 1.0)
    wps[#wps + 1] = { pos = vec.sub(c, step), size = size, tol = hatch and 0.3 or 0.6 }
    wps[#wps + 1] = { pos = vec.add(c, step), size = size, tol = hatch and 0.5 or 0.8 }
    local rc = M.room_center(ruin.rooms[rid], kit, origin, hh)
    rc[2] = c[2] + step[2]
    wps[#wps + 1] = { pos = rc, size = size, tol = 1.0 }
  end
  -- the first waypoint stands well clear of the hull
  local first = wps[1]
  local d0 = doors[chain[1]]
  first.pos[d0.axis] = first.pos[d0.axis] - d0.sign * 12
  return wps
end

-- steer(ship, target) -> axes table for move_x, move_z, lift, turn and the distance
function M.steer(ship, target, face)
  local cfg = configs.get(ship.size)
  local d = vec.sub(target, ship.pos)
  local dist = vec.len(d)
  local look = face or target
  local ld = vec.sub(look, ship.pos)
  local want_yaw = saucer.math.atan2(ld[1], ld[3])
  local diff = saucer.math.wrap(want_yaw - ship.yaw)
  if not face and math.abs(ld[1]) + math.abs(ld[3]) < 2 then diff = 0 end
  -- wanted velocity (in units of top speed), split over the three thrust axes:
  -- forward thrust follows the pitch, so part of it is vertical (sim/flight.lua)
  local flight = require("sim.flight")
  local f, r = vec.fwd(ship.yaw), vec.right(ship.yaw)
  local gain = 1.2 / cfg.speed
  local damp = 0.9 / cfg.speed
  local want = vec.sub(vec.scale(d, gain), vec.scale(ship.vel, damp))
  local pitch = ship.pitch or 0
  local cp, sp = saucer.math.cos(pitch), saucer.math.sin(pitch)
  local lz = vec.clamp(vec.dot(want, f) / cp, -1, 1)
  local lx = vec.dot(want, r)
  local ly = (want[2] - lz * sp) / flight.LIFT_FACTOR
  return {
    move_x = vec.clamp(lx, -1, 1), move_z = lz, lift = vec.clamp(ly, -1, 1),
    turn = vec.clamp(-diff * 2.5, -1, 1),
  }, dist, diff
end


-- Drivers for scripted runs. `t` is an input API with axis(p, name, v, ticks,
-- nowait), press(p, name, ticks) and wait(n) (saucer.test in game tests);
-- `get` returns the live player table.
M.AXES = { "move_x", "move_z", "lift", "turn", "look" }

function M.hold(t, pl, axes)
  for _, a in ipairs(M.AXES) do t.axis(pl, a, axes[a] or 0, 1, true) end
  t.wait(1)
end

function M.resize(t, pl, get, size)
  local guard = 0
  while get().ship.size ~= size and guard < 8 do
    if not get().ship.morph then
      if get().ship.size < size then t.press(pl, "shrink") else t.press(pl, "grow") end
    end
    M.hold(t, pl, {})
    guard = guard + 1
  end
  while get().ship.morph do M.hold(t, pl, {}) end
  return get().ship.size == size
end

-- where a config-`from` saucer has to be so that reconfiguring to `to`
-- (around its pilot's eyes) puts the new hull's centre at `center`
function M.spot_for(center, yaw, from, to)
  local shipm = require("sim.ship")
  return shipm.center_for_eye(shipm.eye_world(center, yaw, to), yaw, from)
end

-- On-foot driver: walk the body to a hull-local point (x, z). Turns toward it
-- with the look axis, then walks forward. Returns true when within tol.
function M.walk(t, pl, get, target, tol, max_ticks)
  for _ = 1, max_ticks or 900 do
    local b = get().body
    local dx, dz = target[1] - b.pos[1], target[3] - b.pos[3]
    local dist = saucer.math.sqrt(dx * dx + dz * dz)
    if dist < (tol or 0.3) then
      M.hold(t, pl, {})
      return true
    end
    local diff = saucer.math.wrap(saucer.math.atan2(dx, dz) - b.yaw)
    local fwd = math.abs(diff) < 0.6 and vec.clamp(dist * 1.5, 0.15, 1) or 0
    M.hold(t, pl, { turn = vec.clamp(-diff * 3, -1, 1), move_z = fwd })
  end
  return false
end

-- walk a list of hull-local points
function M.walk_path(t, pl, get, pts, tol, max_ticks)
  for i, q in ipairs(pts) do
    if not M.walk(t, pl, get, q, tol, max_ticks) then return false, i end
  end
  return true
end

-- hold the stick (default: forward) until cond() or max_ticks, then let go
function M.push(t, pl, cond, max_ticks, axes)
  for _ = 1, max_ticks or 600 do
    if cond() then
      M.hold(t, pl, {})
      return true
    end
    M.hold(t, pl, axes or { move_z = 1 })
  end
  M.hold(t, pl, {})
  return cond()
end

-- get out of bed: pick "Get up" on the wake-up title panel
function M.wake(t, pl, get)
  if get().mode ~= "wake" then return true end
  t.press(pl, "use")
  t.wait(1)
  return get().mode == "walk"
end

-- walk to a named nav node of the interior layout along the nav graph
function M.walk_to(t, pl, get, node, tol, max_ticks)
  local avatar = require("sim.avatar")
  local L = avatar.layout()
  local from = avatar.nav_nearest(L, get().body)
  local path = avatar.nav_path(L, from, node)
  if not path then return false end
  return M.walk_path(t, pl, get, path, tol or 0.3, max_ticks)
end

-- pick a panel row by its text prefix (moves the selection with the stick)
function M.pick(t, pl, get, prefix)
  local panel = require("sim.panel")
  for _ = 1, 40 do
    local p = get()
    if not p.panel then return false end
    local want = panel.find(t.state(), p, prefix)
    if not want then return false end
    if p.panel.sel == want then
      t.press(pl, "use")
      t.wait(1)
      return true
    end
    t.axis(pl, "move_z", -1, 1, true)
    t.wait(1)
    t.axis(pl, "move_z", 0, 1, true)
    t.wait(1)
  end
  return false
end

-- turn the body (on foot) or the saucer (at the helm) to a heading/pitch
function M.look(t, pl, get, yaw, pitch, max_ticks)
  for _ = 1, max_ticks or 240 do
    local p = get()
    local cur = p.mode == "walk" and p.body or p.ship
    local dy = saucer.math.wrap(yaw - cur.yaw)
    local dp = (pitch or 0) - cur.pitch
    if math.abs(dy) < 0.02 and math.abs(dp) < 0.02 then
      M.hold(t, pl, {})
      return true
    end
    for _, a in ipairs(M.AXES) do t.axis(pl, a, 0, 1, true) end
    t.axis(pl, "turn", vec.clamp(-dy * 2, -1, 1), 1, true)
    t.axis(pl, "look", vec.clamp(dp * 2, -1, 1), 1, true)
    t.wait(1)
  end
  return false
end

-- fly to a point; returns true when within tol before max_ticks
function M.fly(t, pl, get, pos, tol, max_ticks, face)
  for _ = 1, max_ticks or 1200 do
    local axes, dist = M.steer(get().ship, pos, face)
    if dist < (tol or 1) then
      M.hold(t, pl, {})
      return true
    end
    M.hold(t, pl, axes)
  end
  return false
end

-- follow a route, changing size before each leg
function M.follow(t, pl, get, wps, max_ticks)
  for i, wp in ipairs(wps) do
    if wp.size and get().ship.size ~= wp.size and not M.resize(t, pl, get, wp.size) then return false, i end
    if not M.fly(t, pl, get, wp.pos, wp.tol, max_ticks) then return false, i end
  end
  return true
end

-- Where to park so the pilot's eyes are `dist` from item_pos on the line
-- from from_pos (e.g. the door you came in by), hull clear of the floor whose
-- top is floor_y. -> hull centre, yaw, eye
function M.stand_for(item_pos, from_pos, size, floor_y, dist)
  local shipm = require("sim.ship")
  local dx, dz = item_pos[1] - from_pos[1], item_pos[3] - from_pos[3]
  local l = saucer.math.sqrt(dx * dx + dz * dz)
  if l < 1e-6 then dx, dz, l = 0, 1, 1 end
  dx, dz = dx / l, dz / l
  local yaw = saucer.math.atan2(dx, dz)
  local cfg = configs.get(size)
  local eye = { item_pos[1] - dx * dist, item_pos[2] + 0.3, item_pos[3] - dz * dist }
  local lowest = floor_y + cfg.height / 2 + 0.5 + cfg.pilot_eye[2]
  if eye[2] < lowest then eye[2] = lowest end
  return shipm.center_for_eye(eye, yaw, size), yaw, eye
end

-- pitch (radians) to look from eye at pos
function M.pitch_to(eye, pos)
  local dx, dz = pos[1] - eye[1], pos[3] - eye[3]
  return saucer.math.atan2(pos[2] - eye[2], saucer.math.sqrt(dx * dx + dz * dz))
end

-- turn toward a point while holding position
function M.face(t, pl, get, pos, max_ticks)
  local hold = get().ship.pos
  for _ = 1, max_ticks or 240 do
    local axes, _, diff = M.steer(get().ship, { hold[1], hold[2], hold[3] }, pos)
    if math.abs(diff) < 0.03 then return true end
    M.hold(t, pl, axes)
  end
  return false
end

-- milestone 3 drivers ---------------------------------------------------

-- walk to the helm and take it (from anywhere on foot)
function M.take_helm(t, pl, get)
  if get().mode == "helm" then return true end
  if not M.walk_to(t, pl, get, "helm") then return false end
  t.press(pl, "use")
  t.wait(1)
  return get().mode == "helm"
end

-- stand up from the helm and walk to a station node (lab, trade, bed, ...)
function M.walk_to_station(t, pl, get, node)
  if get().mode == "helm" then
    t.press(pl, "use")
    t.wait(1)
    if get().mode ~= "walk" then return false end
  end
  return M.walk_to(t, pl, get, node)
end

-- is the straight flight from a to b clear for a hull of radius r and half
-- height hh? (five rays: the centre line and the four hull edges)
function M.clear_line(a, b, r, hh)
  local d = vec.sub(b, a)
  for _, o in ipairs({ { 0, 0, 0 }, { r, 0, 0 }, { -r, 0, 0 }, { 0, hh, 0 }, { 0, -hh, 0 }, { 0, 0, r }, { 0, 0, -r } }) do
    if saucer.physics.raycast(vec.add(a, o), d, 1.0, 1) then return false end
  end
  return true
end

-- altitude of the sky lane: above every site in the sector
function M.sky_lane(state)
  local game = require("sim.game")
  local top = 0
  for i = 1, #state.sector.sites do
    local b = game.site_bounds(i)
    if b and b[2][2] > top then top = b[2][2] end
  end
  return top + 40
end

-- fly a long way in open space. Sites are huge and 3D, so when something is
-- in the way the saucer climbs to the sky lane, crosses over, and drops onto
-- the target from above (the approach face of every derelict is kept clear).
function M.travel(t, pl, get, pos, tol, max_ticks)
  local ship = get().ship
  local r, hh = configs.get(ship.size).diameter / 2, configs.get(ship.size).height / 2
  if not M.clear_line(ship.pos, pos, r, hh) then
    local h = M.sky_lane(t.state())
    if not M.fly(t, pl, get, { ship.pos[1], h, ship.pos[3] }, 4, max_ticks or 6000) then return false end
    if not M.fly(t, pl, get, { pos[1], h, pos[3] }, 4, max_ticks or 6000) then return false end
  end
  return M.fly(t, pl, get, pos, tol or 4, max_ticks or 6000)
end

-- fly into a derelict to room_id (min_size 2 keeps to the Seat, which
-- Watchers ignore). -> ok, the route used
function M.enter(t, pl, get, ruin, origin, room_id, min_size)
  local route = M.route(ruin, origin, room_id, min_size)
  local first = route[1]
  if get().ship.size ~= first.size then
    -- reconfigure well outside, where there is room
    if not M.resize(t, pl, get, first.size) then return false, route end
  end
  if not M.travel(t, pl, get, first.pos, 3) then return false, route end
  local ok = M.follow(t, pl, get, route, 1500)
  return ok, route
end

-- fly back out along a route (reverse), then clear of the site
function M.leave(t, pl, get, route, away)
  local back = {}
  for i = #route, 1, -1 do back[#back + 1] = { pos = route[i].pos, tol = route[i].tol } end
  if not M.follow(t, pl, get, back, 1500) then return false end
  local o = get().ship.pos
  local a = away or { o[1], o[2], o[3] - 70 }
  return M.fly(t, pl, get, a, 3, 2400)
end

-- add-tractor-beam drivers ------------------------------------------------

-- hull centre that puts the belly beam right over a target, `depth` below the
-- emitter (default: a few meters inside the beam's range)
function M.beam_spot(pos, size, depth)
  local tractor = require("sim.tractor")
  local b = tractor.beam(configs.get(size))
  depth = depth or (b.console and b.min + 4 or b.min + 0.35)
  local e = b.emitter
  return { pos[1] - e[1], pos[2] + depth - e[2], pos[3] - e[3] }
end

-- the heading that lines the keel up with a target: long scrap's axis (the
-- end nearest the current heading), anything else keeps the heading
function M.beam_yaw(cand, yaw)
  if not cand.axis then return yaw end
  local a = cand.axis
  if math.abs(saucer.math.wrap(a - yaw)) > saucer.math.pi / 2 then a = saucer.math.wrap(a + saucer.math.pi) end
  return a
end

local function settled(get, yaw, spot)
  local s = get().ship
  return vec.dist(s.pos, spot) < 0.1 and vec.len(s.vel) < 0.3 and math.abs(s.bank or 0) < 0.02 and math.abs(saucer.math.wrap(yaw - s.yaw)) < 0.05
end

-- fly (from the helm or the Seat) to hover over a target with the keel lined
-- up, and wait for the hull to settle level and still. -> true when settled
function M.hover_over(t, pl, get, cand, depth, max_ticks)
  local ship = get().ship
  local spot = M.beam_spot(cand.pos, ship.size, depth)
  local yaw = M.beam_yaw(cand, ship.yaw)
  local face = { spot[1] + saucer.math.sin(yaw) * 80, spot[2], spot[3] + saucer.math.cos(yaw) * 80 }
  if not M.fly(t, pl, get, spot, 0.3, max_ticks or 1500, face) then return false end
  for _ = 1, 600 do
    if settled(get, yaw, spot) then return true end
    local axes = M.steer(get().ship, spot, face)
    M.hold(t, pl, axes)
  end
  return settled(get, yaw, spot)
end

-- at the beam console: trim the saucer over a new spot (and heading) with the
-- console's slow thrusters, in the operator's frame. -> true when there
function M.trim_to(t, pl, get, spot, yaw, max_ticks)
  local avatar = require("sim.avatar")
  local L = avatar.layout()
  for _ = 1, max_ticks or 1800 do
    local s = get().ship
    local c = configs.get(s.size)
    local tspeed = (c.beam and c.beam.trim_speed) or 3
    local d = vec.sub(spot, s.pos)
    local diff = saucer.math.wrap(yaw - s.yaw)
    if vec.len(d) < 0.25 and vec.len(s.vel) < 0.3 and math.abs(diff) < 0.04 then
      M.hold(t, pl, {})
      return true
    end
    local want = vec.sub(vec.scale(d, 0.9), vec.scale(s.vel, 0.6))
    local h = s.yaw + L.tractor.yaw
    M.hold(t, pl, {
      move_z = vec.clamp(vec.dot(want, vec.fwd(h)) / tspeed, -1, 1),
      move_x = vec.clamp(vec.dot(want, vec.right(h)) / tspeed, -1, 1),
      lift = vec.clamp(want[2] / (tspeed * 0.6), -1, 1),
      turn = vec.clamp(-diff * 3, -1, 1),
    })
  end
  return false
end

-- go down to the Tractor Room and sit at the beam console (from the helm or on foot)
function M.to_console(t, pl, get)
  if get().beam_console then return true end
  if get().mode == "helm" then
    t.press(pl, "use")
    t.wait(1)
  end
  if not M.walk_to(t, pl, get, "tractor") then return false end
  t.press(pl, "use")
  t.wait(1)
  return get().beam_console == true
end

-- get up from the beam console and walk back up to the helm
function M.back_to_helm(t, pl, get)
  if get().beam_console then
    t.press(pl, "use")
    t.wait(1)
  end
  return M.take_helm(t, pl, get)
end

-- pull the target the saucer hovers over (going to the console if the beam
-- needs it) and wait until it is aboard. -> true when it is
function M.pull(t, pl, get, key)
  local tractor = require("sim.tractor")
  -- add-playtest-recs: with the helm beam relay a small find is pulled from the helm
  local p = get()
  local relay = false
  if p.mode == "helm" and key then
    local c = tractor.by_key(t.state(), p, p.site, p.site ~= 0 and require("sim.game").ruin(p.site) or nil, key)
    relay = c ~= nil and require("sim.upgrades").relay(p, c.item)
  end
  if tractor.beam_of(get().ship).console and not relay and not M.to_console(t, pl, get) then return false end
  t.press(pl, "tractor")
  t.wait(1)
  local tr = get().tractor
  if not tr or (key and tr.key ~= key) then return false end
  M.wait_until(t, pl, function() return not get().tractor end, 1200)
  return true
end

-- hover over one target and beam it up (the Villa stays at the console). -> ok
function M.beam_up(t, pl, get, cand, depth)
  if get().beam_console then
    local s = get().ship
    if not M.trim_to(t, pl, get, M.beam_spot(cand.pos, s.size, depth), M.beam_yaw(cand, s.yaw)) then return false end
  elseif not M.hover_over(t, pl, get, cand, depth) then
    return false
  end
  return M.pull(t, pl, get, cand.key)
end

-- beam up every target of this player in a room that the current saucer can
-- lift (filter(c) optional), nearest first; the Villa trims from target to
-- target at the console, then walks back up to the helm. -> number picked up
-- (from and dist are kept for older callers; the beam decides where to hover)
function M.grab(t, pl, get, site_idx, ruin, room_id, from, filter, dist)
  local tractor = require("sim.tractor")
  local got = 0
  for _ = 1, 8 do
    local best
    for _, c in ipairs(tractor.candidates(t.state(), get(), site_idx, ruin)) do
      if (c.room == room_id or (not c.room and filter)) and tractor.can_lift(get().ship, c.item)
          and (not filter or filter(c)) then
        local e = get().ship.pos
        local d = (c.pos[1] - e[1]) ^ 2 + (c.pos[3] - e[3]) ^ 2
        if not best or d < best.d then best = { c = c, d = d } end
      end
    end
    if not best then break end
    local before = #get().hold + t.state().mystery.found
    if not M.beam_up(t, pl, get, best.c) then break end
    if #get().hold + t.state().mystery.found <= before then break end
    got = got + 1
  end
  if get().beam_console then M.back_to_helm(t, pl, get) end
  return got
end

-- wait (holding still) until cond() or max ticks
-- Holodeck drivers (add-holodeck-home-life): walk the holo body to a point of
-- the simulated space, or fly the simulated Seat through every ring in order.
function M.holo_walk(t, pl, get, x, z, tol, max_ticks)
  return M.walk(t, pl, function() return { body = get().holo_run.body } end, { x, 0, z }, tol or 0.4, max_ticks)
end

function M.holo_course(t, pl, get, max_ticks)
  local holo = require("sim.holo")
  local p = get()
  local sc = holo.scene(t.state(), p, p.holo_run)
  local craft = function() return { ship = get().holo_run.craft } end
  for _, g in ipairs(sc.gates) do
    if not M.fly(t, pl, craft, { g[1], g[2], g[3] }, (g.r or 1.5) * 0.5, max_ticks or 900) then return false end
  end
  return get().holo_run.done == true
end

-- On-foot drivers in a trader station (add-pocket-station-visits): walk the
-- body to a station-local point along the station's walk graph (sprinting
-- when run), or run down the fleeing pickpocket.
function M.foot_to(t, pl, get, x, z, tol, max_ticks, run)
  local sg = require("sim.stationgen")
  local visit = require("sim.visit")
  for _ = 1, max_ticks or 2400 do
    local p = get()
    if p.mode ~= "foot" then return false end
    local b = p.station.body
    local L = visit.layout(t.state(), p)
    local here = { b.pos[1], b.pos[3] }
    local dx, dz = x - here[1], z - here[2]
    if dx * dx + dz * dz < (tol or 0.4) ^ 2 then
      M.hold(t, pl, {})
      return true
    end
    local q = sg.route(L, here, { x, z })[1]
    local diff = saucer.math.wrap(saucer.math.atan2(q[1] - here[1], q[2] - here[2]) - b.yaw)
    local fwd = math.abs(diff) < 0.5 and 1 or (math.abs(diff) < 1.0 and 0.3 or 0)
    local left = saucer.math.sqrt(dx * dx + dz * dz)
    if left < 1.2 then fwd = math.min(fwd, math.max(0.2, left)) end
    for _, a in ipairs(M.AXES) do t.axis(pl, a, 0, 1, true) end
    t.axis(pl, "turn", vec.clamp(-diff * 3, -1, 1), 1, true)
    t.axis(pl, "move_z", fwd, 1, true)
    if run then t.press(pl, "boost", 1, true) end
    t.wait(1)
  end
  return false
end

-- walk up to a market stall (by vendor id) or the bar, and press Use
function M.foot_use(t, pl, get, spot)
  if not M.foot_to(t, pl, get, spot[1], spot[2], 0.5) then return false end
  t.press(pl, "use")
  t.wait(1)
  return get().panel ~= false
end

function M.chase(t, pl, get, max_ticks)
  local sg = require("sim.stationgen")
  local visit = require("sim.visit")
  for _ = 1, max_ticks or 3600 do
    local p = get()
    if p.mode ~= "foot" or p.station.thief.mode ~= "flee" then return p.station and p.station.coin ~= "thief" end
    local b = p.station.body
    local L = visit.layout(t.state(), p)
    local here = { b.pos[1], b.pos[3] }
    local th = p.station.thief.pos
    local q = sg.route(L, here, th)[1]
    local diff = saucer.math.wrap(saucer.math.atan2(q[1] - here[1], q[2] - here[2]) - b.yaw)
    for _, a in ipairs(M.AXES) do t.axis(pl, a, 0, 1, true) end
    t.axis(pl, "turn", vec.clamp(-diff * 3, -1, 1), 1, true)
    t.axis(pl, "move_z", math.abs(diff) < 0.7 and 1 or 0.2, 1, true)
    t.press(pl, "boost", 1, true)
    t.wait(1)
  end
  return false
end

function M.wait_until(t, pl, cond, max_ticks)
  for _ = 1, max_ticks or 600 do
    if cond() then return true end
    M.hold(t, pl, {})
  end
  return cond()
end

-- add-on-foot-excursions drivers ----------------------------------------

-- walk (or crawl) the excursion body toward a world point's x, z
function M.ex_to(t, pl, get, pos, tol, max_ticks, run)
  for _ = 1, max_ticks or 2400 do
    local p = get()
    if p.mode ~= "foot" or not p.excursion then return false end
    local b = p.excursion.body
    local dx, dz = pos[1] - b.pos[1], pos[3] - b.pos[3]
    local left = saucer.math.sqrt(dx * dx + dz * dz)
    if left < (tol or 0.4) then
      M.hold(t, pl, {})
      return true
    end
    local diff = saucer.math.wrap(saucer.math.atan2(dx, dz) - b.yaw)
    local fwd = math.abs(diff) < 0.4 and 1 or (math.abs(diff) < 0.9 and 0.3 or 0)
    if left < 1.0 then fwd = math.min(fwd, math.max(0.25, left)) end
    for _, a in ipairs(M.AXES) do t.axis(pl, a, 0, 1, true) end
    t.axis(pl, "turn", vec.clamp(-diff * 3, -1, 1), 1, true)
    t.axis(pl, "move_z", fwd, 1, true)
    if run then t.press(pl, "boost", 1, true) end
    t.wait(1)
  end
  return false
end

function M.ex_path(t, pl, get, pts, tol, max_ticks)
  for _, q in ipairs(pts) do
    if not M.ex_to(t, pl, get, q, tol, max_ticks) then return false end
  end
  return true
end

-- turn the body on foot to a yaw / pitch
function M.ex_look(t, pl, get, yaw, pitch, max_ticks)
  local body = function() return { mode = "walk", body = get().excursion.body } end
  return M.look(t, pl, body, yaw, pitch, max_ticks)
end

-- Use, then wait (standing still) until cond() or max_ticks
function M.ex_work(t, pl, get, cond, max_ticks)
  t.press(pl, "use")
  t.wait(1)
  return M.wait_until(t, pl, cond, max_ticks or 400)
end

-- tune-sentry-economy: game tests about the beam, trade or story (not the sentries) put the tutorial derelict's light
-- Watcher back to its old, gentle bite: no beam shaken loose, no faster fire with the alarm, 4-damage bolts
-- -> a function that puts the tuning back
function M.gentle_tutorial()
  local t = require("sim.sentry").tune()
  local S, L = t.stealth, t.watcher.light
  local was = { S.light_drops, S.light_fire, L.bolt_damage }
  S.light_drops, S.light_fire, L.bolt_damage = false, 0, 4
  return function() S.light_drops, S.light_fire, L.bolt_damage = was[1], was[2], was[3] end
end

return M
