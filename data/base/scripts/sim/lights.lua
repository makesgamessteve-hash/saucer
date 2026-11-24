-- SPDX-License-Identifier: MIT
-- add-realistic-lighting: your saucer's light switches. Three lights, each on or off:
--   head  - two forward spotlights in the rim (they cast shadows) for looking into the dark
--   flood - a strong all-round light under the hull, to see where you are
--   cabin - the Villa's ceiling lamps, one per room
-- Keys 4 / 5 / 6 toggle them; a gamepad's one light button (Share / Capture / touchpad, or a back
-- paddle) taps for the headlights (the cabin lamps while you walk the Villa) and holds for the floods.
-- Lit up you are easier to see: headlights and floods add to your signature (sim/stealth.lua,
-- tuning in data/base/sentries/sentries.lua `stealth.lights`). The rendering is view/lights.lua.
local M = {}

M.DEFAULT = { head = false, flood = false, cabin = true }
M.HOLD = 30 -- ticks the pad's light button is held to switch the floods
M.NAMES = { head = "Headlights", flood = "Floodlights", cabin = "Cabin lights" }

-- -> the player's switches (older saves had none: the defaults)
function M.of(p)
  local l = p.lights
  if type(l) ~= "table" then
    l = { head = M.DEFAULT.head, flood = M.DEFAULT.flood, cabin = M.DEFAULT.cabin }
    p.lights = l
  end
  return l
end

function M.toggle(state, p, which, ctx)
  local l = M.of(p)
  l[which] = not l[which]
  if ctx then
    ctx.msg(state, p, M.NAMES[which] .. (l[which] and " on" or " off"))
    ctx.fx(state, p, "click")
  end
  return l[which]
end

-- what the pad's tap switches: the cabin lamps while walking the Villa, else the headlights
function M.tap_target(p)
  if p.mode == "walk" then return "cabin" end
  return "head"
end

function M.step(state, p, cmd, ctx)
  if p.mode == "wake" then return end
  if cmd:pressed("headlights") then M.toggle(state, p, "head", ctx) end
  if cmd:pressed("floods") then M.toggle(state, p, "flood", ctx) end
  if cmd:pressed("cabin_lights") then M.toggle(state, p, "cabin", ctx) end
  if cmd:held("lights") then
    p.lights_hold = (p.lights_hold or 0) + 1
    if p.lights_hold == M.HOLD then M.toggle(state, p, "flood", ctx) end
  elseif p.lights_hold then
    if p.lights_hold < M.HOLD then M.toggle(state, p, M.tap_target(p), ctx) end
    p.lights_hold = nil
  end
end

-- how much your lights add to your signature (none on foot: they are the saucer's, not yours)
function M.signature(p, S)
  local l = p.lights
  if not l or not S.lights or (p.mode == "foot" and p.excursion) then return 0 end
  return (l.head and S.lights.head or 0) + (l.flood and S.lights.flood or 0)
end

return M
