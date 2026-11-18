-- SPDX-License-Identifier: MIT
-- add-presentation-packaging: WebXR comfort and diegetic controls (render
-- only, never touches the sim state).
--  * seated sessions ("local" space) put the headset origin at the cockpit
--    eye; standing ones ("local-floor") put it on the floor, so the cockpit
--    is lowered by the eye height and the player's real height takes over;
--  * a comfort vignette closes in while the view moves or turns smoothly
--    (strength = saucer.xr.comfort().vignette, 0 turns it off);
--  * tracked controllers are drawn as hands, and the left wrist carries a
--    panel (charge, hold, beam lock) because the flat HUD is off in XR.
local avatar = require("sim.avatar")
local configs = require("sim.config")
local panel = require("sim.panel")
local M = {}

M.STAND_EYE = 1.62         -- interior eye height (saucer/interior.lua eye)
M.MOVE_FULL = 0.12         -- metres per frame that give the full vignette
M.TURN_FULL = 0.05         -- radians per frame that give the full vignette
M.SNAP_JUMP = 0.3          -- a yaw step this big is a snap turn: no vignette
M.EASE = 0.25

local last = {}            -- per view index: { pos, yaw, k }
local fb = { morph = false, hit = 99 } -- what the haptics saw last frame
M.stats = { frames = 0, vignettes = 0, hands = 0, panels = 0, pulses = 0 }

function M.reset()
  last = {}
  fb = { morph = false, hit = 99 }
  M.stats = { frames = 0, vignettes = 0, hands = 0, panels = 0, pulses = 0 }
end

-- the headset's reference space for this view: "seated", "standing" or nil
function M.space(v)
  if not v.xr then return nil end
  return saucer.xr.session()
end

-- shift a camera table for the session's reference space (in place)
function M.adjust(v, cam)
  if M.space(v) == "standing" then cam.pos = { cam.pos[1], cam.pos[2] - M.STAND_EYE, cam.pos[3] } end
  return cam
end

-- vignette strength for this frame's camera motion
function M.motion(i, cam, strength)
  local l = last[i]
  local k = 0
  if l then
    local dx, dy, dz = cam.pos[1] - l.pos[1], cam.pos[2] - l.pos[2], cam.pos[3] - l.pos[3]
    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
    local dyaw = math.abs(saucer.math.wrap(cam.yaw - l.yaw))
    if dyaw >= M.SNAP_JUMP then dyaw = 0 end
    if d > 5 then d = 0 end -- teleports (folds, docking) are cuts, not motion
    k = math.min(1, math.max(d / M.MOVE_FULL, dyaw / M.TURN_FULL))
    k = l.k + (k - l.k) * M.EASE
  end
  last[i] = { pos = cam.pos, yaw = cam.yaw, k = k }
  return k * strength
end

-- A headset-space point -> world. The engine keeps head, hands and joints flipped (x, z negated, see
-- sx_sdl_main.c) so that +z is forward; the eye matrices stay in the WebXR frame (forward is -z) and
-- sit rigidly on the cockpit, so what we draw must be un-flipped before the cockpit's yaw.
function M.world(cam, p)
  local r = avatar.rot(cam.yaw, { -p[1], p[2], -p[3] })
  return { cam.pos[1] + r[1], cam.pos[2] + r[2], cam.pos[3] + r[3] }
end

local CHARGE, HOLD, LOCK, DIM, FRAME = { 0.3, 0.9, 1, 1 }, { 1, 0.7, 0.25, 1 }, { 0.3, 1, 0.4, 1 }, { 0.25, 0.3, 0.35, 1 },
  { 0.12, 0.14, 0.18, 1 }

