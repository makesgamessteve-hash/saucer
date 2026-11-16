-- SPDX-License-Identifier: MIT
-- Milestone 3: the optional mystery, end to end. Echo I (Who) waits in the
-- tutorial vault; decoding it at the lab bench makes derelict 2 Resonant and
-- unlocks Echo II (Where), which the Seat fetches past the Watchers. Decoding
-- Echo II reveals the Resonant vault in open space and unlocks Echo III (the
-- Key) at derelict 3. Carrying the Key to the vault opens it: a unique Curio
-- and a teaser. Sleep saves, Load restores the solved chain.
local T = saucer.test
local game = require("sim.game")
local ap = require("sim.autopilot")
local items = require("sim.items")
local mystery = require("sim.mystery")
local ruinm = require("sim.ruin")
local vec = require("lib.vec")
local get = function() return T.state().players[1] end
local m = function() return T.state().mystery end
local function said(s)
  for _, x in ipairs(get().msgs or {}) do if x.text:find(s, 1, true) then return true end end
  return false
end

-- fetch the Echo waiting at a site (the Seat for guarded derelicts)
local function fetch(site, size)
  local ruin, origin = game.ruin(site), T.state().sector.sites[site].pos
  local room
  for _, r in ipairs(ruin.rooms) do if r.echo_pos then room = r.id end end
  T.assert(room ~= nil, "site " .. site .. " hosts an Echo")
  T.assert(mystery.echo_at(m(), site) ~= nil, "the Echo at site " .. site .. " is unlocked")
  T.assert(ap.take_helm(T, 1, get), "at the helm")
  -- cross open space in the Villa (fast), reconfigure at the entry
  T.assert(ap.resize(T, 1, get, 1), "the Villa for the trip")
  T.assert(ap.travel(T, 1, get, ap.route(ruin, origin, room, size)[1].pos, 4, 60 * 150), "flew to site " .. site)
  local ok, route = ap.enter(T, 1, get, ruin, origin, room, size)
  T.assert(ok, "flew into site " .. site .. "'s Echo room (at " .. vec.dist(get().ship.pos, route[1].pos) .. " m from the entry, size " .. get().ship.size .. ", room " .. room .. ")")
  local door = ap.door_center(ap.door_of(ruin, room), ruin.rooms, ruinm.kit_of(ruin.kit), origin)
  T.assert(ap.grab(T, 1, get, site, ruin, room, door, function(c) return c.kind == "echo" end) == 1,
    "tractored the Echo at site " .. site)
  T.assert(ap.leave(T, 1, get, route), "back out of site " .. site)
  T.assert(get().site == 0, "in open space")
end

-- decode the newest Echo at the lab bench (in the Villa)
local function decode(idx)
  T.assert(ap.take_helm(T, 1, get), "at the helm")
  T.assert(ap.resize(T, 1, get, 1), "unfolded the Villa")
  T.assert(ap.walk_to_station(T, 1, get, "lab"), "walked to the lab bench")
  T.press(1, "use")
  T.wait(1)
  local name = mystery.item(m(), idx).name
  T.assert(ap.pick(T, 1, get, "Decode " .. name), "queued " .. name)
  T.assert(ap.pick(T, 1, get, "Close"), "closed the bench")
  T.assert(ap.wait_until(T, 1, function() return m().echoes[idx].decoded end, 60 * 40), "decoded " .. name)
end

T.assert(ap.wake(T, 1, get), "got up")
T.assert(m().mode == "on" and not m().solved, "a fresh chain")

-- Who: the tutorial vault (unguarded, the Villa fits)
fetch(1, nil)
T.assert(said("Echo I: glyph tablet"), "Echo I message")
local e1 = get().hold[#get().hold]
T.assert(e1.echo == 1 and not e1.hot, "Echo I is safe in the hold")
T.assert(mystery.echo_at(m(), 2) == nil, "Echo II stays locked until Echo I is decoded")
decode(1)
T.assert(#mystery.resonant_sites(m()) == 1 and mystery.resonant_sites(m())[1] == 2, "derelict 2 is Resonant")

-- Where: derelict 2 with the Seat (the Watchers ignore it)
fetch(2, 2)
T.assert(not m().vault_revealed, "the vault is still hidden")
decode(2)
T.assert(m().vault_revealed, "Echo II revealed the Resonant vault")
T.assert(said("Resonant vault"), "vault reveal message")

-- Key: derelict 3
fetch(3, 2)
T.assert(said("key fragment"), "the Key announces itself")
T.assert(not mystery.decodable(m(), 3), "the Key is not decoded, it is carried")

-- the Resonant vault opens to the Key
local vp = T.state().vault.pos
T.assert(ap.resize(T, 1, get, 1), "the Villa for the trip")
T.assert(ap.travel(T, 1, get, { vp[1], vp[2] + 2, vp[3] - 40 }, 4, 60 * 120), "flew to the Resonant vault")
T.assert(ap.wait_until(T, 1, function() return m().vault_open end, 120), "the vault opened")
T.assert(m().solved, "the chain is solved")
T.assert(said("Resonant vault opens"), "vault message")
local key_left = false
for _, it in ipairs(get().hold) do if it.echo == 3 then key_left = true end end
T.assert(not key_left, "the Key was used up")

-- beam up the Curio: hover over it, go down to the Tractor Room, pull
local tractor = require("sim.tractor")
local curio_c
for _, c in ipairs(tractor.candidates(T.state(), get(), 0, nil)) do if c.kind == "curio" then curio_c = c end end
T.assert(curio_c ~= nil, "the Curio is a beam target")
T.assert(ap.beam_up(T, 1, get, curio_c), "beamed up the Curio from the Tractor Room")
T.assert(ap.back_to_helm(T, 1, get), "back at the helm")
T.assert(T.state().vault.taken, "took the Curio")
local curio
for _, it in ipairs(get().hold) do if it.unique then curio = it end end
T.assert(curio and curio.name == m().curio and not curio.hot, "the unique Curio is in the hold")
T.assert(said(mystery.TEASER), "the teaser")
T.assert(not items.losable(get())[1] or not items.losable(get())[1].unique, "a unique Curio is never lost")

-- save and load: the solved chain persists
T.assert(ap.take_helm(T, 1, get), "helm")
T.assert(ap.resize(T, 1, get, 1), "Villa")
T.assert(ap.walk_to_station(T, 1, get, "bed"), "to the bed")
T.press(1, "use")
T.wait(1)
T.assert(ap.pick(T, 1, get, "Sleep"), "slept (and saved)")
local saved = T.state().tick
T.state().mystery.solved = false -- tamper, then load back
T.assert(ap.walk_to(T, 1, get, "bed"), "at the bed")
T.press(1, "use")
T.wait(1)
T.assert(ap.pick(T, 1, get, "Load"), "loaded")
T.assert(T.state().tick == saved, "back at the save")
T.assert(m().solved and m().vault_open and T.state().vault.taken, "chain, vault and Curio restored")
T.assert(items.find(get(), curio.uid) ~= nil, "the Curio is still aboard")
T.assert(vec.dist(T.state().vault.pos, vp) < 1e-6, "the vault sits where it did")
print(string.format("mystery: %s solved at tick %d, curio %s", m().cause, saved, curio.name))
