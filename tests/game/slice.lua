-- SPDX-License-Identifier: MIT
-- Vertical slice, end to end, through real command frames (concept v0.4):
-- walk across the dome to the helm and take it, fly the whole Villa into the
-- derelict's great halls, tractor the vault's loot, fold down to the Seat for
-- a tight duct, grab what is in there, come back out and unfold the Villa
-- inside the hall, fly out (loot banks), then stand up and walk to the kitchen.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local ruinm = require("sim.ruin")
local tractor = require("sim.tractor")
local configs = require("sim.config")
local avatar = require("sim.avatar")
local L = avatar.layout()
local get = function() return T.state().players[1] end

local st = T.state()
T.assert(get().ship.size == 1, "starts as the Villa")
T.assert(get().mode == "wake", "wakes up in the bedroom")
T.assert(ap.wake(T, 1, get), "got up")
T.assert(get().ship.charge == 100, "starts with full Charge")
local site = st.sector.sites[1]
local origin = site.pos
local ruin = game.ruin(1)
local kit = ruinm.kit_of(ruin.kit)

-- 1. walk across the dome deck to the helm and take it
T.assert(ap.walk_to(T, 1, get, "helm"), "walked upstairs to the helm")
T.press(1, "use")
T.wait(1)
T.assert(get().mode == "helm", "took the helm")
print("tick", T.state().tick, "at the helm")

-- the vault is a great hall at the end of the chain; pick a duct room with loot
local vault, duct
for _, r in ipairs(ruin.rooms) do
  if r.kind == "vault" then vault = r end
  if r.kind == "side" and r.class == 1 and not duct then duct = r end
end
T.assert(vault ~= nil and vault.class == 4, "the vault is a great hall")
T.assert(duct ~= nil, "derelict has a tight duct with loot")
local host = ruin.rooms[duct.parent]
while host.class < 4 do host = ruin.rooms[host.parent] end
local vchain = ap.chain(ruin, vault.id)
local hi
for i, id in ipairs(vchain) do if id == host.id then hi = i end end
T.assert(hi ~= nil, "the duct branches off a hall on the way to the vault")

-- beam up every item of this player in room `room` (add-tractor-beam): hover
-- over each, the Villa from its Tractor Room console, the Seat from the seat
local function grab_room(room)
  local door = ap.door_center(ap.door_of(ruin, room.id), ruin.rooms, kit, origin)
  local n = 0
  for _, c in ipairs(tractor.candidates(T.state(), get(), 1, ruin)) do
    if c.room == room.id and tractor.can_lift(get().ship, c.item) then n = n + 1 end
  end
  local got = ap.grab(T, 1, get, 1, ruin, room.id, door)
  if got < n then for _, m in ipairs(get().msgs) do print("msg", m.tick, m.text) end end
  -- tune-sentry-economy: the tutorial's light Watcher's bolts can shake the beam loose; then the rest stays behind
  local shaken = false
  for _, m in ipairs(get().msgs) do if m.text:find("shook the beam loose", 1, true) then shaken = true end end
  T.assert(got == n or (shaken and got >= 1), "beamed up all " .. n .. " items in room " .. room.id .. " (got " .. got .. ")")
  return got
end

-- 2. fly the whole Villa into the derelict, all the way to the vault
local vroute = ap.route(ruin, origin, vault.id)
for _, wp in ipairs(vroute) do T.assert(wp.size == 1, "every great-hall door takes the Villa") end
local ok, leg = ap.follow(T, 1, get, vroute, 1500)
T.assert(ok, "flew the Villa to the vault (stuck on leg " .. tostring(leg) .. ")")
T.assert(get().site == 1 and get().ship.size == 1, "the Villa is inside the derelict")
print("tick", T.state().tick, "villa in the vault")
local got = grab_room(vault)
T.assert(got >= 1, "the Villa's belly beam picked up loot in the vault")
T.assert(get().mode == "helm" and not get().beam_console, "walked back up to the helm from the Tractor Room")
T.screenshot("slice_vault.png")

