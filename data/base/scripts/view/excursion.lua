-- SPDX-License-Identifier: MIT
-- Drawing on-foot excursions (OpenSpec add-on-foot-excursions). Render-only:
--   * the on-foot props of every nearby derelict: the strongroom shutter
--     (sliding up once its hand-lock turned), the hand-lock couplings, the
--     grid consoles, your Delicate finds and a lit frame round each
--     crawlspace's mouth
--   * on foot: your hand, the coin in it, the saucer folding into it and
--     the Seat unfolding out of it, other players' bodies
-- Nothing here writes the sim state.
local vec = require("lib.vec")
local configs = require("sim.config")
local game = require("sim.game")
local ex = require("sim.excursion")
local sm = saucer.math
local M = {}

M.NEAR = 260 -- props of sites whose foot features are this close to the camera

local function smooth(t) return t * t * (3 - 2 * t) end

-- 0 (closed) .. 1 (fully open) for a shutter this tick
function M.shutter_open(state, site, id, tick)
  local t0 = (state.locks or {})[ex.key(site, id)]
  if not t0 then return 0 end
  return smooth(vec.clamp((tick - t0) / (ex.tune().shutter_time * 60), 0, 1))
end

-- the props of one site's foot features -> draws
function M.site_props(v, A, state, p, site, f, tick)
  local n = 0
  for _, sh in ipairs(f.shutters) do
    local k = M.shutter_open(state, site, sh.id, tick)
    -- a hazard frame round the strongroom door, open or shut
    local l = sh.axis == 1 and 3 or 1
    local c0 = vec.scale(vec.add(sh.min, sh.max), 0.5)
    local hgt = sh.max[2] - sh.min[2]
    local wid = sh.max[l] - sh.min[l]
    local fc = { 1, 0.62, 0.1, 1 }
    for _, side in ipairs({ -1, 1 }) do
      local q = vec.copy(c0)
      q[l] = c0[l] + side * (wid / 2 + 0.1)
      v:mesh(A.unit, { pos = { q[1], sh.min[2] + hgt / 2, q[3] }, scale = { 0.2, hgt + 0.4, 0.2 }, tint = fc })
    end
    local tsc = { 0.2, 0.2, 0.2 }
    tsc[l] = wid + 0.4
    v:mesh(A.unit, { pos = { c0[1], sh.max[2] + 0.1, c0[3] }, scale = tsc, tint = fc })
    n = n + 3
    if k < 1 then
      local size = vec.sub(sh.max, sh.min)
      local c = vec.scale(vec.add(sh.min, sh.max), 0.5)
      -- it slides up into the wall
      c[2] = c[2] + size[2] * k
      local sc = { size[1], size[2] * (1 - k * 0.9), size[3] }
      v:mesh(A.foot.shutter, { pos = c, scale = sc, tex = A.tex.hull, palette = A.pal.base })
      n = n + 1
    end
  end
  for _, l in ipairs(f.locks) do
    local open = ex.lock_open(state, site, l.id)
    v:mesh(A.foot.lock, { pos = l.pos, yaw = l.yaw + sm.pi, palette = A.pal.base })
    local glow = open and { 0.3, 1, 0.45, 0.8 } or { 1, 0.7, 0.2, 0.5 + 0.3 * sm.sin(tick * 0.08) }
    v:billboard(A.tex.glow, { l.pos[1], l.pos[2] + 0.55, l.pos[3] }, 0.35, { palette = A.pal.base, tint = glow })
    n = n + 2
  end
  for _, c in ipairs(f.consoles) do
    local down = ex.grid_down(state, site)
    v:mesh(A.foot.console, { pos = c.pos, yaw = c.yaw + sm.pi, palette = A.pal.base })
    v:billboard(A.tex.glow, { c.pos[1], c.pos[2] + 0.7, c.pos[3] }, 0.45,
                { palette = A.pal.base, tint = down and { 0.3, 1, 0.5, 0.6 } or { 1, 0.3, 0.25, 0.6 } })
    n = n + 2
  end
  -- your Delicate finds still in the chamber
  if p then
    for _, d in ipairs(f.delicates) do
      if not p.looted["delicate:" .. ex.key(site, d.id)] then
        v:mesh(A.unit, { pos = d.pos, yaw = tick * 0.03, scale = { 0.22, 0.34, 0.22 }, tint = { 0.6, 0.95, 1, 1 } })
        v:billboard(A.tex.glow, d.pos, 0.7, { palette = A.pal.base, tint = { 0.6, 0.9, 1, 0.45 } })
        n = n + 2
      end
    end
  end
  -- a lit frame round the crawlspace mouth (it is easy to miss in a great hall)
  local m = f.route[1]
  local ch = f.channel
  local mouth = { m[1], m[2], m[3] }
  mouth[ch.axis] = (ch.sign > 0 and f.crawl[1][ch.axis] or f.crawl[2][ch.axis]) - ch.sign * 0.05
  local l = ch.axis == 1 and 3 or 1
  for _, side in ipairs({ -1, 1 }) do
    local q = { mouth[1], mouth[2] + ch.h / 2, mouth[3] }
    q[l] = ch.mid + side * (ch.w / 2 + 0.08)
    local sc = { 0.08, ch.h + 0.16, 0.08 }
    v:mesh(A.unit, { pos = q, scale = sc, tint = { 0.95, 0.72, 0.12, 1 } })
    n = n + 1
  end
  local top = { mouth[1], mouth[2] + ch.h + 0.08, mouth[3] }
  top[l] = ch.mid
  local tsc = { 0.08, 0.08, 0.08 }
  tsc[l] = ch.w + 0.32
  v:mesh(A.unit, { pos = top, scale = tsc, tint = { 0.95, 0.72, 0.12, 1 } })
  return n + 1
