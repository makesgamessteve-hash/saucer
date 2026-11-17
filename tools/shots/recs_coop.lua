-- SPDX-License-Identifier: MIT
-- Co-op screenshot tour for OpenSpec add-playtest-recs. Run from the folder
-- that should receive shots_recs/:
--   saucer --root REPO --seed 42 --windowed --width 1280 --height 720 --local-players 2 --viewports 2
--          --script REPO/tools/shots/recs_coop.lua
-- P2 says "I'm ready to fold" from the party panel (P1's view shows it), then
-- holds a twin vault's shutter anchor while P1 beams the vault up.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local twin = require("sim.twin")
local tractor = require("sim.tractor")
local P = function(i) return function() return T.state().players[i] end end
local p1, p2 = P(1), P(2)
local D = "shots_recs/"
local function shot(name) T.wait(2) T.screenshot(D .. name .. ".png") T.wait(1) end

T.wait(10)
if #T.state().players < 2 then T.press(2, "use") end
T.wait(10)
ap.wake(T, 1, p1)
ap.wake(T, 2, p2)
ap.take_helm(T, 1, p1)
ap.take_helm(T, 2, p2)

-- 1. ready to fold
T.press(2, "map")
T.wait(2)
T.assert(ap.pick(T, 2, p2, "Party"), "party row")
T.wait(2)
T.assert(ap.pick(T, 2, p2, "I'm ready to fold"), "ready row")
T.wait(2)
ap.pick(T, 2, p2, "Close")
T.wait(30)
shot("05a_coop_ready")

-- 2. a twin vault: P2 holds the anchor, P1 beams the vault
local site, L
for i = 1, #T.state().sector.sites do
  if not site and twin.layout(game.ruin(i)) then site, L = i, twin.layout(game.ruin(i)) end
end
T.assert(site, "a site with a twin vault")
local ruin, origin = game.ruin(site), T.state().sector.sites[site].pos
local function cand(get, kind)
  for _, c in ipairs(tractor.candidates(T.state(), get(), site, ruin)) do if c.kind == kind then return c end end
end
print(string.format("twin site %d anchor room %s vault room %s", site, tostring(L.anchor.room), tostring(L.vault.room)))
-- the Seat where the way in is too small for the Villa
local function size_for(room)
  for _, w in ipairs(ap.route(ruin, origin, room)) do if w.size ~= 1 then return 2 end end
  return nil
end
local function go(pl, get, room)
  local sz = size_for(room)
  ap.travel(T, pl, get, ap.route(ruin, origin, room, sz)[1].pos, 4, 6000)
  if sz then ap.resize(T, pl, get, 2) end
  ap.enter(T, pl, get, ruin, origin, room, sz)
end
go(2, p2, L.anchor.room)
-- (the anchor sits on a loot slot: beam the find under it up first)
ap.grab(T, 2, p2, site, ruin, L.anchor.room, nil, function(c) return c.kind ~= "anchor" and c.kind ~= "twin" end)
ap.grab(T, 2, p2, site, ruin, L.anchor.room, nil, function(c) return c.kind == "anchor" end)
local ok = twin.holder(T.state(), site) == p2()
print("anchor held " .. tostring(twin.holder(T.state(), site) == p2()) .. " beam " .. tostring(ok))
go(1, p1, L.vault.room)
T.wait(20)
shot("05b_twin_vault_held")
local c = cand(p1, "twin")
print("twin sealed " .. tostring(c and c.sealed))
-- (the vault sits on a loot slot too: whatever lies on top comes up first)
ap.grab(T, 1, p1, site, ruin, L.vault.room, nil, function(x) return x.kind ~= "anchor" and x.kind ~= "twin" end)
ok = c and ap.grab(T, 1, p1, site, ruin, L.vault.room, nil, function(x) return x.kind == "twin" end) > 0
T.wait(30)
print("twin taken " .. tostring(ok) .. " twins " .. tostring(p1().twins) .. "/" .. tostring(p2().twins))
shot("05c_twin_vault_taken")
print("recs coop tour done")