-- wrist panel bars -> list of { frac, colour } (charge, hold fill, beam lock)
function M.wrist(p, scan)
  local all = configs.all()
  -- add-on-foot-excursions: on foot the wrist shows the suit, the hands, a hand-lock's progress
  if p.mode == "foot" and p.excursion then
    local T = require("sim.excursion").tune()
    local s = math.max(0, math.min(1, (p.suit or 0) / T.suit.max))
    local w = p.excursion.work
    local f = w and math.min(1, w.t / w.total) or 0
    return { { s, s > 0.3 and CHARGE or HOLD }, { #(p.hands or {}) / T.hands, HOLD }, { f, f > 0 and LOCK or DIM } }
  end
  local charge = math.max(0, math.min(1, (p.ship.charge or 0) / all.max_charge))
  local hold = math.min(1, #(p.hold or {}) / require("sim.upgrades").hold_slots(p))
  local lock = scan and scan.ok and 1 or 0
  return { { charge, CHARGE }, { hold, HOLD }, { lock, lock > 0 and LOCK or DIM } }
end

-- a flat-shaded slab centred at c facing yaw (A.decal is 1 x 1 x 0.02)
local function box(v, A, c, yaw, w, h, depth, tint)
  local cy, sy = saucer.math.cos(yaw), saucer.math.sin(yaw)
  v:mesh(A.decal, { pos = { c[1] - cy * w / 2, c[2] - h / 2, c[3] + sy * w / 2 }, yaw = yaw,
                    scale = { w, h, depth }, tint = tint })
end

-- the controllers as hands, the left one with the wrist panel -> draw count
function M.hands(v, A, cam, p, scan)
  local n = 0
  local head = saucer.xr.head()
  local eye = head and M.world(cam, head) or cam.pos
  for _, h in ipairs(saucer.xr.hands()) do
    local pos = M.world(cam, h.pos)
    local f = avatar.rot(cam.yaw, { -h.fwd[1], h.fwd[2], -h.fwd[3] })
    local yaw = saucer.math.atan2(f[1], f[3])
    box(v, A, pos, yaw, 0.05, 0.03, 4, FRAME)
    n = n + 1
    if h.hand == "left" then
      local c = { pos[1], pos[2] + 0.07, pos[3] }
      local fy = saucer.math.atan2(eye[1] - c[1], eye[3] - c[3])
      box(v, A, c, fy, 0.12, 0.065, 1, FRAME)
      local cy, sy = saucer.math.cos(fy), saucer.math.sin(fy)
      local out = { sy * 0.004, 0, cy * 0.004 }
      for i, b in ipairs(M.wrist(p, scan)) do
        local w = 0.1 * math.max(0.02, b[1])
        local off = -0.05 + w / 2
        local bc = { c[1] + cy * off + out[1], c[2] + 0.03 - i * 0.016 + 0.004, c[3] - sy * off + out[3] }
        box(v, A, bc, fy, w, 0.01, 1, b[2])
        n = n + 1
      end
      n = n + 1
    end
  end
  return n
end

-- the size lever's handle by your right hip, where a pinch grabs it
function M.lever(v, A, cam)
  local pos, held = saucer.xr.lever()
  if not pos then return 0 end
  local w = M.world(cam, pos)
  box(v, A, { w[1], w[2] - 0.05, w[3] }, cam.yaw, 0.03, 0.12, 2, FRAME)
  box(v, A, w, cam.yaw, 0.07, 0.035, 3, held and LOCK or HOLD)
  return 2
end

-- haptics: one pulse when the fold starts, one when debris strikes the hull
-- (only ever a pulse: the camera never shakes or rolls in XR)
function M.feedback(p)
  local ship = p.ship
  local morphing = ship.morph and true or false
  local hit = ship.since_hit or 99
  if morphing and not fb.morph then
    saucer.xr.haptic("both", 0.6, 80)
    M.stats.pulses = M.stats.pulses + 1
  end
  if hit < fb.hit then
    saucer.xr.haptic("both", 1, 120)
    M.stats.pulses = M.stats.pulses + 1
  end
  fb.morph, fb.hit = morphing, hit
end

local WHITE, GREEN, AMBER, DIMC, CYANC = { 1, 1, 1, 1 }, { 0.4, 1, 0.5, 1 }, { 1, 0.75, 0.2, 1 }, { 0.5, 0.55, 0.6, 1 },
  { 0.4, 0.9, 1, 1 }

-- an open menu (title card, bed, comfort settings...) drawn head-locked in the middle of
-- each eye, big enough to read: the flat HUD is off in the headset -> rows drawn
function M.panel(v, state, p)
  if not p.panel then return 0 end
  local rows, title = panel.rows(state, p), panel.title(state, p)
  local s = math.max(1, math.min(v.width // 360, v.height // 240))
  local cw, rh = 8 * s, 11 * s
  local all, first = rows, 1
  local maxr = 9
  if #all > maxr then
    first = math.max(1, math.min(p.panel.sel - maxr // 2, #all - maxr + 1))
    rows = {}
    for i = first, first + maxr - 1 do rows[#rows + 1] = all[i] end
  end
  local chars = #title + 2
  for _, r in ipairs(rows) do chars = math.max(chars, #r.text + 4) end
  chars = math.min(chars, v.width // cw - 2)
  local w, h = chars * cw, (#rows + 3) * rh
  local x, y = v.width // 2 - w // 2, v.height // 2 - h // 2
  v:rect(x - cw, y - rh, w + 2 * cw, h + 2 * rh, { 0, 0.02, 0.06, 0.88 })
  v:text(x, y, title, AMBER, s)
  for i, r in ipairs(rows) do
    local sel = i + first - 1 == p.panel.sel
    local ry = y + (i + 1) * rh
    if sel then v:rect(x - cw // 2, ry - s, w + cw, rh - s, { 0.2, 0.5, 0.3, 0.6 }) end
    v:text(x, ry, ((sel and "> " or "  ") .. r.text):sub(1, chars), r.enabled == false and DIMC or (sel and GREEN or WHITE), s)
  end
  local cur = all[p.panel.sel]
  local foot = y + (#rows + 2) * rh
  v:text(x, foot, "STICK UP/DOWN  L TRIGGER: PICK", DIMC, math.max(1, s - 1))
  if cur and cur.hint then v:text(x, foot + rh, cur.hint:sub(1, chars * 2), CYANC, math.max(1, s - 1)) end
  M.stats.panels = M.stats.panels + 1
  return #rows
end

-- everything XR adds to a view after the scene: hands, the lever, a menu, then the vignette
function M.overlay(v, A, cam, p, scan, state)
  if not v.xr then return 0 end
  local n = M.hands(v, A, cam, p, scan) + M.lever(v, A, cam)
  if v.index == 1 then M.feedback(p) end
  if state and p.panel then M.panel(v, state, p) end
  local k = M.motion(v.index, cam, saucer.xr.comfort().vignette)
  M.stats.frames = M.stats.frames + 1
  M.stats.hands = M.stats.hands + n
  if k > 0.01 then
    v:vignette(k)
    M.stats.vignettes = M.stats.vignettes + 1
  end
  return n, k
end

return M
