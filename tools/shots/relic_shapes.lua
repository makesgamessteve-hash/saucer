-- SPDX-License-Identifier: MIT
-- relic-room-shapes: inside a shaped relic hall. Seed 42 sector 3's relic, generated as the massing archetype ONLY
-- (the civ is wrapped with that massing), its biggest hall of the archetype's shape shot from inside.
-- One archetype a run (a copy with another ONLY for the others: sed 's/^local ONLY = .*/local
-- ONLY = "lattice"/'):
--   xvfb-run -a -s "-screen 0 1280x720x24" saucer --seed 42 --windowed --width 1280 --height 720 \
--     --script tools/shots/relic_shapes.lua
-- writes shots_relic_shapes/<massing>_<kind>.png.
local ONLY = "ring"
local T = saucer.test
local ap = require("sim.autopilot")
local game = require("sim.game")
local civs = require("sim.civs")
local ruinm = require("sim.ruin")
local R = require("view.render")
local relicv = require("view.relic")
local sm = saucer.math
local get = function() return T.state().players[1] end
local D = "shots_relic_shapes/"
local free
local orig = R.camera
R.camera = function(p, xr) if free then return free end return orig(p, xr) end
local function look_at(from, to, fov)
  local dx, dy, dz = to[1] - from[1], to[2] - from[2], to[3] - from[3]
  free = { pos = from, yaw = sm.atan2(dx, dz), pitch = sm.atan2(dy, sm.sqrt(dx * dx + dz * dz)), fov = fov or 70,
           near = 0.3, far = 9000 }
end
require("view.hud").draw = function() return nil end   -- (clean shots)
local function shot(name) T.wait(3) T.screenshot(D .. name .. ".png") T.wait(1) end
local function park(pos)
  local s = get().ship
  s.pos, s.vel, s.yaw = { pos[1], pos[2], pos[3] }, { 0, 0, 0 }, 0
end

-- (the relic is regenerated under the sentries' feet: they stand still for the shots)
require("sim.sentry").step = function() end
-- the relic's civ, wearing another massing
local MASS
local get0, by0 = civs.get, civs.by_id
civs.get = function(seed, ci)
  local c = get0(seed, ci)
  if MASS and c then return setmetatable({ id = c.id .. "~" .. MASS, massing = MASS }, { __index = c }) end
  return c
end
civs.by_id = function(seed, id)
  local base, m = tostring(id):match("^(.-)~(.+)$")
  if base then
    local c = by0(seed, base)
    return c and setmetatable({ id = id, massing = m }, { __index = c })
  end
  return by0(seed, id)
end

MASS = ONLY
local WANT = { ring = "arc", helix = "arc", shell = "round", lattice = "diamond", hive = "tri", spine = "skew",
               cluster = "cross", organism = "round" }
T.wait(5)
ap.wake(T, 1, get)
ap.take_helm(T, 1, get)
game.enter_sector(T.state(), 3)
T.wait(5)
relicv.BUILDS = 1000
local i
for k, s in ipairs(T.state().sector.sites) do if s.kit == "relic" then i = k end end
local site = T.state().sector.sites[i]
local r = game.ruin(i)
local kit = ruinm.kit_of(r.kit)
-- the biggest hall of the wanted kind (any shaped hall if none)
local best, ba
for _, rm in ipairs(r.rooms) do
  if rm.shape then
    local a = rm.size[1] * rm.size[3] + (rm.shape.kind == WANT[ONLY] and 1e6 or 0)
    if not ba or a > ba then best, ba = rm, a end
  end
end
local mn, mx = ruinm.room_box(best, kit, site.pos)
local c = { (mn[1] + mx[1]) / 2, mn[2] + kit.wall, (mn[3] + mx[3]) / 2 }
-- look at the corner with the most solid in it, from the far side of the centre
local far, fd = nil, -1
for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
  local n = 0
  for _, b in ipairs(r.fill) do
    if b.room == best.id then
      local bx, bz = (b[1][1] + b[2][1]) / 2 - c[1], (b[1][3] + b[2][3]) / 2 - c[3]
      if bx * q[1] > 0 and bz * q[2] > 0 then n = n + (b[2][1] - b[1][1]) * (b[2][3] - b[1][3]) end
    end
  end
  if n > fd then far, fd = q, n end
end
local hx, hz = (mx[1] - mn[1]) / 2, (mx[3] - mn[3]) / 2
-- the eye high on the far side of the centre, looking down across it; the saucer parked behind the eye
local eye = { c[1] - far[1] * hx * 0.55, c[2] + (mx[2] - mn[2]) * 0.62, c[3] - far[2] * hz * 0.55 }
park({ eye[1] - far[1] * 6, eye[2] - 6, eye[3] - far[2] * 6 })
T.wait(20)
look_at(eye, { c[1] + far[1] * hx * 0.7, c[2], c[3] + far[2] * hz * 0.7 }, 80)
T.wait(10)
saucer.log.info(string.format("relic_shapes: %s room %d kind %s", ONLY, best.id, best.shape.kind))
shot(ONLY .. "_" .. best.shape.kind)
