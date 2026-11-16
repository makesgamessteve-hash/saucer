-- SPDX-License-Identifier: MIT
-- The belly tractor beam end to end (OpenSpec add-tractor-beam): fly the Villa
-- over long scrap with the keel across it, get told off from the helm, walk
-- down to the Tractor Room, see the beam refuse, trim the hull round from the
-- console, pull (the item rises and shrinks, the hatch opens), get up mid-pull
-- (the beam lets go), pull again for real, refuse an off-axis target, walk
-- back up, then fold to the Seat and use its mini beam.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local tractor = require("sim.tractor")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local function said(s)
  for _, m in ipairs(get().msgs) do if m.text:find(s, 1, true) then return true end end
  return false
end
local function cand_by(key)
  return tractor.by_key(T.state(), get(), 1, game.ruin(1), key)
end

local st = T.state()
local ruin = game.ruin(1)
local origin = st.sector.sites[1].pos
T.assert(ap.wake(T, 1, get), "got up")
T.assert(ap.take_helm(T, 1, get), "took the helm")

-- the first great hall holds long scrap; the vault behind it more loot
local long, vault
for _, c in ipairs(tractor.candidates(st, get(), 1, ruin)) do
  local r = ruin.rooms[c.room]
  if c.axis and r.class >= 4 and tractor.can_lift(get().ship, c.item) and not long then long = c end
end
for _, r in ipairs(ruin.rooms) do if r.kind == "vault" then vault = r end end
T.assert(long ~= nil, "a great hall holds long scrap")
local vroute = ap.route(ruin, origin, vault.id)
local hi
for i, id in ipairs(ap.chain(ruin, vault.id)) do if id == long.room then hi = i end end
T.assert(hi ~= nil, "the long scrap lies on the way to the vault")
local to_hall = {}
for i = 1, 3 * hi do to_hall[#to_hall + 1] = vroute[i] end
T.assert(ap.follow(T, 1, get, to_hall, 1500), "flew the Villa into the hall")

-- 1. hover over it with the keel 60 degrees off its axis
local spot = ap.beam_spot(long.pos, 1)
local wrong = long.axis + 1.05
T.assert(ap.fly(T, 1, get, spot, 0.3, 1500, { spot[1] + saucer.math.sin(wrong) * 80, spot[2],
  spot[3] + saucer.math.cos(wrong) * 80 }), "hovering over the long scrap")
T.assert(ap.wait_until(T, 1, function() return vec.len(get().ship.vel) < 0.2 and math.abs(get().ship.bank or 0) < 0.02 end,
  600), "settled")
local _, yaw = game.viewpoint(get())
local sc = tractor.scan(st, get(), 1, ruin, yaw)
T.assert(sc and sc.cand.key == long.key and sc.status == "yaw", "the indicator says: turn the keel (" ..
  tostring(sc and sc.status) .. ")")
T.assert(sc.info.hint:find("LONG SCRAP - TURN", 1, true), "with a turn hint")
T.press(1, "tractor")
T.wait(1)
T.assert(said("The beam runs from the Tractor Room"), "the helm sends you down to the Tractor Room")
T.screenshot("tractor_helm.png")

-- 2. down the belly stair to the console; the beam refuses until the keel lines up
T.assert(ap.to_console(T, 1, get), "walked down to the Tractor Room and sat at the console")
T.assert(require("sim.avatar").room(require("sim.avatar").layout(), get().body) == "Tractor room", "in the Tractor Room")
T.assert(vec.dist(get().ship.pos, spot) < 1.0, "hover-hold kept the saucer in place while we walked")
T.press(1, "tractor")
T.wait(1)
T.assert(said("Beam: long scrap - turn"), "the console refuses: turn the keel")
T.assert(not get().tractor, "no lock")
T.assert(ap.trim_to(T, 1, get, spot, ap.beam_yaw(long, get().ship.yaw)), "trimmed the hull round from the console")

-- 3. pull, then get up halfway: the beam lets go and the scrap drops
T.press(1, "tractor")
T.wait(1)
local tr = get().tractor
T.assert(tr and tr.key == long.key and tr.console, "beam lock on the long scrap")
T.wait(math.floor(tr.total * 30))
local pos, scale = tractor.pull_pose(get().ship, get().tractor)
T.assert(pos[2] > long.pos[2] + 1 and scale < 0.8, "it rises up the beam and shrinks")
T.assert(get().hatch > 0.5, "the hatch iris opens")
T.press(1, "use")
T.wait(1)
T.assert(not get().tractor and said("You left the console: the beam let go"), "getting up drops it")
T.assert(cand_by(long.key) ~= nil, "the scrap is still down there")

-- 4. sit down again and pull it all the way in
local before = #get().hold
T.assert(ap.to_console(T, 1, get), "back at the console")
T.assert(ap.beam_up(T, 1, get, long), "beamed up the long scrap")
T.assert(#get().hold == before + 1 and cand_by(long.key) == nil, "it is in the hold")
T.assert(ap.wait_until(T, 1, function() return get().hatch < 0.05 end, 240), "the hatch closes again")

-- 5. on to the vault; an off-axis target is refused, then lined up and taken
T.assert(ap.back_to_helm(T, 1, get), "walked back up to the helm")
local rest = {}
for i = 3 * hi + 1, #vroute do rest[#rest + 1] = vroute[i] end
T.assert(ap.follow(T, 1, get, rest, 1500), "flew on into the vault")
local villa_t, seat_t
for _, c in ipairs(tractor.candidates(st, get(), 1, ruin)) do
  if c.room == vault.id and c.kind == "slot" then
    if c.item.size <= 1 and not seat_t then seat_t = c elseif not villa_t then villa_t = c end
  end
end
T.assert(villa_t and seat_t, "the vault holds loot for both beams")
local vspot = ap.beam_spot(villa_t.pos, 1)
local off = vec.add(vspot, vec.scale(vec.right(get().ship.yaw), 5))
T.assert(ap.hover_over(T, 1, get, { pos = vec.sub(off, { 0, vspot[2] - villa_t.pos[2], 0 }), item = villa_t.item }),
  "hovering 5 m off to the side")
T.assert(tractor.check(get().ship, villa_t) == "axis", "off axis")
T.assert(ap.to_console(T, 1, get), "at the console")
T.press(1, "tractor")
T.wait(1)
T.assert(not get().tractor and said("Beam: "), "nothing taken: the target is off axis")
T.assert(ap.beam_up(T, 1, get, villa_t), "trimmed over it and beamed it up")
T.assert(ap.back_to_helm(T, 1, get), "back at the helm")

-- 6. the one-seat car fires a mini beam straight from the seat
T.assert(ap.resize(T, 1, get, 2), "folded down to the Seat")
T.assert(ap.beam_up(T, 1, get, seat_t), "the Seat's mini beam took the small loot")
T.assert(cand_by(seat_t.key) == nil, "in the hold")
print(string.format("tractor: hold %d tick %d", #get().hold, T.state().tick))