end

-- every nearby site's props -> draws
function M.props(v, A, state, p, cam)
  local n = 0
  for i in ipairs(state.sector.sites) do
    local r = game.ruin(i)
    local f = r and r.foot
    if f and vec.dist(f.route[4], cam.pos) < M.NEAR then n = n + M.site_props(v, A, state, p, i, f, state.tick) end
  end
  return n
end

-- in front of the camera, low and to the right: where your hand holds the coin
function M.hand_pose(eye, yaw, pitch) return require("view.station").hand_pose(eye, yaw, pitch) end

-- the saucer folding into your hand / the Seat growing out of it -> pose or nil
function M.morph_pose(p, hand)
  local e = p.excursion
  local ship = p.ship
  if not e or not ship.morph then return nil end
  local t = smooth(ex.morph_t(p))
  local coin = configs.get(ex.pocket_size()).diameter
  if e.coin == "fold" then
    local from = ship.morph.from
    local c = configs.get(from)
    local start = ship.morph.pos
    local k = (coin / c.diameter) ^ t
    local f = (k - coin / c.diameter) / (1 - coin / c.diameter)
    return { size = from, pos = vec.add(hand, vec.scale(vec.sub(start, hand), f)), scale = k,
             yaw = ship.morph.yaw + sm.pi * (1 - f) * 0.5 }
  end
  if e.coin == "grow" and e.deploy then
    local c = configs.get(ship.size)
    local k0 = coin / c.diameter
    local k = k0 ^ (1 - t)
    local f = (k - k0) / (1 - k0)
    return { size = ship.size, pos = vec.add(hand, vec.scale(vec.sub(e.deploy.pos, hand), f)), scale = k,
             yaw = ship.yaw + sm.pi * f * 0.5 }
  end
  return nil
end

-- your own view on foot: the hand, the coin, the folding saucer -> draws
function M.own(v, A, state, p, cam)
  local n = 0
  local e = p.excursion
  local hand = M.hand_pose(cam.pos, cam.yaw, cam.pitch)
  local mp = M.morph_pose(p, hand)
  if mp then
    local m = A.saucer[mp.size]
    local c = configs.get(mp.size)
    v:mesh(m.hull, { pos = mp.pos, yaw = mp.yaw, scale = mp.scale, tex = A.tex.hull, palette = A.pal.base })
    if c.interior then
      v:mesh(A.glass, { pos = mp.pos, yaw = mp.yaw, scale = mp.scale, ghost = true, tint = { 0.55, 0.8, 1, 0.3 } })
    else
      v:mesh(m.dome, { pos = mp.pos, yaw = mp.yaw, scale = mp.scale, ghost = true, tint = { 0.55, 0.8, 1, 0.3 } })
    end
    local dia = c.diameter * mp.scale
    if dia < 1.5 then
      v:billboard(A.tex.glow, mp.pos, math.max(0.05, dia * 0.9), { palette = A.pal.base, tint = { 0.6, 0.9, 1, 0.35 } })
    end
    n = n + 3
  end
  local show = e.coin == "hand" or e.coin == "fold" or (e.coin == "grow" and ex.morph_t(p) < 0.25)
  if show and not v.xr then
    v:mesh(A.hand, { pos = hand, yaw = cam.yaw, pitch = 0 })
    n = n + 1
    if e.coin == "hand" then
      v:mesh(A.saucer[ex.pocket_size()].hull, { pos = { hand[1], hand[2] + 0.012, hand[3] }, yaw = state.tick * 0.02,
                                                tex = A.tex.hull, palette = A.pal.base })
      n = n + 1
    end
  end
  -- what is in your hands rides along low on the left
  for i, it in ipairs(p.hands or {}) do
    if not v.xr then
      local f, r = vec.aim(cam.yaw, cam.pitch), vec.right(cam.yaw)
      local q = vec.add(cam.pos, vec.add(vec.scale(f, 0.5), vec.add(vec.scale(r, -0.2 - i * 0.05), { 0, -0.24, 0 })))
      v:mesh(A.unit, { pos = q, yaw = state.tick * 0.02 + i, scale = 0.05,
                       tint = it.delicate and { 0.6, 0.95, 1, 1 } or { 1, 0.8, 0.4, 1 } })
      n = n + 1
    end
  end
  return n
end

-- other players walking a derelict -> draws
function M.others(v, A, state, p)
  local n = 0
  for _, o in ipairs(state.players) do
    if o ~= p and o.mode == "foot" and o.excursion then
      local b = o.excursion.body
      v:mesh(A.person, { pos = b.pos, yaw = b.yaw, scale = b.crouch and { 1, 0.5, 1 } or nil })
      n = n + 1
    end
  end
  return n
end

-- the chase camera on foot: a little behind and above your shoulder
function M.chase(p)
  local b = p.excursion.body
  local eye = ex.eye(b)
  local f = vec.fwd(b.yaw)
  local back = b.crouch and 1.6 or 3.0
  return { pos = { eye[1] - f[1] * back, eye[2] + 0.7, eye[3] - f[3] * back }, yaw = b.yaw, pitch = b.pitch - 0.15,
           fov = 70, near = 0.05, far = 4000 }
end

return M
