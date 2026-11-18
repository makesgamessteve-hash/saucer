-- SPDX-License-Identifier: MIT
-- Co-op screenshots of the twin spots (OpenSpec add-playtest-recs 5.4, gameplay gaps). Run from the
-- folder that should receive shots_gameplay/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --local-players 2 --viewports 2
--          --script REPO/tools/shots/gameplay_twin.lua
-- P2 beams the twin vault's shutter anchor straight up (no loot slot under it to clear first) while P1
-- beams the vault in its room, where the twin vault sits on its own spot beside the room's loot.
-- Staged: both Seats are placed over their targets (the flights there are tests/game/tractor.lua's).
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local twin = require("sim.twin")
local tractor = require("sim.tractor")
local vec = require("lib.vec")
local P = function(i) return function() return T.state().players[i] end end
local p1, p2 = P(1), P(2)
local D = "shots_gameplay/"
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end

T.wait(10)
if #T.state().players < 2 then T.press(2, "use") end
T.wait(10)
ap.wake(T, 1, p1)
ap.wake(T, 2, p2)
ap.take_helm(T, 1, p1)
ap.take_helm(T, 2, p2)

-- 2. a twin vault: P2 holds the anchor, P1 beams the vault
local site, L
for i = 1, #T.state().sector.sites do
  if not site and twin.layout(game.ruin(i)) then site, L = i, twin.layout(game.ruin(i)) end
end
T.assert(site, "a site with a twin vault")
local ruin = game.ruin(site)
local function cand(get, kind)
  for _, c in ipairs(tractor.candidates(T.state(), get(), site, ruin)) do if c.kind == kind then return c end end
end
print(string.format("twin site %d anchor room %s vault room %s", site, tostring(L.anchor.room), tostring(L.vault.room)))
for _, sp in ipairs({ L.anchor, L.vault }) do
  local near = math.huge
  for _, sl in ipairs(ruin.slots) do
    if sl.room == sp.room then near = math.min(near, math.sqrt((sl.pos[1] - sp.pos[1]) ^ 2 + (sl.pos[3] - sp.pos[3]) ^ 2)) end
  end
  print(string.format("twin spot in room %s is %.1f m from the nearest loot slot", tostring(sp.room), near))
end
-- the Seat hovers over its target, keel lined up, the way the autopilot's hover_over leaves it
local function over(pl, get, c)
  local p = get()
  p.ship.size, p.ship.morph, p.site, p.mode = 2, false, site, "helm"
  p.ship.pos = ap.beam_spot(c.pos, 2)
  p.ship.yaw = ap.beam_yaw(c, 0)
  p.ship.bank, p.ship.pitch, p.ship.vel = 0, 0, { 0, 0, 0 }
  T.wait(30)
end
local ac = cand(p2, "anchor")
over(2, p2, ac)
T.press(2, "tractor")
ap.wait_until(T, 2, function() return not p2().tractor end, 1500)
T.wait(5)
T.assert(twin.holder(T.state(), site) == p2(), "P2 holds the anchor")
local vc = cand(p1, "twin")
over(1, p1, vc)
T.wait(20)
shot("10_twin_vault_room_anchor_held")
local c = cand(p1, "twin")
print("twin sealed " .. tostring(c and c.sealed))
T.press(1, "tractor")
T.wait(5)
ap.wait_until(T, 1, function() return not p1().tractor end, 1500)
T.wait(30)
print("twin taken: twins " .. tostring(p1().twins) .. "/" .. tostring(p2().twins))
T.assert((p1().twins or 0) == 1 and (p2().twins or 0) == 1, "both got a prize")
shot("11_twin_vault_taken_first")
print("gameplay twin tour done")
