-- SPDX-License-Identifier: MIT
-- Networked co-op (OpenSpec add-home-among-stars). Run by
-- tools/net_loopback.cmake as two processes on loopback: a host (slot 1)
-- and a guest (slot 2, in a WebXR session) play one universe in lockstep.
-- Both processes run this same script on the same shared state; each one's
-- injected inputs only reach its own slot, so the script drives the whole
-- game and every decision is the same on both machines. Inputs land `delay`
-- ticks after they are sampled, so every discrete step waits delay + 2 ticks.
-- The host decorates the dome (a placed lamp and aquarium, a find on a
-- display slot, a planted bed), the two Villas dock, the guest walks into the
-- host's dome and admires the display. The cmake driver then checks that
-- both machines compared state hashes and ended on the same final hash.
local T = saucer.test
local ap = require("sim.autopilot")
local panel = require("sim.panel")
local decor = require("sim.decor")
local items = require("sim.items")
local avatar = require("sim.avatar")
local homeedit = require("sim.homeedit")
local NS = saucer.net.status()
T.assert(NS and NS.max_players == 2, "a two-player network session")
local D = NS.delay
local ME = NS.slot
local function P(i) return function() return T.state().players[i] end end
local function step(n) T.wait(n or (D + 2)) end
local function press(i, a) T.press(i, a, 1, true) step() end
-- a panel row by its prefix, one stick flick at a time (inputs arrive late)
local function pick(i, prefix)
  for _ = 1, 40 do
    local p = P(i)()
    if not p.panel then return false end
    local want = panel.find(T.state(), p, prefix)
    if not want then return false end
    if p.panel.sel == want then
      press(i, "use")
      return true
    end
    T.axis(i, "move_z", -1, 1, true)
    step()
  end
  return false
end
local function close(i)
  if P(i)().panel then pick(i, "Close") end
  return not P(i)().panel
end
-- Place from the planner enters edit mode; leave it before Use opens a station
local function leave_edit(i)
  if not homeedit.on(P(i)()) then return true end
  press(i, "edit")
  return not homeedit.on(P(i)())
