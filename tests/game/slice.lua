-- SPDX-License-Identifier: MIT
-- Vertical slice, end to end, through real command frames:
-- fly to the derelict, shrink to fit each door, reach the vault, tractor the
-- loot, fly back out (loot banks) and grow back to the Villa.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local get = function() return T.state().players[1] end

local st = T.state()
T.assert(get().ship.size == 1, "starts as the Villa")
T.assert(get().ship.charge == 100, "starts with full Charge")
local site = st.sector.sites[1]
local ruin = game.ruin(1)
local vault
for _, r in ipairs(ruin.rooms) do if r.kind == "vault" then vault = r end end
T.assert(vault ~= nil, "derelict has a vault")

-- the Villa cannot fit the hangar door
local route = ap.route(ruin, site.pos, vault.id)
T.assert(route[1].size > 1, "first door needs a smaller configuration")
local ok, leg = ap.follow(T, 1, get, route, 1500)
T.assert(ok, "reached the vault (stuck on leg " .. tostring(leg) .. ")")
T.assert(get().site == 1, "inside site 1")
T.assert(get().ship.size > 1, "shrank to get inside")

-- pick up everything this player can see in the vault
local tractor = require("sim.tractor")
local got = 0
for _ = 1, 6 do
  local cands = tractor.candidates(T.state(), get(), 1, ruin)
  local best
  for _, c in ipairs(cands) do
    local d = ((c.pos[1] - get().ship.pos[1]) ^ 2 + (c.pos[3] - get().ship.pos[3]) ^ 2)
    if c.room == vault.id and require("sim.tractor").can_lift(get().ship, c.item) and (not best or d < best.d) then best = { c = c, d = d } end
  end
  if not best then break end
  -- stand off from it at its height, facing it
  local p = best.c.pos
  -- stand on the side of the item that faces the room centre
  local sp = ap.room_center(vault, require("sim.ruin").kit_of(ruin.kit), site.pos, 0)
  local dx, dz = p[1] - sp[1], p[3] - sp[3]
  local dl = math.sqrt(dx * dx + dz * dz)
  if dl < 0.5 then dx, dz, dl = 0, 1, 1 end
  local r = require("sim.config").get(get().ship.size).diameter / 2
  local stand = r + 1.5
  ap.fly(T, 1, get, { p[1] - dx / dl * stand, p[2], p[3] - dz / dl * stand }, 0.5, 600, p)
  ap.face(T, 1, get, p, 300)
  local before = #get().hold + T.state().mystery.found
  T.press(1, "tractor")
  T.wait(45)
  local after = #get().hold + T.state().mystery.found
  if after <= before then for _, m in ipairs(get().msgs) do print("msg", m.tick, m.text) end print("ship", get().ship.pos[1], get().ship.pos[2], get().ship.pos[3], get().ship.yaw, get().ship.pitch, "item", p[1], p[2], p[3]) end
  T.assert(after > before, "tractored " .. best.c.item.name)
  got = got + 1
end
T.assert(got >= 1, "picked up loot in the vault")
local hot = 0
for _, it in ipairs(get().hold) do if it.hot then hot = hot + 1 end end
T.assert(hot == #get().hold, "fresh loot is hot until we leave the site")
T.screenshot("slice_vault.png")

-- fly back out along the route in reverse and clear the site
local back = {}
for i = #route, 1, -1 do back[#back + 1] = { pos = route[i].pos, tol = route[i].tol } end
ok, leg = ap.follow(T, 1, get, back, 1500)
T.assert(ok, "flew back out (stuck on leg " .. tostring(leg) .. ")")
local out = get().ship.pos
ap.fly(T, 1, get, { out[1], out[2], out[3] - 60 }, 2, 1500)
T.assert(get().site == 0, "left the derelict site")
for _, it in ipairs(get().hold) do T.assert(not it.hot, "loot banked after leaving") end
T.assert(get().banked_value > 0 or T.state().mystery.found > 0, "banked value")

T.assert(ap.resize(T, 1, get, 1), "grew back to the Villa in open space")
T.wait(10)
T.screenshot("slice_outside.png")
print(string.format("slice: hold %d banked %d echoes %d charge %.1f tick %d", #get().hold, get().banked_value,
  T.state().mystery.found, get().ship.charge, T.state().tick))
