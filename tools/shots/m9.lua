-- SPDX-License-Identifier: MIT
-- Screenshot tour for milestone 9 (OpenSpec add-home-among-stars). Run from
-- the folder that should receive shots_m9/:
--   saucer --root REPO --seed 42 --mods-dir REPO/tests/fixtures/mods --windowed
--          --width 1600 --height 900 --script REPO/tools/shots/m9.lua
-- The title card (Hardcore, the mod browser) is played on command frames.
-- The dome is decorated through the sim API (sim.decor: place, show, plant)
-- from spots the player stands on, to keep the tour short; the garden's beds
-- are grown on. The Warden is met by jumping straight to the first danger-3
-- sector of the spine (game.enter_sector) and flying into its great hall.
-- The two-machine shot is tools/shots/m9_net.sh.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local decor = require("sim.decor")
local items = require("sim.items")
local galaxy = require("sim.galaxy")
local ruinm = require("sim.ruin")
local configs = require("sim.config")
local vec = require("lib.vec")
local D = "shots_m9/"
local function P() return T.state().players[1] end
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end
local ctx = { msg = function() end, fx = function() end }

-- 1. the title card: choose Hardcore, then open the mod browser
T.wait(10)
T.assert(P().panel and P().panel.kind == "title", "the title card")
T.assert(ap.pick(T, 1, P, "Hardcore"), "Hardcore row")
T.wait(20)
shot("06_hardcore")
T.assert(ap.pick(T, 1, P, "Mod browser"), "mod browser row")
T.wait(5)
-- move the cursor onto a mod so its description shows
T.axis(1, "move_z", -1, 1) T.wait(1) T.axis(1, "move_z", 0, 1) T.wait(4)
T.axis(1, "move_z", -1, 1) T.wait(1) T.axis(1, "move_z", 0, 1) T.wait(4)
shot("05_mod_browser")
T.assert(ap.pick(T, 1, P, "Close"), "closed the browser")
T.wait(5)
ap.wake(T, 1, P)
T.assert(ap.walk_to(T, 1, P, "dome", 0.4, 3600), "up in the dome")

-- 2. furnish the dome: buy pieces and place them from where you stand
local p = P()
for _, k in ipairs({ "aquarium", "armchair", "rug", "telescope", "crystal", "bookcase", "beanbag", "hammock" }) do
  decor.buy_furniture(p, k)
end
local spots = {
  { "rug", -3.4, 1.6, 1.5708 }, { "armchair", -4.6, 1.0, 1.5708 }, { "aquarium", -2.0, 2.4, -1.5708 },
  { "telescope", 1.8, 4.0, 0.0 }, { "crystal", -1.4, 4.2, 0.0 }, { "beanbag", 2.6, 1.6, 1.5708 },
  { "bookcase", -5.6, 2.2, -1.5708 }, { "hammock", 3.0, 0.4, 0.0 },
}
local placed = 0
-- the nearest free spot to each wish (searching outwards in grid steps)
local function try(kind, x, z, yaw)
  local def = decor.furniture(kind)
  local reach = decor.REACH + math.max(0, def.size[2] / 2 - 0.5)
  local b = p.body
  b.yaw = yaw
  b.pos = { x - saucer.math.sin(yaw) * reach, b.pos[2], z - saucer.math.cos(yaw) * reach }
  return decor.place(T.state(), p, kind, ctx)
end
for _, s in ipairs(spots) do
  local done = false
  for r = 0, 8 do
    for dx = -r, r do
      for dz = -r, r do
        if not done and math.max(math.abs(dx), math.abs(dz)) == r then
          done = try(s[1], s[2] + dx * 0.25, s[3] + dz * 0.25, s[4])
        end
      end
    end
  end
  if done then placed = placed + 1 else print("no room for " .. s[1]) end
end
print("placed " .. placed)