end
local function last(i)
  local m = P(i)().msgs
  return m[#m] and m[#m].text or ""
end
local function until_(f, n)
  for _ = 1, n or 600 do
    if f() then return true end
    T.wait(1)
  end
  return f()
end

-- the guest wears a headset (client state only: it never reaches the sim)
if ME == 2 then
  T.xr({ available = 1, session = 1, views = 2, head_pos = { 0, 1.2, 0 }, head_fwd = { 0, 0, 1 } })
  T.assert(saucer.xr.session() == "seated", "the guest is in XR")
end

-- 1. the guest's slot joins on its first frame; both get up
T.assert(until_(function() return #T.state().players == 2 end, 120), "player 2 joined over the network")
for i = 1, 2 do
  T.assert(until_(function()
    if P(i)().mode ~= "wake" then return true end
    T.press(i, "use", 1, true)
    step()
    return P(i)().mode ~= "wake"
  end, 60), "player " .. i .. " got up")
end

-- 2. the host decorates: an aquarium and the starter lamp from the planner
local host = P(1)
decor.buy_furniture(host(), "aquarium")
T.assert(ap.walk_to(T, 1, host, "planner", 0.3, 2400), "host at the planner")
T.assert(ap.look(T, 1, host, -1.5708, 0), "host faces the free floor")
press(1, "use")
T.assert(host().panel and host().panel.kind == "planner", "the planner is open")
T.assert(pick(1, "Place Aquarium"), "started placing the aquarium")
T.assert(until_(function()
  if host().decor and #host().decor.placed >= 1 then return true end
  T.press(1, "use", 1, true)
  step()
  return host().decor and #host().decor.placed >= 1
end, 40), "one piece placed: " .. last(1))
T.assert(leave_edit(1), "left edit after the aquarium")
T.assert(ap.look(T, 1, host, 0, 0), "host turns")
press(1, "use")
T.assert(pick(1, "Place Floor lamp"), "started placing the lamp")
T.assert(until_(function()
  if host().decor and #host().decor.placed >= 2 then return true end
  T.press(1, "use", 1, true)
  step()
  return host().decor and #host().decor.placed >= 2
end, 40), "two pieces placed: " .. last(1))
T.assert(leave_edit(1), "left edit after the lamp")

-- a find on display slot 1 (an identified Curio from the hold)
local it = items.stamp(host(), { name = "Lucid Lens of Stillness", type = "lens", value = 40, size = 1 }, 2, nil)
it.ident, it.category = true, "curio"
host().hold[#host().hold + 1] = it
T.assert(ap.walk_to(T, 1, host, "display1", 0.25, 2400), "host at display slot 1")
press(1, "use")
T.assert(host().panel and host().panel.kind == "display", "display slot panel")
T.assert(pick(1, "Display "), "put the lens on display")
T.assert(host().decor.display[1] and host().decor.display[1].uid == it.uid, "the lens is on the plinth")

-- the garden: plant glowmoss and water it
T.assert(ap.walk_to(T, 1, host, "garden", 0.3, 3600), "host at the garden")
press(1, "use")
T.assert(pick(1, "Plant Glowmoss in bed 1"), "planted bed 1")
T.assert(pick(1, "Water bed 1"), "watered bed 1")
local comfort = decor.comfort(T.state(), host())
T.assert(comfort >= 8, "a comfortable dome: " .. comfort)
T.assert(close(1), "garden closed")

-- 3. dock: the host asks from the party panel, the guest accepts
local guest = P(2)
T.assert(require("sim.coop").can_dock(T.state(), host(), guest()), "the Villas are close enough to dock")
press(1, "map")
T.assert(pick(1, "Party"), "host opens the party panel")
T.assert(pick(1, "Dock with P2"), "host asks to dock")
press(2, "map")
T.assert(pick(2, "Party"), "guest opens the party panel")
T.assert(pick(2, "Accept dock with P1"), "guest accepts")
T.assert(require("sim.coop").docked(T.state(), host(), guest()), "docked")
T.assert(pick(2, "Visit P1"), "guest steps into the host's dome")
T.assert(guest().visiting == 1, "guest is visiting P1")
T.assert(close(2) and close(1), "panels closed")

-- 4. the guest walks the decorated dome to the display and admires it
local vg = function() return { body = guest().vbody } end
T.assert(ap.walk_to(T, 2, vg, "display1", 0.25, 3600), "guest reaches the display in the host's dome")
press(2, "use")
local ad = guest().admired
T.assert(ad and ad[1] and ad[1].host == 1 and ad[1].name == items.label(it), "the guest admired the host's lens")
close(2)
-- the guest walks into the aquarium: it is solid for guests too
local aq = host().decor.placed[1]
T.assert(aq.kind == "aquarium", "aquarium first")
T.assert(avatar.blocked(avatar.layout(), aq.deck, aq.x, aq.z, require("sim.home").solids(avatar.layout(), host())),
  "placed furniture blocks guests")

-- 5. a while longer of both playing: the guest heads home, both take the helm
press(2, "map")
T.assert(pick(2, "Party"), "party again")
T.assert(pick(2, "Return"), "guest goes home")
close(2)
T.assert(ap.walk_to(T, 1, host, "helm", 0.3, 2400), "host walks to the helm")
press(1, "use")
T.assert(host().mode == "helm", "host at the helm")
for _ = 1, 240 do
  T.axis(1, "lift", 1, 1, true)
  T.axis(2, "turn", 0.5, 1, true)
  T.wait(1)
end
local st = saucer.net.status()
T.assert((st.state == "running" or st.state == "closed") and st.checks >= 5, "hashes compared: " .. st.checks)
print(string.format("netplay slot %d: tick %d comfort %d checks %d rtt %d", ME, T.state().tick, comfort, st.checks, st.rtt))