-- 3. back to the hall the duct opens from, fold down to the Seat and squeeze in
local back = {}
for i = #vroute, 3 * hi, -1 do back[#back + 1] = { pos = vroute[i].pos, tol = vroute[i].tol } end
ok, leg = ap.follow(T, 1, get, back, 1500)
T.assert(ok, "flew back to the duct's hall (stuck on leg " .. tostring(leg) .. ")")
local droute = ap.route(ruin, origin, duct.id)
local inside = {}
for i = 3 * hi + 1, #droute do inside[#inside + 1] = droute[i] end
T.assert(#inside >= 3 and inside[1].size == 2, "the duct needs the Seat")
print("tick", T.state().tick, "folding")
T.assert(ap.resize(T, 1, get, 2), "folded down to the Seat")
T.assert(get().mode == "helm", "seated in the one-seat car")
ok, leg = ap.follow(T, 1, get, inside, 1500)
T.assert(ok, "squeezed through the duct (stuck on leg " .. tostring(leg) .. ")")
print("tick", T.state().tick, "seat in the duct")
T.assert(grab_room(duct) >= 1, "picked up loot in the duct")
local hot, loot_n = 0, 0
for _, it in ipairs(get().hold) do
  if not it.echo then
    loot_n = loot_n + 1
    if it.hot then hot = hot + 1 end
  end
end
T.assert(hot == loot_n and hot > 0, "fresh loot is hot until we leave the site (Echoes never are)")
T.screenshot("slice_duct.png")

-- 4. back out into the hall and unfold the Villa around the seat
local out = {}
for i = #inside, 1, -1 do out[#out + 1] = { pos = inside[i].pos, tol = inside[i].tol } end
ok, leg = ap.follow(T, 1, get, out, 1500)
T.assert(ok, "came back out of the duct (stuck on leg " .. tostring(leg) .. ")")
local villa_hh = configs.get(1).height / 2
local hall_c = ap.room_center(host, kit, origin, villa_hh + 1.5)
local yaw0 = get().ship.yaw
local spot = ap.spot_for(hall_c, yaw0, 2, 1)
local f = require("lib.vec").fwd(yaw0)
T.assert(ap.fly(T, 1, get, spot, 0.3, 1500, { spot[1] + f[1] * 80, spot[2], spot[3] + f[3] * 80 }),
  "found room for the Villa in the hall")
print("tick", T.state().tick, "unfolding")
local grew = ap.resize(T, 1, get, 1)
if not grew then for _, m in ipairs(get().msgs) do print("msg", m.tick, m.text) end end
T.assert(grew, "unfolded the Villa inside the great hall")
T.assert(get().site == 1, "still inside the derelict")

-- 5. fly out the way we came in; leaving the site banks the loot
local exit = {}
for i = 3 * hi, 1, -1 do exit[#exit + 1] = { pos = vroute[i].pos, tol = vroute[i].tol } end
ok, leg = ap.follow(T, 1, get, exit, 1500)
T.assert(ok, "flew back out (stuck on leg " .. tostring(leg) .. ")")
local o = get().ship.pos
ap.fly(T, 1, get, { o[1], o[2], o[3] - 60 }, 2, 1500)
T.assert(get().site == 0, "left the derelict site")
for _, it in ipairs(get().hold) do T.assert(not it.hot, "loot banked after leaving") end
T.assert(get().banked_value > 0 or T.state().mystery.found > 0, "banked value")

-- 6. leave the helm and walk to the kitchen
T.press(1, "use")
T.wait(1)
T.assert(get().mode == "walk", "stood up")
T.assert(ap.walk_path(T, 1, get, { { 2.0, 0.6, 3.0 }, { 3.0, 0.6, -2.4 } }, 0.3, 900), "walked to the kitchen")
T.assert(avatar.room(L, get().body) == "Kitchen", "in the kitchen")
T.wait(10)
T.screenshot("slice_kitchen.png")
print(string.format("slice: hold %d banked %d echoes %d charge %.1f tick %d", #get().hold, get().banked_value,
  T.state().mystery.found, get().ship.charge, T.state().tick))
