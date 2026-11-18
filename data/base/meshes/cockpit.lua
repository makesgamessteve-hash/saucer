-- SPDX-License-Identifier: MIT
-- Hero meshes: the cockpit props (OpenSpec add-mesh-builder). Code-generated,
-- retro low-poly, in the style of the Villa's helm and beam console. Local +z
-- is away from the operator, y is up, the origin is on the floor / table top.
--   params.kind = "console": the helm desk (params.w, params.d, params.h: the
--                 box it fills; a sloped, lit panel, a button row, a radar well)
--   params.kind = "lever":   the size lever, a base plate with three detents
--                 (nodes: handle, pitching about the base of the shaft)
--   params.kind = "orb":     the throttle orb in its gimbal ring (nodes: orb,
--                 tilting about the socket)
-- Collision volumes are named: the lever's "grab" sphere is where a pinch takes
-- the handle (the engine's reach, SX_XR_LEVER_REACH, is the same 12 cm).
local kit = require("lib.meshkit")
local P = kit.part
local sm = saucer.math

local STEEL, DARK, FRAME = { 0.62, 0.66, 0.72 }, { 0.14, 0.15, 0.18 }, { 0.3, 0.32, 0.4 }
local AMBER, CYAN, GREEN = { 1.0, 0.75, 0.3 }, { 0.35, 0.9, 1.0 }, { 0.3, 1.0, 0.6 }

local function box(x0, y0, z0, x1, y1, z1, color, emissive)
  return P("box", { min = { x0, y0, z0 }, max = { x1, y1, z1 }, color = color, emissive = emissive })
end

-- the helm desk: fills x in [-w/2, w/2], z in [-d/2, d/2], y in [0, h]
local function console(params)
  local w, d, h = params.w or 2.2, params.d or 0.35, params.h or 0.32
  local color = params.color or FRAME
  local parts, hw, hd = {}, w / 2, d / 2
  local function add(p) parts[#parts + 1] = p end
  add(box(-hw, 0, -hd, hw, h - 0.05, hd, color))                               -- the body
  add(box(-hw - 0.05, h - 0.05, -hd - 0.1, hw + 0.05, h, hd + 0.02,
          { color[1] * 0.75, color[2] * 0.75, color[3] * 0.75 }))              -- the top
  add(box(-hw + 0.04, 0, -hd - 0.04, hw - 0.04, 0.06, -hd, DARK))              -- the kick plate
  -- a radar well in the middle, ringed in light
  add(P("cylinder", { c = { 0, h, 0 }, r = 0.24, h = 0.012, seg = 16, color = { 0.05, 0.12, 0.1 }, emissive = 0.6 }))
  add(P("ring", { c = { 0, h, 0 }, rin = 0.24, r = 0.27, h = 0.02, seg = 16, color = GREEN, emissive = 1 }))
  -- two button banks either side of the well, tilted toward the pilot, and a lit strip along the front
  for _, s in ipairs({ -1, 1 }) do
    for k = 0, 3 do
      local x = s * (0.42 + k * 0.1)
      add(box(x - 0.035, h, -hd + 0.03, x + 0.035, h + 0.022, -hd + 0.09,
              (k + (s > 0 and 1 or 0)) % 3 == 0 and AMBER or CYAN, 1))
    end
    add(box(s * 0.4 - 0.02, h, -hd + 0.01, s * 0.82 + 0.02, h + 0.004, -hd + 0.12, DARK))
    add(box(s * (hw - 0.06) - 0.05, h, -0.04, s * (hw - 0.06) + 0.05, h + 0.05, 0.1, STEEL)) -- a grab handle
  end
  add(box(-hw + 0.1, h - 0.03, -hd - 0.105, hw - 0.1, h - 0.02, -hd - 0.1, CYAN, 0.8))
  -- a hood over the back edge and two status lamps on it
  add(box(-hw, h, hd - 0.04, hw, h + 0.07, hd, { color[1] * 0.6, color[2] * 0.6, color[3] * 0.6 }))
  add(box(-0.06, h + 0.07, hd - 0.04, -0.02, h + 0.09, hd - 0.02, GREEN, 1))
  add(box(0.02, h + 0.07, hd - 0.04, 0.06, h + 0.09, hd - 0.02, AMBER, 1))
  return { parts = parts,
           collision = { { name = "body", shape = "box", min = { -hw - 0.05, 0, -hd - 0.1 }, max = { hw + 0.05, h + 0.09, hd + 0.02 } } },
           budget = { tris = 800 } }
end

-- the size lever: pitching the handle up is "bigger", down is "smaller" (one detent each)
local function lever()
  local parts = {}
  local function add(p) parts[#parts + 1] = p end
  add(box(-0.07, -0.02, -0.1, 0.07, 0.0, 0.1, DARK))                                   -- the base plate
  add(box(-0.012, 0.0, -0.085, 0.012, 0.012, 0.085, { 0.05, 0.06, 0.08 }))               -- the slot
  for k = -1, 1 do                                                                       -- three detents
    add(box(-0.03, 0.0, k * 0.07 - 0.008, 0.03, 0.016, k * 0.07 + 0.008, k == 0 and AMBER or STEEL, k == 0 and 0.7 or nil))
  end
  add(P("cylinder", { c = { 0, 0, 0 }, r = 0.032, h = 0.05, seg = 8, color = STEEL, pos = { 0, 0, 0 }, roll = sm.pi / 2 }))
  -- the handle (node): a shaft up from the pivot and a lit knob
  add(P("cylinder", { c = { 0, 0.02, 0 }, r = 0.014, h = 0.16, seg = 6, color = STEEL, node = "handle" }))
  add(P("sphere", { c = { 0, 0.18, 0 }, r = 0.04, h = 0.04, seg = 8, rings = 2, color = AMBER, emissive = 0.6, node = "handle" }))
  return { parts = parts,
           nodes = { handle = { pivot = { 0, 0.02, 0 }, axis = "pitch" } },
           collision = { { name = "grab", shape = "sphere", c = { 0, 0.18, 0 }, r = 0.12 },
                         { name = "base", shape = "box", min = { -0.07, -0.02, -0.1 }, max = { 0.07, 0.016, 0.1 } } },
           budget = { tris = 500 } }
end

-- the throttle orb: a ball on a stalk in a gimbal ring; it tilts toward the push
local function orb()
  local parts = {}
  local function add(p) parts[#parts + 1] = p end
  add(P("cylinder", { c = { 0, -0.02, 0 }, r = 0.1, h = 0.04, seg = 12, color = DARK }))
  add(P("ring", { c = { 0, 0.02, 0 }, rin = 0.06, r = 0.1, h = 0.03, seg = 12, color = STEEL }))
  for k = 0, 3 do
    add(box(-0.01, 0.05, 0.075, 0.01, 0.075, 0.1, CYAN, 0.6))
    parts[#parts].yaw = sm.tau * k / 4
  end
  add(P("cylinder", { c = { 0, 0.04, 0 }, r = 0.012, h = 0.08, seg = 6, color = STEEL, node = "orb" }))
  add(P("sphere", { c = { 0, 0.13, 0 }, r = 0.055, h = 0.055, seg = 10, rings = 3, color = CYAN, emissive = 0.7, node = "orb" }))
  add(P("ring", { c = { 0, 0.13, 0 }, rin = 0.05, r = 0.068, h = 0.012, seg = 10, color = AMBER, emissive = 0.8, node = "orb" }))
  return { parts = parts,
           nodes = { orb = { pivot = { 0, 0.04, 0 }, axis = "pitch" } },
           collision = { { name = "grab", shape = "sphere", c = { 0, 0.13, 0 }, r = 0.09 } },
           budget = { tris = 500 } }
end

return function(params, _rng)
  local k = params.kind or "console"
  if k == "lever" then return lever() end
  if k == "orb" then return orb() end
  return console(params)
end