-- 3. finds on the display slots
local finds = {
  { name = "Lucid Lens of Stillness", type = "lens", value = 40, size = 1, category = "curio" },
  { name = "Singing Coil of the Deep", type = "coil", value = 55, size = 1, category = "curio" },
  { name = "Velari Star Chart", type = "chart", value = 30, size = 1, category = "relic" },
  { name = "Oquun Prayer Bowl", type = "bowl", value = 35, size = 1, category = "curio" },
  { name = "Hive Resonator", type = "resonator", value = 60, size = 1, category = "tech" },
  { name = "Brass Orrery", type = "orrery", value = 45, size = 1, category = "curio" },
}
for slot, f in ipairs(finds) do
  local it = items.stamp(p, f, 2, nil)
  it.ident, it.category = true, f.category
  p.hold[#p.hold + 1] = it
  decor.show(T.state(), p, slot, it.uid, ctx)
end

-- 4. the garden: four beds at different stages
decor.buy_seeds(p, "sunvine", 2)
decor.buy_seeds(p, "emberleaf", 2)
for bi, sd in ipairs({ "glowmoss", "sunvine", "emberleaf", "glowmoss" }) do
  decor.plant(T.state(), p, bi, sd, ctx)
  local bed = p.decor.garden[bi]
  if bed then bed.growth = ({ 0.95, 0.7, 0.4, 0.15 })[bi] * decor.seed(sd).minutes end
end
T.wait(10)
print(string.format("comfort %d (%s)", decor.comfort(T.state(), p), decor.level(T.state(), p)))

local function stand(x, z, yaw, pitch)
  p.body.pos = { x, p.body.pos[2], z }
  p.body.yaw = yaw
  if p.body.pitch then p.body.pitch = pitch or 0 end
  T.wait(20)
end
stand(3.0, 0.2, -1.3, -0.2)
shot("02_decorated_dome")
stand(0.6, 4.4, -1.1, -0.35)
shot("04_display_slots")
stand(-4.4, -6.0, 1.84, -0.45)
shot("03_garden")

-- 5. the Warden: the first danger-3 sector of the spine, its great hall
local g = galaxy.generate(T.state().seed)
local deep
for _, id in ipairs(g.spine) do if not deep and g.sectors[id].danger >= 3 then deep = id end end
game.enter_sector(T.state(), deep)
T.wait(30)
local si, wdef, wk
for s = 1, #T.state().sector.sites do
  for k, d in ipairs(game.sentries(s)) do
    if d.kind == "warden" and not wdef then si, wdef, wk = s, d, k end
  end
end
T.assert(wdef, "a Warden in " .. g.sectors[deep].name)
local ruin, origin = game.ruin(si), T.state().sector.sites[si].pos
ap.take_helm(T, 1, P)
P().ship.charge = configs.all().max_charge
ap.resize(T, 1, P, 2)
-- (staged) the Villa is already inside the hall, across it from the Warden
local dyn0 = T.state().sentries[si][wk]
local room
for _, r in ipairs(ruin.rooms) do if r.id == wdef.room then room = r end end
local mn, mx = ruinm.room_box(room, ruinm.kit_of(ruin.kit), origin)
local c = { (mn[1] + mx[1]) / 2, dyn0.pos[2] + 1.5, (mn[3] + mx[3]) / 2 }
local away = vec.sub(c, dyn0.pos)
away[2] = 0
if vec.len(away) < 1 then away = { 0, 0, 1 } end
away = vec.norm(away)
local half = math.min(mx[1] - mn[1], mx[3] - mn[3]) / 2 - 4
P().ship.pos = vec.add(c, vec.scale(away, math.max(2, half)))
P().ship.vel = { 0, 0, 0 }
P().site = si
T.wait(5)
local dyn = T.state().sentries[si][wk]
-- (staged) it is back at the middle of its first hall; the Villa hovers at
-- the hall's far end, level with it, looking at it
dyn.pos, dyn.wp, dyn.st = vec.copy(wdef.route[1]), 2, "patrol"
local long = (mx[1] - mn[1]) > (mx[3] - mn[3]) and { 1, 0, 0 } or { 0, 0, 1 }
local reach2 = math.min(18, math.max(mx[1] - mn[1], mx[3] - mn[3]) / 2 - 4)
local a = P().ship
a.pos, a.vel = vec.add(dyn.pos, vec.scale(long, reach2)), { 0, 0, 0 }
a.yaw = saucer.math.atan2(dyn.pos[1] - a.pos[1], dyn.pos[3] - a.pos[3])
T.wait(40)
a.yaw = saucer.math.atan2(dyn.pos[1] - a.pos[1], dyn.pos[3] - a.pos[3])
local flat = math.sqrt((dyn.pos[1] - a.pos[1]) ^ 2 + (dyn.pos[3] - a.pos[3]) ^ 2)
a.pitch = saucer.math.atan2(dyn.pos[2] + 1.0 - a.pos[2], flat)
T.wait(2)
print(string.format("warden %s at %.0f m", dyn.st, vec.dist(dyn.pos, P().ship.pos)))
shot("07_warden")
print("m9 tour done")
