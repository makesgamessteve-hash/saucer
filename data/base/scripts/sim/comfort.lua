-- SPDX-License-Identifier: MIT
-- XR comfort. The engine's comfort filter turns a right-stick flick into one
-- tick of snap_left / snap_right (client setting, see saucer.xr.set_comfort)
-- and puts the chosen angle on the same tick as two more buttons (snap_a,
-- snap_b: no bits = the default 30 degrees, then 45, 60, 15), so the command stream
-- alone decides the result (replays stay deterministic). The comfort
-- settings panel (add-webxr-cockpit) is reachable from the title card and
-- the bed, in and out of the headset; it only ever touches client settings
-- (saucer.xr.set_comfort / save_comfort), never the sim, and says the same
-- thing on every machine.
local panel = require("sim.panel")
local M = {}

M.STEP = math.rad(15)
M.SNAP = math.rad(30)      -- the default angle (kept for mods and tests)
M.ANGLES = { 15, 30, 45, 60 }
M.VIGNETTES = { { 0, "Off" }, { 0.25, "Low" }, { 0.5, "Medium" }, { 0.75, "High" } }
-- touch-look-speed: the touch look sensitivity steps (comfort.txt look_sens)
M.LOOK_SENS = { 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0 }

-- "1.25x [###-]..." : the setting as a little slider (one mark per step)
function M.look_sens_text(v)
  local bar = {}
  for _, s in ipairs(M.LOOK_SENS) do bar[#bar + 1] = s <= v + 1e-6 and "#" or "-" end
  return string.format("%.2fx [%s]", v, table.concat(bar))
end

-- snap angle in radians carried by this command (15, 30, 45 or 60 degrees)
function M.angle(cmd)
  local code = 0
  if cmd:held("snap_a") then code = code + 1 end
  if cmd:held("snap_b") then code = code + 2 end
  return ((code + 1) % 4 + 1) * M.STEP
end

-- extra yaw (radians, + = left like a negative turn axis) for this command
function M.snap(cmd)
  local d = 0
  local a = M.angle(cmd)
  if cmd:pressed("snap_left") then d = d + a end
  if cmd:pressed("snap_right") then d = d - a end
  return d
end

-- touch-look-speed: a touch look drag arrives as angles (radians this tick),
-- carried on the aim_yaw / aim_pitch axes over +-AIM_RANGE
M.AIM_RANGE = math.pi / 2
function M.aim_yaw(cmd) return cmd:axis("aim_yaw") * M.AIM_RANGE end
function M.aim_pitch(cmd) return cmd:axis("aim_pitch") * M.AIM_RANGE end

-- yaw after this tick's smooth turn, the touch drag and any snap turn
function M.yaw(yaw, cmd, rate, dt)
  return saucer.math.wrap(yaw - cmd:axis("turn") * rate * dt - M.aim_yaw(cmd) + M.snap(cmd))
end

-- pitch after this tick's look rate and the touch drag, kept to +-limit
function M.pitch(pitch, cmd, rate, dt, limit)
  local v = pitch + cmd:axis("look") * rate * dt + M.aim_pitch(cmd)
  return v < -limit and -limit or (v > limit and limit or v)
end

-- ---- the comfort settings panel ----

local function next_of(list, value, key)
  for i, v in ipairs(list) do
    local x = key and v[key] or v
    if math.abs(x - value) < 1e-6 then return list[i % #list + 1] end
  end
  return list[1]
end

function M.vignette_name(strength)
  for _, v in ipairs(M.VIGNETTES) do
    if math.abs(v[1] - strength) < 0.13 then return v[2] end
  end
  return "Custom"
end

-- the rows (pure: they read the client's settings, never the sim)
function M.rows(state, p, ctx)
  local c = saucer.xr.comfort()
  local function change(tbl)
    saucer.xr.set_comfort(tbl, p.index)
    saucer.xr.save_comfort(p.index)
    ctx.msg(state, p, "Comfort setting changed")
  end
  return {
    { text = "Turning: " .. (c.snap and "snap" or "smooth"),
      hint = "Snap turns in steps; smooth turns while the stick is held",
      act = function() change({ snap = not c.snap }) end },
    { text = string.format("Snap angle: %d degrees", c.snap_turn), enabled = c.snap,
      hint = "How far one flick of the right stick turns you",
      act = function() change({ snap_turn = next_of(M.ANGLES, c.snap_turn) }) end },
    { text = string.format("Vignette: %s", M.vignette_name(c.vignette)),
      hint = "Darkens the edges of the view while you move or turn smoothly",
      act = function() change({ vignette = next_of(M.VIGNETTES, c.vignette, 1)[1] }) end },
    { text = "Touch look speed: " .. M.look_sens_text(c.look_sens or 1),
      hint = "How far a swipe on a touch screen turns you (resets to 0.5x after 2x)",
      act = function() change({ look_sens = next_of(M.LOOK_SENS, c.look_sens or 1) }) end },
    { text = "VR mode: " .. (c.mode == "seated" and "seated" or "standing"),
      hint = "The way the next VR session starts: seated at the cockpit eye, or standing on the floor",
      act = function() change({ mode = c.mode == "seated" and "standing" or "seated" }) end },
    { text = "Back", act = function(_, q)
      local back = q.panel and q.panel.back
      if back then panel.open(q, back) else panel.close(q) end
    end },
  }
end

-- open the settings panel from another panel (Back returns to it)
function M.open(p)
  local from = p.panel and p.panel.kind
  panel.open(p, "comfort")
  p.panel.back = from or nil
end

function M.register(ctx)
  panel.register("comfort", { title = "COMFORT SETTINGS", rows = function(state, p) return M.rows(state, p, ctx) end })
end

return M
