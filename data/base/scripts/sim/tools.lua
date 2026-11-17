-- SPDX-License-Identifier: MIT
-- Suit tools on foot (OpenSpec add-home-among-stars, concept §8.3):
--   * Grapple (Scan on foot): fires along your view; when it hooks a wall,
--     floor or ceiling within 25 m it reels you there (around the derelict's
--     geometry, never through it). Costs suit charge.
--   * Cutter (hold the Override spike where there is no sentry to spike): 6 s
--     at a sealed shutter or a Lockdown seal cuts it open for good (a shutter)
--     or for this lockdown (a seal). Costs suit charge.
local vec = require("lib.vec")
local sm = saucer.math
local M = {}

local function game() return require("sim.game") end
local function ex() return require("sim.excursion") end
function M.tune() return require("sim.sentry").tune() end

local function dir_of(yaw, pitch)
  local c = sm.cos(pitch)
  return { sm.sin(yaw) * c, sm.sin(pitch), sm.cos(yaw) * c }
end

-- ---------- grapple ----------
function M.grapple_fire(state, p, ctx)
  local x = p.excursion
  local t = M.tune().grapple
  if x.grapple then return false end
  if p.suit < t.suit then
    ctx.msg(state, p, "Grapple: not enough suit charge")
    ctx.fx(state, p, "denied")
    return false
  end
  local eye, yaw, pitch = ex().viewpoint(p)
  local d = dir_of(yaw, pitch)
  local hit = saucer.physics.raycast(eye, d, t.range, 1)
  if not hit then
    ctx.msg(state, p, string.format("Grapple: nothing to hook within %d m", t.range))
    ctx.fx(state, p, "denied")
    return false
  end
  local stop = math.max(0, hit.t - 0.6)
  x.grapple = { to = vec.add(eye, vec.scale(d, stop)), t = 0, from = vec.copy(eye) }
  p.suit = p.suit - t.suit
  p.grapples = (p.grapples or 0) + 1
  ctx.msg(state, p, string.format("Grapple hooked %.0f m away: reeling in", hit.t))
  ctx.fx(state, p, "tractor")
  return true
end

-- reel the body toward the hook; -> true while the grapple is in charge
function M.grapple_step(state, p, dt)
  local x = p.excursion
  local g = x.grapple
  if not g then return false end
  local t = M.tune().grapple
  local b = x.body
  local T = ex().tune().body
  local hh = (b.crouch and T.crouch or T.stand) / 2
  local eye_off = (b.crouch and T.crouch_eye or T.eye)
  -- the hook point is where the eye goes; the body's centre follows
  local c = ex().center(b)
  local goal = { g.to[1], g.to[2] - eye_off + hh, g.to[3] }
  local d = vec.sub(goal, c)
  local l = vec.len(d)
  g.t = g.t + dt
  if l < 0.05 or g.t >= t.max_time then
    x.grapple = nil
    b.vy, b.ground = 0, false
    return false
  end
  local step = vec.scale(d, math.min(1, t.speed * dt / l))
  local moved, blocked = saucer.physics.move({ c[1], c[2] + 1e-6, c[3] }, T.radius, hh, step, 1)
  b.pos = { moved[1], moved[2] - hh, moved[3] }
  b.vy = 0
  if blocked > 0 and vec.len(vec.sub(moved, c)) < 1e-3 then
    -- stuck against something: let go
    x.grapple = nil
    b.ground = false
    return false
  end
  return true
end

-- ---------- cutter ----------
local function box_dist(q, mn, mx)
  local c = { vec.clamp(q[1], mn[1], mx[1]), vec.clamp(q[2], mn[2], mx[2]), vec.clamp(q[3], mn[3], mx[3]) }
  return vec.dist(c, q)
end

-- what the cutter would cut from here -> { kind = "shutter"|"seal", id/idx, dist } or nil
function M.cut_target(state, p)
  if not (p.mode == "foot" and p.excursion) or p.site == 0 then return nil end
  local t = M.tune().cutter
  local eye = ex().viewpoint(p)
  local site = p.site
  local best
  local r = game().ruin(site)
  for _, sh in ipairs(r and r.foot and r.foot.shutters or {}) do
    if game().shutter_closed(site, sh.id) then
      local d = box_dist(eye, sh.min, sh.max)
      if d <= t.reach and (not best or d < best.dist) then best = { kind = "shutter", id = sh.id, dist = d } end
    end
  end
  for i, def in ipairs(game().sentries(site)) do
    local dyn = state.sentries[site] and state.sentries[site][i]
    if def.kind == "lockdown" and dyn and #(dyn.sealed or {}) > 0 then
      for _, k in ipairs(dyn.sealed) do
        local bx = def.boxes[k]
        local d = bx and box_dist(eye, bx[1], bx[2])
        if d and d <= t.reach and (not best or d < best.dist) then best = { kind = "seal", idx = i, dist = d } end
      end
    end
  end
  return best
end

-- one tick of holding the cutter; -> true when there was something to cut
function M.cut_step(state, p, pressed, dt, ctx)
  local t = M.tune().cutter
  local tgt = M.cut_target(state, p)
  if not tgt then
    p.cut = nil
    return false
  end
  local key = tgt.kind .. ":" .. tostring(tgt.id or tgt.idx)
  if not p.cut or p.cut.key ~= key or p.cut.site ~= p.site then
    if p.suit < t.suit then
      if pressed then
        ctx.msg(state, p, "Cutter: not enough suit charge")
        ctx.fx(state, p, "denied")
      end
      return true
    end
    p.cut = { site = p.site, key = key, t = 0 }
    ctx.msg(state, p, string.format("Cutter on the %s: hold for %d s", tgt.kind == "shutter" and "shutter" or "seal", t.time))
    ctx.fx(state, p, "scan")
  end
  p.cut.t = p.cut.t + dt
  if p.cut.t < t.time then return true end
  p.cut = nil
  p.suit = math.max(0, p.suit - t.suit)
  if tgt.kind == "shutter" then
    state.locks = state.locks or {}
    state.locks[tostring(p.site) .. ":" .. tostring(tgt.id)] = state.tick
    game().open_shutter(p.site, tgt.id)
    ctx.msg(state, p, "The cutter bites through: the shutter slumps open for good.")
  else
    local def, dyn = game().sentries(p.site)[tgt.idx], state.sentries[p.site][tgt.idx]
    game().seal(def, dyn, false)
    dyn.st, dyn.t = "rest", M.tune().lockdown.rest
    ctx.msg(state, p, "The cutter slices the Lockdown seals: the hall's doors are open.")
  end
  p.cuts = (p.cuts or 0) + 1
  ctx.fx(state, p, "door")
  return true
end

return M
